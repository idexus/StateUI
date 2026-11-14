# Destinations

A destination is where a head runs. An AppKit, WinUI or GTK head runs on the
machine that built it; a UIKit head runs on an iPhone or iPad simulator, or
on a real iPhone or iPad paired with the Mac.

## Listing them

`stateui devices --host uikit` (`devices/list`) lists the real devices first,
as `devicectl list devices` writes them - iOS, paired, of iOS 26.4 or newer,
and not `simulated`, which `devicectl` says of a simulator while it at times
leaves a real device's `reality` unsaid - each with how it is reached, `USB` or `Wi-Fi`; then the
simulators `simctl list devices available` gives, of the iOS runtimes 26.4 or
newer, the newest runtime first and each runtime's in its own order, each
saying whether it is booted. A destination is known by `id` - a device's
`devicectl` identifier, a simulator's UDID - and keeps the hardware's UDID
apart, the one a development profile provisions. A host whose heads run on
the machine itself has no destinations, and asking for them is refused.

## Android

`stateui devices --host android` lists what `adb devices -l` says is attached
and ready - an unauthorized or offline device is not - each with its model,
its Android version and its ABI as StateUI names an architecture
(`arm64-v8a` is `arm64`); a running emulator by its virtual device's name;
then the virtual devices the emulator knows that are not running. A run names
one by its serial or name, a running one before a virtual device of that
name; naming none means the one `ANDROID_SERIAL` names, else the only one
running, and none or several are refused. A virtual device named that is not
running is booted - the emulator started apart from the tool, which it
outlives as a booted simulator does - and waited for until Android says it
booted, four minutes at most.

## The one meant

A run names its destination by any of the three: a device's identifier, UDID
or name first, then a simulator's UDID or name - the newest runtime's where
several share a name. Naming none means the booted simulator, else an
iPhone. A name nothing listed has is refused, and the refusal says how to
list them.

## A destination's SDK

A simulator runs code built for `arm64-apple-ios26.4-simulator` against the
`iphonesimulator` SDK; a device, `arm64-apple-ios26.4` against `iphoneos`.
The SDK's platform, version and folder are part of a build's context
(builds.md), so a simulator's build and a device's are two scratch folders
of one application, and changing the destination never rebuilds the other.
A build uses the tool's one Swift for every Apple platform: the swift.org
toolchain carries the iOS and simulator libraries, and the SDK comes from the
Xcode `xcrun` selects.
