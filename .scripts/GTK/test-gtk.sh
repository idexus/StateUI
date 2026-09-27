#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Runs the GTK host's suite with the digest of the sources its conformance
# verdicts rest on (.scripts/Marks/inputs.sh), which a run with
# STATEUI_UPDATE_EXPORTS=1 writes over each verdict file it writes.
#
# USAGE:
#   test-gtk.sh [swift test arguments - --filter ...]
set -euo pipefail

repository_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATEUI_MARKS_INPUTS="$("$repository_dir/.scripts/Marks/inputs.sh" gtk)"
export STATEUI_MARKS_INPUTS
exec swift test --package-path "$repository_dir/lib/StateUI.GTK" "$@"
