#!/usr/bin/env bash
# Build penjuru.koplugin into a distributable zip.
# Usage:
#   ./build.sh           -> writes dist/penjuru.koplugin.zip
#   ./build.sh --clean   -> removes dist/ first
set -euo pipefail

cd "$(dirname "$0")"

# Defensive: a self-referential symlink inside penjuru.koplugin/
# bloats the zip to multi-GB. Refuse to build until it's removed.
if find penjuru.koplugin -type l -name 'penjuru.koplugin' | grep -q .; then
    echo "ERROR: recursive symlink penjuru.koplugin/penjuru.koplugin detected — remove it before building" >&2
    exit 1
fi

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

# Also build a KUAL-extension zip so users can launch penjuru directly
# from the Kindle home (KUAL) without going through KOReader's menu.
KUAL_ZIP="dist/penjuru-kual.zip"
rm -f "$KUAL_ZIP"
if [ -d kual ]; then
    (cd kual && zip -r "../$KUAL_ZIP" extensions \
        --exclude '*.DS_Store' \
        > /dev/null)
    echo "Built: $KUAL_ZIP ($(du -h "$KUAL_ZIP" | awk '{print $1}'))"
fi

echo
echo "Plugin install on Kindle:"
echo "  1. Unzip penjuru.koplugin.zip into /mnt/us/koreader/plugins/"
echo "     Result must be /mnt/us/koreader/plugins/penjuru.koplugin/"
echo "  2. Restart KOReader"
echo "  3. Enable: Menu → Tools → Plugin management → penjuru"
echo "  4. Open: Menu → Tools → penjuru → Open home"
echo
echo "KUAL launcher (optional — opens penjuru directly from Kindle home):"
echo "  1. Unzip penjuru-kual.zip into /mnt/us/"
echo "     Result: /mnt/us/extensions/penjuru/{menu.json,run.sh}"
echo "  2. Refresh KUAL (drop into KUAL once for it to scan)"
echo "  3. Tap 'penjuru' in KUAL → KOReader boots straight into the home"
