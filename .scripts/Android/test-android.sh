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
# STATEUI_FILTER=<names> runs only the tests whose "Case.test" name holds one of the names, split at commas
# ("testPicker,AndroidColorBoxViewTests"), and then holds nothing to exports/: a part of the suite proves only part
# of what the host declares.
#
# Each item, and each conformance case, says as it ends where the run stands and how long it took
# ("[12/310] ... passed in 812 ms"), followed from the device's log as it comes. The screen is woken and kept on
# for the run - a phone whose screen goes off freezes the test app - and the setting put back after.
#
# The suite also writes what the host declares - its registry, as exports/
# holds it for the control dictionary. The run is held to exports/android.txt;
# STATEUI_UPDATE_EXPORTS=1 writes it instead.
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
# The verdicts of a run before this one stay in the APK's files: none may stand for this run's.
"$ADB" -s "$serial" shell run-as "$package" rm -rf files/marks

declared=""
follower=""
stay_on="$("$ADB" -s "$serial" shell settings get global stay_on_while_plugged_in | tr -d '\r')"
# Put back through the power service, as it was set: a phone's shell may not write the setting itself.
case "$stay_on" in
  0) awake="false" ;; 1) awake="ac" ;; 2) awake="usb" ;; 4) awake="wireless" ;; *) awake="true" ;;
esac
cleanup() {
  [[ -z "$follower" ]] || kill "$follower" 2>/dev/null || true
  "$ADB" -s "$serial" shell svc power stayon "$awake" >/dev/null 2>&1 || true
  [[ -z "$declared" ]] || rm -rf "$declared"
}
trap cleanup EXIT
# A phone may refuse the power service to the shell (the CPH2363 kills the command): its own "Stay awake" then holds.
"$ADB" -s "$serial" shell svc power stayon usb >/dev/null 2>&1 || true
"$ADB" -s "$serial" shell input keyevent KEYCODE_WAKEUP || true
"$ADB" -s "$serial" shell wm dismiss-keyguard >/dev/null 2>&1 || true

# The follower is the log's own reader, so ending it ends the filter after it: a filter left holding the output
# keeps whatever reads this script's output waiting.
"$ADB" -s "$serial" logcat -c
"$ADB" -s "$serial" logcat -v raw -s StateUI 2>/dev/null > >(grep --line-buffered -E '\[[0-9]+/[0-9]+\]') &
follower=$!

filter=()
[[ -n "${STATEUI_FILTER:-}" ]] && filter=(-e filter "$STATEUI_FILTER")
output="$("$ADB" -s "$serial" shell am instrument -w ${filter[@]+"${filter[@]}"} "$package/stateui.android.test.StateUITestRunner" | tr -d '\r')"
echo "$output"

summary="$(grep -E '^Executed [0-9]+ tests, with [0-9]+ failures' <<< "$output" | tail -n 1)"
[[ -n "$summary" ]] || { echo "ERROR: the tests reported nothing - read: $ADB -s $serial logcat -s StateUI"; exit 1; }
[[ "$summary" == *" with 0 failures" ]] || exit 1
[[ -z "${STATEUI_FILTER:-}" ]] || exit 0

declared="$(mktemp -d)"
for name in android.txt; do
  "$ADB" -s "$serial" exec-out run-as "$package" cat "files/$name" > "$declared/$name"
  if [[ "${STATEUI_UPDATE_EXPORTS:-}" == 1 ]]; then
    cp "$declared/$name" "$repository_dir/exports/$name"
  elif ! cmp -s "$declared/$name" "$repository_dir/exports/$name"; then
    echo "ERROR: exports/$name is not what the host declares - a registration changed, or something"
    echo "stopped being realized. Run again with STATEUI_UPDATE_EXPORTS=1 and read the diff."
    exit 1
  fi
done

# The conformance families' verdicts, one file a family: Android's column of the control dictionary.
held="$declared/marks"
marks="$repository_dir/exports/marks/android"
mkdir -p "$held"
for name in $("$ADB" -s "$serial" exec-out run-as "$package" ls files/marks/android | tr -d '\r'); do
  "$ADB" -s "$serial" exec-out run-as "$package" cat "files/marks/android/$name" > "$held/$name"
done
if [[ "${STATEUI_UPDATE_EXPORTS:-}" == 1 ]]; then
  rm -rf "$marks"
  mkdir -p "$marks"
  cp "$held"/*.txt "$marks/"
elif ! diff -r "$held" "$marks" >/dev/null 2>&1; then
  diff -r "$held" "$marks" | head -n 40
  echo "ERROR: exports/marks/android is not what this run proved - a verdict changed, or something stopped"
  echo "working. Run again with STATEUI_UPDATE_EXPORTS=1 and read the diff."
  exit 1
fi
