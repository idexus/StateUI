#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's UIKit head for the iOS simulator and makes it an
# application bundle: the executable, the Swift libraries beside it, the
# pictures drawn for a toolkit that draws no SVG, an Info.plist whose scenes
# are many - an iPad's windows - and an ad-hoc signature. Prints the bundle.
#
# USAGE:
#   build-app.sh <app-dir> [debug|release]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tools.sh"
app_dir="$(cd "${1:?the directory of an application}" && pwd)"
configuration="${2:-debug}"
name="$(basename "$app_dir")"
product="${name}UIKit"
scratch="$app_dir/.build-uikit"

export STATEUI_UIKIT=1
binary_dir="$(uikit_build "$app_dir" "$scratch" "$configuration" "$product")"
bundle="$scratch/$configuration/$product.app"
identifier="com.stateui.$(tr '[:upper:]' '[:lower:]' <<< "$name")"
uikit_bundle "$binary_dir" "$product" "$name" "$identifier" "$app_dir/Resources/Images" "$bundle" "$scratch/tools"
echo "$bundle"
