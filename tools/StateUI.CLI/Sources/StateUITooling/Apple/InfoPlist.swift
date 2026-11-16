// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// An Apple bundle's `Info.plist`: the keys every application's bundle of a host has, with the application's own
/// `Platforms/<Host>/Info.plist` laid over them key by key.
/// Design: docs/design/tooling/apple-bundles.md#infoplist
public enum InfoPlist {
    /// The keys an application's own `Info.plist` never says: its identifier, version and build, its
    /// `stateui.json`'s.
    public static let identityKeys = ["CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion"]

    /// The keys of a macOS application's bundle: its executable `product`, its name shown and spoken, the identifier,
    /// version and build its `stateui.json` says (`identity`), the oldest macOS it runs on, and the icon
    /// `StateUI.icns`.
    public static func macOS(name: String, product: String, identity: ApplicationFile, minimumSystem: String)
        -> [String: Any] {
        [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": name,
            "CFBundleExecutable": product,
            "CFBundleIconFile": "StateUI",
            "CFBundleIdentifier": identity.identifier,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": identity.version,
            "CFBundleVersion": String(identity.build),
            "LSMinimumSystemVersion": minimumSystem,
            "NSHighResolutionCapable": true,
        ]
    }

    /// The keys of an iOS application's bundle for `platform` - a simulator's or a device's: its executable `product`,
    /// its name shown and spoken, the identifier, version and build its `stateui.json` says (`identity`), the oldest
    /// iOS it runs on, both families, every orientation, and many scenes - an iPad's windows.
    public static func iOS(
        name: String, product: String, identity: ApplicationFile, minimumSystem: String, platform: AppleSDK.Platform
    ) -> [String: Any] {
        [
            "CADisableMinimumFrameDurationOnPhone": true,
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": name,
            "CFBundleExecutable": product,
            "CFBundleIdentifier": identity.identifier,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": identity.version,
            "CFBundleSupportedPlatforms": [platform.bundleName],
            "CFBundleVersion": String(identity.build),
            "LSRequiresIPhoneOS": true,
            "MinimumOSVersion": minimumSystem,
            "UIApplicationSceneManifest": ["UIApplicationSupportsMultipleScenes": true],
            "UIDeviceFamily": [1, 2],
            "UILaunchScreen": [String: Any](),
            "UISupportedInterfaceOrientations": [
                "UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
                "UIInterfaceOrientationLandscapeRight", "UIInterfaceOrientationPortraitUpsideDown",
            ],
        ]
    }

    /// `keys` with the dictionary of the property list at `own` laid over - each of its keys replacing the same key
    /// whole - written as an XML property list. No `own`, the keys alone.
    ///
    /// - Throws: An error naming `own` where it holds no dictionary; ``ToolingError`` `INVALID_CONFIGURATION` where it
    ///   says what the application's `stateui.json` says alone (``identityKeys``).
    public static func compose(_ keys: [String: Any], over own: URL?) throws -> Data {
        var composed = keys
        if let own {
            let read = try PropertyListSerialization.propertyList(from: Data(contentsOf: own), format: nil)
            guard let laid = read as? [String: Any] else {
                throw CocoaError(.propertyListReadCorrupt, userInfo: [NSFilePathErrorKey: own.path])
            }
            if let said = identityKeys.first(where: { laid[$0] != nil }) {
                throw ToolingError(
                    .invalidConfiguration, "\(own.path) says \(said), which the application's \(ApplicationFile.name) says alone.")
            }
            composed.merge(laid) { _, theirs in theirs }
        }
        return try PropertyListSerialization.data(fromPropertyList: composed, format: .xml, options: 0)
    }
}
