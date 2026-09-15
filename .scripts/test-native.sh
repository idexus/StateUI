#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/.." && pwd)"

swift test --package-path "$repository_dir"
swift test --package-path "$repository_dir/lib/StateUI.AppKit"
swift test --package-path "$repository_dir/apps/Gallery"

# Swift written for the MAUI host alone stands under `#if MAUI`, so the library
# and the Gallery run again with that condition - on build directories of
# their own, which a switch of condition would otherwise rebuild from scratch.
swift test --package-path "$repository_dir" \
  --scratch-path "$repository_dir/.build-maui" -Xswiftc -DMAUI
swift test --package-path "$repository_dir/apps/Gallery" \
  --scratch-path "$repository_dir/apps/Gallery/.build-maui" -Xswiftc -DMAUI

# And Swift written for the AppKit host alone stands under `#if APPKIT`, so the
# Gallery runs once more with that condition, on the directory its AppKit
# build keeps.
swift test --package-path "$repository_dir/apps/Gallery" \
  --scratch-path "$repository_dir/apps/Gallery/.build-appkit" -Xswiftc -DAPPKIT
