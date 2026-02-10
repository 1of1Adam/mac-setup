#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/AutoInstaller"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs"
PLIST_PATH="$LAUNCH_AGENTS/com.adampeng.auto-installer.plist"
DOMAIN="gui/$(id -u)"

NODE_BIN="$(command -v node || true)"
FSWATCH_BIN="$(command -v fswatch || true)"

if [[ -z "$NODE_BIN" ]]; then
  echo "[ERROR] node not found. Please install Node.js first." >&2
  exit 1
fi

if [[ -z "$FSWATCH_BIN" ]]; then
  if command -v brew >/dev/null 2>&1; then
    echo "[INFO] fswatch not found; installing via Homebrew..." >&2
    brew install fswatch
    FSWATCH_BIN="$(command -v fswatch || true)"
  fi
fi

if [[ -z "$FSWATCH_BIN" ]]; then
  echo "[ERROR] fswatch not found. Install it first: brew install fswatch" >&2
  exit 1
fi

mkdir -p "$APP_SUPPORT" "$LAUNCH_AGENTS" "$LOG_DIR"

# Install script + config template
cp "$SCRIPT_DIR/auto-installer.mjs" "$APP_SUPPORT/auto-installer.mjs"
cp "$SCRIPT_DIR/config.json" "$APP_SUPPORT/config.json"

# Create state file if missing
STATE_PATH="$APP_SUPPORT/state.json"
if [[ ! -f "$STATE_PATH" ]]; then
  cat > "$STATE_PATH" <<'JSON'
{
  "version": 1,
  "createdAt": "",
  "updatedAt": "",
  "entries": {}
}
JSON
fi

# Patch config.json with discovered paths (avoid relying on PATH inside launchd)
TMP_CFG="$(mktemp)"
jq --arg fs "$FSWATCH_BIN" \
   --arg log "$HOME/Library/Logs/auto-installer.log" \
   '.fswatchPath=$fs | .logPath=$log' \
   "$APP_SUPPORT/config.json" > "$TMP_CFG"
mv "$TMP_CFG" "$APP_SUPPORT/config.json"

# Generate LaunchAgent plist
OUT_LOG="$HOME/Library/Logs/auto-installer.launchd.out.log"
ERR_LOG="$HOME/Library/Logs/auto-installer.launchd.err.log"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.adampeng.auto-installer</string>

  <key>ProgramArguments</key>
  <array>
    <string>${NODE_BIN}</string>
    <string>${APP_SUPPORT}/auto-installer.mjs</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>ThrottleInterval</key>
  <integer>5</integer>

  <key>StandardOutPath</key>
  <string>${OUT_LOG}</string>

  <key>StandardErrorPath</key>
  <string>${ERR_LOG}</string>
</dict>
</plist>
PLIST

plutil -lint "$PLIST_PATH" >/dev/null

# Reload
launchctl bootout "$DOMAIN" "$PLIST_PATH" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$DOMAIN/com.adampeng.auto-installer"

echo "[OK] AutoInstaller installed and started." >&2
echo "      Log: $HOME/Library/Logs/auto-installer.log" >&2
