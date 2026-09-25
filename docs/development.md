# Project structure and development

## Repository layout

```text
Package.swift                      StateUI core package and core tests
lib/StateUI/Sources/               platform-neutral StateUI
lib/StateUI/Tests/                 core tests and shared test support
lib/StateUI.AppKit/                independent AppKit host package and tests
lib/StateUI.Android/               Android Views host package, its Java layer and tests
lib/StateUI.WinUI/                 WinUI host package, its C++/WinRT relay and tests
lib/StateUI.GTK/                   GTK host package, Swift over GTK's C API, and tests
lib/StateUI.VSCode/                the editor extension
.scripts/AppKit/                   AppKit Gallery bundling
.scripts/Android/                  Android Views builds, runs, devices and tests
.scripts/WinUI/                    WinUI builds, runs and tests, and the Windows App SDK
.scripts/GTK/                      GTK builds and runs
apps/Gallery/Sources/              platform-neutral Gallery application
apps/Gallery/Platforms/AppKit/     Gallery AppKit entry point
apps/Gallery/Platforms/Android/    Gallery Android head
apps/Gallery/Tests/                Gallery acceptance tests
apps/HelloWorld/Sources/           small platform-neutral example application
apps/HelloWorld/Platforms/AppKit/  HelloWorld AppKit entry point
apps/HelloWorld/Platforms/Android/ HelloWorld Android head
apps/HelloWorld/Platforms/WinUI/   HelloWorld WinUI head
apps/HelloWorld/Platforms/GTK/     HelloWorld GTK head
```

The core never imports Foundation or a platform UI framework. Application code
may import Foundation. Platform frameworks remain inside host packages and
platform entry points.

Swift written for one host alone stands under the condition named for it:
`#if APPKIT`, which every AppKit build of an application defines through its
manifest, and `#if ANDROID`, which every Android Views build of an application
defines the same way, from `STATEUI_ANDROID=1`. `NativeProjectTests` refuses
any other mention of a host in the library and in the applications'
`Sources/`.

`STATEUI_APPKIT=1` is what makes a build an AppKit one. An application's
manifest reads it and then declares the `Platforms/AppKit` target, the product
it makes and the `StateUIAppKit` dependency, and defines `APPKIT` for every
module of the application. A manifest cannot read a compiler flag - a flag
reaches the targets of a build, never the manifest describing them - so no
`-Xswiftc -DAPPKIT` is given beside the variable. Without it, `swift test`
resolves no host package and compiles no line of one host's half, and a
`Platforms/AppKit/` folder needs no condition inside it.

`.scripts/AppKit/build-gallery-appkit.sh` and the AppKit tasks set the variable
for a build. The editor gets it from the StateUI extension (`lib/StateUI.VSCode`):
choosing AppKit in its status bar sets the variable for the Swift language
server and restarts it, which then resolves `Platforms/AppKit` and completes the
code inside `#if APPKIT`, with no window reload. A
`swift.swiftEnvironmentVariables` setting naming the variable would override
that choice, so `.vscode/settings.json` sets none.

## Gallery

Gallery is the acceptance surface for the element contracts. Its examples
show behavior directly and keep on-screen prose to a title and, when needed,
one short instruction.

Across the catalog, applicable examples prove:

- a state read rebuilding only its reader;
- a host-carried binding updating without that rebuild;
- `Journey` and host-side motion.

Detailed teaching belongs in the Markdown documentation and public `///`
comments. A sample outside the active contract does not remain in the catalog.

### Adding a sample

A sample is a `SampleContent` under
`apps/Gallery/Sources/Samples/<Group>/`. Register it once in
`apps/Gallery/Sources/Gallery/Catalog.swift`; group pages, navigation, and the
home count derive from that catalog.

Keep the visible example and its `code` listing equivalent. The listing is the
smallest usable expression of the behavior: include state and helpers it names,
but leave Gallery-only decoration out. Give the sample a unique stable id and a
short title. Its summary is one instruction or result, not a second handbook.

A sample that owns vertical scrolling or a continuous drag must own its page
viewport; do not nest it under the page's scroller. Boolean choices are
switches and momentary actions are buttons. Add group artwork only when a new
contract category genuinely needs a group; resources and catalog reachability
are checked by `GalleryTests`.

## Changing the public contract

Treat one control, property, event, or host action as one vertical change:

1. Decide its cross-platform semantic name and ownership.
2. Add or change the public Swift declaration and its `///` documentation.
3. Declare the member in its element's contract - its name, its value's type
   and its layer; its host-SPI token follows from the member.
