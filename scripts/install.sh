#!/bin/bash
# Double-clickable installer (also named Install.command in the zip).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$HERE/CursorLimits.app"
DEST="/Applications/CursorLimits.app"
WIDGET_ID="com.local.CursorLimits.widget"

if [[ ! -d "$APP_SRC" ]]; then
  osascript -e 'display alert "CursorLimits.app not found" message "Keep Install.command next to CursorLimits.app inside the unzipped folder." as critical' || true
  exit 1
fi

echo "Installing Cursor Limits to /Applications…"
rm -rf "$DEST"
cp -R "$APP_SRC" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

APPEX="$DEST/Contents/PlugIns/CursorLimitsWidget.appex"
if [[ -d "$APPEX" ]]; then
  pluginkit -a "$APPEX" 2>/dev/null || true
  pluginkit -e use -i "$WIDGET_ID" 2>/dev/null || true
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$DEST" 2>/dev/null || true
killall -9 pkd 2>/dev/null || true
killall Dock NotificationCenter 2>/dev/null || true

echo "Done."
open "$DEST"

osascript <<'EOF' || true
display dialog "Cursor Limits installed.

Next:
1. Sign in to the AI tools you use (Cursor, Claude CLI, Codex, OpenCode, gh, …)
2. Menu bar icon → Check (or open Settings → providers)
3. Copilot: Settings → Connect GitHub

Desktop widgets may not work yet — the menu bar is the supported surface." buttons {"OK"} default button 1 with title "Cursor Limits"
EOF
