#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Waits until the app process exists, then returns.
#
# Used as a preLaunchTask by the second half of a compound debug configuration.
# Compound sessions start simultaneously, so the debugger that attaches would
# otherwise race the one that launches the app.
#
# Polling rather than a fixed sleep: a cold build can take a minute while a warm
# one is nearly instant, so any constant is either too short sometimes or wasted
# time always.
# ---------------------------------------------------------------------------
set -uo pipefail

PROCESS_NAME="${1:-Gallery}"
TIMEOUT="${2:-180}"     # seconds; generous, because a cold build is included
SETTLE="${3:-1}"        # extra pause after the process appears

echo "Waiting for '$PROCESS_NAME' to start (timeout: ${TIMEOUT}s)..."

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
    # -x matches the EXECUTABLE NAME exactly.
    #
    # Do NOT fall back to "pgrep -f", which matches the whole command line: the
    # project path contains "Gallery", so dotnet/msbuild processes match
    # while the app is still being BUILT. This script then returned instantly,
    # the wait did nothing, and the attaching debugger raced the build - showing
    # up as "'...Gallery.app/Contents/MacOS/Gallery' does not exist"
    # on a cold build, or "process failed to stop within 30 s" afterwards.
    if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
        echo "Found '$PROCESS_NAME' after ${elapsed}s."
        # A brief settle: the process exists a moment before its runtime is
        # ready to be attached to.
        sleep "$SETTLE"
        exit 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))

    # Progress every 10s, so a long wait does not look like a hang.
    if [ $((elapsed % 10)) -eq 0 ]; then
        echo "  still waiting... (${elapsed}s)"
    fi
done

echo "Timed out after ${TIMEOUT}s - '$PROCESS_NAME' never appeared."
echo "The build may have failed; check the other debug session's output."
exit 1
