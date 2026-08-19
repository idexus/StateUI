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
# Builds a Swift module for Apple platforms as a static library.
#
# Called once per module: first for the StateUI library, then for the
# application's UI module, which links against it. Nothing here is specific to
# either - the module name and source directory are arguments, so a second app
# needs no change to this script.
#
# USAGE:
#   ./build-apple.sh <variant> <out-dir> <module> <sources-dir> [deps-dir]
#
#   variant      ios-device | ios-simulator | ios-simulator-x64
#                maccatalyst | maccatalyst-x64
#   out-dir      where lib<module>.a is written
#   module       Swift module name, e.g. StateUI or GalleryUI
#   sources-dir  directory globbed for .swift files (recursively)
#   deps-dir     directory holding .swiftmodule files this module imports
#
# Environment:
#   SWIFT_CONFIG=debug|release      (default: release)
#   STATEUI_PLUGIN_PACKAGE=<dir>  SwiftPM package to build the macro plugin
#                                   from - see "the macro plugin" below
#   STATEUI_MACRO_SOURCES=<dir>   the plugin's own sources, so editing one
#                                   rebuilds it
#
# Static libraries link straight into the app binary, so there is no framework
# to embed or sign, and P/Invoke targets "__Internal".
#
# Bash 3.2 compatible - macOS ships that version and has not moved since.
# ---------------------------------------------------------------------------
set -euo pipefail

VARIANT="${1:-}"
OUT_DIR="${2:-}"
MODULE="${3:-}"
SOURCES_DIR="${4:-}"
DEPS_DIR="${5:-}"

if [[ -z "$VARIANT" || -z "$OUT_DIR" || -z "$MODULE" || -z "$SOURCES_DIR" ]]; then
  echo "USAGE: $0 <variant> <out-dir> <module> <sources-dir> [deps-dir]"
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Apple platforms can only be built on macOS."
  exit 1
fi

CONFIG="${SWIFT_CONFIG:-release}"
if [[ "$CONFIG" == "debug" ]]; then
  # -Onone keeps the code recognizable in a debugger; -g emits DWARF, the native
  # format on Apple platforms and what LLDB reads.
  OPT_FLAGS=(-Onone -g)
else
  OPT_FLAGS=(-O)
fi

# Must match SupportedOSPlatformVersion in the app project and `platforms:` in
# every Package.swift. 17 rather than 15 because a custom
# SerialExecutor - which is how a handler resumes on the thread MAUI draws on,
# see Core/MainThread.swift - is iOS 17 API. Below that the same thing is only
# reachable through a deprecated, underscored entry point.
IOS_MIN="17.0"
CATALYST_MIN="17.0"

case "$VARIANT" in
  ios-device)        TARGET="arm64-apple-ios${IOS_MIN}";              SDK="iphoneos" ;;
  ios-simulator)     TARGET="arm64-apple-ios${IOS_MIN}-simulator";    SDK="iphonesimulator" ;;
  ios-simulator-x64) TARGET="x86_64-apple-ios${IOS_MIN}-simulator";   SDK="iphonesimulator" ;;
  maccatalyst)       TARGET="arm64-apple-ios${CATALYST_MIN}-macabi";  SDK="macosx" ;;
  maccatalyst-x64)   TARGET="x86_64-apple-ios${CATALYST_MIN}-macabi"; SDK="macosx" ;;
  *)
    echo "ERROR: unknown variant '$VARIANT'"
    echo "Available: ios-device, ios-simulator, ios-simulator-x64, maccatalyst, maccatalyst-x64"
    exit 1
    ;;
esac

# Resolved first, because both the exclusion below and the incremental map
# further down are expressed relative to it - the map names an object file after
# each source's path RELATIVE to this directory, so the prefix it strips has to
# be the same shape as the paths find produces.
SOURCES_DIR="$(cd "$SOURCES_DIR" && pwd)"

