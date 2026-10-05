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
# Creates a new StateUI application in apps/: one page with a counter, and a
# head for every host.
#
# USAGE:
#   ./new-app.sh Name [apps-dir]
#
#     Name      letters and digits, starting with a letter. Becomes the
#               directory, the process name and the Swift module (NameUI).
#     apps-dir  where to create the application. Defaults to <repo>/apps.
#               Tests pass a temporary directory here.
#
# WHAT IT MAKES is apps/HelloWorld under another name - the worked example of
# the layout every application in apps/ has:
#
#     Package.swift         the application's Swift module, its tests and the
#                           heads Swift builds
#     Sources/              the application, its page, and Styles/
#     Tests/                an example test of the application's own logic
#     Resources/            the artwork
#     Platforms/AppKit/     the macOS head
#     Platforms/UIKit/      the iOS and iPadOS head, run on a simulator
#     Platforms/Android/    the Android Views head: its Gradle build and Swift/
#     Platforms/WinUI/      the WinUI 3 head, built on Windows
#     Platforms/GTK/        the GTK 4 head, built on Linux
#     Platforms/Web/        the Web head, a WebAssembly module in a browser's page
#
# HelloWorld is copied rather than kept here a second time, so the two never
# drift; what its builds write is left behind.
#
# Bash 3.2 compatible - macOS ships that version and has not moved since.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODEL="$ROOT_DIR/apps/HelloWorld"

NAME="${1:-}"
APPS_DIR="${2:-$ROOT_DIR/apps}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -n "$NAME" ]] || fail "no application name. Usage: new-app.sh Name"

# Letters and digits, starting with a letter: the name becomes a Swift
# module, a process name, a package identifier and a directory, and the
# strictest of those wins. No dots in particular - macOS Finder treats a directory named
# Something.App as an application bundle.
[[ "$NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] \
  || fail "'$NAME' cannot name an application: letters and digits only, starting with a letter. (No dots - Finder reads Name.App as a bundle.)"

# The library's own name is taken: an app called StateUI builds a StateUI.app
# around a different executable, which reads as if the library were the
# application.
[[ "$NAME" != "StateUI" ]] || fail "'StateUI' is the library. Pick a name of the app's own."

[[ ! -e "$APPS_DIR/$NAME" ]] || fail "$APPS_DIR/$NAME already exists."
[[ -d "$MODEL" ]] || fail "HelloWorld is not at $MODEL - it is what a new application is made from."

APP="$APPS_DIR/$NAME"
LOWER="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"

mkdir -p "$APP/Platforms/Android"
for item in Package.swift Sources Tests Resources Platforms/AppKit Platforms/UIKit Platforms/WinUI Platforms/GTK Platforms/Web; do
  cp -R "$MODEL/$item" "$APP/$item"
done

# The Android head without Gradle's .gradle/, which an editor that opens the
# head writes beside it: the glob leaves every dot-directory out.
for item in "$MODEL"/Platforms/Android/*; do
  cp -R "$item" "$APP/Platforms/Android/"
done

# And whatever Finder left behind.
find "$APP" -name .DS_Store -delete

# The rename, in names and then in contents: the model's name is a plain token
# wherever it appears, and the application identifier carries it lowercased.
# perl rather than sed -i, whose in-place flag disagrees between BSD and GNU.
find "$APP" -depth -name '*HelloWorld*' | while IFS= read -r path; do
  mv "$path" "$(dirname "$path")/$(basename "$path" | sed "s/HelloWorld/$NAME/g")"
done

find "$APP" -type f \( -name "*.swift" -o -name "*.xml" -o -name "*.kts" \) \
  -exec perl -pi -e "s/HelloWorld/$NAME/g; s/helloworld/$LOWER/g" {} +

cat <<DONE
Created $APP

Next, from the repository root:
  STATEUI_HOST=appkit swift run --package-path apps/$NAME --scratch-path apps/$NAME/.build/appkit ${NAME}AppKit   # the AppKit head
  .scripts/UIKit/run-app.sh apps/$NAME                                      # the UIKit head, on a simulator
  .scripts/Android/run-app.sh apps/$NAME                                    # the Android head
  .scripts\\WinUI\\run-app.ps1 -App apps\\$NAME                                # the WinUI head, on Windows
  .scripts/GTK/run-app.sh apps/$NAME                                        # the GTK head, on Linux
  .scripts/Web/run-app.sh apps/$NAME                                        # the Web head, in a browser
DONE
