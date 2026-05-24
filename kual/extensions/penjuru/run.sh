#!/bin/sh
# penjuru — KUAL launcher.
# Drops an auto-open flag so the plugin's main.lua opens the home
# overlay immediately after KOReader finishes initializing, then
# execs KOReader. Tap "penjuru" in KUAL -> KOReader boots straight
# into the home, no menu navigation required.

KO_SETTINGS="/mnt/us/koreader/settings"
KO_LAUNCHER="/mnt/us/koreader/koreader.sh"

# Ensure the settings dir exists (it should, but be defensive).
mkdir -p "$KO_SETTINGS"

# Drop the auto-open marker. main.lua consumes (deletes) it on the
# next init so a normal KOReader launch after this doesn't trigger
# the home overlay again.
touch "$KO_SETTINGS/penjuru-autoopen.flag"

# Launch KOReader.
if [ -x "$KO_LAUNCHER" ]; then
  exec "$KO_LAUNCHER"
else
  echo "penjuru/run.sh: $KO_LAUNCHER not found or not executable" >&2
  exit 1
fi
