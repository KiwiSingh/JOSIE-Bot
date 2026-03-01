@echo off
echo 🫦 JOSIE - Windows Build Engine (Resilient Version) 🫦
echo --------------------------------------------------

echo 1. Checking for Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found! Please install Python 3.10+ from python.org
    pause
    exit /b
)

echo 2. Ensuring Core Tools are ready...
python -m pip install --upgrade pip
python -m pip install PyInstaller requests Pillow --prefer-binary

echo 3. Attempting to install Voice Features (Silent Fail if missing Build Tools)...
echo [NOTE] If this fails, JOSIE will build without Neural Voice/Mic support.
python -m pip install edge-tts SpeechRecognition PyAudio --prefer-binary

echo 4. Compiling JOSIE.exe (Even if voice failed)...
python -m PyInstaller --noconsole --onefile --icon=josie.ico --add-data "josie_avatar.png;." --clean josie.py

echo --------------------------------------------------
if exist "dist\JOSIE.exe" (
    echo ✅ SUCCESS! Your 'JOSIE.exe' is in the 'dist' folder.
    echo 👄 Note: If voice libraries failed above, those features will be disabled in the app.
) else (
    echo ❌ ERROR: Compilation failed. 
    echo [TIP] Try installing 'Microsoft C++ Build Tools' for full feature support.
)
pause
