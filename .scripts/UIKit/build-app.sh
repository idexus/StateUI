#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Builds an application's UIKit head for the iOS simulator and makes it an
# application bundle: the executable, the Swift libraries beside it, the
# pictures drawn for a toolkit that draws no SVG, an Info.plist whose scenes
# are many - an iPad's windows - and an ad-hoc signature. Prints the bundle.
#
# USAGE:
#   build-app.sh <app-dir> [debug|release]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "${1:?the directory of an application}" && pwd)"
configuration="${2:-debug}"
name="$(basename "$app_dir")"
product="${name}UIKit"
scratch="$app_dir/.build-uikit"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
triple="arm64-apple-ios26.0-simulator"

export STATEUI_UIKIT=1
build=(xcrun swift build --package-path "$app_dir" --scratch-path "$scratch" --configuration "$configuration"
  --triple "$triple" --sdk "$sdk")
"${build[@]}" --product "$product" >&2
binary_dir="$("${build[@]}" --show-bin-path)"

bundle="$scratch/$configuration/$product.app"
rm -rf "$bundle"
mkdir -p "$bundle/Images"
cp "$binary_dir/$product" "$bundle/$product"
cp "$binary_dir"/*.dylib "$bundle/"
install_name_tool -add_rpath @executable_path "$bundle/$product" 2>/dev/null || true

# The pictures, SVGs drawn three times over, as the Android head's are.
rasterizer="$scratch/tools/rasterize-images"
if [[ ! -x "$rasterizer" || "$script_dir/../rasterize-images.swift" -nt "$rasterizer" ]]; then
  mkdir -p "$scratch/tools"
  xcrun swiftc -O "$script_dir/../rasterize-images.swift" -o "$rasterizer" >&2
fi
[[ -d "$app_dir/Resources/Images" ]] && "$rasterizer" "$app_dir/Resources/Images" "$bundle/Images" >&2

plist="$bundle/Info.plist"
identifier="com.stateui.$(tr '[:upper:]' '[:lower:]' <<< "$name")"
plutil -create xml1 "$plist"
plutil -insert CFBundleDevelopmentRegion -string en "$plist"
plutil -insert CFBundleDisplayName -string "$name" "$plist"
plutil -insert CFBundleExecutable -string "$product" "$plist"
plutil -insert CFBundleIdentifier -string "$identifier" "$plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$plist"
plutil -insert CFBundleName -string "$name" "$plist"
plutil -insert CFBundlePackageType -string APPL "$plist"
plutil -insert CFBundleShortVersionString -string 0.4.0 "$plist"
plutil -insert CFBundleVersion -string 1 "$plist"
plutil -insert CFBundleSupportedPlatforms -array "$plist"
plutil -insert CFBundleSupportedPlatforms.0 -string iPhoneSimulator "$plist"
plutil -insert MinimumOSVersion -string 26.0 "$plist"
plutil -insert LSRequiresIPhoneOS -bool true "$plist"
plutil -insert UIDeviceFamily -array "$plist"
plutil -insert UIDeviceFamily.0 -integer 1 "$plist"
plutil -insert UIDeviceFamily.1 -integer 2 "$plist"
plutil -insert UILaunchScreen -dictionary "$plist"
plutil -insert UIApplicationSceneManifest -dictionary "$plist"
plutil -insert UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes -bool true "$plist"
for orientation in UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortraitUpsideDown; do
  plutil -insert UISupportedInterfaceOrientations -array "$plist" 2>/dev/null || true
  plutil -insert UISupportedInterfaceOrientations -string "$orientation" -append "$plist"
done

codesign --force --sign - "$bundle"/*.dylib >/dev/null 2>&1
codesign --force --sign - "$bundle" >/dev/null 2>&1
echo "$bundle"
