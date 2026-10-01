#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Runs the GTK host's suite. A run with STATEUI_UPDATE_EXPORTS=1 writes each
# verdict file under the revision its family stands at
# (lib/StateUI.Conformance/revisions.txt); STATEUI_STALE_ONLY=1 runs only the
# conformance families whose verdicts stand at another revision, or at none.
#
# USAGE:
#   test-gtk.sh [swift test arguments - --filter ...]
set -euo pipefail

repository_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec swift test --package-path "$repository_dir/lib/StateUI.GTK/Testing" "$@"
