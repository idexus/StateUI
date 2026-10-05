# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Sourced by the Web scripts: sets `sdk` to the Swift SDK for WebAssembly of the
# compiler's release - the one whose id ends in _wasm, as its _wasm-embedded
# sibling is Embedded Swift, which StateUI is not written for - or stops,
# saying where to get it.

release_of () {
  case "$1" in
    *.*.0) echo "${1%.0}" ;;
    *)     echo "$1" ;;
  esac
}
release="$(release_of "$(swift --version 2>&1 | grep -oE 'Swift version [0-9]+\.[0-9]+(\.[0-9]+)?' | grep -oE '[0-9.]+$' | head -n 1)")"
sdk=""
for id in $(swift sdk list 2>/dev/null | grep -E '_wasm$'); do
  version="$(printf '%s' "$id" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)"
  [[ "$(release_of "$version")" == "$release" ]] && sdk="$id"
done
if [[ -z "$sdk" ]]; then
  echo "ERROR: no Swift SDK for WebAssembly of Swift $release is installed."
  echo "  https://www.swift.org/documentation/articles/wasm-getting-started.html"
  exit 1
fi
