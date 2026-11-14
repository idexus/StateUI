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
    /// The compiler, where the host takes another than the tool's own: Android's, of the Swift SDK's build.
    var compiler: ProcessExecutable?
    /// What the build's environment gains: Android's NDK.
    var environment: [String: String] = [:]
    /// An Android head's Swift SDK and NDK.
    var android: (swiftSDK: String, ndk: URL)?

    /// The identity of what the build compiles against, for its context: the Apple SDK, or the Swift SDK and NDK.
    var sdkIdentity: String {
        sdk?.identity ?? android.map { "\($0.swiftSDK) \($0.ndk.path)" } ?? ""
    }

    enum Signing: Sendable {
        case adHoc
        #if os(macOS)
        case development(DevelopmentSigning)
        #endif
    }

    /// The target of a head built for this machine itself - GTK's: its own architecture, nothing for SwiftPM to be told.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for another architecture than the machine's.
    static func native(_ architecture: Architecture, machine: Architecture, host: HostFamily) throws -> BuildTarget {
        guard architecture == machine else {
            throw ToolingError(.invalidConfiguration, "A \(host.rawValue) head is built for this machine's architecture, \(machine.rawValue).")
        }
        return BuildTarget(architecture: architecture, arguments: [])
    }

    /// The target of an AppKit head for `architecture`: this Mac's SDK, a triple where it is not the machine's own.
    static func appKit(_ architecture: Architecture, machine: Architecture) async -> BuildTarget {
        BuildTarget(
            architecture: architecture, sdk: await AppleSDK.find(.macOS),
            arguments: architecture == machine ? [] : ["--triple", AppleSDK.Platform.macOS.triple(architecture, floor: Doctor.appleFloor)])
    }

    /// The target of an Android head for the ABI of `architecture`, else of the device `device` names - or the only
    /// one running - else `arm64-v8a`: the Swift SDK for Android of the swift.org compiler's release, the triple at
    /// API 28, and the NDK, 30 or newer.
    ///
    /// - Throws: ``ToolingError`` `MISSING_TOOLCHAIN` where the compiler, the SDK or the NDK is missing,
    ///   `INVALID_CONFIGURATION` where the device named is not here.
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

    /// The target of a UIKit head of `application` named `name` for the destination `device` names among `listed`:
    /// its SDK and triple - an arm64 device's, a simulator's of `architecture` - and a device's signing.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` where no destination or signing is found,
    ///   `MISSING_TOOLCHAIN` where Xcode holds no SDK for it.
    static func uiKit(
        device: String?, listed: [Destination], architecture: Architecture?, machine: Architecture, application: URL, name: String
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
            let identifier = UIKitBundle.identifier(of: application, name: name)
            target.signing = .development(try await DevelopmentSigning.find(identifier: identifier, device: destination.udid))
        }
        return target
        #else
        throw ToolingError(.invalidConfiguration, "A UIKit head is built on a Mac.")
        #endif
    }
}
