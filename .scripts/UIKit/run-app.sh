#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's UIKit head, installs it on an iOS simulator - booted
# first where it is not - and starts it.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [simulator] [--no-log] [--wait-for-debugger]
#
# The simulator is a name ("iPhone 18 Pro", "iPad Air 13-inch (M4)") or a
# UDID; the one booted, else an iPhone, where none is named. --no-log returns
# once the application has started, instead of following what it prints.
# --wait-for-debugger starts it held until a debugger attaches, and prints its
# process.
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
    --wait-for-debugger) wait=(--wait-for-debugger) ;;
    *) simulator="$argument" ;;
  esac
done

device="$(uikit_simulator "$simulator")"

bundle="$("$script_dir/build-app.sh" "$app_dir" "$configuration")"
identifier="$(plutil -extract CFBundleIdentifier raw "$bundle/Info.plist")"
xcrun simctl install "$device" "$bundle"
xcrun simctl terminate "$device" "$identifier" 2>/dev/null || true
if [[ $follow == 1 ]]; then
  exec xcrun simctl launch --console-pty ${wait[@]+"${wait[@]}"} --terminate-running-process "$device" "$identifier"
fi
launched="$(xcrun simctl launch ${wait[@]+"${wait[@]}"} "$device" "$identifier")"
echo "started:    $identifier on $device, process ${launched##*: }"
