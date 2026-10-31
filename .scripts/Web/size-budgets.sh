#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds each application's release Web head and holds its module, gzipped -
# what a page downloads - within the application's budget. A module past its
# budget fails the run; one a twentieth or more under it says so, for the
# budget to come down with it.
#
# USAGE:
#   size-budgets.sh
#
# A budget is raised only in the change that grows the module, with the reason
# (docs/design/platforms/web/runtime.md, The module's size).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"

# The application and its budget, in bytes of the module gzipped at level 9.
budgets=(
  "HelloWorld 4900000"
  "Gallery 5950000"
)

failed=0
for entry in "${budgets[@]}"; do
  read -r application budget <<< "$entry"
  bash "$here/run-app.sh" "$root/apps/$application" release --build-only > /dev/null
  module="$root/apps/$application/.build/web/site/release/${application}Web.wasm"
  size=$(gzip -9 -n -c "$module" | wc -c | tr -d ' ')
  if (( size > budget )); then
    echo "$application: $size bytes gzipped, over its budget of $budget"
    failed=1
  elif (( size * 20 <= budget * 19 )); then
    echo "$application: $size bytes gzipped, a twentieth or more under its budget of $budget - lower it"
  else
    echo "$application: $size bytes gzipped, within its budget of $budget"
  fi
done
exit "$failed"
