#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's AppKit head for release and lays it in a folder of
# its own, made anew: its application bundle, where a script of this folder
# bundles it (build-<application>-appkit.sh), else the head and the StateUI
# libraries it links, with the application's artwork - its Resources' Images
# and AppIcon - beside them, where the head reads it.
#
# USAGE:
#   deploy.sh <app-dir> <destination>
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "${1:?the directory of an application}" && pwd)"
destination="${2:?the folder the head is laid in}"
application="$(basename "$app_dir")"
product="${application}AppKit"
build="$app_dir/.build/appkit/release"
bundler="$script_dir/build-$(tr '[:upper:]' '[:lower:]' <<< "$application")-appkit.sh"
# A bundling script is the checkout's own application's alone: one of the same name elsewhere is laid out plainly.
[[ "$app_dir" == "$(cd "$script_dir/../.." && pwd)/apps/$application" ]] || bundler=""

rm -rf "$destination"
mkdir -p "$destination"
if [[ -n "$bundler" && -x "$bundler" ]]; then
  "$bundler" release
  cp -R "$build/$product.app" "$destination/"
  echo "deployed:   $destination/$product.app"
else
  STATEUI_HOST=appkit swift build --package-path "$app_dir" --scratch-path "$app_dir/.build/appkit" \
    --configuration release --product "$product"
  cp "$build/$product" "$destination/"
  find -H "$build" -maxdepth 1 -name '*.dylib' -exec cp {} "$destination/" \;
  for artwork in Images AppIcon; do
    [[ ! -d "$app_dir/Resources/$artwork" ]] || { mkdir -p "$destination/Resources"; cp -R "$app_dir/Resources/$artwork" "$destination/Resources/"; }
  done
  echo "deployed:   $destination/$product"
fi
