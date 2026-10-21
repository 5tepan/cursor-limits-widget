#!/bin/bash
# Dev install into /Applications + widget registration.
# For a shareable zip: ./scripts/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."
exec ./scripts/install-local.sh
