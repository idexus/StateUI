# Project structure and development

## Repository layout

```text
Package.swift                      StateUI's core package, its sources in lib/StateUI/Core
lib/StateUI/Core/Sources/          platform-neutral StateUI
lib/StateUI/Core/Tests/            core tests and shared test support
lib/StateUI/StateUI.Host/          the host layer every host stands on, and its tests
lib/StateUI/StateUI.Conformance/   the conformance suite every host's tests run
lib/StateUI/exports/               what each host's runs declare and prove, the marks
lib/StateUI/StateUI.AppKit/        independent AppKit host package and tests
lib/StateUI/StateUI.UIKit/         UIKit host package, its tests an application of their own
lib/StateUI/StateUI.Android/       Android Views host package, its Java layer and tests
lib/StateUI/StateUI.WinUI/         WinUI host package and its C++/WinRT relay
lib/StateUI/StateUI.WinUI/Testing/ its tests, and the driver its conformance runs go through
lib/StateUI/StateUI.GTK/           GTK host package, Swift over GTK's C API
lib/StateUI/StateUI.GTK/Testing/   its tests, and the driver its conformance runs go through
lib/StateUI/StateUI.Web/           Web host package, Swift for WebAssembly over its JavaScript relay
lib/StateUI/StateUI.Web/Testing/   its tests, and the driver its conformance runs go through
lib/StateUI.Head/                  the package that brings each application's head its host
lib/Backends/                      backends: one element on one host, its engine not shipped - WebView.GTK, WebView.WinUI
lib/StateUI.VSCode/                the editor extension
.scripts/AppKit/                   AppKit Gallery bundling, the host's tests and deploys
.scripts/UIKit/                    UIKit bundles, runs on a simulator or a device, tests and deploys
.scripts/Android/                  Android Views builds, runs, devices, tests and deploys
.scripts/WinUI/                    WinUI builds, runs, tests and deploys, and the Windows App SDK
.scripts/GTK/                      GTK builds, runs, tests and deploys
.scripts/Web/                      Web builds, pages, runs, tests and deploys, and the Swift SDK for WebAssembly
.scripts/Marks/                    the revision a conformance family's verdicts stand at
.scripts/new-app.sh                a new application in apps/ (new-app.ps1 on Windows)
.scripts/test-native.sh            the Swift suites on macOS, the AppKit host's among them
apps/Gallery/Sources/              platform-neutral Gallery application
apps/Gallery/Platforms/AppKit/     Gallery AppKit entry point
apps/Gallery/Platforms/UIKit/      Gallery UIKit head
apps/Gallery/Platforms/Android/    Gallery Android head
apps/Gallery/Platforms/WinUI/      Gallery WinUI head
apps/Gallery/Platforms/GTK/        Gallery GTK head
apps/Gallery/Platforms/Web/        Gallery Web head
apps/Gallery/Tests/                Gallery acceptance tests
apps/HelloWorld/Sources/           small platform-neutral example application
apps/HelloWorld/Tests/             its example test, which every new application starts with
apps/HelloWorld/Platforms/AppKit/  HelloWorld AppKit entry point
apps/HelloWorld/Platforms/UIKit/   HelloWorld UIKit head
apps/HelloWorld/Platforms/Android/ HelloWorld Android head
apps/HelloWorld/Platforms/WinUI/   HelloWorld WinUI head
apps/HelloWorld/Platforms/GTK/     HelloWorld GTK head
apps/HelloWorld/Platforms/Web/     HelloWorld Web head
```

The core and the host layer never import Foundation or a platform UI
framework. Application code may import Foundation. Platform frameworks remain inside host packages and
platform entry points.

Swift written for one host alone stands under the condition named for it:
`#if APPKIT`, `#if UIKIT`, `#if ANDROID`, `#if WINUI`, `#if GTK` and
`#if WEB`, which every build of an application for that host defines through
its manifest, from the one variable a build names its host by:
`STATEUI_HOST=appkit`, `uikit`, `android`, `winui`, `gtk` or `web`. One
variable holds one host, so no build is two hosts' at once.
`NativeProjectTests` refuses a mention of AppKit, WinUI or GTK outside its
condition in the core's and the applications' `Sources/`.

