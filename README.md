<p align="center">
  <img src="https://i.ibb.co/bM8LfC4r/josie-avatar.png" alt="JOSIE Avatar" width="480" height="480"/>
</p>

# J.O.S.I.E
### *Just One S\*xually Involved E-girl* — Your Local AI Companion

JOSIE is a premium, localized AI desktop application designed for immersive roleplay and emotional conversations. Powered by Ollama and featuring a sleek, dark-mode interface, JOSIE brings your favorite roleplay models to life with integrated voice support and high-fidelity text-to-speech.

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
- **macOS**: `JOSIE.dmg` (Optimized for Apple Silicon).
- **Windows**: `JOSIE.exe.zip`.
- **iOS**: `JOSIE.ipa`
---

## 📱 iOS Version

- **Model Availability**: The iOS build currently ships with only two models (**JosieQwen** and **JosieNidum**). For the best experience, use **JosieNidum**.
- **Model Download**: Download the models as a zip file [here](https://mega.nz/file/Ik0SFIpI#3_uxyZyzpcdoLw85T-lJWKwKuoiHu7NICFHUST10OG0), unzip it, and move the individual model folders into the `JOSIE/Models` folder in your Files app.
- **Download Issues**: If you hit rate limits or download errors, use **MegaBasterd**.
- **Installation:** Sideload the IPA using Sideloadly, AltStore, or TrollStore.

---

### 💻 Developer / Linux Setup

If you are on Linux, or prefer running from source:

#### 1. Prerequisites
- **Python 3.10+** (Recommend Python 3.12 for macOS users).
- **[Ollama](https://ollama.com/)**: Must be installed and running in the background.

> [!TIP]
> **No Ollama yet?** You can download Ollama and install all required models directly from within the JOSIE interface using the integrated setup buttons!

#### 2. Linux / Manual Installation
Linux users should run the application directly via Python. We recommend using a virtual environment:

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
- **LLM Backend**: Ollama API.
- **TTS**: Microsoft Edge TTS (edge-tts).
- **STT**: Apple Native Speech Framework (macOS) / SpeechRecognition (Generic).
- **Packaging**: PyInstaller (using `JOSIE.spec`).

---

## 📜 License

JOSIE is released under the **MIT License**. See [LICENSE.md](LICENSE.md) for details.

---
<p align="center">Made with ❤️ for the Local AI Community.</p>