# Sources are DISCOVERED, never listed - a new .swift file needs no edit here.
#
# Two exclusions, the same two SwiftPM applies on its own: the app module is
# compiled from its whole Swift/ folder, where Package.swift is the MANIFEST
# (import PackageDescription would fail to compile, and it is not app code)
# and .build/ is SwiftPM's scratch, which SourceKit fills with checkouts
# whose .swift files belong to other packages entirely.
#
# THE .build EXCLUSION IS ANCHORED to this directory, and it was not: a plain
# */.build/* threw away everything when the LIBRARY was the thing being
# compiled, because in an app that consumes StateUI as a dependency its
# sources sit under .build/checkouts/StateUI/src/StateUI/Sources - inside a
# .build, and nobody's scratch. What it read as was "no .swift files found under
# <a directory plainly full of them>".
find_sources () {
  find "$SOURCES_DIR" -name '*.swift' -type f \
    -not -name 'Package.swift' -not -path "$SOURCES_DIR/.build/*"
}

# Read with a while loop rather than mapfile: macOS ships bash 3.2, where
# mapfile does not exist and the script would fail with exit code 127 before
# doing anything at all.
# The count is taken from find itself rather than from ${#SOURCES[@]}: on an
# empty array, bash 3.2 under `set -u` is unreliable about both the length and
# the expansion, so the emptiness check happens before the array is touched.
SOURCE_COUNT=$(find_sources | wc -l | tr -d ' ')
if [[ "$SOURCE_COUNT" -eq 0 ]]; then
  echo "ERROR: no .swift files found under $SOURCES_DIR"
  exit 1
fi

SOURCES=()
while IFS= read -r file; do
  SOURCES+=("$file")
done < <(find_sources | sort)

# --- the macro plugin ------------------------------------------------------
# `@StateClass` is a macro, and a macro is an EXECUTABLE the compiler starts and
# talks to - so it has to exist before any Swift here compiles, and it is built
# for THIS machine rather than for the target. SwiftPM is what builds one;
# swiftc only knows how to load it.
#
# The first build compiles swift-syntax and takes minutes. Every build after
# that finds it and does nothing - which is why the timestamp check is here
# rather than an unconditional `swift build`: this script runs twice per
# platform, and a second each for an answer that never changed adds up.
#
# The executable's NAME is SwiftPM's business, and it has changed - recent
# versions add a "-tool" suffix. Both are looked for rather than one assumed,
# because guessing wrong fails much later, as a macro that "cannot be resolved"
# with nothing in the message about a file name.
#
# WHICH PACKAGE IS BUILT is the APP's, and it is passed in rather than worked
# out here. It is the one package that exists in both layouts: in this
# repository the library sits a few directories up, while an app made by
# `dotnet new stateui` has it as a SwiftPM dependency, checked out under the
# app's own .build - and building the library's package THERE would fetch and
# compile swift-syntax a second time for a plugin the app already has.
#
# The defaults are this repository's answers, so running the script by hand
# needs no environment at all.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# The default is whichever layout this copy of the script is sitting in: the
# gallery in this repository, the one app beside it in a scaffolded one. The
# manifest sits beside the .csproj in both, so the package IS the app directory.
DEFAULT_PLUGIN_PACKAGE="$ROOT_DIR"
[[ -f "$ROOT_DIR/apps/Gallery/Package.swift" ]] &&
  DEFAULT_PLUGIN_PACKAGE="$ROOT_DIR/apps/Gallery"

PLUGIN_PACKAGE="${STATEUI_PLUGIN_PACKAGE:-$DEFAULT_PLUGIN_PACKAGE}"
MACRO_SOURCES="${STATEUI_MACRO_SOURCES:-$ROOT_DIR/src/StateUI/Macros}"
PLUGIN_MODULE="StateUIMacros"

find_plugin () {
  local bin
  bin="$(swift build --package-path "$PLUGIN_PACKAGE" -c release --show-bin-path 2>/dev/null)" || return 1
  for candidate in "$bin/$PLUGIN_MODULE-tool" "$bin/$PLUGIN_MODULE"; do
    if [[ -x "$candidate" ]]; then echo "$candidate"; return 0; fi
  done
  return 1
}

PLUGIN="$(find_plugin || true)"

