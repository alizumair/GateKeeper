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

# 5. Fix permissions & clear quarantine attributes
chmod -R 755 "$APP_DIR"
xattr -cr "$APP_DIR" 2>/dev/null || true

# 6. Ad-hoc code sign the bundle
echo "✍️  Signing application bundle..."
codesign --force --deep --sign - --entitlements Resources/GateKeeper.entitlements "$APP_DIR"

# 7. Install / update in /Applications
if [ -d "/Applications" ]; then
    echo "📦 Updating /Applications/GateKeeper.app..."
    rm -rf /Applications/GateKeeper.app
    cp -R "$APP_DIR" /Applications/
    chmod -R 755 /Applications/GateKeeper.app
    xattr -cr /Applications/GateKeeper.app 2>/dev/null || true
fi

echo "✅ Successfully built and installed GateKeeper.app at: /Applications/GateKeeper.app"
