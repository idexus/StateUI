#!/usr/bin/env bash
# Copyright 2026 the StateUI project authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ---------------------------------------------------------------------------
# Builds the Swift modules for Android (.so per ABI).
#
# USAGE:
#   ./build-android.sh <out-dir> <app-package-dir> <app-module> [api]
#
#   out-dir          root for the per-ABI output directories
#   app-package-dir  the app's project folder - the one holding Package.swift
#   app-module       Swift module name, e.g. GalleryUI
#   api              Android API level (default: 28)
#
# Environment:
#   SWIFT_CONFIG=debug|release   (default: release)
#   SWIFT_BIN=<path>             explicit compiler, if PATH has the wrong one
#   ANDROID_NDK_HOME=<path>      the NDK, where it is not under the Android SDK
#
# WHY SwiftPM:
# Android needs it, because a Swift SDK is a SwiftPM feature and swiftc rejects
# -swift-sdk outright. The app is a real package - its manifest at the
# application's root, its sources under Sources/ - depending on the library, so both modules
# build in one pass, and the same manifest is what gives SourceKit the context
# it needs in the editor.
#
# Bash 3.2 compatible.
# ---------------------------------------------------------------------------
set -euo pipefail

OUT_ROOT="${1:-}"
APP_PACKAGE="${2:-}"
APP_MODULE="${3:-}"
API="${4:-28}"

if [[ -z "$OUT_ROOT" || -z "$APP_PACKAGE" || -z "$APP_MODULE" ]]; then
  echo "USAGE: $0 <out-dir> <app-package-dir> <app-module> [api]"
  exit 1
fi

if [[ ! -f "$APP_PACKAGE/Package.swift" ]]; then
  echo "ERROR: no Package.swift in $APP_PACKAGE"
  echo "An application is a SwiftPM package - Package.swift at its root, beside Sources/. See apps/HelloWorld."
  exit 1
fi

CONFIG="${SWIFT_CONFIG:-release}"
SWIFT_BIN="${SWIFT_BIN:-swift}"

command -v "$SWIFT_BIN" >/dev/null 2>&1 || { echo "ERROR: swift not found."; exit 1; }

swift_version_of () {
  # NOTE: `swift --version` prints the swift-driver version FIRST, so anchor on
  # "Swift version" rather than taking the first number in the output.
  "$1" --version 2>&1 \
    | grep -oE 'Swift version [0-9]+\.[0-9]+(\.[0-9]+)?' \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1
}

swift_build_of () {
  # The parenthesized BUILD identity: "swift-6.4-RELEASE" from swift.org,
  # "swiftlang-6.4.0.34.1" from Xcode. The version NUMBERS can agree across
  # those two while their binary modules do not, so the build is what has to
  # agree with the SDK.
  "$1" --version 2>&1 \
    | grep -oE '\(swift[a-z]*-[^) ]+' | head -n 1 | tr -d '('
}

release_of () {
  # One release, two spellings: swift.org names its files "6.4.0" while the
  # compiler calls itself "6.4". A trailing ".0" is the only difference.
  case "$1" in
    *.*.0) echo "${1%.0}" ;;
    *)     echo "$1" ;;
  esac
}

sdk_search_roots () {
  echo "$HOME/Library/org.swift.swiftpm/swift-sdks" "$HOME/.swiftpm/swift-sdks"
}

# THE SDK OF THE PROJECT'S RELEASE, by its id. The release is the compiler's -
# the Swift every other platform of the application builds with - and an SDK
# id carries the release it belongs to (swift-6.4.0-RELEASE_android). Named by
# id, because a TRIPLE names every installed SDK that serves it: with two
# releases installed SwiftPM refuses "matched multiple SDKs".
TOOLCHAIN_VER="$(swift_version_of "$SWIFT_BIN")"
TOOLCHAIN_BUILD="$(swift_build_of "$SWIFT_BIN")"
RELEASE="$(release_of "$TOOLCHAIN_VER")"

SDK_ID=""
for id in $("$SWIFT_BIN" sdk list 2>/dev/null | grep -i android); do
  version="$(printf '%s' "$id" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)"
  [[ "$(release_of "$version")" == "$RELEASE" ]] && SDK_ID="$id"
done

if [[ -z "$SDK_ID" ]]; then
  echo "ERROR: no Swift SDK for Android of Swift $RELEASE is installed."
  echo "  installed: $("$SWIFT_BIN" sdk list 2>/dev/null | grep -i android | tr '\n' ' ')"
  echo "  https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html"
  exit 1
fi

