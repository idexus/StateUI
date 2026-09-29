#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's UIKit head, installs it on an iOS simulator - booted
# first where it is not - or on a device of this Mac's, and starts it.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [simulator or device] [--no-log] [--debugger]
#
# A simulator is a name ("iPhone 18 Pro", "iPad Air 13-inch (M4)") or a UDID;
# a device, its name, devicectl's identifier or its UDID; where none is named,
# the simulator booted, else an iPhone. --no-log returns once the application
# has started, instead of following what it prints. --debugger starts it held
# until a debugger attaches, and writes where to <app-dir>/.build/uikit/
# debugger.json: the process - on a simulator one of this Mac's - and, on a
# device, the device and the bundle built, where the debugger reads symbols.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tools.sh"
app_dir="${1:?the directory of an application}"
configuration="debug"
wanted=""
follow=1
debugger=0
for argument in "${@:2}"; do
  case "$argument" in
    debug|release) configuration="$argument" ;;
    --no-log) follow=0 ;;
    --debugger) debugger=1 ;;
    *) wanted="$argument" ;;
  esac
done

[[ $debugger == 0 || "$configuration" == debug ]] || { echo "ERROR: only a debug build can be debugged"; exit 1; }
read -r kind id udid <<< "$(uikit_destination "$wanted")"
[[ -n "$kind" ]] || exit 1
facts="$app_dir/.build/uikit/debugger.json"
rm -f "$facts"

# tell <process> [device] - says the application started; with --debugger, where the debugger attaches.
tell () {
  local process="${1//[^0-9]/}"
  if [[ $debugger == 1 ]]; then
    printf '{"process": %s%s}\n' "$process" "${2:+, \"device\": \"$2\", \"symbols\": \"$bundle\"}" > "$facts"
  fi
  echo "started:    $identifier on ${2:-$id}, process $process"
}

if [[ "$kind" == device ]]; then
  bundle="$("$script_dir/build-app.sh" "$app_dir" "$configuration" "$udid")"
  identifier="$(plutil -extract CFBundleIdentifier raw "$bundle/Info.plist")"
  xcrun devicectl device install app --device "$id" "$bundle" >/dev/null \
    || { echo "ERROR: $identifier did not install on $wanted"; exit 1; }
  launch=(xcrun devicectl device process launch --device "$id" --terminate-existing)
  if [[ $debugger == 1 || $follow == 0 ]]; then
    # Held for the debugger, a device's application says nothing to follow;
    # its process is read from what devicectl answers.
    answer="$(mktemp)"
    "${launch[@]}" $([[ $debugger == 1 ]] && echo --start-stopped) --json-output "$answer" "$identifier" >/dev/null \
      || { echo "ERROR: $identifier did not start on $wanted"; exit 1; }
    tell "$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["result"]["process"]["processIdentifier"])' "$answer")" "$id"
    rm -f "$answer"
    exit 0
  fi
  exec "${launch[@]}" --console "$identifier"
fi

bundle="$("$script_dir/build-app.sh" "$app_dir" "$configuration")"
identifier="$(plutil -extract CFBundleIdentifier raw "$bundle/Info.plist")"
xcrun simctl install "$id" "$bundle"
xcrun simctl terminate "$id" "$identifier" 2>/dev/null || true
if [[ $follow == 1 && $debugger == 0 ]]; then
  exec xcrun simctl launch --console-pty --terminate-running-process "$id" "$identifier"
elif [[ $follow == 1 ]]; then
  # To a pipe simctl says which process it started only once it has more to
  # say, which an application held for the debugger never does: `script` gives
  # it a terminal, and the line comes at once. Its own input stays apart: a
  # terminal is what it asks that to be.
  script -q /dev/null xcrun simctl launch --console-pty --wait-for-debugger --terminate-running-process "$id" \
    "$identifier" < /dev/null | { IFS= read -r first && tell "${first##*: }"; cat; }
  exit 0
fi
launched="$(xcrun simctl launch $([[ $debugger == 1 ]] && echo --wait-for-debugger) "$id" "$identifier")"
tell "${launched##*: }"
