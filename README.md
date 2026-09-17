[![Tests](https://github.com/idexus/StateUI/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/tests.yml?query=branch%3Amain)
[![iOS / Mac Catalyst](https://github.com/idexus/StateUI/actions/workflows/build-apple.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/build-apple.yml?query=branch%3Amain)
[![Android](https://github.com/idexus/StateUI/actions/workflows/build-android.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/build-android.yml?query=branch%3Amain)
[![Windows](https://github.com/idexus/StateUI/actions/workflows/build-windows.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/build-windows.yml?query=branch%3Amain)
[![Linux](https://github.com/idexus/StateUI/actions/workflows/build-linux.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/build-linux.yml?query=branch%3Amain)
# StateUI

 **Native interfaces, written in Swift.**
> StateUI describes an application's interface in Swift. Swift owns the UI tree,
identity, state, diffing, and motion; a thin host applies sparse patches to
controls from its platform toolkit.

Two hosts are active: AppKit, and .NET MAUI, which already runs StateUI
applications on Android, iOS, Mac Catalyst, Windows, and Linux. UIKit, Android
Views, WinUI 3, and GTK 4 follow the same host contract. Web DOM/CSS comes after
the native contract is settled.

| MAUI - Catalyst, iOS, Android, Windows, Linux | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| ✅ | ☑️ | — | — | — | — | — |

## In Action

One application, described once in Swift, on two hosts. The AppKit host draws
it with macOS controls, in the same process as the application module - here
the Gallery's Metal sample: the cube is an `MTKView` the application registers
with the host, and its size, colour and spin are described from StateUI. The
edge is handed over as a state, so dragging the slider rebuilds nothing:

<video src="https://github.com/idexus/StateUI/raw/main/docs/assets/appkit.mp4" controls muted loop width="840">
  <a href="https://github.com/idexus/StateUI/raw/main/docs/assets/appkit.mp4">The Gallery's Metal sample on the AppKit host (mp4)</a>
</video>

The .NET MAUI host renders the same application from the wire - here on
Windows, under the debugger:

<video src="https://github.com/idexus/StateUI/raw/main/docs/assets/win.mp4" controls muted loop width="840">
  <a href="https://github.com/idexus/StateUI/raw/main/docs/assets/win.mp4">The Gallery on the MAUI host, on Windows (mp4)</a>
</video>

## In Code

```swift
struct CounterPage: ContentView {
    @State private var count = 0

    var content: any View {
        VStack {
            Label("Tapped \(count) times")
            Button("Tap me").onClicked { count += 1 }
        }
    }
}
```

StateUI has one state declaration and two reactive paths:

- reading a state rebuilds only the body that read it;
- handing a binding to a control or property lets the host update it without
  rebuilding that body.

`Journey` belongs to the same state and carries its current value, destination,
velocity, and motion. A host with verified motion support animates compatible
property changes on the platform display clock; an unverified or unsupported
pair snaps to its destination.

StateUI is under active development. Until a 1.0 release, the public Swift API
and host contract may change together when native evidence reveals a clearer
cross-platform model. The handbook and platform matrix describe the contract
that is usable now.

## Documentation

- [StateUI handbook](docs/README.md) — the complete guide to applications,
  state, layout, controls, interaction, concurrency, and native hosts.
- [Architecture](docs/architecture.md) — state, reactivity, Journey, motion,
  and application sessions.
- [Host contract](docs/host-contract.md) — `HostPatch`, ownership, identity,
  lifetime, and native adapter rules.
- [Platform contract](docs/platform-contract.md) — the control, property, and
  event inventory with verified host coverage.
- [Control dictionary](docs/controls/README.md) — every control and part of an
  application's structure, member by member, with a mark per platform.
- [MAUI host](docs/maui-host.md) — platforms, an application's MAUI head, the
  `stateui-maui` template, builds, debugging, and C# registrations.
- [Project structure and development](docs/development.md) — packages, Gallery,
  build, F5, and test commands.
- [Contributing](CONTRIBUTING.md) — rules for changing the public contract.

Public API declarations provide the focused reference beside the code.

## Quick start

StateUI is developed and used in VS Code, through the StateUI extension in
`lib/StateUI.VSCode`. Build and install it from the checkout (Node.js 20 or
newer):

```bash
cd lib/StateUI.VSCode
npm ci
npm run package
code --install-extension stateui-*.vsix
```

For the .NET MAUI host - Android, iOS, Mac Catalyst, Windows, and Linux -
install the .NET 10 SDK, the MAUI workload (everywhere except Linux, which has
none), and the **.NET MAUI** extension (Microsoft), which brings the device
picker and the C# debugger. The AppKit host needs only Xcode.

```bash
dotnet workload install maui
code --install-extension ms-dotnettools.dotnet-maui
```

Android asks for more, and builds on macOS only:

- the Android SDK with NDK 27 or newer, for Android 9 (API 28) or newer;
- the Swift SDK for Android, Swift 6.3 or newer, installed with `swift sdk
  install`;
- the swift.org toolchain of exactly that SDK's build, such as
  `swift-6.3.3-RELEASE`, beside Xcode. Xcode's own Swift of the same version
  number is a different build and cannot read the SDK's modules; the build
  picks the matching toolchain by itself and names the one to install when
  none is there.

[MAUI host](docs/maui-host.md#requirements) lists what each platform needs,
GTK 4 on Linux among them.

Then open the repository in VS Code:

1. Choose the host in the status bar - **AppKit** or **.NET MAUI** - and the
   application, **Gallery**.
2. Press **F5**. **StateUI: Debug** builds the Gallery for that host and starts
   it under the debugger; **StateUI: Release** runs the optimized build.
3. Run **StateUI: Run Tests** from the Command Palette for every suite of that
   host.

[Working in VS Code](docs/getting-started.md#working-in-vs-code) covers the
extension's hosts, debuggers, and commands, including **StateUI: New
Application**.

From a terminal, the same builds are:

```bash
.scripts/AppKit/build-gallery-appkit.sh debug   # the AppKit Gallery bundle
.scripts/Maui/run-app.sh maccatalyst            # the MAUI Gallery: ios, linux
.scripts/test-native.sh                         # the Swift suites
dotnet test lib/StateUI.Maui/Tests              # the C# suite
```

## Continuous integration

Every workflow runs on pushes and pull requests to `main` and `dev`.

### Native

`Tests` runs the StateUI, StateUI.AppKit, and Gallery suites on macOS.

### MAUI

`Tests` also runs the MAUI host's C# suite on Ubuntu. The four platform
workflows build the Gallery's MAUI head, and the Windows and Linux workflows
also run the StateUI and C# suites on those hosts.

## License

StateUI is licensed under the Apache License 2.0. See [LICENSE](LICENSE) and
[NOTICE](NOTICE). Use of the StateUI name and mark is described in
[TRADEMARK.md](TRADEMARK.md).
