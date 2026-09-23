#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's Android head, installs it on a device and starts it.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [serial] [--no-logcat]
#
#   app-dir     the application's folder: Package.swift, and Platforms/Android
#   serial      the device, as `adb devices` names it; ANDROID_SERIAL, or the
#               one device attached, when absent
#   --no-logcat returns once the application has started, instead of
#               following its log
#
# The Swift is built for the device's ABI alone, by build-swift.sh; Gradle
# packages it with the host's Java layer. Everything a build writes stays under
# <app-dir>/.build-android.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/../.." && pwd)"
# shellcheck source=tools.sh
source "$script_dir/tools.sh"

app_dir=""
configuration="debug"
serial="${ANDROID_SERIAL:-}"
follow_log=1
for argument in "$@"; do
  case "$argument" in
    --no-logcat)   follow_log=0 ;;
    debug|release) configuration="$argument" ;;
    *)             if [[ -z "$app_dir" ]]; then app_dir="$argument"; else serial="$argument"; fi ;;
  esac
done
[[ -n "$app_dir" ]] || { echo "USAGE: $0 <app-dir> [debug|release] [serial] [--no-logcat]"; exit 1; }

app_dir="$(cd "$app_dir" && pwd)"
application="$(basename "$app_dir")"

serial="$(device_serial "$serial")"
abi="$(device_abi "$serial")"
echo "device:     $serial ($abi)"

apk="$(build_head "$app_dir" "${application}Android" "$configuration" "$abi")"
package="$("$AAPT2" dump packagename "$apk")"

"$ADB" -s "$serial" install -r "$apk"
"$ADB" -s "$serial" shell am force-stop "$package"
"$ADB" -s "$serial" shell am start -W -n "$package/stateui.android.StateUIActivity"

process=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  process="$("$ADB" -s "$serial" shell pidof "$package" | tr -d '\r')"
  [[ -n "$process" ]] && break
  sleep 0.5
done
[[ -n "$process" ]] || { echo "ERROR: $package did not start"; exit 1; }
echo "started:    $package, process $process"

if [[ "$follow_log" == 1 ]]; then
  exec "$ADB" -s "$serial" logcat -v color --pid="$process"
fi
