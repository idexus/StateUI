#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# The browsers installed on this machine, and a page opened in one.
#
# USAGE:
#   browsers.sh list               one browser a line: id, name, executable, and
#                                  "default" for the system's own - tab-separated
#   browsers.sh open <id> <url>    opens <url> in the browser <id>; "default" is
#                                  the system's own
#
# A browser is what the system opens both a web address and a web page with: on
# macOS every application Launch Services lists for https and for an HTML file,
# by its bundle id; on Linux every desktop entry that takes
# x-scheme-handler/https and text/html, by its file's name.
set -euo pipefail

command="${1:-}"

list_macos () {
  local page; page="$(mktemp -t stateui-browsers).html"
  echo "<html></html>" > "$page"
  osascript -l JavaScript - "$page" <<'JXA'
function run(argv) {
  ObjC.import("AppKit");
  const workspace = $.NSWorkspace.sharedWorkspace;
  const address = $.NSURL.URLWithString("https://example.com");
  const ids = (applications) => {
    const found = [];
    for (let index = 0; index < applications.count; index++) found.push(applications.objectAtIndex(index));
    return found;
  };
  const opensPages = new Set(ids(workspace.URLsForApplicationsToOpenURL($.NSURL.fileURLWithPath(argv[0])))
    .map((application) => ObjC.unwrap($.NSBundle.bundleWithURL(application).bundleIdentifier)));
  const preferred = workspace.URLForApplicationToOpenURL(address);
  const seen = new Set();
  const lines = [];
  for (const application of ids(workspace.URLsForApplicationsToOpenURL(address))) {
    const bundle = $.NSBundle.bundleWithURL(application);
    const id = ObjC.unwrap(bundle.bundleIdentifier);
    if (!id || seen.has(id) || !opensPages.has(id)) continue;
    seen.add(id);
    const name = ObjC.unwrap($.NSFileManager.defaultManager.displayNameAtPath(application.path)).replace(/\.app$/, "");
    const isDefault = !preferred.isNil() && ObjC.unwrap(preferred.path) === ObjC.unwrap(application.path);
    lines.push([id, name, ObjC.unwrap(bundle.executablePath) || "", isDefault ? "default" : ""].join("\t"));
  }
  return lines.join("\n");
}
JXA
  rm -f "$page" "${page%.html}"
}

list_linux () {
  local preferred
  preferred="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  local directories=("${XDG_DATA_HOME:-$HOME/.local/share}/applications" /usr/local/share/applications
    /usr/share/applications /var/lib/flatpak/exports/share/applications /var/lib/snapd/desktop/applications)
  declare -A seen=()
  for directory in "${directories[@]}"; do
    [[ -d "$directory" ]] || continue
    for entry in "$directory"/*.desktop; do
      [[ -f "$entry" ]] || continue
      local id; id="$(basename "$entry")"
      [[ -z "${seen[$id]:-}" ]] || continue
      grep -q '^MimeType=.*x-scheme-handler/https' "$entry" || continue
      grep -q '^MimeType=.*text/html' "$entry" || continue
      grep -q '^NoDisplay=true' "$entry" && continue
      seen[$id]=1
      local name executable
      name="$(sed -n 's/^Name=//p' "$entry" | head -n 1)"
      executable="$(sed -n 's/^Exec=//p' "$entry" | head -n 1 | awk '{print $1}')"
      executable="$(command -v "$executable" 2>/dev/null || echo "$executable")"
      printf '%s\t%s\t%s\t%s\n' "$id" "${name:-$id}" "$executable" "$([[ "$id" == "$preferred" ]] && echo default)"
    done
  done
}

case "$command" in
  list)
    case "$(uname -s)" in
      Darwin) list_macos ;;
      Linux)  list_linux ;;
      *)      echo "ERROR: browsers are listed on macOS and Linux." >&2; exit 1 ;;
    esac
    ;;
  open)
    id="${2:?USAGE: $0 open <id> <url>}"
    url="${3:?USAGE: $0 open <id> <url>}"
    case "$(uname -s)" in
      Darwin) if [[ "$id" == "default" ]]; then open "$url"; else open -b "$id" "$url"; fi ;;
      Linux)
        if [[ "$id" == "default" ]]; then xdg-open "$url" >/dev/null 2>&1 &
        else gtk-launch "${id%.desktop}" "$url" >/dev/null 2>&1 || gio launch "$(find /usr/share/applications \
          "${XDG_DATA_HOME:-$HOME/.local/share}/applications" -name "$id" 2>/dev/null | head -n 1)" "$url"; fi ;;
      *)      echo "ERROR: browsers are opened on macOS and Linux." >&2; exit 1 ;;
    esac
    ;;
  *)
    echo "USAGE: $0 list | open <id> <url>" >&2
    exit 1
    ;;
esac
