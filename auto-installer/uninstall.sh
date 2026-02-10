#!/usr/bin/env bash
set -euo pipefail

APP_SUPPORT="$HOME/Library/Application Support/AutoInstaller"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS/com.adampeng.auto-installer.plist"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN" "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH" || true

# Remove installed files
rm -rf "$APP_SUPPORT" || true

echo "[OK] AutoInstaller removed." >&2
