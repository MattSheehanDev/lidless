#!/usr/bin/env bash
# Usage: scripts/package.sh 1.2.0
# Builds a universal Lidless.app and produces build/Lidless.zip and build/release-notes.md.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/package.sh <version>, e.g. 1.2.0}"
ZIP="build/Lidless.zip"
NOTES_FILE="build/release-notes.md"

UNIVERSAL=1 VERSION="$VERSION" ./scripts/bundle.sh

# ditto keeps the code signature and bundle metadata intact, unlike plain zip.
rm -f "$ZIP"
ditto -c -k --keepParent build/Lidless.app "$ZIP"

cat > "$NOTES_FILE" <<'EOF'
## Install

1. Download **Lidless.zip** below and unzip it.
2. Move **Lidless.app** to your Applications folder and open it.
3. macOS will block it the first time because it isn't notarized. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Lidless.

Or, from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Lidless.app && open /Applications/Lidless.app
```

Requires macOS 14 or later. Universal build for Apple Silicon and Intel.
EOF

echo "Packaged $ZIP"
