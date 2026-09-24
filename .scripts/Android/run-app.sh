#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's Android head, installs it on a device and starts it.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [serial] [--no-logcat] [--debugger]
#
#   app-dir     the application's folder: Package.swift, and Platforms/Android
#   serial      the device, as `adb devices` names it; ANDROID_SERIAL, or the
#               one device attached, when absent
#   --no-logcat returns once the application has started, instead of
#               following its log
#   --debugger  readies the Swift debugger to attach to the application once
#               it has started - a debug build's: the NDK's lldb-server runs in
#               the application's own sandbox, and what the debugger needs to
#               reach it is written to <app-dir>/.build-android/debugger.json
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
debugger=0
for argument in "$@"; do
  case "$argument" in
    --no-logcat)   follow_log=0 ;;
    --debugger)    debugger=1 ;;
    debug|release) configuration="$argument" ;;
    *)             if [[ -z "$app_dir" ]]; then app_dir="$argument"; else serial="$argument"; fi ;;
  esac
done
[[ -n "$app_dir" ]] || { echo "USAGE: $0 <app-dir> [debug|release] [serial] [--no-logcat] [--debugger]"; exit 1; }
[[ "$debugger" == 0 || "$configuration" == debug ]] || { echo "ERROR: only a debug build can be debugged"; exit 1; }

app_dir="$(cd "$app_dir" && pwd)"
application="$(basename "$app_dir")"
build="$app_dir/.build-android"
rm -f "$build/debugger.json"

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

if [[ "$debugger" == 1 ]]; then
  # The debugger's server is the NDK's the build used, for the device's ABI.
  case "$abi" in
    arm64-v8a)   architecture=aarch64 ;;
    armeabi-v7a) architecture=arm ;;
    x86)         architecture=i386 ;;
    *)           architecture="$abi" ;;
  esac
  ndk="$(cat "$build/ndk-root")"
  server="$(ls -d "$ndk"/toolchains/llvm/prebuilt/*/lib/clang/*/lib/linux/"$architecture"/lldb-server 2>/dev/null \
    | sort -V | tail -n 1)"
  [[ -n "$server" ]] || { echo "ERROR: the NDK at $ndk has no lldb-server for $abi"; exit 1; }

  # It runs as the application - run-as, which a debug build allows - in the application's own directory, and
  # listens on a socket named after the package. A server left from the last run is stopped first: stopping the
  # application does not stop what run-as started; and the new one is renamed into place, since a running
  # server's file cannot be written over.
  socket="$package/stateui-debugger.sock"
  "$ADB" -s "$serial" push "$server" /data/local/tmp/stateui-lldb-server >/dev/null
  "$ADB" -s "$serial" shell run-as "$package" sh -c "'pkill -x lldb-server; \
    cp /data/local/tmp/stateui-lldb-server lldb-server.new && chmod 700 lldb-server.new && mv lldb-server.new lldb-server'"
  "$ADB" -s "$serial" shell \
    "run-as $package sh -c './lldb-server platform --server --listen unix-abstract:///$socket </dev/null >/dev/null 2>&1 &'" \
    </dev/null
  printf '{ "serial": "%s", "package": "%s", "process": %s, "socket": "%s", "symbols": "%s" }\n' \
    "$serial" "$package" "$process" "$socket" "$build/symbols/$abi" > "$build/debugger.json"
  echo "debugger:   ready to attach - $build/debugger.json"
fi

if [[ "$follow_log" == 1 ]]; then
  exec "$ADB" -s "$serial" logcat -v color --pid="$process"
fi
