#!/usr/bin/env bash
# Build penjuru.koplugin into a distributable zip.
# Usage:
#   ./build.sh           -> writes dist/penjuru.koplugin.zip
#   ./build.sh --clean   -> removes dist/ first
set -euo pipefail

cd "$(dirname "$0")"

if [[ "${1:-}" == "--clean" ]]; then
    rm -rf dist
fi

mkdir -p dist
ZIP="dist/penjuru.koplugin.zip"
rm -f "$ZIP"

# Exclude dev-only files and .old_simpleui stashes from the shipped zip.
zip -r "$ZIP" penjuru.koplugin \
    --exclude '*.old_simpleui' \
    --exclude 'penjuru.koplugin/spec/*' \
    --exclude '*.DS_Store' \
    --exclude '*/.git/*' \
    > /dev/null

SIZE=$(du -h "$ZIP" | awk '{print $1}')
echo "Built: $ZIP ($SIZE)"
echo
echo "To install on Kindle:"
echo "  1. Unzip into /mnt/us/koreader/plugins/"
echo "     The result must be /mnt/us/koreader/plugins/penjuru.koplugin/"
echo "  2. Restart KOReader"
echo "  3. Enable: Menu → Tools → Plugin management → penjuru"
echo "  4. Open: Menu → Tools → penjuru → Open home"
