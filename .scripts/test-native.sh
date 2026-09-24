#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/.." && pwd)"

swift test --package-path "$repository_dir"
swift test --package-path "$repository_dir/lib/StateUI.AppKit"
swift test --package-path "$repository_dir/apps/Gallery"

# And Swift written for the AppKit host alone stands under `#if APPKIT`, so the
# Gallery runs once more as an AppKit build - STATEUI_APPKIT, which its
# manifest reads to define that condition - on the directory that build keeps.
STATEUI_APPKIT=1 swift test --package-path "$repository_dir/apps/Gallery" \
  --scratch-path "$repository_dir/apps/Gallery/.build-appkit"
