# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['josie.py'],
    pathex=[],
    binaries=[],
    datas=[('josie_avatar.png', '.')],
    hiddenimports=[
        'objc', 
        'AppKit', 
        'Speech', 
        'AVFoundation',
        'Foundation',
        'edge_tts',
        'asyncio',
        'aiohttp',
        'queue'
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'PyQt5', 'PyQt6', 'PySide2', 'PySide6', 
        'tensorflow', 'tensorboard', 'notebook', 
        'matplotlib', 'pandas', 'numpy', 'scipy'
    ],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='JOSIE',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['josie.icns'],
)

app = BUNDLE(
    exe,
    name='JOSIE.app',
    icon='josie.icns',
    bundle_identifier='com.pekoxusagikiwi.josie',
    info_plist={
        'NSMicrophoneUsageDescription': 'JOSIE needs access to your microphone for real-time speech recognition.',
        'NSSpeechRecognitionUsageDescription': 'JOSIE uses macOS native speech recognition for M1-accelerated transcription.',
        'NSHighResolutionCapable': True,
        'LSMinimumSystemVersion': '11.0.0',
        'NSAppTransportSecurity': {'NSAllowsArbitraryLoads': True},
    },
)
