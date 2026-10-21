#!/bin/bash
# Dev run. For a shareable zip use: ./scripts/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -scheme CursorLimits -configuration Debug -derivedDataPath ./DerivedData -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" build
open ./DerivedData/Build/Products/Debug/CursorLimits.app
echo "Widget: right-click desktop → Edit Widgets → Cursor Limits"
echo "RU: ПКМ на рабочем столе → Редактировать виджеты → Cursor Limits"
