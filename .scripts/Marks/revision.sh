#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Prints the revision a conformance family's verdicts on a host stand at, as
# lib/StateUI.Conformance/revisions.txt says: the family's own on every host,
# then the host's own, each 1 where no line names it - `1.1`. The host's tests
# and the dictionary's renderer read it the same way (HostVerdict.revision).
#
# USAGE:
#   revision.sh <appkit|uikit|android|winui|gtk> <family>
set -euo pipefail

host="${1:?a host: appkit, uikit, android, winui or gtk}"
family="${2:?a family, such as Button}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
every=1
own=1
while read -r first second third; do
  [[ -z "$first" || "$first" == \#* ]] && continue
  if [[ -z "$third" && "$first" == "$family" ]]; then every="$second"; fi
  if [[ "$first" == "$host" && "$second" == "$family" && -n "$third" ]]; then own="$third"; fi
done < "$root/lib/StateUI.Conformance/revisions.txt"
echo "$every.$own"
