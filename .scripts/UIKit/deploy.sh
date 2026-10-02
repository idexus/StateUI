#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's UIKit head for release, as an application bundle for
# the device named - a simulator, or an iPhone or iPad it is signed for - and
# lays the bundle in a folder of its own, made anew.
#
# USAGE:
#   deploy.sh <app-dir> <destination> <device-udid>
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tools.sh"
app_dir="$(cd "${1:?the directory of an application}" && pwd)"
destination="${2:?the folder the bundle is laid in}"
device="${3:?the simulator or device the bundle is built for}"

# A simulator's bundle is built for the simulator, a device's signed for it, by its UDID.
read -r kind _ udid <<< "$(uikit_destination "$device")"
if [[ "$kind" == device ]]; then
  bundle="$("$script_dir/build-app.sh" "$app_dir" release "$udid" | tail -n 1)"
else
  bundle="$("$script_dir/build-app.sh" "$app_dir" release | tail -n 1)"
fi

rm -rf "$destination"
mkdir -p "$destination"
cp -R "$bundle" "$destination/"
echo "deployed:   $destination/$(basename "$bundle")"
