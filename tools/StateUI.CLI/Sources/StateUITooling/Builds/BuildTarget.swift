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

    enum Signing: Sendable {
        case adHoc
        #if os(macOS)
        case development(DevelopmentSigning)
        #endif
    }

    /// The target of an AppKit head for `architecture`: this Mac's SDK, a triple where it is not the machine's own.
    static func appKit(_ architecture: Architecture, machine: Architecture) async -> BuildTarget {
        BuildTarget(
            architecture: architecture, sdk: await AppleSDK.find(.macOS),
            arguments: architecture == machine ? [] : ["--triple", AppleSDK.Platform.macOS.triple(architecture, floor: Doctor.appleFloor)])
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
