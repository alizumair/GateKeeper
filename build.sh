#!/bin/bash
set -e

echo "🔨 Building GateKeeper for macOS..."

# 1. Compile via Swift Package Manager
swift build -c release

# 2. Prepare .app bundle structure
APP_DIR="build/GateKeeper.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 3. Copy binary
cp .build/release/GateKeeper "$MACOS_DIR/GateKeeper"

# 4. Copy Info.plist and AppIcon
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# 5. Ad-hoc code sign the bundle
echo "✍️  Signing application bundle..."
codesign --force --deep --sign - --entitlements Resources/GateKeeper.entitlements "$APP_DIR"

echo "✅ Successfully built GateKeeper.app at: $APP_DIR"
