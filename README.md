<p align="center">
  <img src="https://i.ibb.co/bM8LfC4r/josie-avatar.png" alt="JOSIE Avatar" width="480" height="480"/>
</p>

# J.O.S.I.E
### *Just One S\*xually Involved E-girl* — Your Local AI Companion

JOSIE is a premium, localized AI desktop application designed for immersive roleplay and emotional conversations. Powered by Ollama (MLXLLM on iOS) and featuring a sleek, dark-mode interface, JOSIE brings your favorite roleplay models to life with integrated voice support and high-fidelity text-to-speech.

---

## ✨ Features

- **🎙️ Natural Voice Interaction**: Talk to JOSIE and hear her respond in real-time. Supports high-quality neural voices via Edge TTS and localized STT (M1/M2 Mac optimized).
- **🎭 Model Flavors**: Switch between various roleplay-specific models instantly, including:
  - **Stheno 8B**: Premium Roleplay Specialist.
  - **Self After Dark**: Realistic Emotional Conversations.
  - **Vanessa**: Versatile RP Assistant.
  - **Xwin-MLEWD**: Diverse Roleplay Expert.
- **🛡️ 100% Private & Local**: No cloud APIs, no data mining. Everything stays on your machine using the Ollama backend.
- **🎨 Elite Aesthetic**: A polished, dark-themed GUI designed for focus and immersion.
- **🧠 Persistent Memory**: JOSIE remembers the conversation context during your session.

---

## 🚀 Getting Started

### 📦 Download Latest Builds

For the easiest experience, download the latest stable application for your platform from the **[Releases](https://github.com/KiwiSingh/JOSIE-Bot/releases)** section:
- **Linux**: `JOSIE-Linux.tar.gz`
- **macOS**: `JOSIE.dmg` (Optimized for Apple Silicon).
- **Windows**: `JOSIE.exe.zip`.
- **iOS**: `JOSIE.ipa`
- **Android:** `JOSIE.apk`
---

## 📱 iOS Version

- **Model Availability**: The iOS build currently ships with only three models (**JosieQwen**, **JosieGabby** and **JosieNidum**). For the best experience, use **JosieQwen**.
- **Model Download**: Download the models as a zip file [here](https://mega.nz/file/g0liAITa#VA0Tz8-2eNcVWi66Q-pgT8UKr9gVglY5k2fqKI-nLpI), unzip it, and move the individual model folders into the `JOSIE/Models` folder in your Files app.
- **Download Issues**: If you hit rate limits or download errors, use **[MegaBasterd](https://github.com/tonikelope/megabasterd)**.
- **Installation:** Sideload the IPA using Sideloadly, AltStore, or TrollStore.

---

## 📱 Android Version
- **Model Availability**: The Android build currently caches 3.8B, 4B, 8B and 12B model URLs from HuggingFace. These include **Phi-3.5-Mini**, **Gemma-3-4B (uncensored)**, **Stheno-8B**, and **Violet-Lotus-12B**. When in doubt, use **Gemma-3-4B**. **Stheno** and other higher parameter count models will only run on high-end flagship Android devices with plenty of RAM (ideally 12 gigs or higher) 
- **Model Download**: When you select a model from inside the app for the first time, it downloads directly from HuggingFace, and is cached until you delete app data or completely uninstall the app.
- **TTS and STT:** STT works perfectly, provided you are not using a sandboxed environment like an Android emulator or an AVD. TTS works perfectly as well. Once J.O.S.I.E finishes a sentence, she begins speaking. You can turn off speech entirely from the settings menu in the app. Unlike the iOS build, TTS and STT are decoupled, so you can enjoy one without the other, if you so desire.
- **Installation:** Turn on installation from unknown sources in your device's settings, and install the APK. If Google Play Protect gives you any grief, ignore the inane warnings and proceed anyway.

---

### 💻 Developer  Setup

If you are on a nonstandard Linux distro or prefer running from source:

#### 1. Prerequisites
- **Python 3.10+** (Recommend Python 3.12 for macOS users).
- **[Ollama](https://ollama.com/)**: Must be installed and running in the background.

> [!TIP]
> **No Ollama yet?** You can download Ollama and install all required models directly from within the JOSIE interface using the integrated setup buttons!

#### 2. Manual Installation
Linux users on nonstandard distros should run the application directly via Python. We recommend using a virtual environment:

```bash
# Clone the Repository
git clone https://github.com/KiwiSingh/JOSIE-Bot.git
cd JOSIE-Bot

# Create and Activate Virtual Environment
python3 -m venv venv
source venv/bin/activate  # On Windows use: venv\Scripts\activate

# Install Dependencies
pip install -r requirements.txt
```

#### 3. Install Ollama Models
Open JOSIE and click "📥 Install E-girls" or run the following manually:
   ```bash
   ollama pull adi0adi/ollama_stheno-8b_v3.1_q6k
   ollama pull gurubot/self-after-dark:latest
   ollama pull draganis/vanessa:latest
   ollama pull leeplenty/xwin-mlewd-v0.2:7b
   ```

### Running JOSIE

Run the main script directly with Python:
```bash
python josie.py
```

### 📦 Packaging for macOS

To create a standalone `.app` bundle for macOS (optimized for M1/M2/M3), use PyInstaller with the provided spec file:

1. **Install PyInstaller**:
   ```bash
   pip install pyinstaller
   ```

2. **Build the Application**:
   ```bash
   pyinstaller --clean JOSIE.spec
   ```

3. **Locate your App**:
   The `JOSIE.app` will be created in the `dist/` folder.

### 🪟 Packaging for Windows

JOSIE includes a resilient build engine for Windows:

1. **Run the Build Script**:
   Double-click `BUILD_WINDOWS.bat` or run it via CMD:
   ```cmd
   BUILD_WINDOWS.bat
   ```

2. **Locate your Exe**:
   The `JOSIE.exe` will be created in the `dist/` folder.

---

## 🛠️ Tech Stack

- **GUI**: Tkinter with PIL (Pillow) integration.
- **LLM Backend**: Ollama API, MLXLLM (iOS) and Llama.CPP (Android)
- **TTS**: Microsoft Edge TTS (edge-tts), on-device speech models (Android and iOS).
- **STT**: Apple Native Speech Framework (macOS) / SpeechRecognition (Generic).
- **Packaging**: PyInstaller (using `JOSIE.spec`), build script (Windows), decrypted and unsigned IPA (iOS), APK file (Android)

---

## 📜 License

JOSIE is released under the **MIT License**. See [LICENSE.md](LICENSE.md) for details.

---

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/kiwisingh)

---

<p align="center">Made with ❤️ for the Local AI Community.</p>
