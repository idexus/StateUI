#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds the UIKit host's tests as an application, installs it on an iOS
# simulator and runs it: each test says itself as it ends, and the run ends
# with "Executed N tests, with M failures".
#
# USAGE:
#   test-uikit.sh [simulator]
#
# The simulator is a name ("iPhone 18 Pro", "iPad Air 13-inch (M4)") or a
# UDID; the one booted, else an iPhone, where none is named.
# STATEUI_FILTER=<names> runs only the tests whose "Case.test" name holds one
# of the names, split at commas. STATEUI_UPDATE_EXPORTS=1 writes what the run
# says into exports/ instead of holding it to them, each verdict file under the
# revision its family stands at (lib/StateUI.Conformance/revisions.txt);
# STATEUI_STALE_ONLY=1 runs only the conformance families whose verdicts stand
# at another revision, or at none.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tools.sh"
repository_dir="$(cd "$script_dir/../.." && pwd)"
package="$repository_dir/lib/StateUI.UIKit/Tests"
scratch="$package/.build"
product="StateUIUIKitTests"
identifier="com.stateui.uikit.tests"

read -r kind device _ <<< "$(uikit_destination "${1:-}")"
[[ -n "$kind" ]] || exit 1
[[ "$kind" == simulator ]] || { echo "ERROR: the host's suite runs on a simulator - $1 is a device"; exit 1; }

# A macOS accessibility client reading the Simulator - the Accessibility
# Inspector, an AX script - turns the simulator's application accessibility
# on, and UIKit's accessibility bundles then answer for its controls in its
# place: the suite runs with it off, as a simulator starts.
for key in ApplicationAccessibilityEnabled AccessibilityEnabled; do
  xcrun simctl spawn "$device" defaults write com.apple.Accessibility "$key" -bool false
done

# XCTest is the simulator platform's own, read where it stands.
frameworks="$UIKIT_PLATFORM/Developer/Library/Frameworks"
libraries="$UIKIT_PLATFORM/Developer/usr/lib"
binary_dir="$(uikit_build "$package" "$scratch" debug "$product" \
  -Xswiftc -F -Xswiftc "$frameworks" -Xswiftc -I -Xswiftc "$libraries" \
  -Xlinker -F -Xlinker "$frameworks" -Xlinker -L -Xlinker "$libraries" \
  -Xlinker -rpath -Xlinker "$frameworks" -Xlinker -rpath -Xlinker "$libraries")"
bundle="$scratch/debug/$product.app"
uikit_bundle "$binary_dir" "$product" "$product" "$identifier" "$package/Resources" "$bundle" "$scratch/tools" ""

xcrun simctl install "$device" "$bundle"
output="$(mktemp)"
trap 'rm -f "$output"' EXIT
SIMCTL_CHILD_STATEUI_FILTER="${STATEUI_FILTER:-}" SIMCTL_CHILD_STATEUI_UPDATE_EXPORTS="${STATEUI_UPDATE_EXPORTS:-}" \
SIMCTL_CHILD_STATEUI_STALE_ONLY="${STATEUI_STALE_ONLY:-}" \
  xcrun simctl launch --console-pty --terminate-running-process "$device" "$identifier" 2>&1 | tee "$output"

summary="$(tr -d '\r' < "$output" | grep -E '^Executed [0-9]+ tests, with [0-9]+ failures' | tail -n 1)"
[[ -n "$summary" ]] || { echo "ERROR: the tests reported nothing"; exit 1; }
[[ "$summary" == *" with 0 failures" ]]
