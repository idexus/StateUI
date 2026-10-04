#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's GTK head for release and lays it in a folder of its
# own, made anew: the head, the StateUI libraries it links, and its pictures.
#
# USAGE:
#   deploy.sh <app-dir> <destination>
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "${1:?the directory of an application}" && pwd)"
destination="${2:?the folder the head is laid in}"
application="$(basename "$app_dir")"
build="$app_dir/.build/gtk/release"

"$script_dir/run-app.sh" "$app_dir" release --build-only

rm -rf "$destination"
mkdir -p "$destination"
cp "$build/${application}GTK" "$destination/"
find "$build" -maxdepth 1 -name '*.so' -exec cp {} "$destination/" \;
[[ ! -d "$build/Images" ]] || cp -R "$build/Images" "$destination/"
echo "deployed:   $destination/${application}GTK"
