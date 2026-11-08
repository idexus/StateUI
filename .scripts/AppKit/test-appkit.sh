#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Runs the AppKit host's suite. A run with STATEUI_UPDATE_EXPORTS=1 writes each
# verdict file under the revision its family stands at
# (lib/StateUI/StateUI.Conformance/revisions.txt); STATEUI_STALE_ONLY=1 runs only the
# conformance families whose verdicts stand at another revision, or at none. After the suite the facade and
# the testing module, built for it, are held to their API records (lib/StateUI/exports/api/StateUIAppKit.txt,
# StateUITesting.txt), which STATEUI_UPDATE_EXPORTS=1 writes.
#
# USAGE:
#   test-appkit.sh [swift test arguments - --filter ...]
set -euo pipefail

repository_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
package="$repository_dir/lib/StateUI/StateUI.AppKit"
swift test --package-path "$package" "$@"
modules="$(swift build --package-path "$package" --show-bin-path)"
for module in StateUIAppKit StateUITesting; do
  "$repository_dir/.scripts/API/record.sh" "$module" "$modules"
done
