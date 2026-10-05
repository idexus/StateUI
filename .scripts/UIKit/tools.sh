# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# What the UIKit scripts beside this one share: what a build is for - a
# simulator or a device - a build for it, an application bundle assembled
# around a build's binary, and where a run goes. Sourced, never run.

UIKIT_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# uikit_target <iphonesimulator|iphoneos>
# What a build is for - the simulator, or a device: its SDK, the SDK's
# platform and the triple. The simulator's is set as this file is sourced.
uikit_target () {
  UIKIT_SDK_NAME="$1"
  UIKIT_SDK="$(xcrun --sdk "$1" --show-sdk-path)"
  UIKIT_PLATFORM="$(xcrun --sdk "$1" --show-sdk-platform-path)"
  UIKIT_TRIPLE="arm64-apple-ios26.0"
  [[ "$1" == iphoneos ]] || UIKIT_TRIPLE+="-simulator"
}
uikit_target iphonesimulator

# uikit_build <package-dir> <scratch> <configuration> <product> [swift build arguments...]
# Builds <product> for the target set; prints the directory its binaries are in.
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

# uikit_bundle <binary-dir> <product> <name> <identifier> <resources-dir or ""> <bundle> <tools-dir>
#              <own-info-plist or ""> [device-udid]
# Assembles <bundle> for the target set: the binary, the StateUI libraries in
# Frameworks/, the pictures of <resources-dir>/Images with each SVG drawn
# three times over, the icon drawn from <resources-dir>/AppIcon, an Info.plist
# whose scenes are many, joined by the application's own keys - theirs where
# both say one. For the simulator it is signed ad hoc; for a device, with the
# development certificate and profile that let it run on the device
# <device-udid>.
uikit_bundle () {
  local binary_dir="$1" product="$2" name="$3" identifier="$4" resources="$5" bundle="$6" tools="$7"
  local own="$8" device="${9:-}"
  rm -rf "$bundle"
  mkdir -p "$bundle/Images" "$bundle/Frameworks" "$tools"
  cp "$binary_dir/$product" "$bundle/$product"
  cp "$binary_dir"/*.dylib "$bundle/Frameworks/"
  install_name_tool -add_rpath @executable_path/Frameworks "$bundle/$product" 2>/dev/null || true

  local rasterizer="$tools/rasterize-images"
  if [[ ! -x "$rasterizer" || "$UIKIT_TOOLS_DIR/../rasterize-images.swift" -nt "$rasterizer" ]]; then
    xcrun swiftc -O "$UIKIT_TOOLS_DIR/../rasterize-images.swift" -o "$rasterizer" >&2
  fi
  [[ -z "$resources" || ! -d "$resources/Images" ]] || "$rasterizer" "$resources/Images" "$bundle/Images" >&2

  local plist="$bundle/Info.plist"
  local platform=iPhoneSimulator
  [[ "$UIKIT_SDK_NAME" == iphoneos ]] && platform=iPhoneOS
  plutil -create xml1 "$plist"
  plutil -insert CFBundleDevelopmentRegion -string en "$plist"
  plutil -insert CFBundleDisplayName -string "$name" "$plist"
  plutil -insert CFBundleExecutable -string "$product" "$plist"
  plutil -insert CFBundleIdentifier -string "$identifier" "$plist"
  plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$plist"
  plutil -insert CFBundleName -string "$name" "$plist"
  plutil -insert CFBundlePackageType -string APPL "$plist"
  plutil -insert CFBundleShortVersionString -string 0.5.1 "$plist"
  plutil -insert CFBundleVersion -string 1 "$plist"
  plutil -insert CFBundleSupportedPlatforms -array "$plist"
  plutil -insert CFBundleSupportedPlatforms.0 -string "$platform" "$plist"
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

  if [[ -n "$own" && -f "$own" ]]; then
    python3 - "$own" "$plist" <<'MERGE' || { echo "ERROR: $own is no property list" >&2; return 1; }
import plistlib, sys
own, target = sys.argv[1:3]
with open(own, "rb") as file: keys = plistlib.load(file)
with open(target, "rb") as file: merged = plistlib.load(file)
merged.update(keys)
with open(target, "wb") as file: plistlib.dump(merged, file)
MERGE
  fi

  if [[ -n "$resources" && -f "$resources/AppIcon/appicon_bkg.svg" && -f "$resources/AppIcon/appicon_mark.svg" ]]; then
    uikit_icon "$resources/AppIcon" "$bundle" "$tools" || return 1
  fi

  if [[ -z "$device" ]]; then
    codesign --force --sign - "$bundle"/Frameworks/*.dylib >/dev/null 2>&1
    codesign --force --sign - "$bundle" >/dev/null 2>&1
    return 0
  fi
  uikit_sign "$bundle" "$identifier" "$device" "$tools"
}

# uikit_icon <Resources/AppIcon> <bundle> <tools-dir>
# The application's icon, drawn by draw-app-icon.swift into an asset catalog
# and compiled into <bundle> by actool, whose icon keys join its Info.plist.
uikit_icon () {
  local artwork="$1" bundle="$2" tools="$3"
  local drawer="$tools/draw-app-icon"
  if [[ ! -x "$drawer" || "$UIKIT_TOOLS_DIR/draw-app-icon.swift" -nt "$drawer" ]]; then
    xcrun swiftc -O "$UIKIT_TOOLS_DIR/draw-app-icon.swift" -o "$drawer" >&2 || return 1
  fi
  "$drawer" "$artwork" "$tools/Assets.xcassets" >&2 || return 1
  xcrun actool "$tools/Assets.xcassets" --compile "$bundle" --platform "$UIKIT_SDK_NAME" \
    --minimum-deployment-target 26.0 --target-device iphone --target-device ipad --app-icon AppIcon \
    --output-partial-info-plist "$tools/icon.plist" --output-format human-readable-text >/dev/null \
    || { echo "ERROR: actool did not compile the icon" >&2; return 1; }
  /usr/libexec/PlistBuddy -c "Merge $tools/icon.plist" "$bundle/Info.plist" >/dev/null
}

# uikit_sign <bundle> <identifier> <device-udid> <tools-dir>
# Signs <bundle> to run on the device <device-udid>: with a development profile
# of this Mac's - one still valid, provisioning that device, whose application
# identifier covers <identifier>, the exact one before a wildcard - and a
# certificate of the keychain's that profile names. The profile goes into the
# bundle and its entitlements, the team's identifier in place of the wildcard,
# into the signature.
uikit_sign () {
  local bundle="$1" identifier="$2" device="$3" tools="$4"
  local chosen
  chosen="$(python3 - "$identifier" "$device" "$tools/entitlements.plist" <<'PICK'
import datetime, glob, hashlib, os, plistlib, re, subprocess, sys
identifier, device, entitlements = sys.argv[1:4]
identities = set(re.findall(r"\b([0-9A-F]{40})\b", subprocess.run(
    ["security", "find-identity", "-v", "-p", "codesigning"], capture_output=True, text=True).stdout))
home = os.path.expanduser("~")
found = []
for path in glob.glob(f"{home}/Library/Developer/Xcode/UserData/Provisioning Profiles/*.mobileprovision") \
        + glob.glob(f"{home}/Library/MobileDevice/Provisioning Profiles/*.mobileprovision"):
    decoded = subprocess.run(["security", "cms", "-D", "-i", path], capture_output=True).stdout
    try:
        profile = plistlib.loads(decoded)
    except Exception:
        continue
    granted = profile.get("Entitlements", {})
    team = (profile.get("TeamIdentifier") or [""])[0]
    pattern = granted.get("application-identifier", "")
    certificates = [hashlib.sha1(c).hexdigest().upper() for c in profile.get("DeveloperCertificates", [])]
    usable = [c for c in certificates if c in identities]
    covers = pattern == f"{team}.{identifier}" or (pattern.endswith("*") and f"{team}.{identifier}".startswith(pattern[:-1]))
    if (granted.get("get-task-allow") and usable and covers and profile["ExpirationDate"] > datetime.datetime.now()
            and (device in profile.get("ProvisionedDevices", []) or profile.get("ProvisionsAllDevices"))):
        found.append((not pattern.endswith("*"), profile["ExpirationDate"], path, usable[0], team, granted))
if not found:
    sys.exit(f"no development profile of this Mac lets {identifier} run on {device} - make one in Xcode, "
             "for this device and a certificate in the keychain")
exact, _, path, identity, team, granted = max(found, key=lambda each: each[:2])
signed = dict(granted)
signed["application-identifier"] = f"{team}.{identifier}"
with open(entitlements, "wb") as file:
    plistlib.dump(signed, file)
print(path)
print(identity)
PICK
)" || { echo "ERROR: the bundle cannot be signed for the device" >&2; return 1; }
  local profile identity
  profile="$(sed -n 1p <<< "$chosen")"
  identity="$(sed -n 2p <<< "$chosen")"
  cp "$profile" "$bundle/embedded.mobileprovision"
  codesign --force --sign "$identity" --timestamp=none "$bundle"/Frameworks/*.dylib >/dev/null \
    || { echo "ERROR: the libraries could not be signed" >&2; return 1; }
  codesign --force --sign "$identity" --timestamp=none --entitlements "$tools/entitlements.plist" "$bundle" >/dev/null \
    || { echo "ERROR: the bundle could not be signed" >&2; return 1; }
}

# uikit_destination <name, identifier or "">
# Where a run goes, as "simulator <udid>" or "device <identifier> <udid>": a
# device of this Mac's by its name, devicectl's identifier or its UDID; else a
# simulator by its name or UDID, on the newest runtime that has one; where none
# is named, the simulator booted, else an iPhone. A simulator is booted and
# the Simulator brought in front.
uikit_destination () {
  local wanted="$1" listed
  listed="$(mktemp)"
  if [[ -n "$wanted" ]] && xcrun devicectl list devices --json-output "$listed" >/dev/null 2>&1; then
    local device
    device="$(python3 - "$wanted" "$listed" <<'FIND'
import json, sys
wanted, listed = sys.argv[1:3]
for each in json.load(open(listed))["result"]["devices"]:
    hardware = each.get("hardwareProperties", {})
    if hardware.get("reality") != "physical" or hardware.get("platform") != "iOS":
        continue
    if wanted in (each.get("identifier"), hardware.get("udid"), each.get("deviceProperties", {}).get("name")):
        print(each["identifier"], hardware["udid"])
        break
FIND
)"
    rm -f "$listed"
    [[ -z "$device" ]] || { echo "device $device"; return 0; }
  fi
  rm -f "$listed"
  local simulator
  simulator="$(uikit_simulator "$wanted")" || return 1
  echo "simulator $simulator"
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
  [[ -n "$device" ]] || { echo "ERROR: no simulator or device ${1:-at all}" >&2; return 1; }
  xcrun simctl boot "$device" 2>/dev/null || true
  open -a Simulator --args -CurrentDeviceUDID "$device" 2>/dev/null || true
  echo "$device"
}
