import tkinter as tk
from tkinter import scrolledtext, messagebox, ttk
from PIL import Image, ImageTk
import threading
import requests
import json
import os
import sys
import subprocess
import time
import queue
import platform
import webbrowser
import re

# --- Cross-Platform Compatibility Layer ---

# 1. Native macOS Speech (M1/M2/M3 Optimized)
MACOS_SPEECH_ENABLED = False
if sys.platform == "darwin":
    try:
        import objc
        from AppKit import NSApplication
        from Speech import SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest
        from AVFoundation import AVAudioEngine, AVAudioSession, AVAudioSessionCategoryRecord, AVAudioSessionModeMeasurement
        from Foundation import NSLocale
        MACOS_SPEECH_ENABLED = True
    except ImportError:
        pass

# 2. Resilient Neural Voice (edge-tts)
NEURAL_VOICE_ENABLED = False
try:
    import asyncio
    import edge_tts
    import tempfile
    NEURAL_VOICE_ENABLED = True
except ImportError:
    pass

# 3. Generic STT Fallback
FALLBACK_STT_ENABLED = False
try:
    import speech_recognition as sr
    FALLBACK_STT_ENABLED = True
except ImportError:
    pass

# --- Configuration ---
OLLAMA_HOST = "http://localhost:11434"
MEMORY_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "josie_memory.json")

MODELS = {
    "Stheno 8B (v3.1)": {
        "tag": "adi0adi/ollama_stheno-8b_v3.1_q6k",
        "temp": 1.2,
        "ctx": 8192,
        "penalty": 1.1,
        "description": "Premium 1-on-1 Roleplay Specialist"
    },
    "Self After Dark": {
        "tag": "gurubot/self-after-dark:latest",
        "temp": 1.0,
        "ctx": 8192,
        "penalty": 1.1,
        "description": "Realistic Emotional Conversations"
    },
    "Vanessa": {
        "tag": "draganis/vanessa:latest",
        "temp": 0.9,
        "ctx": 4096,
        "penalty": 1.1,
        "description": "Versatile RP Assistant"
    },
    "Xwin-MLEWD (7B)": {
        "tag": "leeplenty/xwin-mlewd-v0.2:7b",
        "temp": 1.1,
        "ctx": 8192,
        "penalty": 1.1,
        "description": "Powerful & Diverse Roleplay Expert"
    }
}

VOICES = {
    "Jenny (US)": "en-US-JennyNeural",
    "Ava (US)": "en-US-AvaNeural",
    "Emma (US)": "en-US-EmmaNeural",
    "Sonia (UK)": "en-GB-SoniaNeural",
    "Maisie (UK)": "en-GB-MaisieNeural"
}

# --- Aesthetic Constants ---
BG_COLOR = "#0D0D0D"
SURFACE_COLOR = "#1A1A1A"
DRAWER_COLOR = "#121212"
ACCENT_COLOR = "#F48FB1"
REC_COLOR = "#FF5252"
TEXT_COLOR = "#FFFFFF"
SECONDARY_TEXT = "#B0BEC5"
STATUS_COLOR = "#81C784"
USER_MSG_BG = "#303F9F"
BOT_MSG_BG = "#262626"
FONT_FAMILY = "Helvetica Neue" if sys.platform == "darwin" else "Segoe UI" if sys.platform == "win32" else "Helvetica"

def get_resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(base_path, relative_path)
    if not os.path.exists(path):
        executable_path = os.path.dirname(sys.executable)
        path = os.path.join(executable_path, "..", "Resources", relative_path)
    return path

