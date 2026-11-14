# Tested setups

The machines, systems, toolchains and devices on which StateUI's suites pass
and its Gallery is walked, host by host. Other versions may work; these are
the ones proved. **StateUI: Check Toolchain** says what this machine lacks of
what its hosts need ([Getting started](getting-started.md#requirements)).

## A Mac: AppKit, UIKit, Android Views, Web

Last verified 2026-11-13, on Swift 6.4.2: the core, the host layer, the conformance runner, the application-testing package, the Gallery, HelloWorld and the stateui tool; AppKit's suite (621); UIKit's on the iPhone 18 Pro and the iPad Air 13-inch (M4) simulators (314 and every family; 2026-11-14 through `stateui repo test`); Android's on the Pixel 3a emulator and the CPH2363 (562 each; 2026-11-14 through `stateui repo test`); the editor extension's suite (111 on 2026-11-14, its UIKit debugging on a simulator and on the iPad Pro 13-inch; 113 with Android's debugging on the Pixel 3a emulator). The Web's own suite last on 2026-11-08.

| | |
| --- | --- |
| Machine | Apple M1 Max |
| System | macOS 26.6.2 (25G83) |
| Xcode | 27.1 (27A9275), with its Swift 6.4 (`swiftlang-6.4.0.34.1`) |
| Editor | VS Code 1.144.0; the StateUI extension 0.8.5, Swift (`swiftlang.swift-vscode`) 2.18.0, LLDB DAP 0.4.1 |
| Node.js | 26.10.0, for building and testing the extension |

### AppKit

The swift.org toolchain `swift-6.4.2-RELEASE`, which the `stateui` tool builds with, against Xcode 27's macOS SDK, on
macOS 26.6.2.

### UIKit

| | |
| --- | --- |
| Toolchain | the swift.org toolchain `swift-6.4.2-RELEASE`, which the `stateui` tool builds with, against Xcode 27's iOS and simulator SDKs |
| Simulator runtimes | iOS 26.4 (23E244), the floor; iOS 27.0 (24A434); iOS 27.1 (24A94425) |
| Simulators | iPhone 17 Pro on 26.4; iPhone 18 Pro and iPad Air 13-inch (M4) on 27.0; iPhone Duo on 27.1 |
| Devices | an iPad Pro 13-inch (M4) on iPadOS 27.0.1 over Wi-Fi, development-signed |

The iPad Pro 13-inch (M5) simulator shows a black screen on runtime 27.0,
Settings included; the iPad Air stands in for it.

### Android Views

| | |
| --- | --- |
| Swift | the swift.org toolchain `swift-6.4.2-RELEASE`, beside Xcode |
| Swift SDK | `swift-6.4.2-RELEASE_android` |
| NDK | r30 (30.0.16248370) |
| JDK | OpenJDK 21.0.11 |
| Android SDK | platform `android-36`, build-tools 36.0.0 |
| Heads | `compileSdk` and `targetSdk` 36, `minSdk` 28 (Android 9) |
| Build | Gradle 9.4.1, which the build scripts fetch; Android Gradle plugin 9.2.1 |
| Devices | the CPH2363 phone, Android 13 (API 33), over USB; the Pixel 3a emulator, Android 14 (API 34), arm64-v8a |

Xcode's own Swift 6.4 is a different build from swift.org's and cannot read
the Swift SDK's modules; the Android build picks the swift.org toolchain by
itself.

### Web

Verified 2026-11-14: HelloWorld and the Gallery served by `stateui run` and
run, HelloWorld under VS Code's debugger in Chrome; the host's own suite in
Node, and the conformance suite in a headless browser
(`stateui repo test --suite host:web`), its verdicts the Web's column.

| | |
| --- | --- |
| Swift | the swift.org toolchain `swift-6.4.2-RELEASE` |
| Swift SDK | `swift-6.4.2-RELEASE_wasm` |
| Server | Python 3.14.4 |
| Browser | Safari 26.6.2; Google Chrome 152.0.7977.84, headless, for the conformance suite |
| Node.js | 26.10.0, for the host's own suite and the conformance run's controller |

### GTK 4, in Docker

The GTK host's own suite and every conformance family, as CI runs them,
on the Mac (2026-10-12): Docker Desktop (linux/arm64), swift.org's
`swift:6.4.2-resolute` with the packages `.github/workflows/gtk.yml` installs -
GTK 4.22.4, libadwaita 1.9.1, WebKitGTK 2.52.6 (`webkitgtk-6.0`), GLib
2.88.0 - drawn on Xvfb with a session bus, the build in a volume of its own.
It stands for CI, not for a desktop: X11, no portals, no GNOME Shell.

## A Windows machine: WinUI 3

Last verified 2026-11-13, on Swift 6.4.2: the host's own tests, 223 of 224 - `testAChoiceOfActionsLetsGoOfItsDialog` lost a race in the whole run and passed alone five times in five; the stateui tool's suites; the editor extension's suite (89: project groups, both architectures deployed and run with no Swift on the search path, F5 on HelloWorldWinUI). The whole conformance run last on 2026-11-12.

| | |
| --- | --- |
| Machine | a Parallels virtual machine on Apple silicon: ARM64, 4 cores, 16 GB |
| System | Windows 11 Pro 25H2 (build 26200.9457) |
| Display scale | 200% (`AppliedDPI` 192), where the whole conformance suite and the host's own suite passed on 2026-11-12; at 125% (`AppliedDPI` 120) the whole conformance suite passed on 2026-11-11 |
| Swift | the swift.org toolchain `swift-6.4.2-RELEASE` (Asserts), ARM64, with its Embedded Python 3.10.1 for LLDB |
| C++ | Visual Studio Community 2026 18.10.2, MSVC 14.51, the ARM64 C++ tools |
| Windows SDK | 10.0.26100 |
| Editor | VS Code 1.146.0; the StateUI extension 0.8.5, Swift (`swiftlang.swift-vscode`) 2.18.0, LLDB DAP 0.7.20261012 |
| Node.js | 24.21.0, for building and testing the extension |
| Git | 2.54.0 |

### WinUI 3

| | |
| --- | --- |
| Windows App SDK | 1.8: `microsoft.windowsappsdk.winui` 1.8.260528001, `foundation` 1.8.260527000, `interactiveexperiences` 1.8.260525001 |
| C++/WinRT | 3.0.260818.1 |
| WebView2 | the runtime 154.0.4258.53, for the web view's backend; the SDK package 1.0.3179.45 |
| Architectures | ARM64 heads, built, run and debugged; x64 heads built here and run under Windows' emulation, unattached to a debugger |
| A deployed head | the Swift runtime of its architecture from the Swift installer's `Redistributables\6.4.2\rtl.shared.{arm64,amd64}.msm`; Visual Studio's app-local C++ runtime 14.51.36231 (`Microsoft.VC145.CRT`) |

The stateui tool fetches the Windows App SDK, C++/WinRT and the WebView2 SDK
from nuget.org at these versions, pinned in its `WinUIPackages`, and
lay the Windows App SDK beside each executable: nothing of it is installed.
**StateUI: Deploy** lays a head that runs with neither Swift nor Visual
Studio installed: both deployed builds of a project group's application, ARM64
and x64, started with no Swift on the search path.

## A Linux machine: GTK 4, Web

Last verified 2026-11-13, on Swift 6.4.2: GTK's suite (342) and the stateui tool's suites; the editor extension 0.8.5's suite that day (84, F5 on HelloWorldGTK).

| | |
| --- | --- |
| Machine | a Parallels virtual machine on Apple silicon: aarch64, 2 cores, 16 GB |
| System | Ubuntu 26.04.1 LTS, Linux 7.0.0; GNOME Shell 50.1 on Wayland |
| Swift | the swift.org toolchain `swift-6.4.2-RELEASE` for Ubuntu 26.04, installed by swiftly |
| Editor | VS Code 1.141.0; the StateUI extension 0.8.5, Swift (`swiftlang.swift-vscode`) 2.18.0, LLDB DAP 0.4.1 |
| Node.js | 22.23.3 from nodejs.org, first on the user's `PATH`, for building and testing the extension, the Web host's own suite and the conformance run's controller; Ubuntu's own is 22.22.1 |

### GTK 4

The host's own suite and every conformance family.

| | |
| --- | --- |
| GTK | 4.22.4 |
| libadwaita | 1.9.1 |
| WebKitGTK | 2.52.6 (`webkitgtk-6.0`), for the web view's backend |
| Pictures | gdk-pixbuf 2.44.5, with librsvg 2.61.3's SVG loader |
| GLib | 2.88.0 |
| Graphics | Mesa 26.0.8 on the machine's virtio-gpu; the tests draw with GTK's cairo renderer, an application with its GL one |

SwiftPM says `prohibited flag(s): -pthread` for the GTK libraries here:
Ubuntu 26.04's `lcms2.pc`, which libadwaita reaches, adds `-pthread` to its
flags, and SwiftPM leaves the flag out.

### Web

The host's own suite in Node and the conformance suite in a headless browser
(`test-web.sh --browser`); HelloWorld and the Gallery were last served and run
here on Ubuntu 24.04, on 2026-10-05.

| | |
| --- | --- |
| Swift SDK | `swift-6.4.2-RELEASE_wasm` |
| Server | Python 3.14.4 |
| Browser | Firefox 157.0.1; Chromium 155.0.8059.39 from the snap, headless, for the conformance suite |
