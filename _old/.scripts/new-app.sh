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
# Creates a new StateUI application in apps/ - roughly what "dotnet new maui"
# gives a C# app: a buildable project showing one page with a counter.
#
# USAGE:
#   ./new-app.sh Name [apps-dir]
#
#     Name      letters and digits, starting with a letter. Becomes the
#               directory, the .csproj, the process name and the Swift module
#               (NameUI).
#     apps-dir  where to create the project. Defaults to <repo>/apps. Tests
#               pass a temporary directory here; only the default location
#               also registers the project in StateUI.slnx.
#
# WHAT IT MAKES - the layout every app in apps/ has, and apps/HelloWorld is the
# worked example of:
#
#     <Name>.csproj
#     Host/            the C# side: App.cs and MauiProgram.cs, and nothing else
#     Platforms/       the platform heads
#     Resources/       the artwork MAUI rasterizes
#     Swift/           the app, its pages, and Styles/ for its look
#       <Name>App.swift
#       MainPage.swift
#       Styles/AppStyles.swift
#
# WHERE THE FILES COME FROM: the project file, the platform heads, Host/ and the
# artwork (AppIcon, Splash, the logo mark) are the gallery's, renamed throughout
# - so there is no second copy of that boilerplate to keep in step. The Swift
# files come from .scripts/new-app-template/. What is NOT copied is what makes
# the gallery the gallery: its samples, its catalog and their artwork.
#
# Bash 3.2 compatible - macOS ships that version and has not moved since.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GALLERY="$ROOT_DIR/apps/Gallery"
TEMPLATES="$SCRIPT_DIR/new-app-template"

NAME="${1:-}"
APPS_DIR="${2:-$ROOT_DIR/apps}"

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ -n "$NAME" ]] || fail "no project name. Usage: new-app.sh Name"

# Letters and digits, starting with a letter: the name becomes a C# namespace,
# a Swift module, a process name and a directory, and the strictest of those
# wins. No dots in particular - macOS Finder treats a directory named
# Something.App as an application bundle.
[[ "$NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] \
  || fail "'$NAME' cannot name a project: letters and digits only, starting with a letter. (No dots - Finder reads Name.App as a bundle.)"

# The library's own name is taken: an app called StateUI builds a
# StateUI.app around a different executable, which reads as if the library
# were the application - and it broke run-app.sh once already.
[[ "$NAME" != "StateUI" ]] \
  || fail "'StateUI' is the library. Pick a name of the app's own."

[[ ! -e "$APPS_DIR/$NAME" ]] || fail "$APPS_DIR/$NAME already exists."

[[ -d "$GALLERY" ]] || fail "the gallery is not at $GALLERY - it is where the project file, Host/ and the artwork come from."

for template in App MainPage AppStyles; do
  [[ -f "$TEMPLATES/$template.swift.template" ]] \
    || fail "the $template template is not at $TEMPLATES/$template.swift.template."
done

APP="$APPS_DIR/$NAME"
LOWER="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"

# An explicit list, not a copy of the whole directory - see the header.
mkdir -p "$APP/Resources/Images"
cp -R "$GALLERY/Host" "$APP/Host"
cp -R "$GALLERY/Platforms" "$APP/Platforms"
cp -R "$GALLERY/Properties" "$APP/Properties"
cp -R "$GALLERY/Resources/AppIcon" "$APP/Resources/AppIcon"
cp -R "$GALLERY/Resources/Splash" "$APP/Resources/Splash"
cp "$GALLERY/Resources/Images/stateui_mark.svg" "$APP/Resources/Images/stateui_mark.svg"
cp "$GALLERY/Gallery.csproj" "$APP/$NAME.csproj"

# The app's own Swift module: the gallery's manifest - which carries the path
# to the library and the settings an application must not lose - the
# application, its one page, and the styles under Styles/. The manifest
# compiles Swift/ whole (path: "Swift"), so nothing here is listed anywhere.
mkdir -p "$APP/Swift/Styles"
# The manifest sits beside the .csproj, so SwiftPM's .build/ lands where
# bin/ and obj/ do and Swift/ stays nothing but source.
cp "$GALLERY/Package.swift" "$APP/Package.swift"
cp "$TEMPLATES/App.swift.template" "$APP/Swift/${NAME}App.swift"
cp "$TEMPLATES/MainPage.swift.template" "$APP/Swift/MainPage.swift"
cp "$TEMPLATES/AppStyles.swift.template" "$APP/Swift/Styles/AppStyles.swift"

# The page's artwork: the mark on its gradient as ONE image, so the page needs
# no drawing code. It is drawn big, so it gets a BaseSize of its own beside the
# mark's - the wildcard's 24x24 would rasterize it blurry.
cp "$SCRIPT_DIR/new-app-template/stateui_tile.svg" "$APP/Resources/Images/stateui_tile.svg"
perl -pi -e 's{([ \t]*)(<MauiImage Update="Resources/Images/stateui_mark\.svg"[^\n]*/>)}{$1$2\n$1<MauiImage Update="Resources/Images/stateui_tile.svg" BaseSize="128,128" />}' "$APP/$NAME.csproj"

# The rename. The gallery's name is a plain token wherever it appears, the
# ApplicationId carries it lowercased, and the template says __NAME__. perl
# rather than sed -i, whose in-place flag disagrees between BSD and GNU.
find "$APP" -type f \
  \( -name "*.cs" -o -name "*.csproj" -o -name "*.plist" -o -name "*.xml" \
     -o -name "*.json" -o -name "*.xaml" -o -name "*.manifest" -o -name "*.swift" \) \
  -exec perl -pi -e "s/Gallery/$NAME/g; s/gallery/$LOWER/g; s/__NAME__/$NAME/g" {} +

# The title is SET rather than renamed, because it is the one property whose
# value need not be the project name. The token pass above gets it right only
# while the source project is titled after itself; setting it outright is what
# makes every app scaffolded here carry its OWN name into its bundle and its
# window, whatever the source happens to be called.
perl -pi -e "s|<ApplicationTitle>[^<]*</ApplicationTitle>|<ApplicationTitle>$NAME</ApplicationTitle>|" "$APP/$NAME.csproj"

# Into the solution, so the IDE sees it - only when creating in the real apps/,
# never from a test's temporary directory, and never twice.
SLNX="$ROOT_DIR/StateUI.slnx"
if [[ "$APPS_DIR" == "$ROOT_DIR/apps" && -f "$SLNX" ]] && ! grep -q "apps/$NAME/$NAME.csproj" "$SLNX"; then
  perl -pi -e "s|</Solution>|  <Project Path=\"apps/$NAME/$NAME.csproj\" />\n</Solution>|" "$SLNX"
  echo "Registered in StateUI.slnx."
fi

cat <<DONE
Created $APP

Next:
  cd "$APP"
  dotnet build -c Debug -f net10.0-maccatalyst    # or net10.0-ios / net10.0-android / net10.0-windows10.0.19041.0
DONE
