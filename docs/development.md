# Project structure and development

## Repository layout

```text
Package.swift                     StateUI core package and core tests
StateUI.slnx                      the .NET solution: MAUI heads and host projects
lib/StateUI/Sources/              platform-neutral StateUI
lib/StateUI/Tests/                core tests, fixtures, and shared test support
lib/StateUI.AppKit/               independent AppKit host package and tests
lib/StateUI.Maui/Sources/         .NET MAUI host (StateUI.Maui)
lib/StateUI.Maui/Linux/           its Linux platform over GTK 4 (StateUI.Maui.Linux)
lib/StateUI.Maui/Tests/           MAUI host tests
lib/StateUI.Maui/Template/        `dotnet new stateui-maui` template
.scripts/AppKit/                  AppKit Gallery bundling
.scripts/Maui/                    MSBuild targets and per-platform Swift builds
apps/Gallery/Sources/             platform-neutral Gallery application
apps/Gallery/Platforms/AppKit/    Gallery AppKit entry point
apps/Gallery/Platforms/Maui/      Gallery MAUI head
apps/Gallery/Tests/               Gallery acceptance tests
apps/HelloWorld/Sources/          small platform-neutral example application
apps/HelloWorld/Platforms/AppKit/ HelloWorld AppKit entry point
apps/HelloWorld/Platforms/Maui/   HelloWorld MAUI head
```

The core never imports Foundation or a platform UI framework. Application code
may import Foundation. Platform frameworks remain inside host packages and
platform entry points.

Swift written for the MAUI host alone stands under `#if MAUI`, the condition
every MAUI build of a Swift module defines. `NativeProjectTests` refuses any
other mention of that host in the library and in the applications' `Sources/`.

## Gallery

Gallery is the acceptance surface for the active `HostContract`. Its examples
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
3. Register the member in `HostContract` and its typed or Wire vocabulary.
4. Implement every host claimed by the change, keeping native adapters thin.
5. Add focused core tests and direct native-host tests.
6. Add or update the smallest Gallery demonstration and handbook section.
7. Regenerate the member lists with `python3 .scripts/controls-dictionary.py`,
   and mark the exact rows in `platform-contract.md` and in the member's
   `docs/controls/` file only after host tests pass; a `✅*` note says what is
   still missing.

Removing a capability follows the same path: remove stale vocabulary, host
branches, tests, samples, and documentation together. Do not leave an inert
modifier or compatibility alias unless compatibility is itself an explicit
contract.

## Build

The AppKit host requires macOS 14 or newer and a Swift 6 toolchain from Xcode.

Build the runnable Gallery bundle:

```bash
.scripts/AppKit/build-gallery-appkit.sh debug
```

Build the smaller example:

```bash
swift build --package-path apps/HelloWorld --product HelloWorldAppKit
```

VS Code exposes Debug and Release F5 configurations for both applications.
The Gallery build task assembles its resources, icon, runtime libraries, and
ad-hoc signature.

The MAUI host requires the .NET 10 SDK and, except on Linux, the MAUI workload.
A head compiles the library and its application's Swift module for the
platform it builds:

```bash
dotnet build apps/Gallery/Platforms/Maui -f net10.0-maccatalyst
dotnet build apps/Gallery/Platforms/Maui -f net10.0-android -t:Run
```

VS Code groups those launches under "2 MAUI". [MAUI host](maui-host.md) lists
every platform, launch, and task.

## Test

Each suite lives beside the package whose behavior it verifies:

```bash
swift test
swift test --package-path lib/StateUI.AppKit
swift test --package-path apps/Gallery
dotnet test lib/StateUI.Maui/Tests
```

Run the three Swift suites in that order with:

```bash
.scripts/test-native.sh
```

The first suite covers core semantics and typed and Wire boundaries. The second
drives native AppKit objects. The third treats Gallery as application behavior
and compiles the documentation examples. The fourth drives MAUI controls as
ordinary .NET objects over the fixtures the first writes; it needs the .NET 10
SDK and, except on Linux, the MAUI workload, and runs its classes one at a
time. The VS Code launch "Test: all (Swift + C#)" runs all four.

A passing unit suite does not prove native drawing or interaction. Exercise a
user-visible change in the running Gallery on the affected platform. Run only
one application build at a time because Swift build directories are shared by
the package graph.

## Fixtures

Binary fixtures under `lib/StateUI/Tests/Fixtures/` pin the deterministic Wire
contract. Each `.bin` has a readable `.txt` sidecar. When a deliberate protocol
change makes a fixture test fail, regenerate both with:

```bash
STATEUI_UPDATE_FIXTURES=1 swift test
```

Review the binary and text diffs before accepting them, then run the ordinary
suite again without the environment variable, and `dotnet test
lib/StateUI.Maui/Tests`, which applies the same files. The VS Code task "Test
(update wire fixtures)" regenerates them and runs the C# suite in one step.
Never update fixtures merely to make an unexplained failure green.

The documentation examples are another executable fixture. Every exact
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

The MAUI host is three NuGet packages, `StateUI.Maui`, `StateUI.Maui.Linux`,
and `StateUI.Maui.Template`, whose versions move with the Swift package's tag.
None is published yet; [MAUI host](maui-host.md#publishing-the-packages) says
how they are packed and tried locally.
