#!/usr/bin/env bash
# Usage: scripts/package.sh 1.2.0
# Builds a universal Lidless.app and produces build/Lidless.zip.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/package.sh <version>, e.g. 1.2.0}"
ZIP="build/Lidless.zip"

UNIVERSAL=1 VERSION="$VERSION" ./scripts/bundle.sh

# ditto keeps the code signature and bundle metadata intact, unlike plain zip.
rm -f "$ZIP"
ditto -c -k --keepParent build/Lidless.app "$ZIP"

lipo -archs build/Lidless.app/Contents/MacOS/Lidless
codesign --verify --deep --strict build/Lidless.app
echo "Packaged $ZIP"
