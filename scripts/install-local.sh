#!/bin/bash
# Build, install to /Applications, and register the WidgetKit extension.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/DerivedData"
APP_NAME="CursorLimits"
DEST="/Applications/${APP_NAME}.app"
WIDGET_ID="com.local.CursorLimits.widget"
HOST_ENTITLEMENTS="$ROOT/CursorLimits/CursorLimits.entitlements"
WIDGET_ENTITLEMENTS="$ROOT/CursorLimitsWidget/CursorLimitsWidget.entitlements"

cd "$ROOT"
command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }

echo "==> Generating + building"
xcodegen generate
pkill -x CursorLimits 2>/dev/null || true
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="$DERIVED/Build/Products/Debug/${APP_NAME}.app"
APPEX="$APP/Contents/PlugIns/CursorLimitsWidget.appex"
test -d "$APP"
test -d "$APPEX"

IDENTITY_HASH="$(security find-identity -v -p codesigning 2>/dev/null | grep 'Apple Development' | grep -v 'CSSMERR' | head -1 | awk '{print $2}' || true)"
SIGN_ID="${IDENTITY_HASH:--}"

echo "==> Signing ($SIGN_ID)"
codesign --force --sign "$SIGN_ID" --entitlements "$WIDGET_ENTITLEMENTS" "$APPEX"
codesign --force --sign "$SIGN_ID" --entitlements "$HOST_ENTITLEMENTS" "$APP"

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

APPEX_DEST="$DEST/Contents/PlugIns/CursorLimitsWidget.appex"
codesign --force --sign "$SIGN_ID" --entitlements "$WIDGET_ENTITLEMENTS" "$APPEX_DEST"
codesign --force --sign "$SIGN_ID" --entitlements "$HOST_ENTITLEMENTS" "$DEST"

echo "==> Registering widget"
pluginkit -a "$APPEX_DEST" 2>/dev/null || true
pluginkit -e use -i "$WIDGET_ID" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$DEST" 2>/dev/null || true
killall -9 pkd 2>/dev/null || true
killall Dock NotificationCenter chronod 2>/dev/null || true

open "$DEST"
sleep 2

echo ""
codesign -d --entitlements :- "$APPEX_DEST" 2>/dev/null | tr '\n' ' '; echo
pluginkit -m -p com.apple.widgetkit-extension 2>/dev/null | grep -i CursorLimits || true
echo ""
echo "1) Click menu bar icon → refresh"
echo "2) If widget still says No data: remove it and add again from Edit Widgets"
