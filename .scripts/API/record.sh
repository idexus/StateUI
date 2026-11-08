#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Holds a module a host's build made - its facade, a backend, the testing module - to its record,
# lib/StateUI/exports/api/<Module>.txt, or writes the record under STATEUI_UPDATE_EXPORTS=1: through the core's
# APISurfaceTests, the one reading of a public surface. A host's test script calls it after its build.
#
# USAGE:
#   record.sh <module> <modules-dir> [<triple> [<sdk> [<argument>...]]]
#
#   modules-dir  the folder the module and those it imports were built in
#   triple, sdk  the platform it was built for, where it is not this machine
#   argument     what the compiler needs to find the module's C modules: -Xcc -fmodule-map-file=..., -I ...
set -euo pipefail
repository_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ $# -ge 2 ]] || { echo "USAGE: $0 <module> <modules-dir> [<triple> [<sdk> [<argument>...]]]"; exit 1; }
module="$1" modules="$2" triple="${3:-}" sdk="${4:-}"
shift $(( $# < 4 ? $# : 4 ))
echo "recording:  $module"
env -u STATEUI_HOST STATEUI_API_MODULE="$module" STATEUI_API_MODULES="$modules" STATEUI_API_TRIPLE="$triple" \
  STATEUI_API_SDK="$sdk" STATEUI_API_ARGUMENTS="$*" \
  swift test --package-path "$repository_dir" --filter APISurfaceTests/testTheModuleAHostsScriptNamesIsItsRecord
