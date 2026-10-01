#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Runs the Android Views host's tests on a device: a view exists only in an
# application's process, so they run in the test APK's, by its instrumentation.
#
# USAGE:
#   test-android.sh [serial]
#   test-android.sh --build <abi>
#
# --build builds the test APK for <abi> (arm64-v8a, x86_64) with no device, prints where it is, and runs nothing;
# STATEUI_TEST_APK=<apk> then installs that APK instead of building one - CI builds on macOS, where the pictures are
# drawn, and runs it on a Linux emulator.
#
# STATEUI_FILTER=<names> runs only the tests whose "Case.test" name holds one of the names, split at commas
# ("testPicker,AndroidColorBoxViewTests"), and then holds nothing to lib/exports/: a part of the suite proves only part
# of what the host declares.
#
# Each item, and each conformance case, says as it ends where the run stands and how long it took
# ("[12/310] ... passed in 812 ms"), followed from the device's log as it comes. The screen is woken and kept on
# for the run - a phone whose screen goes off freezes the test app - and the setting put back after.
#
# The suite also writes what the host declares - its registry, as lib/exports/
# holds it for the control dictionary. The run is held to lib/exports/android.txt;
# STATEUI_UPDATE_EXPORTS=1 writes it instead.
#
# STATEUI_STALE_ONLY=1 runs only the conformance families whose verdicts in lib/exports/marks/android stand at another
# revision, or at none - chosen here, since the device reads no repository - and takes only theirs off the device.
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

if [[ "${1:-}" == --build ]]; then
  build_head "$tests_dir" StateUIAndroidTests debug "${2:?an ABI: arm64-v8a or x86_64}"
  exit
fi

marks="$repository_dir/lib/exports/marks/android"
stale_only="${STATEUI_STALE_ONLY:-}"
if [[ "$stale_only" == 1 ]]; then
  stale=""
  for family in $(grep -oE 'func test[A-Za-z]+\(\) throws \{ try conform' "$tests_dir/Sources/Conformance/AndroidConformanceTests.swift" \
      | sed -E 's/func test([A-Za-z]+).*/\1/'); do
    revision="$("$repository_dir/.scripts/Marks/revision.sh" android "$family")"
    [[ "$(head -n 1 "$marks/$family.txt" 2>/dev/null)" == "# revision $revision" ]] \
      || stale="$stale,AndroidConformanceTests.test$family"
  done
  [[ -n "$stale" ]] || { echo "Every family's verdicts stand at its revision: nothing to run."; exit 0; }
  STATEUI_FILTER="${stale#,}"
  echo "stale:      ${STATEUI_FILTER//AndroidConformanceTests.test/}"
fi

serial="$(device_serial "${1:-${ANDROID_SERIAL:-}}")"
abi="$(device_abi "$serial")"
echo "device:     $serial ($abi)"

apk="${STATEUI_TEST_APK:-$(build_head "$tests_dir" StateUIAndroidTests debug "$abi")}"
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
# keeps whatever reads this script's output waiting. Disowned, its ending is not announced.
"$ADB" -s "$serial" logcat -c
"$ADB" -s "$serial" logcat -v raw -s StateUI 2>/dev/null > >(grep --line-buffered -E '\[[0-9]+/[0-9]+\]') &
follower=$!
disown "$follower"

filter=()
[[ -n "${STATEUI_FILTER:-}" ]] && filter=(-e filter "$STATEUI_FILTER")
output="$("$ADB" -s "$serial" shell am instrument -w ${filter[@]+"${filter[@]}"} "$package/stateui.android.test.StateUITestRunner" | tr -d '\r')"
echo "$output"

summary="$(grep -E '^Executed [0-9]+ tests, with [0-9]+ failures' <<< "$output" | tail -n 1)"
[[ -n "$summary" ]] || { echo "ERROR: the tests reported nothing - read: $ADB -s $serial logcat -s StateUI"; exit 1; }
[[ "$summary" == *" with 0 failures" ]] || exit 1
[[ -z "${STATEUI_FILTER:-}" || "$stale_only" == 1 ]] || exit 0

declared="$(mktemp -d)"
# A run of the stale families alone runs no declaration's test.
[[ "$stale_only" == 1 ]] && declarations=() || declarations=(android.txt)
for name in ${declarations[@]+"${declarations[@]}"}; do
  "$ADB" -s "$serial" exec-out run-as "$package" cat "files/$name" > "$declared/$name"
  if [[ "${STATEUI_UPDATE_EXPORTS:-}" == 1 ]]; then
    cp "$declared/$name" "$repository_dir/lib/exports/$name"
  elif ! cmp -s "$declared/$name" "$repository_dir/lib/exports/$name"; then
    echo "ERROR: lib/exports/$name is not what the host declares - a registration changed, or something"
    echo "stopped being realized. Run again with STATEUI_UPDATE_EXPORTS=1 and read the diff."
    exit 1
  fi
done

# The conformance families' verdicts, one file a family: Android's column of the control dictionary.
held="$declared/marks"
mkdir -p "$held"
for name in $("$ADB" -s "$serial" exec-out run-as "$package" ls files/marks/android | tr -d '\r'); do
  # The revision its family stands at, written over each verdict file: the device reads no repository.
  family="${name%.txt}"
  revision="$("$repository_dir/.scripts/Marks/revision.sh" android "${family%-[0-9]*}")"
  { echo "# revision $revision"; "$ADB" -s "$serial" exec-out run-as "$package" cat "files/marks/android/$name"; } \
    > "$held/$name"
done
# Two runs at other revisions compare by their verdicts, the line naming the revision aside.
verdicts_alone () {
  mkdir -p "$2"
  for file in "$1"/*.txt; do
    if [[ -e "$file" ]]; then grep -v '^# revision ' "$file" > "$2/$(basename "$file")" || true; fi
  done
}
verdicts_alone "$held" "$declared/run"
verdicts_alone "$marks" "$declared/kept"
# A run of the stale families holds only theirs to what was kept.
if [[ "$stale_only" == 1 ]]; then
  for file in "$declared/kept"/*.txt; do
    if [[ ! -e "$declared/run/$(basename "$file")" ]]; then rm -f "$file"; fi
  done
fi
if [[ "${STATEUI_UPDATE_EXPORTS:-}" == 1 ]]; then
  [[ "$stale_only" == 1 ]] || rm -rf "$marks"
  mkdir -p "$marks"
  cp "$held"/*.txt "$marks/"
elif ! diff -r "$declared/run" "$declared/kept" >/dev/null 2>&1; then
  diff -r "$declared/run" "$declared/kept" | head -n 40
  echo "ERROR: lib/exports/marks/android is not what this run proved - a verdict changed, or something stopped"
  echo "working. Run again with STATEUI_UPDATE_EXPORTS=1 and read the diff."
  exit 1
fi
