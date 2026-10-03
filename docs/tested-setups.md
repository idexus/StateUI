# Tested setups

The machines, systems, toolchains and devices on which StateUI's suites pass
and its Gallery is walked, host by host. Other versions may work; these are
the ones proved. **StateUI: Check Toolchain** says what this machine lacks of
what its hosts need ([Getting started](getting-started.md#requirements)).

## A Mac: AppKit, UIKit, Android Views

Last verified 2026-10-02.

| | |
| --- | --- |
| Machine | Apple M1 Max |
| System | macOS 26.6.2 (25G83) |
| Xcode | 27.0 (27A266a), with its Swift 6.4 (`swift-6.4-RELEASE`) |
| Editor | VS Code 1.139.1; the StateUI extension 0.4.0, Swift (`swiftlang.swift-vscode`) 2.16.7, LLDB DAP 0.4.1 |
| Node.js | 26.10.0, for building and testing the extension |

### AppKit

Xcode 27's Swift 6.4, on macOS 26.6.2.

### UIKit

| | |
| --- | --- |
| Toolchain | Xcode 27's Swift 6.4 and its iOS SDK |
| Simulator runtime | iOS 27.0 (24A434) |
| Simulators | iPhone 18 Pro; iPad Air 13-inch (M4) |

The iPad Pro 13-inch (M5) simulator shows a black screen on runtime 27.0,
Settings included; the iPad Air stands in for it.

### Android Views

| | |
| --- | --- |
| Swift | the swift.org toolchain `swift-6.4.0-RELEASE`, beside Xcode |
| Swift SDK | `swift-6.4.0-RELEASE_android` |
| NDK | r30 (30.0.16248370) |
| JDK | OpenJDK 21.0.11 |
| Android SDK | platform `android-36`, build-tools 36.0.0 |
| Heads | `compileSdk` and `targetSdk` 36, `minSdk` 28 (Android 9) |
| Build | Gradle 9.4.1, which the build scripts fetch; Android Gradle plugin 9.2.1 |
| Devices | the CPH2363 phone, Android 13 (API 33), over USB; the Pixel 3a emulator, Android 14 (API 34), arm64-v8a |

Xcode's own Swift 6.4 is a different build from swift.org's and cannot read
the Swift SDK's modules; the Android build picks the swift.org toolchain by
itself.

## A Windows machine: WinUI 3

Last verified 2026-10-03.

| | |
| --- | --- |
| Machine | a Parallels virtual machine on Apple silicon: ARM64, 4 cores, 16 GB |
| System | Windows 11 Pro 25H2 (build 26200.9457) |
| Swift | the swift.org toolchain `swift-6.4-RELEASE` (6.4.0, Asserts), ARM64, with its Embedded Python 3.10.1 for LLDB |
| C++ | Visual Studio Community 2026 18.10.2, MSVC 14.51, the ARM64 C++ tools |
| Windows SDK | 10.0.26100 |
| Editor | VS Code 1.140.0; the StateUI extension 0.5.0, Swift (`swiftlang.swift-vscode`) 2.16.7, LLDB DAP 0.7.20261002 |
| Node.js | 24.21.0, for building and testing the extension |
| Git | 2.54.0 |

### WinUI 3

| | |
| --- | --- |
| Windows App SDK | 1.8: `microsoft.windowsappsdk.winui` 1.8.260528001, `foundation` 1.8.260527000, `interactiveexperiences` 1.8.260525001 |
| C++/WinRT | 3.0.260818.1 |
| WebView2 | the runtime 154.0.4258.53, for the web view's backend; the SDK package 1.0.3179.45 |
| Architectures | ARM64 heads, built, run and debugged; x64 heads built here and run under Windows' emulation, unattached to a debugger |
| A deployed head | the Swift runtime of its architecture from the Swift installer's `Redistributables\6.4.0\rtl.shared.{arm64,amd64}.msm`; Visual Studio's app-local C++ runtime 14.51.36231 (`Microsoft.VC145.CRT`) |

The build scripts fetch the Windows App SDK, C++/WinRT and the WebView2 SDK
from nuget.org at these versions, pinned in `.scripts/WinUI/tools.ps1`, and
lay the Windows App SDK beside each executable: nothing of it is installed.
**StateUI: Deploy** lays a head that runs with neither Swift nor Visual
Studio installed: both deployed builds of a project group's application, ARM64
and x64, started with no Swift on the search path.

## A Linux machine: GTK 4

Last verified 2026-10-02.

| | |
| --- | --- |
| Machine | a Parallels virtual machine on Apple silicon: aarch64, 2 cores, 16 GB |
| System | Ubuntu 24.04.5 LTS, Linux 7.0.0; GNOME Shell 46 on Wayland |
| Swift | the swift.org toolchain `swift-6.4-RELEASE`, installed by swiftly |
| Editor | VS Code 1.140.0; the StateUI extension 0.5.0, Swift (`swiftlang.swift-vscode`) 2.16.7, LLDB DAP 0.4.1 |
| Node.js | 22.23.3, for building and testing the extension |

### GTK 4

| | |
| --- | --- |
| GTK | 4.14.5 |
| libadwaita | 1.5.0 |
| WebKitGTK | 2.52.6 (`webkitgtk-6.0`), for the web view's backend |
| Pictures | gdk-pixbuf 2.42.10, with librsvg 2.58.0's SVG loader |
| GLib | 2.80.0 |

Ubuntu 24.04's own Node.js is 18, below the extension's 20; Node.js 22 from
nodejs.org stands first on the user's `PATH`.
