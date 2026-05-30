#!/bin/sh
# penjuru/kindle_launch_game.sh
#
# Detached wrapper that lets a KUAL game extension actually run after
# KOReader quits. Why we need this:
#
# KOReader's launcher (platform/kindle/koreader.sh) SIGSTOPs Amazon's
# framework processes (`awesome`, `cvm`) on start and SIGCONTs them on
# exit. If we just launch a game in a detached subshell and call
# UIManager:quit(), koreader.sh resumes those processes, the framework
# grabs the framebuffer back, and the game gets killed within a second
# of starting — what the user sees as "game flashes and then I'm back
# at the kindle home screen".
#
# This wrapper:
#   1. Sleeps briefly so koreader.sh has time to finish its cleanup
#      (the SIGCONTs on awesome / cvm we want to immediately reverse).
#   2. SIGSTOPs awesome + cvm again so the game has the framebuffer.
#   3. Runs the game synchronously.
#   4. SIGCONTs awesome + cvm so the framework comes back when the
#      game exits.
#
# Usage: kindle_launch_game.sh <absolute-path-to-game-launcher.sh>

TARGET="${1}"
if [ -z "${TARGET}" ] || [ ! -f "${TARGET}" ]; then
    exit 1
fi

# Wait for koreader.sh to wrap up. ~2s is enough on PW5; if it's still
# busy after that we'll race, but the worst case is the game flashing
# again, not a brick.
sleep 2

# Re-stop the framework. `2>/dev/null` because awesome/cvm might not
# both be present (sysv vs upstart, model variations); we tolerate misses.
killall -STOP awesome 2>/dev/null
killall -STOP cvm 2>/dev/null

# Run the game synchronously. This script blocks until the game exits.
sh "${TARGET}"

# Give the framework back so the user lands on the Kindle home (or
# wherever the framework decides to put them).
killall -CONT cvm 2>/dev/null
killall -CONT awesome 2>/dev/null

exit 0
