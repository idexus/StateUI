#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# The devices an Android head can run on.
#
# USAGE:
#   devices.sh list          one line a device, tab-separated:
#                              device <serial> <model>   a device attached and ready
#                              avd    <name>             an emulator not running
#   devices.sh boot <avd>    starts the emulator, waits until it has booted,
#                            and prints its serial
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/../.." && pwd)"
# shellcheck source=tools.sh
source "$script_dir/tools.sh"

# The AVD an emulator runs, by its serial.
running_avd () {
  "$ADB" -s "$1" emu avd name 2>/dev/null | head -n 1 | tr -d '\r'
}

case "${1:-}" in
  list)
    running=" "
    while read -r serial state rest; do
      [[ "$state" == device ]] || continue
      model="$(sed -nE 's/.*model:([^ ]+).*/\1/p' <<< "$rest")"
      if [[ "$serial" == emulator-* ]]; then
        avd="$(running_avd "$serial")"
        running="$running$avd "
        model="${avd:-$model}"
      fi
      printf 'device\t%s\t%s\n' "$serial" "${model:-$serial}"
    done < <("$ADB" devices -l | tail -n +2)

    "$EMULATOR" -list-avds 2>/dev/null | while read -r avd; do
      [[ -n "$avd" && "$running" != *" $avd "* ]] && printf 'avd\t%s\n' "$avd"
    done
    ;;

  boot)
    avd="${2:-}"
    [[ -n "$avd" ]] || { echo "USAGE: $0 boot <avd>"; exit 1; }
    before="$("$ADB" devices | awk '/^emulator-/ { print $1 }')"
    nohup "$EMULATOR" -avd "$avd" -no-snapshot-save -no-boot-anim >/dev/null 2>&1 &

    serial=""
    for _ in $(seq 1 120); do
      for candidate in $("$ADB" devices | awk '/^emulator-/ { print $1 }'); do
        [[ " $before " == *" $candidate "* ]] && continue
        [[ "$(running_avd "$candidate")" == "$avd" ]] && serial="$candidate"
      done
      if [[ -n "$serial" ]] \
          && [[ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; then
        echo "$serial"
        exit 0
      fi
      sleep 2
    done
    echo "ERROR: $avd did not boot within four minutes" >&2
    exit 1
    ;;

  *)
    echo "USAGE: $0 list | boot <avd>"
    exit 1
    ;;
esac
