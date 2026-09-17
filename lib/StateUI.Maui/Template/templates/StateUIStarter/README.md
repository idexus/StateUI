# StateUIStarter

An application whose user interface is written in **Swift** with StateUI.
`Sources/` describes the interface, and each host in `Platforms/` renders it
with native controls:

- `Platforms/Maui/` - the .NET MAUI host, on Android, iOS, Mac Catalyst,
  Windows and Linux;
- `Platforms/AppKit/` - the native macOS host, when the application was created
  with `--appkit`.

## What you need

| | |
|---|---|
| **.NET 10 SDK** | <https://dotnet.microsoft.com/download> |
| **.NET MAUI workload** | `dotnet workload install maui` |
| **Swift 6.3 or newer** | macOS: Xcode (it ships the toolchain). Windows: <https://www.swift.org/install/windows/>, plus Visual Studio Build Tools, because Swift links through the MSVC linker |
| **Xcode** | for iOS, Mac Catalyst and the AppKit host |
| **Android SDK + a Swift SDK for Android** | for Android: `swift sdk install …` - see <https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html>. The toolchain must be the SDK's own build - swift.org's, installed beside Xcode's; the build checks, uses a matching installed toolchain by itself, and names the one to install when none matches |

In VS Code: **StateUI** (idexus) for the launches, the host and the editor's
completion under it - it brings **Swift** (swiftlang) along - **.NET MAUI**
(Microsoft) for the device picker, and **LLDB DAP** for the Swift debugger.
`.vscode/extensions.json` recommends them.

## Building

In VS Code, press **F5** for "StateUI: Debug" or pick "StateUI: Release". The
StateUI extension's status bar chooses the host - AppKit or .NET MAUI - and,
for MAUI, the debugger; the editor works as that host, so completion works
inside `#if APPKIT` while AppKit is chosen. On MAUI the debugger decides the
launch; with C#, the .NET MAUI extension's device picker chooses the device.

From a terminal, the MAUI host, from the application's root:

```bash
dotnet build Platforms/Maui -f net10.0-maccatalyst
dotnet build Platforms/Maui -f net10.0-ios
dotnet build Platforms/Maui -f net10.0-android -t:Run
dotnet build Platforms/Maui -f net10.0-windows10.0.19041.0
dotnet build Platforms/Maui                      # Linux
```

The Swift side compiles as part of that - nothing is built separately. The
first build compiles the Swift half of StateUI once, and every build after that
compiles only what changed. `dotnet build` is the only way to build the Swift
half for a MAUI platform: a bare `swift build` builds for the machine you are
on, which is not the target.

The AppKit host, when the application has one:

```bash
STATEUI_APPKIT=1 swift run StateUIStarterAppKit
```

It reads `Resources/` beside its own sources, so it runs from any directory.

`STATEUI_APPKIT=1` is what makes this an AppKit build. `Package.swift` reads it
and then declares the AppKit head - its target, product and StateUIAppKit
dependency - and defines `APPKIT`, the condition Swift written for the AppKit
host alone stands under. Without it, `swift test` compiles no part of one
host's half.

When the app reports a missing native library, run the diagnostic before
guessing - it prints every resolved path and what actually exists:

```bash
dotnet build Platforms/Maui -t:StateUIDiagnose -f net10.0-android
```

## What is where

```
Package.swift              the Swift module, and where StateUI comes from
Sources/                   everything the app says, and nothing else
  StateUIStarterApp.swift  the application: one window, one page
  MainPage.swift           the page
  Styles/AppStyles.swift   what the controls look like
Resources/                 artwork: icon, splash, images - placeholder art
                           carrying the StateUI mark; replace it before you ship
Platforms/Maui/            the MAUI host: StateUIStarter.csproj, Host/ with
                           App.cs and MauiProgram.cs, one folder per platform
Platforms/AppKit/          the macOS host: main.swift (with --appkit)
.vscode/                   launch and build configurations
```

Add a `.swift` file anywhere under `Sources/` and it is compiled: nothing lists
sources, here or in the manifest. Code for the MAUI host alone stands under
`#if MAUI`, the condition every MAUI build of the Swift side defines.

## Where the library comes from

Two halves, and they move together:

- **C#** - `StateUI.Maui` in `Platforms/Maui/StateUIStarter.csproj`.
- **Swift** - `StateUI` in `Package.swift`.

An application created with `--stateui-path` takes both from that checkout: the
project references the host's project there, the manifest names the checkout
with `.package(path:)`, and `StateUIPackagePath` tells the build where it is.
The AppKit host always comes from a checkout, which is why `--appkit` needs
`--stateui-path`.

## More

The StateUI repository holds the handbook, in `docs/`, and the Gallery, which
shows every control with its Swift source beside it.
