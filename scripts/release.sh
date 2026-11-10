#!/usr/bin/env bash
# Usage: scripts/release.sh 1.2.0
# Tests, builds a universal Lidless.app, tags v<version>, and publishes a GitHub release with Lidless.zip.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version>, e.g. 1.2.0}"
TAG="v${VERSION}"
GH="${GH:-$(command -v gh || echo "$HOME/.local/bin/gh")}"
ZIP="build/Lidless.zip"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty; commit or stash first." >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo "Tag ${TAG} already exists." >&2
    exit 1
fi

make test
UNIVERSAL=1 VERSION="$VERSION" ./scripts/bundle.sh

# ditto keeps the code signature and bundle metadata intact, unlike plain zip.
rm -f "$ZIP"
ditto -c -k --keepParent build/Lidless.app "$ZIP"

git tag -a "$TAG" -m "Lidless ${VERSION}"
git push origin "$TAG"

NOTES=$(cat <<EOF
## Install

1. Download **Lidless.zip** below and unzip it.
2. Move **Lidless.app** to your Applications folder and open it.
3. macOS will block it the first time because it isn't notarized. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Lidless.

Or, from Terminal:

\`\`\`bash
xattr -dr com.apple.quarantine /Applications/Lidless.app && open /Applications/Lidless.app
\`\`\`

Requires macOS 14 or later. Universal build for Apple Silicon and Intel.
EOF
)

"$GH" release create "$TAG" "$ZIP" --title "Lidless ${VERSION}" --notes "$NOTES" --generate-notes
