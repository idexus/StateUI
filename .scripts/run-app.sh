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
# Builds and launches the app WITHOUT a debugger, then returns.
#
# Used as the preLaunchTask of "Debug app (Swift)", which is the working way to
# debug Swift on the iOS Simulator: iOS kills an app that stays stopped, and the
# C# debugger starting at the same moment widens that window enough to make it
# near-certain. Launching first, attaching second, avoids it. The "Run app (no
# debugger)" and "Run app (Release, no debugger)" tasks call it for the launch
# alone.
#
# USAGE - the arguments are read by SHAPE, so their order does not matter:
#   ./run-app.sh [ios|maccatalyst|linux] [Debug|Release] [path/to/App.csproj]
#
#     ios | maccatalyst | linux   where to run it; the iOS Simulator unless said
#     Debug | Release             what to build; Debug unless said
#     a path                      the project, when it is not the obvious one
#
# Bash 3.2 compatible - macOS ships that version and has not moved since.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PLATFORM="ios"
CONFIGURATION="Debug"
PROJECT=""

# The arguments are read by SHAPE rather than by position: a platform names
# itself, so does a configuration, and a path is the project. So `ios Release`,
# `Release` alone and `maccatalyst path/to/App.csproj` all mean what they look
# like, and the VS Code tasks - which pass the platform, and sometimes Release
# after it - need no argument order agreed with this file.
#
# Anything else is refused rather than taken for a project: a mistyped platform
# would otherwise be reported as a missing .csproj, which points at the wrong
# thing entirely.
for arg; do
  case "$arg" in
    ios|maccatalyst|linux) PLATFORM="$arg" ;;
    [Dd]ebug)              CONFIGURATION="Debug" ;;
    [Rr]elease)            CONFIGURATION="Release" ;;
    *)
      if [[ -f "$arg" ]]; then
        PROJECT="$arg"
      else
        echo "ERROR: unrecognized argument '$arg'"
        echo "       expected ios, maccatalyst, linux, Debug, Release, or a .csproj path"
        exit 1
      fi
      ;;
  esac
done

