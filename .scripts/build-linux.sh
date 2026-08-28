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
# Builds the Swift modules for Linux (.so for the host architecture).
#
# USAGE:
#   ./build-linux.sh <out-dir> <app-package-dir> <app-module>
#
#   out-dir          where the .so files land - one directory, since the host
#                    toolchain builds its own architecture and nothing else
#   app-package-dir  the app's project folder - the one holding Package.swift
#   app-module       Swift module name, e.g. GalleryUI
#
# Environment:
#   SWIFT_CONFIG=debug|release   (default: release)
#   SWIFT_BIN=<path>             explicit compiler, if PATH has the wrong one
#
# WHY SwiftPM:
# The host toolchain builds natively, so no Swift SDK is involved - but the
# app is a real package, its manifest beside the .csproj, depending on the
# library, so one `swift build` compiles the macro plugin and both modules,
# exactly as the Android build does. NonisolatedNonsendingByDefault comes from
# the manifests' swiftSettings, since SwiftPM reads them here.
#
# THE RUNTIME SHIPS WITH THE APP: a Linux desktop has no Swift runtime of its
# own, so every .so the modules need is copied beside them - and $ORIGIN is
# added to the modules' rpath, because their dependencies are resolved by
# ld.so, which never looks in the directory a library was loaded from unless
# the library itself says so. The DT_NEEDED pass at the end is what proves the
# set is complete; without it the build looks clean and the failure appears
# only when the app starts.
#
# Bash 3.2 compatible.
# ---------------------------------------------------------------------------
set -euo pipefail

OUT_DIR="${1:-}"
APP_PACKAGE="${2:-}"
APP_MODULE="${3:-}"
# WHERE THE LIBRARY IS - this repository when it is the one being built, and
# SwiftPM's checkout of it for an application that consumes it. Its own native
# shims are compiled from there. Empty is not an error: an application with no
# library beside it simply has none to add.
LIB_PACKAGE="${4:-}"

if [[ -z "$OUT_DIR" || -z "$APP_PACKAGE" || -z "$APP_MODULE" ]]; then
  echo "USAGE: $0 <out-dir> <app-package-dir> <app-module> [library-package-dir]"
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

echo "toolchain:     $("$SWIFT_BIN" --version 2>&1 | grep -m 1 'Swift version')"
echo "configuration: $CONFIG"
echo "app module:    $APP_MODULE"
echo

mkdir -p "$OUT_DIR"

# The stamp goes now and the libraries stay. MSBuild reads the stamp to decide
# whether this has to run, so clearing it up front is what makes a FAILED
# build ask to be run again; the libraries are what install_so compares
# against, and wiping them would make every build a first one.
rm -f "$OUT_DIR"/.stamp-*

"$SWIFT_BIN" build \
  --package-path "$APP_PACKAGE" \
  -c "$CONFIG" \
  -Xlinker -rpath -Xlinker '$ORIGIN'

# A build of the macro plugin can spill swift-syntax's .d/.dia/.swiftdeps
# loose into the package root - the Android cross-build measurably does, so
# the same sweep runs here rather than waiting to find out which SwiftPM
# versions do it natively. The real incremental state lives under .build.
find "$APP_PACKAGE" -maxdepth 1 -type f \
  \( -name '*.d' -o -name '*.dia' -o -name '*.swiftdeps' \) -delete

BIN_DIR="$("$SWIFT_BIN" build --package-path "$APP_PACKAGE" -c "$CONFIG" --show-bin-path)"

# --- what gets packaged ----------------------------------------------------
# SwiftPM compiles incrementally on its own, and the copy step must not cost
# a full build's worth of work beside that: the Swift runtime is around 90 MB
# and changes only when the TOOLCHAIN does, so each file is copied only when
# it is missing or newer. The names are remembered as they go, and anything
# else in the directory is removed afterwards - a library whose source is
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