# The whole package, not `--target StateUIMacros`. A macro target on its own
# is COMPILED and never LINKED - SwiftPM produces the module and stops, leaving
# a .build directory with no executable in it - so the plugin only appears once
# something that uses it is built. Measured; the flag that looks like it should
# do this does not.
if [[ -z "$PLUGIN" ]] || [[ -n "$(find "$MACRO_SOURCES" -name '*.swift' -newer "$PLUGIN" 2>/dev/null)" ]]; then
  echo "-- $PLUGIN_MODULE (a first build compiles swift-syntax, which takes minutes)"
  swift build --package-path "$PLUGIN_PACKAGE" -c release
  PLUGIN="$(find_plugin || true)"
fi

if [[ -z "$PLUGIN" ]]; then
  echo "ERROR: the macro plugin was not produced."
  echo "Run it by hand to see why:"
  echo "  swift build --package-path \"$PLUGIN_PACKAGE\" -c release"
  exit 1
fi

SDK_PATH="$(xcrun --sdk "$SDK" --show-sdk-path)"
mkdir -p "$OUT_DIR"

echo "-- $MODULE for $VARIANT ($CONFIG, $SOURCE_COUNT source file(s))"

# -I points at the directory holding .swiftmodule files for imported modules.
# Empty for the library itself, which has no dependencies.
IMPORT_FLAGS=()
if [[ -n "$DEPS_DIR" && -d "$DEPS_DIR" ]]; then
  IMPORT_FLAGS=(-I "$DEPS_DIR")
fi

# --- incremental compilation -----------------------------------------------
# The build is TWO steps - compile to .o, then archive them - rather than the
# one -emit-library step that did both. That is the price of -incremental, and
# it buys the difference between recompiling a module and recompiling a file.
#
# -incremental needs somewhere to record what it learned, which is the output
# file map: for every source file, where its .o goes and where its .swiftdeps
# goes. The entry under "" is the module-wide one. Without the map swiftc
# silently compiles everything, every time - which is what it was doing.
OBJ_DIR="$OUT_DIR/$MODULE.objs"
mkdir -p "$OBJ_DIR"

# The stamp records the configuration the .o files were built with. A build that
# changes -Onone to -O, or one variant's triple to another's, leaves objects
# that are wrong in a way -incremental cannot see: it tracks SOURCES, not flags.
# So a configuration change throws the objects away and starts over.
CONFIG_STAMP="$OBJ_DIR/.config"
CONFIG_NOW="$CONFIG-$VARIANT"

if [[ ! -f "$CONFIG_STAMP" ]] || [[ "$(cat "$CONFIG_STAMP")" != "$CONFIG_NOW" ]]; then
  [[ -f "$CONFIG_STAMP" ]] && echo "   configuration changed - recompiling from scratch"
  find "$OBJ_DIR" -type f -delete
fi

# Object names come from the path relative to the source root, not the file
# name: two files called Button.swift in different folders would otherwise
# share one Button.o, and the second would quietly overwrite the first.
#
# The map is written by hand rather than by a JSON tool, because macOS ships
# neither jq nor an associative array - bash 3.2, and it has not moved since.
# OBJECTS is filled in the same pass, so the link step names exactly what the
# map named and nothing a deleted source left behind.
OFM="$OBJ_DIR/output-file-map.json"
OBJECTS=()

json_string () {
  printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
}

{
  printf '{\n'
  printf '  "": { "swift-dependencies": %s }' "$(json_string "$OBJ_DIR/master.swiftdeps")"

  for file in "${SOURCES[@]}"; do
    relative="${file#$SOURCES_DIR/}"
    flat="$(printf '%s' "${relative%.swift}" | tr '/' '_')"
    OBJECTS+=("$OBJ_DIR/$flat.o")

    printf ',\n  %s: { "object": %s, "swift-dependencies": %s }' \
      "$(json_string "$file")" \
      "$(json_string "$OBJ_DIR/$flat.o")" \
      "$(json_string "$OBJ_DIR/$flat.swiftdeps")"
  done

  printf '\n}\n'
} > "$OFM"