`STATEUI_HOST=appkit` is what makes a build an AppKit one. An application's
manifest reads it, declares its `Platforms/AppKit` head and defines `APPKIT`
for every module of the application. The head depends on
`lib/StateUI.Head`, whose manifest reads the same variable once for every
application and brings the `StateUIAppKit` host; an application names no host
package itself. A manifest cannot read a compiler flag - a flag reaches the
targets of a build, never the manifest describing them - so no
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

A sample's listing is cut from its running code by `// listing: <name>` …
`// listing: end`; decoration is left out unless `// listing: keep`. Once its
notes and the comments in its listings are read against the code,
`STATEUI_UPDATE_SAMPLES=1 swift test --package-path apps/Gallery --filter
'SampleListingsTests|SampleReviewTests'` writes `Listings.swift` and records
the review; nobody edits either. Give the sample a unique stable id and a
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
4. Decide what of it every host shares and write that part in the host layer
   first, with its pure tests ([host layer](internals/host-layer.md)); then implement
   every host claimed by the change, keeping native adapters thin.
5. Add focused core tests and direct native-host tests, and a conformance case
   where executing the contract shows the effect.
6. Add or update the smallest Gallery demonstration and handbook section.
7. Let each host say what it realizes, only after its tests pass. A member a
   registration takes or raises records itself: a host's suite run with
   `STATEUI_UPDATE_EXPORTS=1` writes its declaration,
   `lib/StateUI/exports/<host>.txt` - `appkit`, `uikit`, `android`, `winui`,
   `gtk` - and its conformance verdicts, and the contracts name each member's
   owner when the documents are rendered. What a registry cannot know stays
   written by hand, in the host's `<Host>Realization` - `AppKitRealization`,
   `UIKitRealization`, `AndroidRealization`, `WinUIRealization`,
   `GTKRealization`, `WebRealization` - every judgement: a partial record
   saying what is missing, what a host realizes none of, what it leaves to the
   application or to a backend, and what it presents with no view of its own.
   Where the change alters what a family's cases prove, raise the family's
   revision first. Then `STATEUI_UPDATE_DOCS=1 swift test --filter
   ControlDictionaryTests` writes `docs/controls/` and the tables of
   `platform-contract.md`. [Conformance and marks](#conformance-and-marks)
   walks through it.

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
STATEUI_HOST=appkit swift build --package-path apps/HelloWorld \
  --scratch-path apps/HelloWorld/.build/appkit --product HelloWorldAppKit
```

In VS Code, the StateUI extension (`lib/StateUI.VSCode`) runs either
application: "StateUI: Debug" and "StateUI: Release" build and start the one
chosen in its status bar, on the host chosen there; installing it is under
[Working in VS Code](getting-started.md#working-in-vs-code). The Gallery's
build assembles its resources, icon, runtime libraries, and ad-hoc signature.

The UIKit host builds on macOS with the same Xcode and its iOS 26 or newer
simulator runtime, for iOS and iPadOS 26 or newer. An application's UIKit
head is built as an application bundle, installed on an iOS simulator -
booted first where it is not - or on an iPhone or iPad of this Mac's, and
started by one script:

```bash
.scripts/UIKit/run-app.sh apps/HelloWorld debug "iPhone 18 Pro"
```

A simulator is named by its name or its UDID, a device by its name or its
identifier; with none named, the simulator booted runs it, else an iPhone.
`--no-log` returns once the application has started.
[UIKit host](hosts/uikit.md) lists what it needs and what it builds.

The Android Views host builds on macOS with the swift.org toolchain, the Swift
SDK for Android, the NDK r30 and JDK 21. An application's Android head is
built, installed and started on a device by one script:

```bash
.scripts/Android/run-app.sh apps/HelloWorld debug emulator-5554
```

[Android Views host](hosts/android.md) lists what it needs and what it builds.

The WinUI host builds on Windows with the swift.org toolchain and Visual
Studio's C++ tools; its script fetches C++/WinRT and the Windows App SDK
itself. An application's WinUI head is built and started by one script:

```powershell
.scripts\WinUI\run-app.ps1 -App apps\HelloWorld
```

[WinUI host](hosts/winui.md) lists what it needs and what it builds.

The GTK host builds on Linux with the swift.org toolchain, GTK 4 and
libadwaita. An application's GTK head is built and started by one script:

```bash
.scripts/GTK/run-app.sh apps/HelloWorld
```

[GTK host](hosts/gtk.md) lists what it needs and what it builds.

The Web host builds on macOS and Linux with swift.org's Swift 6.4.0
toolchain and its Swift SDK for WebAssembly. An application's Web head is
built, served and opened in a browser by one script:

```bash
.scripts/Web/run-app.sh apps/HelloWorld
```

[Web host](hosts/web.md) lists what it needs and what it builds.

## Deploy

Each host's `deploy` script builds an application's head for release and lays
it, with what it runs with, in a folder it makes anew:

```bash
.scripts/AppKit/deploy.sh apps/Gallery artifacts/Gallery/AppKit
.scripts/UIKit/deploy.sh apps/Gallery artifacts/Gallery/UIKit <device-udid>
.scripts/Android/deploy.sh apps/Gallery artifacts/Gallery/Android emulator-5554
.scripts/GTK/deploy.sh apps/Gallery artifacts/Gallery/GTK
.scripts/Web/deploy.sh apps/Gallery artifacts/Gallery/Web
```

```powershell
.scripts\WinUI\deploy.ps1 -App apps\Gallery -Destination artifacts\Gallery\WinUI\x64 -Architecture x64
```

- AppKit lays the application bundle where a script beside it bundles the
  application (`build-<application>-appkit.sh`, the Gallery's), else the head
  and the StateUI libraries it links;
- UIKit, an application bundle for the device named - a simulator, or an
  iPhone or iPad it is signed for;
- Android, the APK, for the ABI of the device named;
- WinUI, everything the head runs with - StateUI, the Windows App SDK, the
  Swift and C++ runtimes of its architecture, its pictures - so the folder
  runs on a Windows machine with none of them installed;
- GTK, the head, the StateUI libraries it links, and its pictures;
- Web, the page: `index.html` with the head the application gives it, the
  relay and its style sheet, the module, the application's own scripts and its
  pictures - a folder any web server serves as it is.

In VS Code, **StateUI: Deploy** runs the chosen host's script for the chosen
application and lays it in `artifacts/<application>/<platform>` beside the
`apps/` that holds it, a checkout's or a project group's. A WinUI head is laid
per architecture, in `artifacts/<application>/WinUI/<architecture>`: this
machine's own, and on an ARM64 machine x64 too, which Windows runs emulated.
Git leaves `artifacts/` out.

## Test

Each suite lives beside the package whose behavior it verifies:

```bash
swift test
swift test --package-path lib/StateUI/StateUI.Host
swift test --package-path lib/StateUI/StateUI.Conformance
swift test --package-path lib/StateUI/StateUI.AppKit
swift test --package-path apps/Gallery
swift test --package-path apps/HelloWorld
```

`.scripts/test-native.sh` runs these Swift suites, then the Gallery again as an
AppKit build (`STATEUI_HOST=appkit`), on a build directory of its own:

```bash
.scripts/test-native.sh
```

The first suite covers core semantics and the typed boundary. The host
layer's suite proves the rules every host shares, pure, with no toolkit. The
conformance package's own tests prove its runner and that every member has
its case; each host's suite runs the cases themselves. The AppKit suite drives
native AppKit objects. The Gallery's treats Gallery as application behavior
and compiles the documentation examples. HelloWorld's holds one example test
of the application's own logic, which a new application starts with. In VS Code, **StateUI: Run Tests**
runs them as the chosen host.

Each host's suite - its own tests and the conformance cases - has a script.
The AppKit host's runs `swift test` in `lib/StateUI/StateUI.AppKit` and hands
on `swift test`'s arguments:

```bash
.scripts/AppKit/test-appkit.sh
.scripts/AppKit/test-appkit.sh --filter AppKitConformanceTests
```

The UIKit host's suite is an application of its own, built, installed on an
iOS simulator and run there; with no simulator named, the one booted, else an
iPhone:

```bash
.scripts/UIKit/test-uikit.sh "iPhone 18 Pro"
```

The Android Views host's suite runs on a device, in a test APK:

```bash
.scripts/Android/test-android.sh emulator-5554
```

`STATEUI_FILTER=<names>` narrows a UIKit or an Android run to the tests whose
`Case.test` name holds one of the names, split at commas.

The WinUI host's suite runs on Windows, the Windows App SDK laid beside its
test runner first, every test in a process of its own. Alone the script runs
the host's own tests; `-Conformance` runs the conformance families - some
fifteen minutes; `-Filter <test>` runs the tests it names:

```powershell
.scripts\WinUI\test-winui.ps1
.scripts\WinUI\test-winui.ps1 -Conformance
.scripts\WinUI\test-winui.ps1 -Filter WinUIConformanceTests.testButton
```

The GTK host's suite runs on Linux, in a desktop session whose display shows
its windows. Its script runs `swift test` in
`lib/StateUI/StateUI.GTK/Testing` and hands on `swift test`'s arguments:

```bash
.scripts/GTK/test-gtk.sh
```

The Web host's suite is built for WebAssembly from
`lib/StateUI/StateUI.Web/Testing`. Alone its script runs the host's own tests
in Node; `--browser` runs the conformance families - every family, or those
named - and the host's tests that need a browser's own page, in a headless
Google Chrome or Chromium; `--browser --host` runs only those tests of the
host's:

```bash
.scripts/Web/test-web.sh
.scripts/Web/test-web.sh --browser
```

A passing unit suite does not prove native drawing or interaction. Exercise a
user-visible change in the running Gallery on the affected platform. Run only
one application build at a time because Swift build directories are shared by
the package graph.

On GitHub each suite has a workflow of its own, so each shows its own state,
the core apart from the hosts: **Core macOS**, **Core Linux** and **Core
Windows** (`build-mac.yml`, `build-linux.yml`, `build-windows.yml` - the core,
the host layer and the conformance runner, and the Gallery and HelloWorld), and one
for each host - **AppKit**, **UIKit** (an iPhone and an iPad simulator),
**Android** (the test APK built on macOS, run on a Linux emulator), **WinUI**,
**GTK** and **Web**. **Core macOS** runs the core, the host layer and the
conformance runner once more under Thread Sanitizer, where a race it sees
fails the run - `swift test --sanitize=thread` on a Mac; on Linux the
sanitizer cannot see through a `Mutex` and reports every guarded access.
A host's workflow holds every conformance verdict to its marks and never
writes them: a family whose verdicts changed fails there, and its marks are
written again on that platform's machine. The Web's workflow runs the host's
own tests alone; its marks are written on a Mac by
`STATEUI_UPDATE_EXPORTS=1 .scripts/Web/test-web.sh --browser`.

### Conformance and marks

What executing the contract does is proved once, as a conformance case in
`lib/StateUI/StateUI.Conformance`: a family for each element contract and
each tier, with a case for every member. Every host's suite runs the families
through its driver, and what each case said is a mark in the [platform
contract](platform-contract.md) and the [control
dictionary](controls/README.md). No mark is written by hand: each is the
verdict of a run.

A host's run holds what it says to `lib/StateUI/exports/`, and fails where the
two differ:

- `lib/StateUI/exports/<host>.txt` - what the host declares it realizes, from
  its registry;
- `lib/StateUI/exports/marks/<host>/<Family>.txt` - a family's verdicts, one a
  line, under `# revision <every>.<host>`.

A run with `STATEUI_UPDATE_EXPORTS=1` writes them instead. The revision is the
family's in `lib/StateUI/StateUI.Conformance/revisions.txt`: a line naming the
family alone is its revision on every host, a line naming a host and the
family that host's own, 1 where no line names it.
`.scripts/Marks/revision.sh <host> <family>` prints it - `1.1`. A change that
alters what a family's cases prove raises its revision there - the host's own
line where one host's change alone does - and every verdict written at another
revision shows ⌛ until its host runs the family again. `STATEUI_STALE_ONLY=1`
(`-Stale` on Windows) runs only the families whose verdicts stand at another
revision, or at none.

A host's marks are written again, then the documents rendered from them - on
AppKit:

```bash
STATEUI_UPDATE_EXPORTS=1 .scripts/AppKit/test-appkit.sh --filter AppKitConformanceTests
STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests
```

The second line writes the tables of `docs/platform-contract.md` and the pages
of `docs/controls/` from the contracts and every host's verdicts. Without the
variable, `ControlDictionaryTests` refuses a document that differs from what
they render, a line that is no verdict, and a verdict on what no contract
declares.

In VS Code, **StateUI: Conformance - Rebuild all** runs the chosen host's
families writing their verdicts, then renders the documents;
**StateUI: Conformance - Rebuild changed** runs only the stale families. A
UIKit or an Android rebuild runs on the device chosen in the status bar; for
Android the editor offers Rebuild all alone, and
`STATEUI_STALE_ONLY=1 .scripts/Android/test-android.sh <serial>` runs the
stale families. The editor makes no marks for the Web;
`STATEUI_UPDATE_EXPORTS=1 .scripts/Web/test-web.sh --browser` writes them.
[Reading the matrix](platform-contract.md#reading-the-matrix) says what each
mark means.

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

The core's suite also guards the project itself, in
`lib/StateUI/Core/Tests/Project/`:

- `AppsTests` - every path an application's manifest names resolves, and the
  scaffolder makes a new application from `apps/HelloWorld`;
- `DocumentLinksTests` - every relative link in every Markdown document of
  the repository names a file or a folder that exists;
- `ReleaseTests` - every place that names the release names the one
  `lib/StateUI.VSCode/package.json` states ([Distribution
  boundary](#distribution-boundary));
- `LicenceTests` - every source under `lib/` starts with the two SPDX lines;
- `DocumentationTests` - every public declaration of the library has its
  `///`;
- `DesignNotesTests` - every `Design:` reference in a source names a note and
  a heading that exist, and in each directory it holds, comments stay under a
  quarter of each file's lines;
- `NativeProjectTests` - each host package and head keeps its shape, and
  shared Swift names a host only under its condition;
- `RuntimeArchitectureTests` - each host holds only what its toolkit makes it
  write, and does not do again what the host layer does;
- `ToolchainTests` - every place that names the Swift release, the Xcode, the
  NDK and the oldest system names the same one;
- `VsCodeTests` - every name the VS Code configurations point at, in another
  file or a script, exists;
- `WebPageTests` - the page `.scripts/Web/page.sh` lays out for a Web head
  holds the application's names and what its `Page` folder adds.

## Diagnostics

The inspector and two switches say what each render costs and builds. None
records anything while it is off.

The inspector shows the renders inside the running application: each one's
cause, its road, the time Swift took to describe it and the host to apply it,
and the composed views it built and carried; a render chosen shows its tree of
composed views, each with its time. `ToolbarItem.inspector(window)` - `window`
the session a view reads with `@Environment(\.window)` - puts its ⓘ in a
page's bar, and `InspectorButton()` stands anywhere a view goes. The ⓘ
opens its scene's inspector along the bottom of its window, folded to one line;
opened out, it can dock at the side on a desktop or a tablet.
`Inspector.open(.side, in: window)` opens it from code. A scene that declares
`Window(.debugInspector) { DebugInspector() }` can show it in a window of its
own, where the platform opens windows.

The switches write what the runtime does as text to the standard error, which
an Android application sends to logcat:

- `STATEUI_TALLY=1` - the running totals: messages applied, controls made and
  kept, renders, the elements alive, the runs under way or waiting and the host's
  own views alive, the numbers that tell a page left in memory from one let go;
- `STATEUI_INSPECT=1` - every render the inspector records, from the first.

The host layer's runtime reads both from the process's environment as it
starts (`DiagnosticText`), so they hold on every host. The Android, WinUI,
GTK and Web run scripts hand every `STATEUI_` variable of the shell that runs
them to the application - the Web's as a parameter of the page's address:

```bash
STATEUI_TALLY=1 .scripts/GTK/run-app.sh apps/Gallery
```

[Build diagnostics](interface/composition-and-identity.md#build-diagnostics)
covers both, and `debugInfo()`, which says why the composed view it is called
in is being built.

## Distribution boundary

The repository-root `Package.swift` is the package boundary for the
platform-neutral `StateUI` product. Native hosts remain sibling packages so a
consumer selects a toolkit without pulling it into the core. Every host
package uses the root checkout as a local dependency; the complete remote
library-plus-host installation path is not published yet. Keep Getting Started
honest about that state until both products have a supported versioned route.

A release has one version, stated in the editor extension's
`lib/StateUI.VSCode/package.json`. Every other place that names it - the
published-package line in the root `Package.swift`, the library's own
`stateUIVersion()`, each application's Android
head's version and the Android host's test head's, the Gallery's AppKit
bundle, every UIKit bundle (`.scripts/UIKit/tools.sh`), the bug report's
example - names the same one, and `ReleaseTests` holds them to it.
