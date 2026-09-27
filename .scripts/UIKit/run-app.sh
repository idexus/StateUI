#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's UIKit head, installs it on an iOS simulator - booted
# first where it is not - and starts it.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [simulator] [--no-log] [--debugger]
#
# The simulator is a name ("iPhone 18 Pro", "iPad Air 13-inch (M4)") or a
# UDID; the one booted, else an iPhone, where none is named. --no-log returns
# once the application has started, instead of following what it prints.
# --debugger starts it held until a debugger attaches - a simulator's process
# is one of this Mac's, attached to by its number - and writes that number to
# <app-dir>/.build-uikit/debugger.json.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tools.sh"
app_dir="${1:?the directory of an application}"
configuration="debug"
simulator=""
follow=1
wait=()
for argument in "${@:2}"; do
  case "$argument" in
    debug|release) configuration="$argument" ;;
    --no-log) follow=0 ;;
    --debugger) wait=(--wait-for-debugger) ;;
    *) simulator="$argument" ;;
  esac
done

[[ ${#wait[@]} == 0 || "$configuration" == debug ]] || { echo "ERROR: only a debug build can be debugged"; exit 1; }
device="$(uikit_simulator "$simulator")"
facts="$app_dir/.build-uikit/debugger.json"
rm -f "$facts"

bundle="$("$script_dir/build-app.sh" "$app_dir" "$configuration")"
identifier="$(plutil -extract CFBundleIdentifier raw "$bundle/Info.plist")"
xcrun simctl install "$device" "$bundle"
xcrun simctl terminate "$device" "$identifier" 2>/dev/null || true
# The first line simctl prints names the process - with --debugger, what the
# debugger attaches to.
tell () {
  local process="${1##*: }"
  process="${process//[^0-9]/}"
  [[ ${#wait[@]} == 0 ]] || printf '{"process": %s}\n' "$process" > "$facts"
  echo "started:    $identifier on $device, process $process"
}
if [[ $follow == 1 && ${#wait[@]} == 0 ]]; then
  exec xcrun simctl launch --console-pty --terminate-running-process "$device" "$identifier"
elif [[ $follow == 1 ]]; then
  # To a pipe simctl says which process it started only once it has more to
  # say, which an application held for the debugger never does: `script` gives
  # it a terminal, and the line comes at once. Its own input stays apart: a
  # terminal is what it asks that to be.
  script -q /dev/null xcrun simctl launch --console-pty "${wait[@]}" --terminate-running-process "$device" "$identifier" \
    < /dev/null | { IFS= read -r first && tell "$first"; cat; }
  exit 0
fi
tell "$(xcrun simctl launch ${wait[@]+"${wait[@]}"} "$device" "$identifier")"
