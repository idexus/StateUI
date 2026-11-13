// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// An Apple bundle's `Info.plist`: the keys every application's bundle of a host has, with the application's own
/// `Platforms/<Host>/Info.plist` laid over them key by key.
/// Design: docs/design/tooling/apple-bundles.md#infoplist
public enum InfoPlist {
    /// The keys of a macOS application's bundle: its executable `product`, identifier `com.stateui.<name>`, its name
    /// shown and spoken, StateUI's `release`, the oldest macOS it runs on, and the icon `StateUI.icns`.
    public static func macOS(name: String, product: String, release: String, minimumSystem: String) -> [String: Any] {
        [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": name,
            "CFBundleExecutable": product,
            "CFBundleIconFile": "StateUI",
            "CFBundleIdentifier": "com.stateui.\(name.lowercased())",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": release,
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": minimumSystem,
            "NSHighResolutionCapable": true,
        ]
    }

    /// `keys` with the dictionary of the property list at `own` laid over - each of its keys replacing the same key
    /// whole - written as an XML property list. No `own`, the keys alone.
    ///
    /// - Throws: An error naming `own` where it holds no dictionary.
    public static func compose(_ keys: [String: Any], over own: URL?) throws -> Data {
        var composed = keys
        if let own {
            let read = try PropertyListSerialization.propertyList(from: Data(contentsOf: own), format: nil)
            guard let laid = read as? [String: Any] else {
                throw CocoaError(.propertyListReadCorrupt, userInfo: [NSFilePathErrorKey: own.path])
            }
            composed.merge(laid) { _, theirs in theirs }
        }
        return try PropertyListSerialization.data(fromPropertyList: composed, format: .xml, options: 0)
    }
}
