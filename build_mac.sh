#!/bin/bash

# ==========================================
# JOSIE macOS DMG Builder
# ==========================================

APP_NAME="JOSIE"
VERSION="1.1"
APP_PATH="dist/${APP_NAME}.app"
DMG_NAME="dist/${APP_NAME}.dmg"
STAGING_DIR="dist/dmg_staging"

echo "🍎 Building macOS DMG for ${APP_NAME}..."

# 1. Verify the PyInstaller .app bundle actually exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ ERROR: $APP_PATH not found!"
    echo "Please build the .app bundle with PyInstaller first."
    exit 1
fi

# 2. Inject version into the App's Info.plist
echo "📝 Injecting v${VERSION} metadata into the app properties..."
PLIST_PATH="$APP_PATH/Contents/Info.plist"
if [ -f "$PLIST_PATH" ]; then
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$PLIST_PATH" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST_PATH"
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$PLIST_PATH" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$PLIST_PATH"
else
    echo "⚠️ Warning: Info.plist not found. Version properties won't be set."
fi

# 3. Clean up any previous DMG or left-over staging folders
echo "🧹 Clearing old build files..."
rm -f "$DMG_NAME"
rm -rf "$STAGING_DIR"

# 4. Create a fresh staging directory
echo "📂 Setting up staging folder..."
mkdir -p "$STAGING_DIR"

# 5. Copy the .app bundle into the staging folder
echo "📦 Copying app bundle..."
cp -R "$APP_PATH" "$STAGING_DIR/"

# 6. Create the standard drag-and-drop Applications folder symlink
echo "🔗 Creating Applications shortcut..."
ln -s /Applications "$STAGING_DIR/Applications"

# 7. Generate the compressed DMG using macOS native hdiutil
echo "💿 Generating disk image..."
hdiutil create -volname "${APP_NAME} v${VERSION}" \
               -srcfolder "$STAGING_DIR" \
               -ov -format UDZO \
               "$DMG_NAME"

# 8. Clean up the staging folder
echo "🗑️ Removing staging folder..."
rm -rf "$STAGING_DIR"

echo "=========================================="
echo "✅ SUCCESS! Your DMG is ready at: $DMG_NAME"
echo "=========================================="