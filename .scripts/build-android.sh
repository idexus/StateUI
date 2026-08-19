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
#
# WHY SwiftPM:
# Android needs it, because a Swift SDK is a SwiftPM feature and swiftc rejects
# -swift-sdk outright. The app is a real package - its manifest beside the
# .csproj, its sources under Swift/ - depending on the library, so both modules
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
  echo "An app must be a SwiftPM package - Package.swift beside the .csproj. See apps/HelloWorld."
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
  # The parenthesized BUILD identity: "swift-6.3.3-RELEASE" from swift.org,
  # "swiftlang-6.3.3.1.3" from Xcode. The version NUMBERS can agree across
  # those two while their binary modules do not, so the build is what has to
  # agree with the SDK.
  "$1" --version 2>&1 \
    | grep -oE '\(swift[a-z]*-[^) ]+' | head -n 1 | tr -d '('
}

if ! "$SWIFT_BIN" sdk list 2>/dev/null | grep -qi android; then
  echo "ERROR: no Swift SDK for Android installed."
  echo "  https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html"
  exit 1
fi

SDK_ENTRY="$("$SWIFT_BIN" sdk list | grep -i android | head -n 1 | tr -d '[:space:]')"
SDK_VER="$(printf '%s' "$SDK_ENTRY" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
SDK_TAG="${SDK_ENTRY%%_*}"
TOOLCHAIN_VER="$(swift_version_of "$SWIFT_BIN")"
TOOLCHAIN_BUILD="$(swift_build_of "$SWIFT_BIN")"

echo "Swift SDK:  $SDK_ENTRY"
echo "toolchain:  $TOOLCHAIN_VER ($TOOLCHAIN_BUILD)"

# Swift modules are only readable by the compiler BUILD that wrote them, and
# the version numbers do not decide it: Xcode's 6.3.3 (swiftlang-6.3.3.1.3)
# refuses the SDK's binary modules built by swift-6.3.3-RELEASE, spelled
# "compiled module was created by an older version of the compiler; rebuild
# 'Dispatch'" - which reads as a stale SDK while the compiler is the wrong
# one. So the gate is the BUILD in the parentheses against the SDK's own tag,
# and a default swift that fails it is replaced by a matching toolchain from
# the standard install locations - which is what lets an F5 that knows
# nothing about toolchains build with Xcode first on PATH.
if [[ "$TOOLCHAIN_BUILD" != "$SDK_TAG" ]]; then
  echo "  build mismatch - looking for a $SDK_TAG toolchain on disk..."
  for candidate in \
      "$HOME/Library/Developer/Toolchains/${SDK_TAG}.xctoolchain/usr/bin/swift" \
      "/Library/Developer/Toolchains/${SDK_TAG}.xctoolchain/usr/bin/swift" \
      "$HOME/.swiftly/bin/swift"; do
    if [[ -x "$candidate" ]] && [[ "$(swift_build_of "$candidate")" == "$SDK_TAG" ]]; then
      SWIFT_BIN="$candidate"
      TOOLCHAIN_BUILD="$SDK_TAG"
      TOOLCHAIN_VER="$(swift_version_of "$SWIFT_BIN")"
      echo "  using: $SWIFT_BIN"
      break
    fi
  done
fi

if [[ "$TOOLCHAIN_BUILD" != "$SDK_TAG" ]]; then
  echo
  echo "ERROR: toolchain $TOOLCHAIN_VER ($TOOLCHAIN_BUILD) does not match SDK $SDK_ENTRY."
  echo "Install the matching swift.org toolchain (macOS: the ${SDK_TAG}.pkg from"
  echo "swift.org/install), or point at one directly:  SWIFT_BIN=/path/to/swift $0 ..."
  exit 1
fi

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

sdk_search_roots () {
  echo "$HOME/Library/org.swift.swiftpm/swift-sdks" "$HOME/.swiftpm/swift-sdks"
}

find_in_sdk () {
  # shellcheck disable=SC2046
  find $(sdk_search_roots) -name "$1" -path "*${2}*" 2>/dev/null | head -n 1
}

