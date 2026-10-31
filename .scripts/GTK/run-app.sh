#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's GTK head and starts it.
#
# USAGE:
#   run-app.sh <app-dir> [debug|release] [--detach | --gdb] [--build-only]
#
#   app-dir       the application's folder: Package.swift, and Platforms/GTK
#   --detach      returns once the application has started; its output goes to
#                 <app-dir>/.build/gtk/run.log
#   --gdb         as --detach, under gdb: every GTK critical's stack, and a
#                 crash's, goes to <app-dir>/.build/gtk/gdb.log ("=== CRITICAL",
#                 "=== STOPPED") and the application goes on past a critical. It
#                 starts from the session's service manager where there is one,
#                 as WebKitGTK's sandbox needs a process of the session.
#   --build-only  builds the head and says where it is, starting nothing
#
# A running copy of the head is stopped first: a GTK application is one
# instance, and a second launch would only bring the first one forward.
# Everything a build writes stays under <app-dir>/.build/gtk. Every STATEUI_
# variable of the calling shell - STATEUI_TALLY=1, STATEUI_INSPECT=1 - reaches
# the application.
set -euo pipefail

app_dir=""
configuration="debug"
detach=0
under_gdb=0
build_only=0
for argument in "$@"; do
  case "$argument" in
    --detach)      detach=1 ;;
    --gdb)         under_gdb=1 ;;
    --build-only)  build_only=1 ;;
    debug|release) configuration="$argument" ;;
    *)             app_dir="$argument" ;;
  esac
done
[[ -n "$app_dir" ]] || { echo "USAGE: $0 <app-dir> [debug|release] [--detach | --gdb] [--build-only]"; exit 1; }

app_dir="$(cd "$app_dir" && pwd)"
application="$(basename "$app_dir")"
product="${application}GTK"
scratch="$app_dir/.build/gtk"
executable="$scratch/$configuration/$product"

# The executable is written again; a running copy goes first, found by its path.
pkill -f "^$executable( |$)" 2>/dev/null && sleep 0.3 || true

STATEUI_HOST=gtk swift build \
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
  # The links the application opens: the schemes its head lists in Platforms/GTK/link-schemes, one a line.
  schemes=""
  if [[ -f "$app_dir/Platforms/GTK/link-schemes" ]]; then
    schemes="$(grep -v '^[[:space:]]*$' "$app_dir/Platforms/GTK/link-schemes")"
  fi
  mime_types="$(for scheme in $schemes; do printf 'x-scheme-handler/%s;' "$scheme"; done)"
  cat > "$data/applications/$application_id.desktop" <<ENTRY
[Desktop Entry]
Type=Application
Name=$application
Exec=$executable %u
Icon=$application_id
StartupWMClass=$product
Terminal=false
Categories=Development;
${mime_types:+MimeType=$mime_types}
ENTRY
  for scheme in $schemes; do
    xdg-mime default "$application_id.desktop" "x-scheme-handler/$scheme" 2>/dev/null || true
  done
fi
if [[ "$build_only" == 1 ]]; then
  echo "built:      $executable"
  exit 0
fi

if [[ "$under_gdb" == 1 ]]; then
  commands="$scratch/gdb.cmd"
  cat > "$commands" <<'COMMANDS'
set pagination off
set confirm off
set print thread-events off
set print inferior-events off
set debuginfod enabled off
handle SIGPIPE nostop noprint pass
handle SIGUSR1 nostop noprint pass
set breakpoint pending on
break g_return_if_fail_warning
commands
silent
printf "=== CRITICAL %s: %s\n", (char *)$x1, (char *)$x2
bt 25
continue
end
run
printf "=== STOPPED\n"
bt 60
info threads
thread apply all bt 12
COMMANDS
  launch=(gdb -batch -x "$commands" --args "$executable")
  if systemctl --user show-environment > /dev/null 2>&1; then
    unit="stateui-$(echo "$application" | tr '[:upper:]' '[:lower:]')-gdb"
    systemctl --user stop "$unit" 2> /dev/null || true
    systemctl --user reset-failed "$unit" 2> /dev/null || true
    passed=()
    for name in DISPLAY WAYLAND_DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR HOME PATH \
                ${GDK_BACKEND:+GDK_BACKEND} $(compgen -e | grep '^STATEUI_' || true); do
      passed+=(-E "$name")
    done
    systemd-run --user --quiet --unit="$unit" --same-dir "${passed[@]}" -E SWIFT_BACKTRACE=enable=no \
      bash -c '"$@" > "'"$scratch/gdb.log"'" 2>&1' gdb "${launch[@]}"
  else
    SWIFT_BACKTRACE=enable=no setsid "${launch[@]}" > "$scratch/gdb.log" 2>&1 < /dev/null &
  fi
  # gdb starts the file the build's link names, so the process is found by its name, not by the link's path.
  for _ in $(seq 1 120); do
    pgrep -x "${product:0:15}" > /dev/null && { echo "started:    $product under gdb, log $scratch/gdb.log"; exit 0; }
    sleep 0.5
  done
  echo "ERROR: $product did not start under gdb - $scratch/gdb.log says why"
  exit 1
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
