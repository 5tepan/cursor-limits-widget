#!/bin/bash
# Build a distributable CursorLimits-*-macos.zip for GitHub Releases / sharing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
DERIVED="$ROOT/DerivedData-Release"
APP_NAME="CursorLimits"
VERSION="$(grep -E 'MARKETING_VERSION:' "$ROOT/project.yml" | head -1 | awk '{print $2}' | tr -d '"')"
VERSION="${VERSION:-1.0.0}"

cd "$ROOT"
command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release ($VERSION)"
rm -rf "$DERIVED" "$DIST"
mkdir -p "$DIST"
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="$DERIVED/Build/Products/Release/${APP_NAME}.app"
test -d "$APP"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> Staging zip contents"
STAGE="$DIST/stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
cp "$ROOT/scripts/install.sh" "$STAGE/Install.command"
chmod +x "$STAGE/Install.command"
cp "$ROOT/scripts/INSTALL.txt" "$STAGE/INSTALL.txt"

ZIP_NAME="${APP_NAME}-${VERSION}-macos.zip"
ZIP="$DIST/$ZIP_NAME"
(
  cd "$STAGE"
  zip -ry "$ZIP" "$APP_NAME.app" Install.command INSTALL.txt
)

(
  cd "$DIST"
  shasum -a 256 "$ZIP_NAME" > "${ZIP_NAME}.sha256"
)

rm -rf "$STAGE" "$DERIVED"

echo ""
echo "Packaged:"
ls -lh "$ZIP" "${ZIP}.sha256"
echo ""
echo "Share the zip. Users open Install.command (see INSTALL.txt)."
echo "GitHub: git tag v${VERSION} && git push origin v${VERSION}"
