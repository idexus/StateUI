#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's AppKit head and starts it.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [--build-only]
#
#   app-dir       the application's folder: Package.swift, and Platforms/AppKit
#   --build-only  builds the head and says where it is, starting nothing
#
# The checkout's own application with a bundling script of this folder -
# build-<application>-appkit.sh - is built as its bundle; any other by SwiftPM,
# with the application's artwork - its Resources' Images and AppIcon - laid in
# Resources beside the executable, where the host reads it. Everything a build
# writes stays under <app-dir>/.build/appkit.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir=""
configuration="debug"
build_only=0
for argument in "$@"; do
  case "$argument" in
    --build-only)  build_only=1 ;;
    debug|release) configuration="$argument" ;;
    *)             app_dir="$argument" ;;
  esac
done
[[ -n "$app_dir" ]] || { echo "USAGE: $0 <app-dir> [debug|release] [--build-only]"; exit 1; }

app_dir="$(cd "$app_dir" && pwd)"
application="$(basename "$app_dir")"
product="${application}AppKit"
build="$app_dir/.build/appkit/$configuration"
bundler="$script_dir/build-$(tr '[:upper:]' '[:lower:]' <<< "$application")-appkit.sh"
# A bundling script is the checkout's own application's alone: one of the same name elsewhere is built plainly.
[[ "$app_dir" == "$(cd "$script_dir/../.." && pwd)/apps/$application" && -x "$bundler" ]] || bundler=""

if [[ -n "$bundler" ]]; then
  "$bundler" "$configuration"
  program="$build/$product.app/Contents/MacOS/$product"
else
  STATEUI_HOST=appkit swift build --package-path "$app_dir" --scratch-path "$app_dir/.build/appkit" \
    --configuration "$configuration" --product "$product"
  for artwork in Images AppIcon; do
    rm -rf "$build/Resources/$artwork"
    [[ ! -d "$app_dir/Resources/$artwork" ]] || { mkdir -p "$build/Resources"; cp -R "$app_dir/Resources/$artwork" "$build/Resources/"; }
  done
  program="$build/$product"
fi

echo "built:      $program"
(( build_only )) || exec "$program"
