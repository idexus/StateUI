#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds the Web host's suite, lib/StateUI/StateUI.Web/Testing, for WebAssembly
# and runs it: the host's own tests in Node over a page with just enough of a
# DOM, through the host's own relay - or, with --browser, the tests that need a
# browser's own page, in one, headless: the conformance suite, whose layout,
# focus, dialogs and input its cases need, and the host's tests that run a host.
# The browser is Google Chrome or Chromium, or the one STATEUI_BROWSER names. A
# conformance run with STATEUI_UPDATE_EXPORTS=1 writes each verdict file under
# the revision its family stands at (lib/StateUI/StateUI.Conformance/revisions.txt);
# STATEUI_STALE_ONLY=1 runs only the families whose verdicts stand at another
# revision, or at none.
#
# USAGE:
#   test-web.sh [<Class>[/<test>]]
#   test-web.sh --browser [<Family>...]
#
#   a test class, or one test of it, runs that alone; a family named - Button,
#   TextField - its conformance alone
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checkout="$(cd "$here/../.." && pwd)"
package="$checkout/lib/StateUI/StateUI.Web/Testing"
scratch="$package/.build/web"

. "$here/swift-sdk.sh"

STATEUI_HOST=web swift build --package-path "$package" --scratch-path "$scratch" --swift-sdk "$sdk" --build-tests
products="$(STATEUI_HOST=web swift build --package-path "$package" --scratch-path "$scratch" --swift-sdk "$sdk" --show-bin-path)"
program="$products/StateUIWebTests-test-runner.wasm"
relay="$checkout/lib/StateUI/StateUI.Web/JavaScript/stateui-web.js"
conformance="StateUIWebTests.WebConformanceTests"
# The classes whose tests need a browser's own page.
in_browser="$conformance,StateUIWebTests.WebDrawnChildrenTests,StateUIWebTests.WebFrameReportTests,StateUIWebTests.WebHistoryTests"

browser () {
  if [[ -n "${STATEUI_BROWSER:-}" ]]; then echo "$STATEUI_BROWSER"; return; fi
  for candidate in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
    [[ -x "$candidate" ]] && { echo "$candidate"; return; }
  done
  for name in google-chrome google-chrome-stable chromium chromium-browser; do
    command -v "$name" && return
  done
  echo "ERROR: no Google Chrome or Chromium found - STATEUI_BROWSER names one" >&2
  exit 1
}

if [[ "${1:-}" == "--browser" ]]; then
  shift
  selected="$in_browser"
  if [[ $# -gt 0 ]]; then
    selected="$(printf "$conformance/test%s," "$@")"
    selected="${selected%,}"
  fi
  exec node "$package/JavaScript/run-in-browser.mjs" "$(browser)" "$program" "$selected"
fi

# The host's own tests, every one but those the browser runs where none is named.
selected="${1:-}"
if [[ -z "$selected" ]]; then
  selected="$(node "$package/JavaScript/run.mjs" "$relay" "$program" --list-tests \
    | grep -E '^StateUIWebTests\.' | grep -v -E "^(${in_browser//,/|})/" | paste -sd, -)"
fi
exec node "$package/JavaScript/run.mjs" "$relay" "$program" "$selected"
