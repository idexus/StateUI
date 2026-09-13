#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/.." && pwd)"

swift test --package-path "$repository_dir"
swift test --package-path "$repository_dir/lib/StateUI.AppKit"
swift test --package-path "$repository_dir/apps/Gallery"
