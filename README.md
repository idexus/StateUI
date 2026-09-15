[![Tests](https://github.com/idexus/StateUI/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/tests.yml?query=branch%3Amain)
[![iOS / Mac Catalyst](https://github.com/idexus/StateUI/actions/workflows/build-apple.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/build-apple.yml?query=branch%3Amain)
[![Android](https://github.com/idexus/StateUI/actions/workflows/build-android.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/build-android.yml?query=branch%3Amain)
[![Windows](https://github.com/idexus/StateUI/actions/workflows/build-windows.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/build-windows.yml?query=branch%3Amain)
[![Linux](https://github.com/idexus/StateUI/actions/workflows/build-linux.yml/badge.svg?branch=main)](https://github.com/idexus/StateUI/actions/workflows/build-linux.yml?query=branch%3Amain)
# StateUI

> **Native interfaces, written in Swift.**

StateUI describes an application's interface in Swift. Swift owns the UI tree,
identity, state, diffing, and motion; a thin host applies sparse patches to
controls from its platform toolkit.

Two hosts are active: AppKit, and .NET MAUI, which already runs StateUI
applications on Android, iOS, Mac Catalyst, Windows, and Linux. UIKit, Android
Views, WinUI 3, and GTK 4 follow the same host contract. Web DOM/CSS comes after
the native contract is settled.

| MAUI - Catalyst, iOS, Android, Windows, Linux | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| ✅ | ✅* | — | — | — | — | — |

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

Build the native Gallery application:

```bash
.scripts/AppKit/build-gallery-appkit.sh debug
```

The Gallery bundle is written to
`apps/Gallery/.build/debug/GalleryAppKit.app`.

Build and start the Gallery with the MAUI host on Mac Catalyst (`ios` starts it
in the iOS Simulator, `linux` on a Linux machine):

```bash
.scripts/Maui/run-app.sh maccatalyst
```

Run every active suite:

```bash
.scripts/test-native.sh
dotnet test lib/StateUI.Maui/Tests
```

VS Code exposes F5 configurations for Gallery and HelloWorld under "1 AppKit",
and the MAUI launches under "2 MAUI", which run on the device chosen in the
status bar.

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
