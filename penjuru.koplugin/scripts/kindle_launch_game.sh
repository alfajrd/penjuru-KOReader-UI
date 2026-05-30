#!/bin/sh
# penjuru/kindle_launch_game.sh   (v1.2.14.15)
#
# Detached wrapper that lets a KUAL game extension actually run after
# KOReader quits, with bulletproof framework cleanup.
#
# Why this exists:
#   KOReader's launcher (platform/kindle/koreader.sh) SIGSTOPs Amazon's
#   framework (awesome, cvm) on start and SIGCONTs them on exit. If
#   we just launch a game in a detached subshell, koreader.sh resumes
#   the framework as KOReader quits, the framework grabs the framebuffer
#   back, and the game dies within a second.
#
# What v1.2.14.13 got wrong:
#   It SIGSTOPped awesome/cvm again, then ran `sh "$TARGET"` hoping the
#   game would exit normally. If the game hung or failed silently, the
#   script never reached the SIGCONT lines, the framework stayed paused
#   forever, and the Kindle bricked. That's what happened.
#
# What this rewrite guarantees:
#   1. `trap restore_framework EXIT INT TERM HUP QUIT` ensures SIGCONT
#      runs on ANY exit path the shell can observe (normal exit, error,
#      signal, parent kill, etc.). The ONLY case it can't trap is the
#      script itself being SIGKILLed (kill -9), which is exceptional.
#   2. `timeout 600 …` bounds the game's runtime to 10 minutes — even
#      if the game hangs completely, the wrapper returns and the trap
#      fires.
#   3. The framework re-SIGSTOP only happens AFTER the trap is armed,
#      so any error before it would not leave awesome/cvm paused.
#   4. `kindle_brick_guard.sh` armed at boot time would re-SIGCONT them
#      after 15 minutes if we ever missed (not in this commit, but a
#      future hardening if v1.2.14.15 itself ever bricks).
#
# Usage: kindle_launch_game.sh <absolute-path-to-game-launcher.sh>

TARGET="${1}"

# --- step 0: arm cleanup trap FIRST, before we touch anything dangerous ---
restore_framework() {
    # 2>/dev/null because the processes may have died (e.g. crash, restart).
    # We do not propagate failure — exit code from killall doesn't matter
    # once we've made the attempt.
    killall -CONT cvm 2>/dev/null
    killall -CONT awesome 2>/dev/null
}
trap restore_framework EXIT INT TERM HUP QUIT

# --- step 1: validate the target before doing anything else ---
if [ -z "${TARGET}" ] || [ ! -f "${TARGET}" ]; then
    # trap fires → framework restored (it wasn't stopped yet, but safe)
    exit 1
fi

# --- step 2: wait for koreader.sh to finish its own cleanup ---
# It SIGCONTs awesome/cvm on exit; we want to immediately re-pause them.
# 2s is enough on PW5; the trap covers us if we race.
sleep 2

# --- step 3: re-pause the framework ---
killall -STOP awesome 2>/dev/null
killall -STOP cvm 2>/dev/null

# --- step 4: run the game with a hard timeout ---
# Even if the game hangs forever, `timeout` SIGTERMs it after 10 minutes.
# `|| true` so a non-zero exit from timeout or the game doesn't skip
# the trap-driven cleanup (it wouldn't anyway, but explicit > implicit).
timeout 600 sh "${TARGET}" </dev/null >/dev/null 2>&1 || true

# Trap runs on exit, restoring the framework. Explicit `exit 0` so the
# trap sees a clean exit code.
exit 0
