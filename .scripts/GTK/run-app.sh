#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's GTK head and starts it.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [--detach] [--build-only]
#
#   app-dir       the application's folder: Package.swift, and Platforms/GTK
#   --detach      returns once the application has started; its output goes to
#                 <app-dir>/.build-gtk/run.log
#   --build-only  builds the head and says where it is, starting nothing
#
# A running copy of the head is stopped first: a GTK application is one
# instance, and a second launch would only bring the first one forward.
# Everything a build writes stays under <app-dir>/.build-gtk. Every STATEUI_
# variable of the calling shell - STATEUI_TALLY=1, STATEUI_INSPECT=1 - reaches
# the application.
set -euo pipefail

app_dir=""
configuration="debug"
detach=0
build_only=0
for argument in "$@"; do
  case "$argument" in
    --detach)      detach=1 ;;
    --build-only)  build_only=1 ;;
    debug|release) configuration="$argument" ;;
    *)             app_dir="$argument" ;;
  esac
done
[[ -n "$app_dir" ]] || { echo "USAGE: $0 <app-dir> [debug|release] [--detach] [--build-only]"; exit 1; }

app_dir="$(cd "$app_dir" && pwd)"
application="$(basename "$app_dir")"
product="${application}GTK"
scratch="$app_dir/.build-gtk"
executable="$scratch/$configuration/$product"

# The executable is written again; a running copy goes first, found by its path.
pkill -f "^$executable( |$)" 2>/dev/null && sleep 0.3 || true

STATEUI_GTK=1 swift build \
  --package-path "$app_dir" \
  --scratch-path "$scratch" \
  --configuration "$configuration" \
  --product "$product"

# The application's pictures stand in Images beside the executable, where the host reads them.
if [[ -d "$app_dir/Resources/Images" ]]; then
  mkdir -p "$scratch/$configuration/Images"
  cp -R "$app_dir/Resources/Images/." "$scratch/$configuration/Images/"
fi
# The desktop shows a window with the icon of the entry named by its application's ID: both are installed for
# the user, the entry starting this build.
application_id="$(sed -n 's/.*applicationID: "\([^"]*\)".*/\1/p' "$app_dir/Platforms/GTK/main.swift" | head -1)"
if [[ -n "$application_id" && -f "$app_dir/Resources/AppIcon/appicon_gnome.svg" ]]; then
  data="${XDG_DATA_HOME:-$HOME/.local/share}"
  mkdir -p "$data/icons/hicolor/scalable/apps" "$data/applications"
  cp "$app_dir/Resources/AppIcon/appicon_gnome.svg" "$data/icons/hicolor/scalable/apps/$application_id.svg"
  cat > "$data/applications/$application_id.desktop" <<ENTRY
[Desktop Entry]
Type=Application
Name=$application
Exec=$executable
Icon=$application_id
StartupWMClass=$product
Terminal=false
Categories=Development;
ENTRY
fi
if [[ "$build_only" == 1 ]]; then
  echo "built:      $executable"
  exit 0
fi

if [[ "$detach" == 1 ]]; then
  setsid "$executable" > "$scratch/run.log" 2>&1 < /dev/null &
  for _ in $(seq 1 20); do
    pgrep -f "^$executable( |$)" > /dev/null && { echo "started:    $product, log $scratch/run.log"; exit 0; }
    sleep 0.25
  done
  echo "ERROR: $product did not start - $scratch/run.log says why"
  exit 1
fi

exec "$executable"
