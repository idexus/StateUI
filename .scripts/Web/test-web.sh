#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds the Web host's suite, lib/StateUI/StateUI.Web/Testing, for WebAssembly
# and runs it in Node over a page with just enough of a DOM, through the host's
# own relay.
#
# USAGE:
#   test-web.sh [<Class>[/<test>]]
#
#   a test class, or one test of it, runs that alone
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checkout="$(cd "$here/../.." && pwd)"
package="$checkout/lib/StateUI/StateUI.Web/Testing"
scratch="$package/.build/web"

. "$here/swift-sdk.sh"

STATEUI_HOST=web swift build --package-path "$package" --scratch-path "$scratch" --swift-sdk "$sdk" --build-tests
products="$(STATEUI_HOST=web swift build --package-path "$package" --scratch-path "$scratch" --swift-sdk "$sdk" --show-bin-path)"

node "$package/JavaScript/run.mjs" "$checkout/lib/StateUI/StateUI.Web/JavaScript/stateui-web.js" \
  "$products/StateUIWebTests-test-runner.wasm" "$@"
