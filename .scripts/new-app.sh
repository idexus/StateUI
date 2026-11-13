#!/usr/bin/env bash
# Copyright 2026 the StateUI project authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ---------------------------------------------------------------------------
# Creates a new StateUI application: `stateui new`, run from this checkout's own
# tool (tools/StateUI.CLI), which owns the rule - HelloWorld under another name,
# naming this checkout by the path from it.
#
# USAGE:
#   ./new-app.sh Name [apps-dir]      apps-dir defaults to <repo>/apps
#
# The first run builds the tool, which fetches its packages.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NAME="${1:-}"
APPS_DIR="${2:-$ROOT_DIR/apps}"

exec swift run --quiet --package-path "$ROOT_DIR/tools/StateUI.CLI" stateui new "$NAME" \
  --directory "$APPS_DIR" --checkout "$ROOT_DIR"