# WHICH PROJECT, and it is FOUND rather than spelled out - because this script
# ships in two layouts. In this repository the apps live under apps/ and the
# gallery is the one to run; in an app made by `dotnet new stateui` the
# project file sits beside .scripts and is the only one there.
if [[ -z "$PROJECT" ]]; then
  if [[ -f "$ROOT_DIR/apps/Gallery/Gallery.csproj" ]]; then
    PROJECT="$ROOT_DIR/apps/Gallery/Gallery.csproj"
  else
    found=""
    for candidate in "$ROOT_DIR"/*.csproj; do
      [[ -f "$candidate" ]] || continue
      if [[ -n "$found" ]]; then
        echo "ERROR: more than one .csproj in $ROOT_DIR - name the one to run:"
        echo "       $0 $PLATFORM path/to/App.csproj"
        exit 1
      fi
      found="$candidate"
    done
    PROJECT="$found"
  fi
fi

if [[ -z "$PROJECT" || ! -f "$PROJECT" ]]; then
  echo "ERROR: no project to run. Expected one .csproj beside $ROOT_DIR."
  exit 1
fi

APP_DIR="$(cd "$(dirname "$PROJECT")" && pwd)"

# The project name, which is also the assembly and therefore the PROCESS name -
# what pgrep and the debugger match on. The app BUNDLE is a different thing: its
# name follows $(ApplicationTitle), so it is found rather than spelled out,
# below.
APP_NAME="$(basename "$PROJECT" .csproj)"

# Each platform needs the host it runs on: the Apple two need macOS, the
# Linux head needs Linux.
if [[ "$PLATFORM" == "linux" ]]; then
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: the linux platform needs a Linux host."
    exit 1
  fi
elif [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: the ios and maccatalyst platforms need macOS."
  exit 1
fi

# Locates the .app produced by the build, whatever it is called.
#
# Hardcoding the name breaks the moment ApplicationTitle changes in the .csproj -
# quietly, and with an error that points at a path rather than at the rename that
# caused it. That is exactly how this script broke once already.
find_app_bundle() {
  local output_dir="$1"
  local bundle=""
  local candidate

  if [[ ! -d "$output_dir" ]]; then
    echo "ERROR: nothing was built - $output_dir does not exist." >&2
    return 1
  fi

  while IFS= read -r candidate; do
    if [[ -z "$bundle" ]]; then
      bundle="$candidate"
    else
      echo "ERROR: more than one .app in $output_dir." >&2
      echo "       Remove the stale one, or run a clean build." >&2
      return 1
    fi
  done < <(find "$output_dir" -maxdepth 1 -type d -name '*.app' | sort)

  if [[ -z "$bundle" ]]; then
    echo "ERROR: no .app bundle in $output_dir" >&2
    return 1
  fi

  echo "$bundle"
}

# The bundle identifier from the bundle itself, rather than a second copy of what
# $(ApplicationId) says in the .csproj.
read_bundle_id() {
  local plist="$1/Contents/Info.plist"   # Mac Catalyst
  if [[ ! -f "$plist" ]]; then
    plist="$1/Info.plist"                # iOS
  fi

  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist" 2>/dev/null
}

# An app left over from a previous run would be attached to instead of the new
# one - the attach matches by name, and it would silently be the wrong process.
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "Stopping a previous instance of $APP_NAME..."
  pkill -x "$APP_NAME" || true
  sleep 1
fi

case "$PLATFORM" in

  ios)
    FRAMEWORK="net10.0-ios"
    RID="iossimulator-arm64"

    echo "== Building for the iOS Simulator ($CONFIGURATION) =="
    dotnet build "$PROJECT" -c "$CONFIGURATION" -f "$FRAMEWORK" -r "$RID"

    APP_BUNDLE="$(find_app_bundle "$APP_DIR/bin/$CONFIGURATION/$FRAMEWORK/$RID")"

    BUNDLE_ID="$(read_bundle_id "$APP_BUNDLE")"
    if [[ -z "$BUNDLE_ID" ]]; then
      echo "ERROR: $APP_BUNDLE has no CFBundleIdentifier in its Info.plist."
      exit 1
    fi

    # A simulator has to be running before anything can be installed into it.
    # "booted" then refers to it, so the specific device does not matter here -
    # whichever one is open in Simulator.app is the target.
    if ! xcrun simctl list devices booted | grep -q "Booted"; then
      echo "No simulator is booted. Starting the default one..."
      open -a Simulator
      echo "Waiting for it to finish booting..."
      xcrun simctl bootstatus booted -b
    fi

    echo "== Installing =="
    xcrun simctl install booted "$APP_BUNDLE"

    echo "== Launching (no debugger) =="
    xcrun simctl launch booted "$BUNDLE_ID"
    ;;

  maccatalyst)
    FRAMEWORK="net10.0-maccatalyst"
    RID="maccatalyst-arm64"

    echo "== Building for Mac Catalyst ($CONFIGURATION) =="
    dotnet build "$PROJECT" -c "$CONFIGURATION" -f "$FRAMEWORK" -r "$RID"

    APP_BUNDLE="$(find_app_bundle "$APP_DIR/bin/$CONFIGURATION/$FRAMEWORK/$RID")"

    echo "== Launching (no debugger) =="
    open "$APP_BUNDLE"
    ;;

  linux)
    FRAMEWORK="net10.0"

    echo "== Building for Linux ($CONFIGURATION) =="
    dotnet build "$PROJECT" -c "$CONFIGURATION" -f "$FRAMEWORK"

    # A plain executable, no bundle: bin/<config>/net10.0/<Name>, beside the
    # Swift libraries the build copied there.
    EXECUTABLE="$APP_DIR/bin/$CONFIGURATION/$FRAMEWORK/$APP_NAME"
    if [[ ! -x "$EXECUTABLE" ]]; then
      echo "ERROR: $EXECUTABLE was not built."
      exit 1
    fi

    echo "== Launching (no debugger) =="
    # Detached, with the output kept where a hang can be read back.
    LOG="${TMPDIR:-/tmp}/stateui-run.log"
    nohup "$EXECUTABLE" >"$LOG" 2>&1 &
    echo "   output: $LOG"
    ;;

  *)
    echo "ERROR: unknown platform '$PLATFORM' (expected: ios, maccatalyst, linux)"
    exit 1
    ;;
esac

# Wait for the process to actually exist before returning, so the debug session
# that follows has something to attach to. Polling rather than a fixed sleep: a
# cold build and a warm one differ by more than any single constant would cover.
echo "Waiting for $APP_NAME to start..."
elapsed=0
while [[ $elapsed -lt 60 ]]; do
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "Running (PID $(pgrep -x "$APP_NAME" | head -n 1)) after ${elapsed}s."
    # A moment to get past startup before a debugger stops the process.
    sleep 1
    exit 0
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

echo "ERROR: $APP_NAME did not start within 60s."
exit 1