# NOTE: -emit-module-path is EXPLICIT, which it could not be before.
#
# A bare -emit-module writes <MODULE>.swiftmodule next to the -o file, and that
# was right while -o named the library. Step one has no -o at all, so the path
# is given: it is where the NEXT compilation looks for it via -I, and a module
# written somewhere else does not fail this run - it fails the module that
# imports this one, one step later and somewhere else.
#
# NOTE the ${arr[@]+"${arr[@]}"} form around IMPORT_FLAGS.
#
# Under `set -u`, bash 3.2 - the version macOS ships, and it has not moved since
# for licensing reasons - treats a plain "${arr[@]}" on an EMPTY array as an
# unbound variable and aborts the script. Newer bash does not, so this fails
# only on macOS, and only for the library build: that is the one compilation
# with no dependencies, hence the only place the array is empty.
#
# The ${arr[@]+...} guard expands to nothing when the array is unset or empty,
# and to its elements otherwise. It is the portable way to say "these flags,
# if any".
#
# NOTE the upcoming feature.
#
# Android goes through SwiftPM, where the flag is in each Package.swift; Apple
# and Windows call swiftc directly, so it has to be repeated here or the same
# sources would compile with different concurrency defaults per platform. See
# the note in the repository's Package.swift for what it does. It is accepted in
# every language mode, which matters because this build does not pass one.
#
# NOTE the plugin.
#
# Passed for EVERY module, the library and the application's alike: an author
# writes `@StateClass` in their own code, and that compilation is this same
# script with a different module name. The text after `#` is the plugin's MODULE
# name, which is what `#externalMacro(module:)` names - not the file.
COMPILE_ARGS=(
  -c
  -incremental
  -output-file-map "$OFM"
  -emit-module -emit-module-path "$OUT_DIR/$MODULE.swiftmodule"
  -module-name "$MODULE"
  -parse-as-library
  -enable-upcoming-feature NonisolatedNonsendingByDefault
  -load-plugin-executable "$PLUGIN#$PLUGIN_MODULE"
  -target "$TARGET"
  -sdk "$SDK_PATH"
  ${IMPORT_FLAGS[@]+"${IMPORT_FLAGS[@]}"}
  "${OPT_FLAGS[@]}"
)

if ! swiftc "${COMPILE_ARGS[@]}" "${SOURCES[@]}"; then
  echo
  echo "ERROR: swiftc failed to compile. Full command:"
  echo "  swiftc ${COMPILE_ARGS[*]} ${SOURCES[*]}"
  exit 1
fi

MISSING=""
for object in "${OBJECTS[@]}"; do
  [[ -f "$object" ]] || MISSING="$MISSING $object"
done

if [[ -n "$MISSING" ]]; then
  echo "ERROR: compilation reported success but object file(s) are missing:$MISSING"
  exit 1
fi

# STEP 2 - archive. Every .o the map named, whether or not this run rebuilt it.
#
# -emit-module is NOT repeated here: the module was written by step one, and
# asking for it again would rebuild it from .o files that do not carry what it
# needs.
LINK_ARGS=(
  -emit-library -static
  -module-name "$MODULE"
  -target "$TARGET"
  -sdk "$SDK_PATH"
  -o "$OUT_DIR/lib$MODULE.a"
)

if ! swiftc "${LINK_ARGS[@]}" "${OBJECTS[@]}"; then
  echo
  echo "ERROR: swiftc failed to link. Full command:"
  echo "  swiftc ${LINK_ARGS[*]} ${OBJECTS[*]}"
  exit 1
fi

# Written only after both steps succeed, so a failed build does not leave a
# stamp claiming these objects match the current configuration.
printf '%s' "$CONFIG_NOW" > "$CONFIG_STAMP"

# Configuration stamp, per module. MSBuild compares against it to decide whether
# a rebuild is needed - the file name does not change between configurations, so
# it could not tell otherwise.
rm -f "$OUT_DIR/.stamp-$MODULE-"*
touch "$OUT_DIR/.stamp-$MODULE-$CONFIG"

SYMBOLS=$(nm -gU "$OUT_DIR/lib$MODULE.a" 2>/dev/null | grep -c "_stateui_" || true)
echo "   lib$MODULE.a, $SYMBOLS exported stateui_* symbol(s)"