class OllamaWrapper:
    def __init__(self, host=OLLAMA_HOST):
        self.host = host.rstrip("/") + "/api/generate"
        self.model_key = list(MODELS.keys())[0]
        self.context = None
        self._load_memory()

    def _load_memory(self):
        """Load persisted memory from disk on startup."""
        try:
            if os.path.exists(MEMORY_FILE):
                with open(MEMORY_FILE, "r") as f:
                    data = json.load(f)
                saved_model = data.get("model_key")
                if saved_model and saved_model in MODELS:
                    self.model_key = saved_model
                self.context = data.get("context")
        except Exception:
            self.context = None

    def _save_memory(self):
        """Persist current context to disk."""
        try:
            with open(MEMORY_FILE, "w") as f:
                json.dump({"model_key": self.model_key, "context": self.context}, f)
        except Exception:
            pass

    def _delete_memory(self):
        """Wipe the memory file from disk."""
        try:
            if os.path.exists(MEMORY_FILE):
                os.remove(MEMORY_FILE)
        except Exception:
            pass

    def set_model(self, model_key):
        if model_key in MODELS:
            self.model_key = model_key
            self.context = None
            self._delete_memory()

    def clear_memory(self):
        self.context = None
        self._delete_memory()

    def generate(self, prompt: str) -> str:
        config = MODELS[self.model_key]
        payload = {
            "model": config["tag"],
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": config["temp"],
                "num_ctx": config["ctx"],
                "repeat_penalty": config["penalty"]
            },
            "context": self.context
        }
        try:
            response = requests.post(self.host, json=payload, timeout=None)
            if response.status_code == 200:
                data = response.json()
                self.context = data.get("context")
                self._save_memory()
                return data["response"]
            return f"Error: Status {response.status_code}"
        except:
            return "Error: JOSIE disconnected. Is Ollama running?"

josie_client = OllamaWrapper()

class JOSIEChatGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("JOSIE AI")
        self.root.geometry("600x1000")
        self.root.configure(bg=BG_COLOR)
        
        self.voice_enabled = tk.BooleanVar(value=NEURAL_VOICE_ENABLED)
        self.is_listening = False
        self.stt_queue = queue.Queue()

        # Audio Engine State
        self.audio_engine = None
        self.recognition_request = None
        self.recognition_task = None
        self.recognizer = None

        self.root.grid_columnconfigure(0, weight=1)
        self.root.grid_rowconfigure(1, weight=1)

        # 1. HEADER
        self.header = tk.Frame(root, bg=BG_COLOR, pady=15)
        self.header.grid(row=0, column=0, sticky="ew")
        self._setup_avatar()

        self.title = tk.Label(self.header, text="J.O.S.I.E.", font=(FONT_FAMILY, 32, "bold"), fg=ACCENT_COLOR, bg=BG_COLOR)
        self.title.pack()
        self.sub_title = tk.Label(self.header, text="Just One Sexually Involved E-girl", font=(FONT_FAMILY, 12, "italic"), fg=SECONDARY_TEXT, bg=BG_COLOR)
        self.sub_title.pack()

        # Tools
        self.sys_frame = tk.Frame(self.header, bg=BG_COLOR, pady=10)
        self.sys_frame.pack()
        tk.Button(self.sys_frame, text="⬇️ Download Ollama", command=self.download_ollama, bg="#2c2c2c", fg=ACCENT_COLOR, font=(FONT_FAMILY, 9, "bold"), relief="flat", padx=10, cursor="hand2").pack(side="left", padx=5)
        tk.Button(self.sys_frame, text="📥 Install E-girls", command=self.install_models, bg="#2c2c2c", fg=STATUS_COLOR, font=(FONT_FAMILY, 9, "bold"), relief="flat", padx=10, cursor="hand2").pack(side="left", padx=5)

        # Settings
        self.settings_frame = tk.Frame(self.header, bg=BG_COLOR, pady=10)
        self.settings_frame.pack()
        
        tk.Label(self.settings_frame, text="Model Flavor:", font=(FONT_FAMILY, 9, "bold"), fg=ACCENT_COLOR, bg=BG_COLOR).grid(row=0, column=0, padx=5)
        self.model_var = tk.StringVar(value=list(MODELS.keys())[0])
        self.model_selector = ttk.Combobox(self.settings_frame, textvariable=self.model_var, values=list(MODELS.keys()), state="readonly", width=18)
        self.model_selector.grid(row=1, column=0, padx=5, pady=5)
        self.model_selector.bind("<<ComboboxSelected>>", self.on_model_change)
        
        tk.Label(self.settings_frame, text="Voice Accent:", font=(FONT_FAMILY, 9, "bold"), fg=ACCENT_COLOR, bg=BG_COLOR).grid(row=0, column=1, padx=5)
        self.voice_var = tk.StringVar(value="Jenny (US)")
        self.voice_selector = ttk.Combobox(self.settings_frame, textvariable=self.voice_var, values=list(VOICES.keys()), state="readonly", width=18)
        self.voice_selector.grid(row=1, column=1, padx=5, pady=5)
        if not NEURAL_VOICE_ENABLED: self.voice_selector.config(state="disabled")
        
        self.model_desc = tk.Label(self.header, text=MODELS[self.model_var.get()]["description"], font=(FONT_FAMILY, 9), fg=SECONDARY_TEXT, bg=BG_COLOR)
        self.model_desc.pack()

        # 2. CHAT AREA
        self.chat_display = scrolledtext.ScrolledText(root, wrap="word", font=(FONT_FAMILY, 13), bg=DRAWER_COLOR, fg=TEXT_COLOR, relief="flat", padx=15, pady=15, insertbackground="white")
        self.chat_display.grid(row=1, column=0, sticky="nsew", padx=15, pady=5)
        self.chat_display.config(state="disabled")

        self.chat_display.tag_configure("user", background=USER_MSG_BG, foreground="white", lmargin1=40, lmargin2=40, rmargin=10, spacing1=10, spacing3=10)
        self.chat_display.tag_configure("bot", background=BOT_MSG_BG, foreground=TEXT_COLOR, lmargin1=10, lmargin2=10, rmargin=40, spacing1=10, spacing3=10)
        self.chat_display.tag_configure("sender", font=(FONT_FAMILY, 11, "bold"), foreground=ACCENT_COLOR)

        # 3. INPUT AREA
        self.input_parent = tk.Frame(root, bg=BG_COLOR, pady=10, padx=15)
        self.input_parent.grid(row=2, column=0, sticky="ew")
        self.input_parent.grid_columnconfigure(1, weight=1)

        mic_state = "normal" if (MACOS_SPEECH_ENABLED or FALLBACK_STT_ENABLED) else "disabled"
        self.mic_btn = tk.Button(self.input_parent, text="🎤", command=self.toggle_mic, bg=SURFACE_COLOR, fg=TEXT_COLOR, font=(FONT_FAMILY, 14), relief="flat", padx=10, state=mic_state)
        self.mic_btn.grid(row=0, column=0, padx=(0,10))
        
        self.input_entry = tk.Entry(self.input_parent, font=(FONT_FAMILY, 14), bg=SURFACE_COLOR, fg="white", insertbackground="white", relief="flat", highlightthickness=1, highlightbackground="#333")
        self.input_entry.grid(row=0, column=1, sticky="ew", ipady=12, padx=(0, 15))
        self.input_entry.bind("<Return>", lambda e: self.send_message())

        self.send_btn = tk.Button(self.input_parent, text="SEND", command=self.send_message, bg=ACCENT_COLOR, font=(FONT_FAMILY, 10, "bold"), relief="flat", width=10)
        self.send_btn.grid(row=0, column=2)

        # 4. FOOTER
        self.footer = tk.Frame(root, bg=BG_COLOR, padx=15, pady=10)
        self.footer.grid(row=3, column=0, sticky="ew")
        
        self.footer_left = tk.Frame(self.footer, bg=BG_COLOR)
        self.footer_left.pack(side="left")
        
        voice_btn_state = "normal" if NEURAL_VOICE_ENABLED else "disabled"
        tk.Checkbutton(self.footer_left, text="Real-Audio Mode", variable=self.voice_enabled, bg=BG_COLOR, fg=SECONDARY_TEXT, selectcolor="#333", font=(FONT_FAMILY, 9), state=voice_btn_state).pack(side="left")
        tk.Button(self.footer_left, text="🗑️ Clear Chat", command=self.clear_visual, relief="flat", bg=BG_COLOR, fg=SECONDARY_TEXT, font=(FONT_FAMILY, 9), padx=10).pack(side="left")
        tk.Button(self.footer_left, text="🧠 Reset Brain", command=self.reset_brain, relief="flat", bg=BG_COLOR, fg=SECONDARY_TEXT, font=(FONT_FAMILY, 9), padx=10).pack(side="left")
        
        self.status = tk.Label(self.footer, text="●  READY  ", fg=STATUS_COLOR, bg=BG_COLOR, font=(FONT_FAMILY, 11, "bold"))
        self.status.pack(side="right")

        self.root.after(100, self.poll_stt_queue)
        if MACOS_SPEECH_ENABLED:
            self.recognizer = SFSpeechRecognizer.alloc().initWithLocale_(NSLocale.alloc().initWithLocaleIdentifier_("en-US"))

        # Sync UI to restored memory state
        restored_model = josie_client.model_key
        self.model_var.set(restored_model)
        self.model_desc.config(text=MODELS[restored_model]["description"])
        if josie_client.context:
            self.status.config(text="●  MEMORY RESTORED", fg=ACCENT_COLOR)
            self.root.after(2500, lambda: self.status.config(text="●  READY  ", fg=STATUS_COLOR))

    def poll_stt_queue(self):
        while not self.stt_queue.empty():
            text = self.stt_queue.get()
            self.input_entry.delete(0, tk.END)
            self.input_entry.insert(0, text)
        self.root.after(100, self.poll_stt_queue)

    def download_ollama(self):
        webbrowser.open("https://ollama.com/download")

    def toggle_mic(self):
        if not self.is_listening:
            if MACOS_SPEECH_ENABLED: self.start_native_listening()
            elif FALLBACK_STT_ENABLED: self.start_fallback_listening()
        else: self.stop_listening()

    def start_native_listening(self):
        self.is_listening = True
        self.mic_btn.config(bg=REC_COLOR, text="🔴")
        try:
            session = AVAudioSession.sharedInstance()
            session.setCategory_mode_options_error_(AVAudioSessionCategoryRecord, AVAudioSessionModeMeasurement, 0, None)
            session.setActive_withOptions_error_(True, 0, None)
            self.audio_engine = AVAudioEngine.alloc().init()
            self.recognition_request = SFSpeechAudioBufferRecognitionRequest.alloc().init()
            input_node = self.audio_engine.inputNode()
            recording_format = input_node.outputFormatForBus_(0)
            def handle_result(result, error):
                if result: self.stt_queue.put(result.bestTranscription().formattedString())
            self.recognition_task = self.recognizer.recognitionTaskWithRequest_resultHandler_(self.recognition_request, handle_result)
            input_node.installTapOnBus_bufferSize_format_block_(0, 1024, recording_format, lambda buf, when: self.recognition_request.appendAudioPCMBuffer_(buf))
            self.audio_engine.prepare()
            self.audio_engine.startAndReturnError_(None)
        except: self.stop_listening()

    def start_fallback_listening(self):
        self.is_listening = True
        self.mic_btn.config(bg=REC_COLOR, text="🔴")
        def _listen():
            r = sr.Recognizer()
            try:
                with sr.Microphone() as source:
                    r.adjust_for_ambient_noise(source)
                    audio = r.listen(source, phrase_time_limit=10)
                    text = r.recognize_google(audio)
                    self.stt_queue.put(text)
            except Exception as e:
                print(f"Mic Error: {e}")
            self.root.after(0, self.stop_listening)
        threading.Thread(target=_listen, daemon=True).start()

    def stop_listening(self):
        self.is_listening = False
        self.mic_btn.config(bg=SURFACE_COLOR, text="🎤")
        try:
            if self.audio_engine:
                self.audio_engine.stop()
                self.audio_engine.inputNode().removeTapOnBus_(0)
                self.audio_engine = None
            if self.recognition_request:
                self.recognition_request.endAudio()
                self.recognition_request = None
            if MACOS_SPEECH_ENABLED: AVAudioSession.sharedInstance().setActive_withOptions_error_(False, 0, None)
        except: pass

    def on_model_change(self, event):
        selected = self.model_var.get()
        josie_client.set_model(selected)
        self.model_desc.config(text=MODELS[selected]["description"])

    def install_models(self):
        commands = [f"ollama pull {c['tag']}" for c in MODELS.values()]
        full_command = " & ".join(commands) if sys.platform == "win32" else " && ".join(commands)
        if sys.platform == "win32":
            subprocess.Popen(["cmd.exe", "/c", f"start cmd.exe /k \"{full_command} & echo ✅ DONE & pause\""])
        else:
            subprocess.run(["osascript", "-e", f'tell application "Terminal" to do script "{full_command}"'])

    def _setup_avatar(self):
        try:
            path = get_resource_path("josie_avatar.png")
            if os.path.exists(path):
                img = Image.open(path)
                img = img.resize((160, 160), Image.Resampling.LANCZOS)
                self.avatar_img = ImageTk.PhotoImage(img)
                tk.Label(self.header, image=self.avatar_img, bg=BG_COLOR).pack(pady=(0, 10))
        except: pass

    def send_message(self):
        msg = self.input_entry.get().strip()
        if not msg: return
        if self.is_listening: self.stop_listening()
        self.input_entry.delete(0, tk.END)
        self._append("USER", msg, "user")
        self.status.config(text="●  THINKING...", fg=ACCENT_COLOR)
        threading.Thread(target=self._process, args=(msg,), daemon=True).start()

    def _process(self, prompt):
        try:
            response = josie_client.generate(prompt)
            self.root.after(0, self._render_bot, response)
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", str(e)))

    def _render_bot(self, response):
        self._append("JOSIE", response, "bot")
        self.status.config(text="●  READY  ", fg=STATUS_COLOR)
        if self.voice_enabled.get() and NEURAL_VOICE_ENABLED:
            threading.Thread(target=self.speak_realistic, args=(response,), daemon=True).start()

    def speak_realistic(self, text):
        if not NEURAL_VOICE_ENABLED: return
        try:
            clean_text = re.sub(r'[\(\*].*?[\)\*]', '', text)
            clean_text = re.sub(r'[^\x00-\x7F\xc2-\xf4\u0100-\u24ff\u2100-\u214f]', '', clean_text).strip()
            if not clean_text: return

            voice_id = VOICES.get(self.voice_var.get(), VOICES["Jenny (US)"])

            async def _speak():
                communicate = edge_tts.Communicate(clean_text, voice_id)
                temp_path = os.path.join(tempfile.gettempdir(), f"josie_{int(time.time())}.mp3")
                await communicate.save(temp_path)
                if sys.platform == "darwin": subprocess.run(["afplay", temp_path])
                elif sys.platform == "win32":
                    ps_cmd = f"(New-Object Media.MediaPlayer).Open('{temp_path}'); (New-Object Media.MediaPlayer).Play(); Start-Sleep -s 15"
                    subprocess.run(["powershell", "-c", ps_cmd])
                if os.path.exists(temp_path): os.remove(temp_path)
            
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            loop.run_until_complete(_speak())
            loop.close()
        except: pass

    def _append(self, sender, text, tag):
        self.chat_display.config(state="normal")
        self.chat_display.insert(tk.END, f"\n {sender}\n", "sender")
        self.chat_display.insert(tk.END, f" {text} \n", tag)
        self.chat_display.config(state="disabled")
        self.chat_display.see(tk.END)

    def clear_visual(self):
        self.chat_display.config(state="normal")
        self.chat_display.delete(1.0, tk.END)
        self.chat_display.config(state="disabled")

    def reset_brain(self):
        josie_client.clear_memory()
        messagebox.showinfo("Brain", "JOSIE's memory wiped! She starts fresh next message.")

if __name__ == "__main__":
    app_root = tk.Tk()
    style = ttk.Style()
    style.theme_use('clam')
    style.configure("TCombobox", fieldbackground=SURFACE_COLOR, background=BG_COLOR, foreground=TEXT_COLOR)
    try: app_root.call('tk', 'scaling', 2.0)
    except: pass
    gui = JOSIEChatGUI(app_root)
    app_root.mainloop()