for module in StateUI "$APP_MODULE"; do
  src="$BIN_DIR/lib$module.so"
  [[ -f "$src" ]] || { echo "ERROR: lib$module.so was not produced - check the swift build output above."; exit 1; }
  install_so "$src" "$OUT_DIR"
done

# Native shims - a C file becomes lib<name>.so beside the modules. A shim
# interposes one native symbol and forwards the rest through its own
# dependency, which is how this side answers a native bug it cannot reach from
# C#; StateUI.Runtime.Linux/native/graphene-shim.c says why that one exists.
#
# TWO PLACES, and the library's is the one that matters: an application gets
# its shims from the library it consumes - the same checkout SwiftPM makes for
# the Swift half, which is why $LIB_PACKAGE finds them for an app built from
# NuGet exactly as it does inside this repository. An app may add its own
# beside its Platforms/Linux sources.
for shim_src in "$LIB_PACKAGE"/src/StateUI.Runtime.Linux/native/*.c "$APP_PACKAGE"/Platforms/Linux/*.c; do
  [[ -f "$shim_src" ]] || continue
  shim_name="lib$(basename "$shim_src" .c).so"
  # --no-as-needed, or the linker drops the dependency the shim exists to
  # forward to - a shim references nothing in it by name.
  cc -shared -fPIC -O2 -o "$OUT_DIR/$shim_name" "$shim_src" \
    -Wl,--no-as-needed -l:libgraphene-1.0.so.0
  WANTED="$WANTED $shim_name"
  echo "   shim: $shim_name"
done

# Swift runtime - always. A Linux desktop ships none, and the toolchain that
# just compiled is the one authority on where its own runtime lives.
RUNTIME_DIR="$("$SWIFT_BIN" -print-target-info 2>/dev/null \
  | sed -n 's/ *"runtimeResourcePath": *"\(.*\)".*/\1/p' | head -n 1)/linux"

if [[ -d "$RUNTIME_DIR" ]]; then
  for lib in "$RUNTIME_DIR"/*.so; do
    case "$(basename "$lib")" in
      libXCTest.so|libTesting.so|lib_TestingInterop.so|lib_Testing_Foundation.so) continue ;;
    esac
    install_so "$lib" "$OUT_DIR"
  done
else
  echo "ERROR: Swift runtime not found - $RUNTIME_DIR is not a directory."
  exit 1
fi

remove_the_rest "$OUT_DIR"
touch "$OUT_DIR/.stamp-$CONFIG"

# --- verify every DT_NEEDED entry is satisfied -----------------------------
# The pattern keeps the trailing version glibc puts on its sonames -
# "libc.so.6", not "libc.so" - so the system list below names them the same
# way the dynamic section does.
READER=""
READER_KIND=""

for candidate in readelf llvm-readelf; do
  command -v "$candidate" >/dev/null 2>&1 && { READER="$candidate"; READER_KIND="readelf"; break; }
done

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
  for so in "$OUT_DIR"/lib*.so; do
    for needed in $(needed_libs "$so" | grep -oE '[A-Za-z0-9_.+-]+\.so(\.[0-9]+)*' | sort -u); do
      case "$needed" in
        libc.so*|libm.so*|libdl.so*|libpthread.so*|librt.so*|libutil.so*|ld-linux*.so*|libgcc_s.so*|libstdc++.so*|libatomic.so*|libcurl.so*|libxml2.so*|libz.so*) continue ;;
        # A shim's dependency is the system library it interposes, which the
        # desktop has because GTK4 itself needs it.
        libgraphene-1.0.so*) continue ;;
      esac
      [[ -f "$OUT_DIR/$needed" ]] || missing="$missing $needed"
    done
  done
  if [[ -n "$missing" ]]; then
    echo "   ERROR: needed but not packaged:$(echo "$missing" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
    exit 1
  fi
  echo "   dependencies: all satisfied"
fi

echo "   $(find "$OUT_DIR" -name '*.so' | wc -l | tr -d ' ') .so file(s), $(du -sh "$OUT_DIR" | cut -f1)"
echo
echo "Done."
