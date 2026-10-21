#!/bin/bash
# Double-clickable installer (also named Install.command in the zip).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$HERE/CursorLimits.app"
DEST="/Applications/CursorLimits.app"

if [[ ! -d "$APP_SRC" ]]; then
  osascript -e 'display alert "CursorLimits.app not found" message "Keep Install.command next to CursorLimits.app inside the unzipped folder." as critical' || true
  exit 1
fi

echo "Installing Cursor Limits to /Applications…"
rm -rf "$DEST"
cp -R "$APP_SRC" "$DEST"

# Clear Gatekeeper quarantine so first launch is smoother (unsigned build)
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "Done."
open "$DEST"

osascript <<'EOF' || true
display dialog "Cursor Limits installed.

Next steps:
1. Open Cursor and sign in
2. Click the menu bar icon → Check connection
3. (Optional) Desktop → Edit Widgets → Cursor Limits

No tokens to paste — the app uses your local Cursor session." buttons {"OK"} default button 1 with title "Cursor Limits"
EOF
