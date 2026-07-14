#!/usr/bin/env bash
# Build ClaudeWatch, install it to ~/Applications, and register a LaunchAgent so it
# starts at login and stays running.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ClaudeWatch.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED="$INSTALL_DIR/$APP_NAME"
LABEL="cz.jarvis.claudewatch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BIN="$INSTALLED/Contents/MacOS/ClaudeWatch"

echo "==> Building app bundle"
./bundle.sh >/dev/null

echo "==> Installing to $INSTALLED"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED"
cp -R "$APP_NAME" "$INSTALLED"

echo "==> Writing LaunchAgent $PLIST"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLISTEOF

echo "==> Loading LaunchAgent"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"

echo "==> Done. ClaudeWatch is running and will start at every login."
echo "    Uninstall: ./uninstall.sh"
