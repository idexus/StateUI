# StateUIStarter

A .NET MAUI application whose user interface is written in **Swift**. Swift
describes a UI tree, C# renders it as real MAUI controls, on iOS, Android, macOS
and Windows.

## What you need

| | |
|---|---|
| **.NET 10 SDK** | <https://dotnet.microsoft.com/download> |
| **.NET MAUI workload** | `dotnet workload install maui` |
| **Swift 6.3 or newer** | macOS: Xcode (it ships the toolchain). Windows: <https://www.swift.org/install/windows/>, plus Visual Studio Build Tools, because Swift links through the MSVC linker |
| **Xcode** | for iOS and Mac Catalyst |
| **Android SDK + a Swift SDK for Android** | for Android: `swift sdk install …` — see <https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html>. The toolchain must be the SDK's own **build** - swift.org's, installed beside Xcode's; the build checks, uses a matching installed toolchain by itself, and names the one to install when none matches |

In VS Code, two extensions: **.NET MAUI** (Microsoft) and **Swift**
(swiftlang) — the first gives the device picker and F5, the second gives
completion and LLDB.

## Building

```bash
dotnet build -f net10.0-maccatalyst -r maccatalyst-arm64
dotnet build -f net10.0-ios
dotnet build -f net10.0-android -t:Run
dotnet build -f net10.0-windows10.0.19041.0
```

The Swift side compiles as part of that — nothing is built separately. The first
build downloads the Swift half of StateUI and compiles a macro plugin, which
takes several minutes; every build after that is incremental.

`dotnet build` is the only way to build the Swift half. `swift build` in the
project root fails with "compiled module was created by an older version of the
compiler; rebuild 'SwiftCompilerPlugin'": the macro plugin in `.build/` is the
host toolchain's, and rebuilding it means compiling swift-syntax from source.

In VS Code, press **F5** ("Debug app (C#)"). It follows the device picker in the
status bar. "Launch app (Release)" is the same launch against the optimized
build, for seeing what would ship; breakpoints are not what that one is for.

When the app reports a missing native library, run the diagnostic before
guessing — it prints every resolved path and what actually exists:

```bash
dotnet build -t:StateUIDiagnose -f net10.0-android
```

## What is where

```
StateUIStarter.csproj    the app; the only line about Swift is the .scripts import
Package.swift              the Swift module, and where StateUI comes from
Host/                      the C# side - App.cs and MauiProgram.cs
Platforms/                 the per-platform heads MAUI needs
Resources/                 artwork MAUI rasterizes: icon, splash, images
                             - placeholder art carrying the StateUI mark;
                             replace it with your own before you ship
Swift/                     everything the app says, and nothing else
  StateUIStarterApp.swift  the application: one window, one page
  MainPage.swift             the page
  Styles/AppStyles.swift     what the controls look like
.scripts/                  the native build - one .targets file and the compilers
.vscode/                   launch and build configurations
```

Add a `.swift` file anywhere under `Swift/` and it is compiled: nothing lists
sources, here or in the manifest. The manifest sits beside the `.csproj` rather
than inside `Swift/`, so SwiftPM's `.build/` and `Package.resolved` land where
`bin/` and `obj/` already are - `Swift/` is source and nothing else.

## Where the library comes from

Two halves, and they move together:

- **C#** — `<PackageReference Include="StateUI" …/>` in the `.csproj`.
- **Swift** — `.package(url: …)` in `Package.swift`.

To work against a checkout on disk instead, point the manifest at it with
`.package(path:)` **and** tell the build where it is, with
`<StateUIPackagePath>` in the `.csproj` — a path dependency is never copied
into `.build/checkouts`, which is where the build looks by default. Both places
carry a comment saying so.

## More

The API is MAUI's, in Swift: property names are MAUI's, camelCased, and set by
modifiers rather than initializer arguments. The gallery application in the
StateUI repository shows every control, with its Swift source beside it.
