#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's UIKit head and makes it an application bundle: the
# executable, the Swift libraries in Frameworks/, the pictures drawn for a
# toolkit that draws no SVG, the icon, an Info.plist whose scenes are many - an
# iPad's windows - and a signature. For the iOS simulator by default; for a
# device where its UDID is given, signed with a development profile that lets
# it run there. Prints the bundle.
#
# USAGE:
#   build-app.sh <app-dir> [debug|release] [device-udid]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tools.sh"
app_dir="$(cd "${1:?the directory of an application}" && pwd)"
configuration="${2:-debug}"
device="${3:-}"
name="$(basename "$app_dir")"
product="${name}UIKit"
scratch="$app_dir/.build/uikit"
[[ -z "$device" ]] || uikit_target iphoneos

export STATEUI_HOST=uikit
binary_dir="$(uikit_build "$app_dir" "$scratch" "$configuration" "$product")"
bundle="$binary_dir/$product.app"
identifier="com.stateui.$(tr '[:upper:]' '[:lower:]' <<< "$name")"
uikit_bundle "$binary_dir" "$product" "$name" "$identifier" "$app_dir/Resources" "$bundle" "$binary_dir/tools" \
  "$app_dir/Platforms/UIKit/Info.plist" $device
echo "$bundle"
