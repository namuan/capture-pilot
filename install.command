#!/bin/bash
set -e

echo "Building CapturePilot..."

# Ensure we are in the project root
cd "$(dirname "$0")"

# Create the applications directory if it doesn't exist
APPS_DIR="$HOME/Applications"
mkdir -p "$APPS_DIR"

# Build configuration
CONFIGURATION="Release"
APP_NAME="CapturePilot"
BUILD_DIR=".build/$CONFIGURATION"

# Build using swift build
swift build -c release

# Create the .app bundle structure
APP_BUNDLE="$APPS_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Update instead of delete
if [ -d "$APP_BUNDLE" ]; then
    echo "Updating existing app bundle..."
    rm -f "$MACOS_DIR/$APP_NAME"
else
    echo "Creating new app bundle..."
    mkdir -p "$MACOS_DIR"
    mkdir -p "$RESOURCES_DIR"
fi

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Create and copy icon if it exists
if [ -f "assets/icon.png" ]; then
    echo "Creating app icon..."
    ICONSET_DIR="/tmp/$APP_NAME.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    
    # Generate iconset from PNG (creates multiple sizes)
    sips -z 16 16     "assets/icon.png" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32     "assets/icon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32     "assets/icon.png" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64     "assets/icon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128   "assets/icon.png" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256   "assets/icon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "assets/icon.png" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512   "assets/icon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   "assets/icon.png" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
    sips -z 1024 1024 "assets/icon.png" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1
    
    # Convert to .icns
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    echo "App icon created successfully."
fi

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.CapturePilot</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy Resources if they exist (SwiftPM puts them in a bundle usually, but for simple exec we might need to handle manual copies if we had assets)
# For now, we don't have distinct resources to copy outside the binary's resource bundle if configured.

# Code sign the app bundle
echo "Code signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Installation complete! Launch CapturePilot from $APP_BUNDLE"
tccutil reset ScreenCapture com.example.CapturePilot
open $APP_BUNDLE
