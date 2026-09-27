# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# What the UIKit scripts beside this one share: the simulator's SDK, a build
# for it, an application bundle assembled around a build's binary, and the
# simulator a run goes to. Sourced, never run.

UIKIT_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
UIKIT_PLATFORM="$(xcrun --sdk iphonesimulator --show-sdk-platform-path)"
UIKIT_TRIPLE="arm64-apple-ios26.0-simulator"
UIKIT_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# uikit_build <package-dir> <scratch> <configuration> <product> [swift build arguments...]
# Builds <product> for the simulator; prints the directory its binaries are in.
# A failed build fails the call: a caller's command substitution runs without
# `set -e`, and would go on to the binary an earlier build left.
uikit_build () {
  local package="$1" scratch="$2" configuration="$3" product="$4"
  shift 4
  local build=(xcrun swift build --package-path "$package" --scratch-path "$scratch" --configuration "$configuration"
    --triple "$UIKIT_TRIPLE" --sdk "$UIKIT_SDK" "$@")
  "${build[@]}" --product "$product" >&2 || { echo "ERROR: the build of $product failed" >&2; return 1; }
  "${build[@]}" --show-bin-path
}

# uikit_bundle <binary-dir> <product> <name> <identifier> <images-dir or ""> <bundle> <tools-dir>
# Assembles <bundle>: the binary, the StateUI libraries beside it, the pictures
# with each SVG drawn three times over, an Info.plist whose scenes are many, all
# signed ad hoc.
uikit_bundle () {
  local binary_dir="$1" product="$2" name="$3" identifier="$4" images="$5" bundle="$6" tools="$7"
  rm -rf "$bundle"
  mkdir -p "$bundle/Images"
  cp "$binary_dir/$product" "$bundle/$product"
  cp "$binary_dir"/*.dylib "$bundle/"
  install_name_tool -add_rpath @executable_path "$bundle/$product" 2>/dev/null || true

  local rasterizer="$tools/rasterize-images"
  if [[ ! -x "$rasterizer" || "$UIKIT_TOOLS_DIR/../rasterize-images.swift" -nt "$rasterizer" ]]; then
    mkdir -p "$tools"
    xcrun swiftc -O "$UIKIT_TOOLS_DIR/../rasterize-images.swift" -o "$rasterizer" >&2
  fi
  [[ -z "$images" || ! -d "$images" ]] || "$rasterizer" "$images" "$bundle/Images" >&2

  local plist="$bundle/Info.plist"
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
  plutil -insert UISupportedInterfaceOrientations -array "$plist"
  local orientation
  for orientation in UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft \
    UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortraitUpsideDown; do
    plutil -insert UISupportedInterfaceOrientations -string "$orientation" -append "$plist"
  done

  codesign --force --sign - "$bundle"/*.dylib >/dev/null 2>&1
  codesign --force --sign - "$bundle" >/dev/null 2>&1
}

# uikit_simulator <name, UDID or "">
# Prints the UDID of the simulator named, on the newest runtime that has one;
# where none is named, the one booted, else an iPhone. Boots it and brings the
# Simulator in front.
uikit_simulator () {
  local device
  device="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
wanted = sys.argv[1]
version = lambda runtime: [int(part) for part in re.findall(r"\d+", runtime.split(".")[-1])]
devices = sorted(
    ((version(runtime), d) for runtime, listed in json.load(sys.stdin)["devices"].items()
     if "iOS" in runtime for d in listed),
    key=lambda pair: pair[0])
devices = [d for _, d in devices]
pick = [d for d in devices if wanted and wanted in (d["name"], d["udid"])] \
    or [d for d in devices if not wanted and d["state"] == "Booted"] \
    or [d for d in devices if not wanted and d["name"].startswith("iPhone")]
print(pick[-1]["udid"] if pick else "")
' "$1")"
  [[ -n "$device" ]] || { echo "ERROR: no simulator ${1:-at all}" >&2; return 1; }
  xcrun simctl boot "$device" 2>/dev/null || true
  open -a Simulator --args -CurrentDeviceUDID "$device" 2>/dev/null || true
  echo "$device"
}
