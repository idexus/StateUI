#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's Web head for release and lays its page at a
# destination, made anew: index.html, the relay stateui-web.js, the module
# <App>Web.wasm and the pictures in Images - a folder any web server serves as
# it is.
#
# USAGE:
#   deploy.sh <app-dir> <destination>
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="${1:?USAGE: $0 <app-dir> <destination>}"
destination="${2:?USAGE: $0 <app-dir> <destination>}"

bash "$here/run-app.sh" "$app_dir" release --build-only
app_dir="$(cd "$app_dir" && pwd)"
rm -rf "$destination"
mkdir -p "$destination"
cp -R "$app_dir/.build/web/site/release/." "$destination/"
echo "deployed:   $destination"
