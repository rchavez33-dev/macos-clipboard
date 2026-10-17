#!/usr/bin/env bash
# Builds SwiftClipboard and wraps it in a proper .app bundle.
# Everything stays inside the project (.build/ and build/) — nothing is installed globally.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

APP="build/SwiftClipboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIG/SwiftClipboard" "$APP/Contents/MacOS/SwiftClipboard"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SwiftClipboard</string>
    <key>CFBundleDisplayName</key><string>SwiftClipboard</string>
    <key>CFBundleIdentifier</key><string>com.rchavez.swiftclipboard</string>
    <key>CFBundleExecutable</key><string>SwiftClipboard</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS can remember the Accessibility permission.
codesign --force --sign - "$APP" >/dev/null
echo "✅ Built $APP"
echo "   Run with: open $APP"