# --- what gets packaged ----------------------------------------------------
# SwiftPM compiles incrementally on its own - a one-line change rebuilds one
# file - and the copy step must not cost a full build's worth of work beside
# that: the Swift runtime is around 100 MB per ABI and changes only when the
# TOOLCHAIN does, which is rarely, so each file is copied only when it is
# missing or newer.
#
# The names are remembered as they go, and anything else in the directory is
# removed afterwards. Doing it that way round means a library whose source is
# gone still disappears, while one that has not moved is left where it is.
WANTED=""

install_so () {
  local source="$1" dest_dir="$2" name
  name="$(basename "$source")"
  WANTED="$WANTED $name"

  if [[ ! -f "$dest_dir/$name" ]] || [[ "$source" -nt "$dest_dir/$name" ]]; then
    cp "$source" "$dest_dir/$name"
  fi
}

remove_the_rest () {
  local dest_dir="$1" so name
  for so in "$dest_dir"/*.so; do
    [[ -f "$so" ]] || continue
    name="$(basename "$so")"
    case " $WANTED " in
      *" $name "*) continue ;;
    esac
    rm -f "$so"
  done
}

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
  # The triple goes AS THE VALUE of --swift-sdk. A separate --triple flag
  # overrides the compilation target but not the SDK resource paths, which fails
  # with "could not find module 'Swift' for target ...".
  "$SWIFT_BIN" build \
    --package-path "$APP_PACKAGE" \
    --swift-sdk "$triple" \
    -c "$CONFIG"

  # A cross-build compiles the macro plugin FOR THE HOST in a nested pass, and
  # that pass spills swift-syntax's .d/.dia/.swiftdeps loose into the package
  # root - measured: 70 sources, three files each. The real incremental state
  # lives under .build; these are duplicates ("-2" in the names) with no
  # reader, so they are swept rather than lived with.
  find "$APP_PACKAGE" -maxdepth 1 -type f \
    \( -name '*.d' -o -name '*.dia' -o -name '*.swiftdeps' \) -delete

  built_dir="$APP_PACKAGE/.build/$triple/$CONFIG"
  for module in StateUI "$APP_MODULE"; do
    src="$built_dir/lib$module.so"
    if [[ ! -f "$src" ]]; then
      src="$(find "$APP_PACKAGE/.build" -name "lib$module.so" -path "*${triple}*" -path "*${CONFIG}*" 2>/dev/null | head -n 1)"
    fi
    [[ -f "$src" ]] || { echo "ERROR: lib$module.so was not produced for $abi"; exit 1; }
    install_so "$src" "$dest"
  done

  # libc++_shared.so from the NDK is always required alongside.
  case "$abi" in
    arm64-v8a)   ndk_dir="aarch64-linux-android"; token="aarch64" ;;
    x86_64)      ndk_dir="x86_64-linux-android";  token="x86_64" ;;
    armeabi-v7a) ndk_dir="arm-linux-androideabi"; token="armv7" ;;
  esac
  libcxx="$(find_in_sdk "libc++_shared.so" "$ndk_dir")"
  [[ -n "$libcxx" ]] && install_so "$libcxx" "$dest" || echo "   WARNING: libc++_shared.so not found for $abi"

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
  # llvm-objdump is the third candidate and it is the one that answers on a Mac:
  # Xcode ships it, ships no readelf at all, and the Swift SDK for Android
  # carries neither - without it this check quietly does nothing on the machine
  # most of this gets built on. And with the libraries copied only when they
  # have moved, a runtime that goes missing is exactly what nobody would notice
  # until a device refuses to dlopen it.
  READER=""
  READER_KIND=""

  for candidate in llvm-readelf readelf; do
    command -v "$candidate" >/dev/null 2>&1 && { READER="$candidate"; READER_KIND="readelf"; break; }
  done

  if [[ -z "$READER" ]]; then
    READER="$(find $(sdk_search_roots) -name 'llvm-readelf' -type f 2>/dev/null | head -n 1)"
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
