#!/usr/bin/env bash
# Run penjuru plugin specs against the local KOReader emulator checkout.
#
# Usage:
#   ./scripts/run-specs.sh                  # run all specs under penjuru.koplugin/spec/unit/
#   ./scripts/run-specs.sh path/to/foo_spec.lua  # run a single spec file
#
# Internals: invokes the KOReader busted runner directly (no make build step).
# The emulator must already be built (Task 0.3).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
EMULATOR_DIR="${REPO}/../koreader/koreader-emulator-arm64-apple-darwin25.4.0-debug/koreader"

if [[ ! -d "${EMULATOR_DIR}" ]]; then
    echo "ERROR: KOReader emulator not found at: ${EMULATOR_DIR}" >&2
    echo "       Build it first with: cd ~/Developer/koreader && ./kodev build" >&2
    exit 1
fi

# If no args, default to all spec files in the plugin spec/unit/ dir.
if [[ $# -eq 0 ]]; then
    set -- "${REPO}/penjuru.koplugin/spec/unit/"
fi

exec env -C "${EMULATOR_DIR}" \
    KO_HOME="${EMULATOR_DIR}/spec/run" \
    LUA_CPATH='?.so;common/?.so;spec/rocks/lib/lua/5.1/?.so' \
    LUA_PATH='?.lua;common/?.lua;frontend/?.lua;spec/rocks/share/lua/5.1/?.lua;spec/rocks/share/lua/5.1/?/init.lua' \
    TESSDATA_PREFIX="${EMULATOR_DIR}/data" \
    ./luajit -e 'require "busted.runner" {standalone = false}' /dev/null \
    --output=gtest \
    --run=front \
    --sort-files \
    --config-file=spec/config.lua \
    --exclude-tags=notest \
    --helper=spec/helper.lua \
    --loaders=lua \
    -- "$@"
