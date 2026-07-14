#!/usr/bin/env bash
# Stop ClaudeWatch, remove the LaunchAgent and the installed app.
set -euo pipefail

LABEL="cz.jarvis.claudewatch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
INSTALLED="$HOME/Applications/ClaudeWatch.app"

echo "==> Unloading LaunchAgent"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

echo "==> Removing $INSTALLED"
rm -rf "$INSTALLED"

echo "==> Removing stored account snapshots from Keychain"
security delete-generic-password -s "ClaudeWatch-accounts" >/dev/null 2>&1 || true

echo "==> Done."
