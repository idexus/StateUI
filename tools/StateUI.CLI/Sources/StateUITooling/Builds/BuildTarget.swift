// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What one build is for: the architecture, the SDK and the destination of its head, and what `swift build` is told
/// of them.
/// Design: docs/design/tooling/destinations.md#a-destinations-sdk
struct BuildTarget: Sendable {
    var architecture: Architecture
    /// The Apple SDK built against, where the host has one.
    var sdk: AppleSDK?
    /// The device or simulator a UIKit head is for.
    var destination: Destination?
    /// The signing a device's bundle takes, found before anything is built.
    var signing: Signing = .adHoc
    /// `swift build`'s `--triple` and `--sdk`, where the build is not this machine's own.
    var arguments: [String]
    /// Android's compiler, of its Swift SDK's build, and what its build's environment gains.
    var compiler: ProcessExecutable?
    var environment: [String: String] = [:]
    var android: (swiftSDK: String, ndk: URL)?
    var webSDK: String?

    /// The identity of what the build compiles against, for its context: the Apple SDK, or the Swift SDK and NDK.
    var sdkIdentity: String {
        sdk?.identity ?? android.map { "\($0.swiftSDK) \($0.ndk.path)" } ?? webSDK ?? ""
    }

    enum Signing: Sendable {
        case adHoc
        #if os(macOS)
        case development(DevelopmentSigning)
        #endif
    }

    /// A head built for this machine itself, GTK's; another architecture is refused.
    static func native(_ architecture: Architecture, machine: Architecture, host: HostFamily) throws -> BuildTarget {
        guard architecture == machine else {
            throw ToolingError(.invalidConfiguration, "A \(host.rawValue) head is built for this machine's architecture, \(machine.rawValue).")
        }
        return BuildTarget(architecture: architecture, arguments: [])
    }

    /// A WinUI head for `architecture`: the toolchain's own built as it is, the other with `--arch` (winui-heads.md);
    /// built on Windows alone.
    static func winUI(_ architecture: Architecture, machine: Architecture) throws -> BuildTarget {
        #if os(Windows)
        guard [.arm64, .x86_64].contains(architecture) else {
            throw ToolingError(.invalidConfiguration, "A WinUI head is built for arm64 or x86_64, not \(architecture.rawValue).")
        }
        return BuildTarget(architecture: architecture, arguments: architecture == machine ? [] : ["--arch", architecture == .x86_64 ? "x86_64" : "aarch64"])
        #else
        throw ToolingError(.invalidConfiguration, "A WinUI head is built on Windows.")
        #endif
    }

    /// A Web head: the Swift SDK `_wasm` of `compiler`'s release (web-heads.md), else `MISSING_TOOLCHAIN`.
    static func web(compiler: ProcessExecutable) async throws -> BuildTarget {
        let version = await ToolOutput.text(compiler, ["--version"]) ?? ""
        let list = await ToolOutput.standardOutput(compiler, ["sdk", "list"]) ?? ""
        guard let sdk = Versions.swiftSDK(of: Versions.swiftRelease(in: version), in: list, family: "wasm") else {
            throw ToolingError(.missingToolchain, "No Swift SDK for WebAssembly of this compiler's release is installed: https://www.swift.org/documentation/articles/wasm-getting-started.html")
        }
        var target = BuildTarget(architecture: .wasm32, arguments: ["--swift-sdk", sdk])
        target.webSDK = sdk
        return target
    }

    /// The target of an AppKit head for `architecture`: this Mac's SDK, a triple where it is not the machine's own.
    static func appKit(_ architecture: Architecture, machine: Architecture) async -> BuildTarget {
        BuildTarget(
            architecture: architecture, sdk: await AppleSDK.find(.macOS),
            arguments: architecture == machine ? [] : ["--triple", AppleSDK.Platform.macOS.triple(architecture, floor: Doctor.appleFloor)])
    }

    /// An Android head for `architecture`'s ABI, else the device's, else `arm64-v8a` (android-heads.md); a missing
    /// compiler, SDK or NDK is `MISSING_TOOLCHAIN`, a device named not here `INVALID_CONFIGURATION`.
    static func android(device: String?, listed: [Destination], architecture: Architecture?, tools: AndroidTools) async throws -> BuildTarget {
        guard let (compiler, swiftSDK) = await tools.swift() else {
            throw ToolingError(.missingToolchain, "No swift.org compiler with the Swift SDK for Android of its release: `stateui doctor --host android` says what to install.")
        }
        guard let ndk = tools.ndk(for: swiftSDK), let major = AndroidTools.ndkMajor(of: ndk), major >= 30 else {
            throw ToolingError(.missingToolchain, "No Android NDK 30 or newer: install one with Android Studio's SDK Manager, or name it with ANDROID_NDK_ROOT.")
        }
        let destination = device.flatMap { $0.isEmpty ? nil : $0 } == nil
            ? try? AndroidDestinations.choose(nil, from: listed) : try AndroidDestinations.choose(device, from: listed)
        let architecture = architecture ?? destination?.architecture ?? .arm64
        let names: [Architecture: String] = [.arm64: "aarch64", .x86_64: "x86_64"]
        guard let name = names[architecture] else {
            throw ToolingError(.invalidConfiguration, "An Android head is built for arm64 or x86_64, not \(architecture.rawValue).")
        }
        return BuildTarget(
            architecture: architecture, destination: destination,
            arguments: ["--swift-sdk", swiftSDK, "--triple", "\(name)-unknown-linux-android28"],
            compiler: .path(compiler.path), environment: ["ANDROID_NDK_ROOT": ndk.path], android: (swiftSDK, ndk))
    }

    /// A UIKit head for the destination `device` names among `listed`: its SDK, triple and a device's signing; no
    /// destination or signing is `INVALID_CONFIGURATION`, no SDK `MISSING_TOOLCHAIN`.
    static func uiKit(
        device: String?, listed: [Destination], architecture: Architecture?, machine: Architecture, identifier: String
    ) async throws -> BuildTarget {
        #if os(macOS)
        let destination = try AppleDestinations.choose(device, from: listed)
        let platform = AppleSDK.Platform(destination.kind)
        guard let sdk = await AppleSDK.find(platform) else {
            throw ToolingError(.missingToolchain, "The selected Xcode holds no \(platform.rawValue) SDK; `stateui doctor` says what to install.")
        }
        let architecture = architecture ?? (destination.kind == .device ? .arm64 : machine)
        var target = BuildTarget(
            architecture: architecture, sdk: sdk, destination: destination,
            arguments: ["--triple", platform.triple(architecture, floor: Doctor.appleFloor), "--sdk", sdk.path])
        if destination.kind == .device {
            target.signing = .development(try await DevelopmentSigning.find(identifier: identifier, device: destination.udid))
        }
        return target
        #else
        throw ToolingError(.invalidConfiguration, "A UIKit head is built on a Mac.")
        #endif
    }
}
