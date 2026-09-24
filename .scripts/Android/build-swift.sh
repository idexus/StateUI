#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's Swift for Android: the one owner of that build.
#
# USAGE:
#   build-swift.sh <app-package-dir> <product> <out-dir> [condition...]
#
#   app-package-dir  the application's folder, holding Package.swift
#   product          the dynamic library Android loads, e.g. HelloWorldAndroid
#   out-dir          gets jniLibs/<abi>/ - the product and everything it needs,
#                    stripped - and symbols/<abi>/, the same libraries unstripped
#                    for ndk-stack and a debugger; and ndk-root, the NDK the
#                    build used, whose lldb-server the debugger runs
#   condition        a compilation condition for every module, the library's
#                    included - MAUI for the MAUI head, none for Android Views
#
# Environment:
#   SWIFT_CONFIG=debug|release   (default: debug)
#   ABIS="arm64-v8a x86_64"      (default: both)
#   SCRATCH_PATH=<dir>           SwiftPM's build directory (default: <app>/.build-android)
#   SWIFT_BIN=<path>             the compiler, where PATH has the wrong one
#   ANDROID_NDK_HOME=<path>      the NDK, where it is not found on its own
#
# The application's manifest reads STATEUI_ANDROID to declare its Android
# head; the caller sets it for an Android Views build.
set -euo pipefail

APP_PACKAGE="${1:-}"
PRODUCT="${2:-}"
OUT_ROOT="${3:-}"
shift 3 || true
CONDITIONS=("$@")

if [[ -z "$APP_PACKAGE" || -z "$PRODUCT" || -z "$OUT_ROOT" ]]; then
  echo "USAGE: $0 <app-package-dir> <product> <out-dir> [condition...]"
  exit 1
fi
[[ -f "$APP_PACKAGE/Package.swift" ]] || { echo "ERROR: no Package.swift in $APP_PACKAGE"; exit 1; }

APP_PACKAGE="$(cd "$APP_PACKAGE" && pwd)"
CONFIG="${SWIFT_CONFIG:-debug}"
ABIS="${ABIS:-arm64-v8a x86_64}"
SCRATCH_PATH="${SCRATCH_PATH:-$APP_PACKAGE/.build-android}"
SWIFT_BIN="${SWIFT_BIN:-swift}"
API=28

command -v "$SWIFT_BIN" >/dev/null 2>&1 || { echo "ERROR: swift not found."; exit 1; }

swift_version_of () {
  "$1" --version 2>&1 | grep -oE 'Swift version [0-9]+\.[0-9]+(\.[0-9]+)?' \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1
}

# The compiler's BUILD - "swift-6.4-RELEASE" from swift.org, "swiftlang-..."
# from Xcode: binary modules are readable only by the build that wrote them.
swift_build_of () {
  "$1" --version 2>&1 | grep -oE '\(swift[a-z]*-[^) ]+' | head -n 1 | tr -d '('
}

release_of () {
  case "$1" in
    *.*.0) echo "${1%.0}" ;;
    *)     echo "$1" ;;
  esac
}

# --- the Swift SDK of the compiler's release, by its id ---------------------
RELEASE="$(release_of "$(swift_version_of "$SWIFT_BIN")")"
SDK_ID=""
for id in $("$SWIFT_BIN" sdk list 2>/dev/null | grep -i android); do
  version="$(printf '%s' "$id" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)"
  [[ "$(release_of "$version")" == "$RELEASE" ]] && SDK_ID="$id"
done
if [[ -z "$SDK_ID" ]]; then
  echo "ERROR: no Swift SDK for Android of Swift $RELEASE is installed."
  echo "  https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html"
  exit 1
fi

