#!/usr/bin/env bash
# Build a release binary and wrap it in a double-clickable ClaudeWatch.app bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP="ClaudeWatch.app"
CONTENTS="$APP/Contents"

echo "==> Building release binary"
swift build -c release

if [ ! -f Assets/AppIcon.icns ]; then
    echo "==> Generating app icon"
    (cd Assets && swift make-icon.swift . && iconutil -c icns AppIcon.iconset -o AppIcon.icns && rm -rf AppIcon.iconset)
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp .build/release/ClaudeWatch "$CONTENTS/MacOS/ClaudeWatch"
cp Assets/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ClaudeWatch</string>
    <key>CFBundleDisplayName</key>
    <string>ClaudeWatch</string>
    <key>CFBundleIdentifier</key>
    <string>cz.jarvis.claudewatch</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeWatch</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
</dict>
</plist>
PLIST

echo "==> Done: $(pwd)/$APP"
echo "    Launch:  open $APP"
