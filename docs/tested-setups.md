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
