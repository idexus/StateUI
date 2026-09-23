#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/../.." && pwd)"
gallery_dir="$repository_dir/apps/Gallery"
configuration="${1:-debug}"
product="GalleryAppKit"
# On a build directory of its own: an AppKit build compiles the application
# under `#if APPKIT`, and the Gallery's tests, compiled without it, would
# otherwise rebuild from scratch at every switch.
scratch_dir="$gallery_dir/.build-appkit"

# THE ONE THING THAT MAKES THIS AN APPKIT BUILD. The manifest reads it and then
# declares the AppKit head - the target, its product and the StateUIAppKit
# dependency - and defines APPKIT for every module of the application. A
# manifest cannot read a compiler flag, so it is told this way, and no flag is
# given beside it. See apps/Gallery/Package.swift.
export STATEUI_APPKIT=1

swift build \
    --package-path "$gallery_dir" \
    --scratch-path "$scratch_dir" \
    --disable-build-manifest-caching \
    --configuration "$configuration" \
    --product "$product"

binary_dir="$(swift build \
    --package-path "$gallery_dir" \
    --scratch-path "$scratch_dir" \
    --disable-build-manifest-caching \
    --configuration "$configuration" \
    --show-bin-path)"
application_dir="$scratch_dir/$configuration/$product.app"
contents_dir="$application_dir/Contents"
executable_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

rm -rf "$application_dir"
mkdir -p "$executable_dir" "$resources_dir/Images"

cp "$binary_dir/$product" "$executable_dir/$product"
cp "$binary_dir/libStateUI.dylib" "$executable_dir/libStateUI.dylib"
cp "$binary_dir/libStateUIAppKit.dylib" "$executable_dir/libStateUIAppKit.dylib"
cp -R "$gallery_dir/Resources/Images/." "$resources_dir/Images"

icon_work="$(mktemp -d)"
trap 'rm -rf "$icon_work"' EXIT
iconset="$icon_work/StateUI.iconset"
mkdir -p "$iconset"
# The artwork already on macOS's icon grid - drawn edge to edge, the icon
# would stand larger in the Dock than every one beside it.
source_icon="$gallery_dir/Resources/AppIcon/appicon_macos.svg"

sips -s format png -z 16 16 "$source_icon" --out "$iconset/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$source_icon" --out "$iconset/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$source_icon" --out "$iconset/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$source_icon" --out "$iconset/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$source_icon" --out "$iconset/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$source_icon" --out "$iconset/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$source_icon" --out "$iconset/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$source_icon" --out "$iconset/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$source_icon" --out "$iconset/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$source_icon" --out "$iconset/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$iconset" -o "$resources_dir/StateUI.icns"

plist="$contents_dir/Info.plist"
plutil -create xml1 "$plist"
plutil -insert CFBundleDevelopmentRegion -string en "$plist"
plutil -insert CFBundleDisplayName -string "StateUI Gallery" "$plist"
plutil -insert CFBundleExecutable -string "$product" "$plist"
plutil -insert CFBundleIconFile -string StateUI "$plist"
plutil -insert CFBundleIdentifier -string com.stateui.gallery "$plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$plist"
plutil -insert CFBundleName -string "StateUI Gallery" "$plist"
plutil -insert CFBundlePackageType -string APPL "$plist"
plutil -insert CFBundleShortVersionString -string 0.4.0 "$plist"
plutil -insert CFBundleVersion -string 1 "$plist"
plutil -insert LSMinimumSystemVersion -string 14.0 "$plist"
plutil -insert NSHighResolutionCapable -bool true "$plist"

codesign --force --deep --sign - "$application_dir"

echo "$application_dir"
