// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

/// An Apple platform's SDK a head is built against - this Mac's, the iOS simulator's, or the iPhones' and iPads' -
/// each a build context of its own.
/// Design: docs/design/tooling/destinations.md#a-destinations-sdk
public struct AppleSDK: Equatable, Sendable {
    /// The platform an SDK builds for, by the name `xcrun --sdk` takes.
    public enum Platform: String, Sendable {
        case macOS = "macosx"
        case iOSSimulator = "iphonesimulator"
        case iOS = "iphoneos"

        /// The platform a destination of `kind` runs: a simulator's or a device's.
        public init(_ kind: Destination.Kind) {
            self = kind == .simulator ? .iOSSimulator : .iOS
        }

        /// What a bundle's `CFBundleSupportedPlatforms` names it.
        public var bundleName: String {
            switch self {
            case .macOS: "MacOSX"
            case .iOSSimulator: "iPhoneSimulator"
            case .iOS: "iPhoneOS"
            }
        }

        /// The triple a build for `architecture` targets, the oldest system it runs on `floor`.
        public func triple(_ architecture: Architecture, floor: String) -> String {
            switch self {
            case .macOS: "\(architecture.rawValue)-apple-macosx\(floor)"
            case .iOSSimulator: "\(architecture.rawValue)-apple-ios\(floor)-simulator"
            case .iOS: "\(architecture.rawValue)-apple-ios\(floor)"
            }
        }
    }

    public var platform: Platform
    /// Its version: `27.1`.
    public var version: String
    /// Its folder, which `swift build --sdk` takes.
    public var path: String

    /// The SDK of `platform`, `version`, at `path`.
    public init(platform: Platform, version: String, path: String) {
        self.platform = platform
        self.version = version
        self.path = path
    }

    /// What a build's context knows it by: its platform, version and folder.
    public var identity: String { "\(platform.rawValue) \(version) \(path)" }

    /// The SDK of `platform` the selected Xcode holds, or `nil` where it holds none.
    public static func find(_ platform: Platform) async -> AppleSDK? {
        let asked = { (what: String) async -> String? in
            await ToolOutput.standardOutput(.name("xcrun"), ["--sdk", platform.rawValue, what])?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let version = await asked("--show-sdk-version"), !version.isEmpty,
              let path = await asked("--show-sdk-path"), !path.isEmpty
        else { return nil }
        return AppleSDK(platform: platform, version: version, path: path)
    }
}
