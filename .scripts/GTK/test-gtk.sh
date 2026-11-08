#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Runs the GTK host's suite. A run with STATEUI_UPDATE_EXPORTS=1 writes each
# verdict file under the revision its family stands at
# (lib/StateUI/StateUI.Conformance/revisions.txt); STATEUI_STALE_ONLY=1 runs only the
# conformance families whose verdicts stand at another revision, or at none.
#
# USAGE:
#   test-gtk.sh [swift test arguments - --filter ...]
set -euo pipefail

repository_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Every machine meets one desktop: a user who chose the accent, as GNOME's from 47 on - a machine with no desktop's
# settings stands so too (docs/design/platforms/gtk/runtime.md, The suite's desktop).
export ADW_DEBUG_ACCENT_COLOR=blue
# The foundation's own tests on Linux - its C library and its thread numbers, the Glibc branches no other machine
# runs - before the host's own, in a run of them whole.
if [[ $# -eq 0 ]]; then
  swift test --package-path "$repository_dir" --filter StateUIFoundationTests
fi
testing="$repository_dir/lib/StateUI/StateUI.GTK/Testing"
swift test --package-path "$testing" "$@"

# The facade and the web view's backend, as this build made them, held to their API records
# (lib/StateUI/exports/api/StateUIGTK.txt, StateUIWebViewGTK.txt): their C modules found by their maps and
# pkg-config's flags.
modules="$(swift build --package-path "$testing" --show-bin-path)"
arguments=()
for map in StateUI/StateUI.GTK/Sources/CStateUIGTK StateUI/StateUI.GTK/Sources/CStateUISoup StateUI/StateUI.Host/CStateUIHost \
    Backends/WebView.GTK/Sources/CWebKitGTK; do
  arguments+=(-Xcc "-fmodule-map-file=$repository_dir/lib/$map/module.modulemap")
done
for flag in $(pkg-config --cflags libadwaita-1 libsoup-3.0 webkitgtk-6.0); do arguments+=(-Xcc "$flag"); done
for module in StateUIGTK StateUIWebViewGTK; do
  "$repository_dir/.scripts/API/record.sh" "$module" "$modules" "" "" "${arguments[@]}"
done