SDK_BUNDLE=""
for root in "$HOME/Library/org.swift.swiftpm/swift-sdks" "$HOME/.swiftpm/swift-sdks"; do
  for info in "$root"/*.artifactbundle/info.json; do
    [[ -f "$info" ]] && grep -q "\"$SDK_ID\"" "$info" && SDK_BUNDLE="$(dirname "$info")"
  done
done
[[ -n "$SDK_BUNDLE" ]] || { echo "ERROR: $SDK_ID is listed but its bundle was not found."; exit 1; }

swift_interface="$(find "$SDK_BUNDLE" -path "*Swift.swiftmodule*" -name "*.swiftinterface" 2>/dev/null | head -n 1)"
SDK_BUILD="$(grep -m 1 'swift-compiler-version' "$swift_interface" 2>/dev/null \
  | grep -oE '\(swift[a-z]*-[^) ]+' | tr -d '(')"
[[ -n "$SDK_BUILD" ]] || { echo "ERROR: $SDK_ID does not say which compiler wrote it."; exit 1; }

# --- a compiler of the build that wrote the SDK -----------------------------
if [[ "$(swift_build_of "$SWIFT_BIN")" != "$SDK_BUILD" ]]; then
  for candidate in \
      "$HOME"/Library/Developer/Toolchains/*.xctoolchain/usr/bin/swift \
      /Library/Developer/Toolchains/*.xctoolchain/usr/bin/swift \
      "$HOME/.swiftly/bin/swift"; do
    if [[ -x "$candidate" ]] && [[ "$(swift_build_of "$candidate")" == "$SDK_BUILD" ]]; then
      SWIFT_BIN="$candidate"
      break
    fi
  done
fi
if [[ "$(swift_build_of "$SWIFT_BIN")" != "$SDK_BUILD" ]]; then
  echo "ERROR: $SWIFT_BIN ($(swift_build_of "$SWIFT_BIN")) cannot read $SDK_ID, written by $SDK_BUILD."
  echo "Install the swift.org toolchain of that release, or name it: SWIFT_BIN=/path/to/swift"
  exit 1
fi

# --- the NDK -----------------------------------------------------------------
ndk_root () {
  local candidate include target sdk newest
  for candidate in "${ANDROID_NDK_ROOT:-}" "${ANDROID_NDK_HOME:-}"; do
    [[ -n "$candidate" && -d "$candidate/toolchains/llvm/prebuilt" ]] && { echo "$candidate"; return; }
  done
  include="$(find "$SDK_BUNDLE" -maxdepth 5 -path "*ndk-sysroot/usr/include" 2>/dev/null | head -n 1)"
  if [[ -L "$include" ]]; then
    target="$(readlink "$include")"
    candidate="${target%/toolchains/llvm/prebuilt/*}"
    [[ -d "$candidate/toolchains/llvm/prebuilt" ]] && { echo "$candidate"; return; }
  fi
  for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
    [[ -n "$sdk" && -d "$sdk/ndk" ]] || continue
    newest="$(ls -1 "$sdk/ndk" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)"
    [[ -n "$newest" && -d "$sdk/ndk/$newest/toolchains/llvm/prebuilt" ]] && { echo "$sdk/ndk/$newest"; return; }
  done
}

NDK_ROOT="$(ndk_root)"
[[ -n "$NDK_ROOT" ]] || { echo "ERROR: no Android NDK found. Set ANDROID_NDK_HOME to one - 30 or newer."; exit 1; }
export ANDROID_NDK_ROOT="$NDK_ROOT"
mkdir -p "$OUT_ROOT"
echo "$NDK_ROOT" > "$OUT_ROOT/ndk-root"
NDK_BIN="$(find "$NDK_ROOT/toolchains/llvm/prebuilt" -maxdepth 2 -name bin -type d | head -n 1)"
READELF="$NDK_BIN/llvm-readelf"
STRIP="$NDK_BIN/llvm-strip"

echo "Swift SDK:  $SDK_ID ($SDK_BUILD)"
echo "compiler:   $SWIFT_BIN"
echo "NDK:        $NDK_ROOT"
echo "build:      $PRODUCT, $CONFIG, conditions: ${CONDITIONS[*]:-none}"

triple_of () {
  case "$1" in
    arm64-v8a) echo "aarch64-unknown-linux-android$API" ;;
    x86_64)    echo "x86_64-unknown-linux-android$API" ;;
    *)         echo "" ;;
  esac
}

ndk_arch_of () {
  case "$1" in
    arm64-v8a) echo "aarch64-linux-android" ;;
    x86_64)    echo "x86_64-linux-android" ;;
  esac
}

condition_flags=()
for condition in ${CONDITIONS[@]+"${CONDITIONS[@]}"}; do
  condition_flags+=(-Xswiftc "-D$condition")
done

swift_build () {
  "$SWIFT_BIN" build \
    --package-path "$APP_PACKAGE" \
    --scratch-path "$SCRATCH_PATH" \
    --swift-sdk "$SDK_ID" \
    --triple "$1" \
    -c "$CONFIG" \
    ${condition_flags[@]+"${condition_flags[@]}"} \
    "${@:2}"
}

for abi in $ABIS; do
  triple="$(triple_of "$abi")"
  [[ -n "$triple" ]] || { echo "ERROR: unknown ABI $abi"; exit 1; }
  echo "-- $abi ($triple)"

  swift_build "$triple" --product "$PRODUCT"
  built="$(swift_build "$triple" --show-bin-path)"
  runtime="$(dirname "$(find -L "$SDK_BUNDLE" -name libswiftCore.so -path "*$(ndk_arch_of "$abi" | cut -d- -f1)*" | head -n 1)")"
  platform_libs="$(find "$NDK_ROOT/toolchains/llvm/prebuilt" -type d -path "*/sysroot/usr/lib/$(ndk_arch_of "$abi")/$API" | head -n 1)"
  libcxx="$(find "$NDK_ROOT/toolchains/llvm/prebuilt" -name libc++_shared.so -path "*/$(ndk_arch_of "$abi")/*" | head -n 1)"

  libraries="$OUT_ROOT/jniLibs/$abi"
  symbols="$OUT_ROOT/symbols/$abi"
  mkdir -p "$libraries" "$symbols"

  # THE PRODUCT AND WHAT IT NEEDS, AND NOTHING ELSE: the DT_NEEDED closure,
  # a platform library being one the NDK's sysroot declares for this API.
  queue="lib$PRODUCT.so"
  packaged=" "
  while [[ -n "$queue" ]]; do
    library="${queue%% *}"
    queue="${queue#"$library"}"; queue="${queue# }"
    [[ "$packaged" == *" $library "* ]] && continue
    [[ -f "$platform_libs/$library" ]] && continue

    source=""
    for directory in "$built" "$runtime"; do
      [[ -f "$directory/$library" ]] && { source="$directory/$library"; break; }
    done
    [[ -z "$source" && "$library" == libc++_shared.so ]] && source="$libcxx"
    [[ -n "$source" ]] || { echo "ERROR: $library is needed and found nowhere"; exit 1; }
    packaged="$packaged$library "

    # Copied when it moved, keeping its time, so an unchanged runtime is not
    # stripped again on every build.
    if [[ ! -f "$symbols/$library" || "$source" -nt "$symbols/$library" || "$source" -ot "$symbols/$library" ]]; then
      cp -p "$source" "$symbols/$library"
      "$STRIP" --strip-unneeded -o "$libraries/$library" "$source"
      touch -r "$source" "$libraries/$library"
    fi

    for needed in $("$READELF" --needed-libs "$source" | grep -oE 'lib[A-Za-z0-9_.+-]+\.so' | grep -v "^$library\$"); do
      queue="$queue $needed"; queue="${queue# }"
    done
  done

  for directory in "$libraries" "$symbols"; do
    for file in "$directory"/*.so; do
      [[ -f "$file" && "$packaged" != *" $(basename "$file") "* ]] && rm -f "$file"
    done
  done

  echo "   $(echo $packaged | wc -w | tr -d ' ') libraries, $(du -sh "$libraries" | cut -f1)"
done
