# Destinations

A destination is where a head runs. An AppKit, WinUI or GTK head runs on the
machine that built it - from a Mac a GTK or WinUI head in a virtual machine
of its system ([Guests](guests.md)); a UIKit head runs on an iPhone or iPad
simulator, or on a real iPhone or iPad paired with the Mac.

## Where a host's heads run

The tool says which hosts a machine builds, and where each one's heads run
(`HostPlaces`), in one list every client reads - `server/info`'s `hosts`, which
`stateui version` prints - so an editor, a generated project and the terminal
are told the same and none keeps a table of its own: on a Mac AppKit on the
machine itself, UIKit and Android on a device, WinUI and GTK in a guest, the
Web in a browser; on Linux GTK on the machine and the Web in a browser; on
Windows WinUI on the machine. `devices/list` answers by that place, and whether
a host's work goes to a guest is read from it.

A machine paired with the project ([Pairing](service.md#pairing)) adds the
hosts whose heads run there as its own programs - AppKit on a Mac, WinUI on
Windows, GTK on Linux - as its service said them: a host this machine builds
not stands in `hosts` at `remote`, and `devices/list` lists each such machine
after the destinations of the host's own place (`remote`), a guest paired
listed once, as a guest. Its devices, browsers and guests are reached on that
machine itself. `server/info` says the folder another machine's projects are
copied into there (`workFolder`).

Each destination says what a client needs to offer it: whether a debugger
reaches an application run there (`debugger`) - not in a guest, nor in a
browser not of Chromium's, whose pages no debugger follows - and the
architectures it runs emulated beside its own (`emulated`), which a head can
be built for too: x86_64 on an ARM64 Windows, a machine or a guest.

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
the machine itself has one destination, the machine (`machine`), with its
architecture; a host the machine builds no heads of is refused.

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

## Browsers

A Web head's page opens in a browser. `stateui devices --host web` lists
what the system opens both a web address and a web page with: on macOS every
application Launch Services offers for `https` and for an HTML file, by its
bundle id; on Linux every desktop entry taking `x-scheme-handler/https` and
`text/html` and shown on the desktop running - `NoDisplay`, `Hidden`,
`OnlyShowIn` and `NotShowIn` read as the desktop does - by its file's name.
The system's own is marked, and each names its program (`programUri`): the
bundle's executable, the entry's `Exec` past `env` and its variables. A
browser of Chromium's - Chrome, Chromium, Edge, Brave, Vivaldi, Opera, Arc,
told by its id - with its program found is one a debugger follows. A run
opens the page in the one it names, the system's own where it names none, and
no browser for `none` - the page left to a debugger, which starts a browser's
program on it.

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
