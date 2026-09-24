#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Runs the Android Views host's tests on a device: a view exists only in an
# application's process, so they run in the test APK's, by its instrumentation.
#
# USAGE:
#   test-android.sh [serial]
#
# The suite also writes what the host declares - its registry, as exports/
# holds it for the control dictionary. The run is held to exports/android.bin
# and .txt; STATEUI_UPDATE_EXPORTS=1 writes them instead.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/../.." && pwd)"
# shellcheck source=tools.sh
source "$script_dir/tools.sh"

tests_dir="$repository_dir/lib/StateUI.Android/Tests"
runner="$tests_dir/Sources/Support/AndroidTestRunner.swift"

# EVERY TEST IS LISTED: without discovery a `func test` that no `allTests`
# names, or a case the runner does not name, would never run.
unlisted=""
while IFS= read -r file; do
  for test in $(grep -oE 'func test[A-Za-z0-9_]+\(\)' "$file" | sed 's/func //; s/()//'); do
    grep -q "(\"$test\", $test)" "$file" || unlisted="$unlisted $test"
  done
  for case in $(grep -oE 'class [A-Za-z0-9_]+: XCTestCase' "$file" | awk '{ print $2 }' | tr -d ':'); do
    grep -q "testCase($case.allTests)" "$runner" || unlisted="$unlisted $case"
  done
done < <(find "$tests_dir/Sources" -name '*.swift')
[[ -z "$unlisted" ]] || { echo "ERROR: listed nowhere, so never run:$unlisted"; exit 1; }

serial="$(device_serial "${1:-${ANDROID_SERIAL:-}}")"
abi="$(device_abi "$serial")"
echo "device:     $serial ($abi)"

apk="$(build_head "$tests_dir" StateUIAndroidTests debug "$abi")"
package="$("$AAPT2" dump packagename "$apk")"
"$ADB" -s "$serial" install -r "$apk" >/dev/null

output="$("$ADB" -s "$serial" shell am instrument -w "$package/stateui.android.test.StateUITestRunner" | tr -d '\r')"
echo "$output"

summary="$(grep -E '^Executed [0-9]+ tests, with [0-9]+ failures' <<< "$output" | tail -n 1)"
[[ -n "$summary" ]] || { echo "ERROR: the tests reported nothing - read: $ADB -s $serial logcat -s StateUI"; exit 1; }
[[ "$summary" == *" with 0 failures" ]]

declared="$(mktemp -d)"
trap 'rm -rf "$declared"' EXIT
for name in android.bin android.txt; do
  "$ADB" -s "$serial" exec-out run-as "$package" cat "files/$name" > "$declared/$name"
  if [[ "${STATEUI_UPDATE_EXPORTS:-}" == 1 ]]; then
    cp "$declared/$name" "$repository_dir/exports/$name"
  elif ! cmp -s "$declared/$name" "$repository_dir/exports/$name"; then
    echo "ERROR: exports/$name is not what the host declares - a registration changed, or something"
    echo "stopped being realized. Run again with STATEUI_UPDATE_EXPORTS=1 and read the diff."
    exit 1
  fi
done
