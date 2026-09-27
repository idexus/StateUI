#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Prints the digest of the sources a host's conformance verdicts rest on: the
# git tree of the folders .scripts/Marks/inputs.txt names for every host and
# for this one, as they stand in the working tree - untracked files included,
# ignored ones not. The dictionary's renderer works it out the same way.
#
# USAGE:
#   inputs.sh <appkit|uikit|android|winui|gtk>
set -euo pipefail

host="${1:?a host: appkit, uikit, android, winui or gtk}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
folders=()
while read -r name rest; do
  [[ "$name" == every || "$name" == "$host" ]] || continue
  for folder in $rest; do
    [[ -d "$root/$folder" ]] && folders+=("$folder")
  done
done < <(grep -v '^#' "$root/.scripts/Marks/inputs.txt")
[[ ${#folders[@]} -gt 0 ]] || { echo "ERROR: no folders for $host" >&2; exit 1; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
GIT_INDEX_FILE="$scratch/index" git -C "$root" add -A -- "${folders[@]}"
GIT_INDEX_FILE="$scratch/index" git -C "$root" write-tree