SDK_BUNDLE=""
for root in $(sdk_search_roots); do
  for info in "$root"/*.artifactbundle/info.json; do
    [[ -f "$info" ]] && grep -q "\"$SDK_ID\"" "$info" && SDK_BUNDLE="$(dirname "$info")"
  done
done
[[ -n "$SDK_BUNDLE" ]] || { echo "ERROR: $SDK_ID is listed but its bundle was not found."; exit 1; }

# What the SDK's modules were written by, read from the SDK itself: its name
# says 6.4.0 while the compiler that wrote it calls itself swift-6.4-RELEASE.
swift_interface="$(find "$SDK_BUNDLE" -path "*Swift.swiftmodule*" -name "*.swiftinterface" 2>/dev/null | head -n 1)"
SDK_BUILD="$(grep -m 1 'swift-compiler-version' "$swift_interface" 2>/dev/null \
  | grep -oE '\(swift[a-z]*-[^) ]+' | tr -d '(')"
[[ -n "$SDK_BUILD" ]] || { echo "ERROR: $SDK_ID does not say which compiler wrote it."; exit 1; }

echo "Swift SDK:  $SDK_ID ($SDK_BUILD)"
echo "toolchain:  $TOOLCHAIN_VER ($TOOLCHAIN_BUILD)"

# Swift modules are only readable by the compiler BUILD that wrote them, and
# the version numbers do not decide it: Xcode's 6.4 (swiftlang-6.4.0.34.1)
# refuses the SDK's binary modules written by swift-6.4-RELEASE, spelled
# "compiled module was created by an older version of the compiler; rebuild
# 'Dispatch'" - which reads as a stale SDK while the compiler is the wrong
# one. So the gate is the BUILD in the parentheses against the build that
# wrote the SDK, and a default swift that fails it is replaced by a matching
# toolchain from the standard install locations - which is what lets an F5
# that knows nothing about toolchains build with Xcode first on PATH.
if [[ "$TOOLCHAIN_BUILD" != "$SDK_BUILD" ]]; then
  echo "  build mismatch - looking for a $SDK_BUILD toolchain on disk..."
  for candidate in \
      "$HOME"/Library/Developer/Toolchains/*.xctoolchain/usr/bin/swift \
      /Library/Developer/Toolchains/*.xctoolchain/usr/bin/swift \
      "$HOME/.swiftly/bin/swift"; do
    if [[ -x "$candidate" ]] && [[ "$(swift_build_of "$candidate")" == "$SDK_BUILD" ]]; then
      SWIFT_BIN="$candidate"
      TOOLCHAIN_BUILD="$SDK_BUILD"
      TOOLCHAIN_VER="$(swift_version_of "$SWIFT_BIN")"
      echo "  using: $SWIFT_BIN"
      break
    fi
  done
fi

if [[ "$TOOLCHAIN_BUILD" != "$SDK_BUILD" ]]; then
  echo
  echo "ERROR: toolchain $TOOLCHAIN_VER ($TOOLCHAIN_BUILD) does not match $SDK_ID ($SDK_BUILD)."
  echo "Install the swift.org toolchain of that release (macOS: the ${SDK_ID%_android}.pkg"
  echo "from swift.org/install), or point at one directly:  SWIFT_BIN=/path/to/swift $0 ..."
  exit 1
fi

# THE NDK, which the build links against and which holds the C++ runtime the
# application ships. Named by ANDROID_NDK_ROOT or ANDROID_NDK_HOME, else read
# off the link setup-android-sdk.sh leaves in the SDK, else the newest NDK
# under the Android SDK. Exported, because SwiftPM finds the NDK itself and
# looks only in its standard places otherwise.
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
if [[ -z "$NDK_ROOT" ]]; then
  echo "ERROR: no Android NDK found. Set ANDROID_NDK_HOME to one - 30 or newer."
  exit 1
fi
export ANDROID_NDK_ROOT="$NDK_ROOT"
echo "NDK:        $NDK_ROOT"

echo "configuration: $CONFIG"
echo "app module:    $APP_MODULE"
echo

ABIS="arm64-v8a x86_64"

triple_for_abi () {
  case "$1" in
    arm64-v8a)   echo "aarch64-unknown-linux-android${API}" ;;
    x86_64)      echo "x86_64-unknown-linux-android${API}" ;;
    armeabi-v7a) echo "armv7-unknown-linux-androideabi${API}" ;;
    *) echo "" ;;
  esac
}

find_in_sdk () {
  # The chosen SDK and nothing else: another release's runtime beside it has
  # the same file names and the wrong contents.
  find -L "$SDK_BUNDLE" -name "$1" -path "*${2}*" 2>/dev/null | head -n 1
}

find_in_ndk () {
  find "$NDK_ROOT/toolchains/llvm/prebuilt" -name "$1" -path "*/sysroot/usr/lib/${2}/*" 2>/dev/null | head -n 1
}

# --- what gets packaged: install_so and remove_the_rest --------------------
# shellcheck source=libraries.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libraries.sh"

for abi in $ABIS; do
  triple="$(triple_for_abi "$abi")"
  [[ -n "$triple" ]] || { echo "skipping unknown ABI: $abi"; continue; }

  dest="$OUT_ROOT/$abi"
  mkdir -p "$dest"
  WANTED=""

  # The stamp goes now and the libraries stay. MSBuild reads the stamp to decide
  # whether this has to run, so clearing it up front is what makes a FAILED
  # build ask to be run again; the libraries are what install_so compares
  # against, and wiping them would make every build a first one.
  rm -f "$dest"/.stamp-*

  echo "-- $abi ($triple)"

  # NOTE: --static-swift-stdlib is deliberately NOT used. For a .dynamic product
  # SwiftPM accepts it and silently ignores it: the build succeeds, the output
  # looks lean, and the .so still needs libswiftCore.so at load time. The failure
  # then appears only on device, as a dlopen error.
  #
  # The SDK is named by its id and the target by --triple within it; a triple
  # alone as --swift-sdk names every installed release that serves it.
  #
  # -Xswiftc -DMAUI reaches every module of the build, the library included:
  # Swift code written for the MAUI host alone stands under `#if MAUI`.
  "$SWIFT_BIN" build \
    --package-path "$APP_PACKAGE" \
    --product "$APP_MODULE" \
    --swift-sdk "$SDK_ID" \
    --triple "$triple" \
    -c "$CONFIG" \
    -Xswiftc -DMAUI

  # Where the products are is SwiftPM's to say: the build system decides the
  # layout (.build/out/Products/Release-android-aarch64 under Swift Build).
  built_dir="$("$SWIFT_BIN" build \
    --package-path "$APP_PACKAGE" \
    --swift-sdk "$SDK_ID" \
    --triple "$triple" \
    -c "$CONFIG" \
    -Xswiftc -DMAUI \
    --show-bin-path)"
  for module in StateUI "$APP_MODULE"; do
    src="$built_dir/lib$module.so"
    [[ -f "$src" ]] || { echo "ERROR: lib$module.so was not produced for $abi (looked in $built_dir)"; exit 1; }
    install_so "$src" "$dest"
  done

  # libc++_shared.so from the NDK is always required alongside.
  case "$abi" in
    arm64-v8a)   ndk_dir="aarch64-linux-android"; token="aarch64" ;;
    x86_64)      ndk_dir="x86_64-linux-android";  token="x86_64" ;;
    armeabi-v7a) ndk_dir="arm-linux-androideabi"; token="armv7" ;;
  esac
  libcxx="$(find_in_ndk "libc++_shared.so" "$ndk_dir")"
  [[ -n "$libcxx" ]] && install_so "$libcxx" "$dest" || echo "   WARNING: libc++_shared.so not found for $abi in $NDK_ROOT"

  # Swift runtime - always. Android ships none.
  core="$(find_in_sdk "libswiftCore.so" "$token")"
  if [[ -n "$core" ]]; then
    runtime_dir="$(dirname "$core")"
    for lib in "$runtime_dir"/*.so; do
      case "$(basename "$lib")" in
        libXCTest.so|libTesting.so|lib_TestingInterop.so|lib_Testing_Foundation.so) continue ;;
      esac
      install_so "$lib" "$dest"
    done
  else
    echo "   ERROR: Swift runtime not found under the installed SDK."
    exit 1
  fi

  remove_the_rest "$dest"
  touch "$dest/.stamp-$CONFIG"

  # --- verify every DT_NEEDED entry is satisfied ---------------------------
  # Without this the build looks clean and the failure appears only on device.
  #
  # The NDK's llvm-readelf is the one that answers on a Mac: Xcode ships no
  # readelf at all, and the Swift SDK for Android carries none. objdump is the
  # last resort. With the libraries copied only when they have moved, a
  # runtime that goes missing is exactly what nobody would notice until a
  # device refuses to dlopen it.
  READER=""
  READER_KIND=""

  for candidate in llvm-readelf readelf; do
    command -v "$candidate" >/dev/null 2>&1 && { READER="$candidate"; READER_KIND="readelf"; break; }
  done

  if [[ -z "$READER" ]]; then
    READER="$(find "$NDK_ROOT/toolchains/llvm/prebuilt" -name 'llvm-readelf' -type f 2>/dev/null | head -n 1)"
    [[ -n "$READER" ]] && READER_KIND="readelf"
  fi

  if [[ -z "$READER" ]] && command -v objdump >/dev/null 2>&1; then
    READER="objdump"
    READER_KIND="objdump"
  fi

  needed_libs () {
    if [[ "$READER_KIND" == "readelf" ]]; then
      "$READER" --needed-libs "$1" 2>/dev/null
    else
      "$READER" -p "$1" 2>/dev/null | grep NEEDED
    fi
  }

  if [[ -z "$READER" ]]; then
    echo "   WARNING: no readelf or objdump - dependencies were NOT verified."
  else
    missing=""
    for so in "$dest"/lib*.so; do
      for needed in $(needed_libs "$so" | grep -oE '[A-Za-z0-9_.+-]+\.so' | sort -u); do
        case "$needed" in
          libc.so|libm.so|libdl.so|liblog.so|libandroid.so|libz.so|libstdc++.so) continue ;;
        esac
        [[ -f "$dest/$needed" ]] || missing="$missing $needed"
      done
    done
    if [[ -n "$missing" ]]; then
      echo "   ERROR: needed but not packaged:$(echo "$missing" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
      exit 1
    fi
    echo "   dependencies: all satisfied"
  fi

  echo "   $(find "$dest" -name '*.so' | wc -l | tr -d ' ') .so file(s), $(du -sh "$dest" | cut -f1)"
done

echo
echo "Done."