4. Implement every host claimed by the change, keeping native adapters thin.
5. Add focused core tests and direct native-host tests.
6. Add or update the smallest Gallery demonstration and handbook section.
7. Let the host say what it realizes, only after its tests pass. A member a
   registration takes or raises records itself: with `STATEUI_UPDATE_EXPORTS=1`,
   `swift test --package-path lib/StateUI.AppKit` and
   `.scripts/Android/test-android.sh <serial>` write `exports/appkit.txt` and
   `android.txt`, and the contracts name each member's owner when the
   documents are rendered. What a registry cannot know stays written by hand,
   in `AppKitRealization` and `AndroidRealization` - every judgement: a partial
   record saying what is missing, what a host realizes none of, and what it
   presents with no view of its own.
   Then `STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests`
   writes `docs/controls/` and the tables of `platform-contract.md`.

Removing a capability follows the same path: remove stale vocabulary, host
branches, tests, samples, and documentation together. Do not leave an inert
modifier or compatibility alias unless compatibility is itself an explicit
contract.

## Build

The AppKit host requires macOS 26 or newer and Xcode 27, with its Swift 6.4.

Build the runnable Gallery bundle:

```bash
.scripts/AppKit/build-gallery-appkit.sh debug
```

Build the smaller example:

```bash
STATEUI_APPKIT=1 swift build --package-path apps/HelloWorld --product HelloWorldAppKit
```

In VS Code, the StateUI extension (`lib/StateUI.VSCode`) runs either
application: "StateUI: Debug" and "StateUI: Release" build and start the one
chosen in its status bar, on the host chosen there; installing it is under
[Working in VS Code](getting-started.md#working-in-vs-code). The Gallery's
build assembles its resources, icon, runtime libraries, and ad-hoc signature.

The Android Views host builds on macOS with the swift.org toolchain, the Swift
SDK for Android, the NDK r30 and JDK 21. An application's Android head is
built, installed and started on a device by one script:

```bash
.scripts/Android/run-app.sh apps/HelloWorld debug emulator-5554
```

[Android Views host](android-host.md) lists what it needs and what it builds.

The WinUI host builds on Windows with the swift.org toolchain and Visual
Studio's C++ tools; its script fetches C++/WinRT and the Windows App SDK
itself. An application's WinUI head is built and started by one script:

```powershell
.scripts\WinUI\run-app.ps1 -App apps\HelloWorld
```

[WinUI host](winui-host.md) lists what it needs and what it builds.

The GTK host builds on Linux with the swift.org toolchain, GTK 4 and
libadwaita. An application's GTK head is built and started by one script:

```bash
.scripts/GTK/run-app.sh apps/HelloWorld
```

[GTK host](gtk-host.md) lists what it needs and what it builds.

## Test

Each suite lives beside the package whose behavior it verifies:

```bash
swift test
swift test --package-path lib/StateUI.AppKit
swift test --package-path apps/Gallery
```

`.scripts/test-native.sh` runs the three Swift suites, then the Gallery again as
an AppKit build (`STATEUI_APPKIT=1`), on a build directory of its own:

```bash
.scripts/test-native.sh
```

The first suite covers core semantics and the typed boundary. The second
drives native AppKit objects. The third treats Gallery as application behavior
and compiles the documentation examples. In VS Code, **StateUI: Run Tests**
runs them as the chosen host.

The Android Views host's suite runs on a device, in a test APK:

```bash
.scripts/Android/test-android.sh emulator-5554
```

The WinUI host's suite runs on Windows, the Windows App SDK laid beside its
test runner first:

```powershell
.scripts\WinUI\test-winui.ps1
```

The GTK host's suite runs on Linux, in a desktop session whose display shows
its windows:

```bash
swift test --package-path lib/StateUI.GTK
```

A passing unit suite does not prove native drawing or interaction. Exercise a
user-visible change in the running Gallery on the affected platform. Run only
one application build at a time because Swift build directories are shared by
the package graph.

## What the tests hold

The core's tests assert on the typed patch a host is handed, each by the rule
it keeps - one changed number sends one property of one label, every control
carries only the members its contract declares - rather than comparing it
with a stored copy. A failing assertion names what changed and why it
matters; a deliberate change updates the assertion that states it.

The documentation examples are another executable check. Every exact
`swift` fence in `README.md` and `docs/` is type-checked by Gallery tests.
Mark a deliberately partial declaration or manifest as `swift quote`; keep
copyable application examples as plain `swift` so API drift fails visibly.

## Distribution boundary

The repository-root `Package.swift` is the package boundary for the
platform-neutral `StateUI` product. Native hosts remain sibling packages so a
consumer selects a toolkit without pulling it into the core. The current AppKit
package uses the root checkout as a local dependency; the complete remote
library-plus-host installation path is not published yet. Keep Getting Started
honest about that state until both products have a supported versioned route.

A release has one version, stated in the editor extension's
`lib/StateUI.VSCode/package.json`. Every other place that names it - the
published-package line in each `Package.swift`, each Android head's version,
the Gallery's AppKit bundle, the bug report's example - names the same one, and
`ReleaseTests` holds them to it.
