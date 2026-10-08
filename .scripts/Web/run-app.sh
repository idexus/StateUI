#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's Web head - a WebAssembly module - lays its page out
# beside it, serves the page and opens it in a browser.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [--build-only] [--browser <id>|none] [--port <port>]
#
#   app-dir       the application's folder: Package.swift, and Platforms/Web
#   --build-only  builds the head and lays the page out, serving nothing
#   --browser     the browser to open the page in, by the id browsers.sh lists
#                 it under; none opens none; the system's own when not given
#   --port        the port to serve on; 8460 when not given
#
# The page stands in <app-dir>/.build/web/site/<configuration>, laid out by
# page.sh: index.html with what the head's Page folder adds to it, the relay
# stateui-web.js and its look stateui-web.css, the module <App>Web.wasm and the
# application's pictures in Images. It is served on the same port from run to run, so its
# address - and what the browser keeps for it - stays the same, on every
# interface of this machine, so a tablet on its network opens it too; a server this
# script started for the application before is stopped first. Once the server
# listens, <app-dir>/.build/web/server.json says where. Every STATEUI_ variable
# of the calling shell - STATEUI_TALLY=1 - reaches the application as a
# parameter of the page's address.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

app_dir=""
configuration="debug"
build_only=0
browser="default"
port=8460
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only)  build_only=1 ;;
    --browser)     browser="$2"; shift ;;
    --port)        port="$2"; shift ;;
    debug|release) configuration="$1" ;;
    *)             app_dir="$1" ;;
  esac
  shift
done
[[ -n "$app_dir" ]] || { echo "USAGE: $0 <app-dir> [debug|release] [--build-only] [--browser <id>|none] [--port <port>]"; exit 1; }

app_dir="$(cd "$app_dir" && pwd)"
application="$(basename "$app_dir")"
product="${application}Web"
scratch="$app_dir/.build/web"
site="$scratch/site/$configuration"
facts="$scratch/server.json"

# --- the Swift SDK for WebAssembly of the compiler's release -----------------
. "$here/swift-sdk.sh"

# --- the head ----------------------------------------------------------------
STATEUI_HOST=web swift build \
  --package-path "$app_dir" \
  --scratch-path "$scratch" \
  --configuration "$configuration" \
  --swift-sdk "$sdk" \
  --product "$product"
products="$(STATEUI_HOST=web swift build --package-path "$app_dir" --scratch-path "$scratch" \
  --configuration "$configuration" --swift-sdk "$sdk" --show-bin-path)"

# --- the page ----------------------------------------------------------------
bash "$here/page.sh" "$app_dir" "$products" "$site"
if [[ "$build_only" == 1 ]]; then
  echo "built:      $site"
  exit 0
fi

# --- served, and opened ------------------------------------------------------
pkill -f "serve.py $site " 2>/dev/null && sleep 0.3 || true
rm -f "$facts"
query=""
while IFS='=' read -r name value; do
  query+="${query:+&}$name=$value"
done < <(env | grep '^STATEUI_' | grep -v '^STATEUI_HOST=' || true)

python3 -u "$here/serve.py" "$site" "$port" "$facts" ${query:+"?$query"} &
server=$!
trap 'kill $server 2>/dev/null || true' EXIT INT TERM
for _ in $(seq 1 100); do
  [[ -f "$facts" ]] && break
  kill -0 "$server" 2>/dev/null || { echo "ERROR: the page's server did not start."; exit 1; }
  sleep 0.1
done
[[ -f "$facts" ]] || { echo "ERROR: the page's server did not say where it listens."; exit 1; }
url="$(sed -n 's/.*"url": *"\([^"]*\)".*/\1/p' "$facts")"
if [[ "$browser" != "none" ]]; then
  bash "$here/browsers.sh" open "$browser" "$url"
fi
wait "$server"
