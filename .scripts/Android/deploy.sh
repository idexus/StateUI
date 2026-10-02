#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's Android head for release, for the ABI of the device
# named, and lays its APK in a folder of its own, made anew.
#
# USAGE:
#   deploy.sh <app-dir> <destination> [serial]
#
#   serial  the device, as `adb devices` names it; ANDROID_SERIAL, or the one
#           device attached, when absent
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools.sh
source "$script_dir/tools.sh"
app_dir="$(cd "${1:?the directory of an application}" && pwd)"
destination="${2:?the folder the APK is laid in}"
application="$(basename "$app_dir")"
serial="$(device_serial "${3:-${ANDROID_SERIAL:-}}")"

apk="$(build_head "$app_dir" "${application}Android" release "$(device_abi "$serial")")"

rm -rf "$destination"
mkdir -p "$destination"
cp "$apk" "$destination/$application.apk"
echo "deployed:   $destination/$application.apk"
