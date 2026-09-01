#!/bin/bash
set -e

WORKSPACE_DIR="$(pwd)"
BUILD_BIN="${WORKSPACE_DIR}/.build/bin/MasterDock"
APP_DIR="${WORKSPACE_DIR}/MasterDock.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

if [ ! -f "${BUILD_BIN}" ]; then
    echo "Executable not found. Running build_and_test.sh first..."
    ./build_and_test.sh
fi

echo "=================================================="
echo "      PACKAGING MASTER DOCK .APP BUNDLE           "
echo "=================================================="

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp "${BUILD_BIN}" "${MACOS_DIR}/MasterDock"
chmod +x "${MACOS_DIR}/MasterDock"

# Create Info.plist
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MasterDock</string>
    <key>CFBundleIdentifier</key>
    <string>com.masterdock.app</string>
    <key>CFBundleName</key>
    <string>Master Dock</string>
    <key>CFBundleDisplayName</key>
    <string>Master Dock</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Master Dock requires microphone access for interactive AI Voice Mode.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Master Dock requires speech recognition to transcribe your voice prompts in real time.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Master Dock requires calendar access to display today's upcoming meetings.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Master Dock requires automation permissions to control Apple Music, Spotify, YouTube Music, and media playback.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Strip extended attributes and sign the bundle with persistent entitlements for TCC
xattr -cr "${APP_DIR}" || true

if [ -f "${WORKSPACE_DIR}/MasterDock.entitlements" ]; then
    echo "Signing MasterDock.app with entitlements..."
    codesign --force --deep --sign - --entitlements "${WORKSPACE_DIR}/MasterDock.entitlements" "${APP_DIR}"
fi

# Sync to /Applications if /Applications/MasterDock.app exists
if [ -d "/Applications/MasterDock.app" ]; then
    echo "Updating /Applications/MasterDock.app..."
    rm -rf "/Applications/MasterDock.app"
    cp -R "${APP_DIR}" "/Applications/MasterDock.app"
fi

# Sync to ~/Applications if ~/Applications/MasterDock.app exists
if [ -d "${HOME}/Applications/MasterDock.app" ]; then
    echo "Updating ${HOME}/Applications/MasterDock.app..."
    rm -rf "${HOME}/Applications/MasterDock.app"
    cp -R "${APP_DIR}" "${HOME}/Applications/MasterDock.app"
fi

echo "✅ Successfully packaged and signed Master Dock into ${APP_DIR}"
echo "🚀 To launch: open '${APP_DIR}' or .build/bin/MasterDock"
