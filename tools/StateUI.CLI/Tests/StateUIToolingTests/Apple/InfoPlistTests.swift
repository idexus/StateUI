// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class InfoPlistTests: XCTestCase {
    private static let gallery = ApplicationFile(identifier: "com.stateui.gallery", version: "1.2.3", build: 45)

    /// A bundle's keys are the host's own with the application's laid over, each key whole; its identifier, version
    /// and build are its `stateui.json`'s.
    func testTheApplicationsOwnKeysLieOverTheHosts() throws {
        let own = FileManager.default.temporaryDirectory.appendingPathComponent("own-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: own) }
        let theirs: [String: Any] = [
            "CFBundleDisplayName": "StateUI Gallery",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["stateui-gallery"]]],
        ]
        try PropertyListSerialization.data(fromPropertyList: theirs, format: .xml, options: 0).write(to: own)

        let keys = InfoPlist.macOS(name: "Gallery", product: "GalleryAppKit", identity: Self.gallery, minimumSystem: "26.4")
        let data = try InfoPlist.compose(keys, over: own)
        let plist = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.stateui.gallery")
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "1.2.3")
        XCTAssertEqual(plist["CFBundleVersion"] as? String, "45")
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "StateUI Gallery")
        XCTAssertEqual(plist["CFBundleName"] as? String, "Gallery")
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "GalleryAppKit")
        XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, "26.4")
        XCTAssertEqual(((plist["CFBundleURLTypes"] as? [[String: Any]])?.first?["CFBundleURLSchemes"] as? [String]), ["stateui-gallery"])
        XCTAssertEqual(
            try PropertyListSerialization.propertyList(from: try InfoPlist.compose(keys, over: nil), format: nil) as? NSDictionary,
            keys as NSDictionary)
    }

    /// An iOS bundle's keys say the platform it was built for - a simulator's or a device's - and the many scenes,
    /// both families and every orientation an iPad's windows take, the same keys a head of the baseline had.
    func testAnIOSBundlesKeysSayItsPlatformAndScenes() throws {
        let identity = ApplicationFile(identifier: "com.stateui.helloworld", version: "0.8.5", build: 1)
        let simulator = InfoPlist.iOS(
            name: "HelloWorld", product: "HelloWorldUIKit", identity: identity, minimumSystem: "26.4", platform: .iOSSimulator)
        let device = InfoPlist.iOS(
            name: "HelloWorld", product: "HelloWorldUIKit", identity: identity, minimumSystem: "26.4", platform: .iOS)
        XCTAssertEqual(simulator["CFBundleSupportedPlatforms"] as? [String], ["iPhoneSimulator"])
        XCTAssertEqual(device["CFBundleSupportedPlatforms"] as? [String], ["iPhoneOS"])
        XCTAssertEqual(simulator["CFBundleIdentifier"] as? String, "com.stateui.helloworld")
        XCTAssertEqual([simulator["CFBundleShortVersionString"], simulator["CFBundleVersion"]] as? [String], ["0.8.5", "1"])
        XCTAssertEqual(simulator["MinimumOSVersion"] as? String, "26.4")
        XCTAssertEqual(simulator["UIDeviceFamily"] as? [Int], [1, 2])
        XCTAssertEqual((simulator["UIApplicationSceneManifest"] as? [String: Bool])?["UIApplicationSupportsMultipleScenes"], true)
        XCTAssertEqual((simulator["UISupportedInterfaceOrientations"] as? [String])?.count, 4)
        XCTAssertEqual(Set(simulator.keys), [
            "CADisableMinimumFrameDurationOnPhone", "CFBundleDevelopmentRegion", "CFBundleDisplayName", "CFBundleExecutable",
            "CFBundleIdentifier", "CFBundleInfoDictionaryVersion", "CFBundleName", "CFBundlePackageType",
            "CFBundleShortVersionString", "CFBundleSupportedPlatforms", "CFBundleVersion", "LSRequiresIPhoneOS",
            "MinimumOSVersion", "UIApplicationSceneManifest", "UIDeviceFamily", "UILaunchScreen",
            "UISupportedInterfaceOrientations",
        ])
        XCTAssertNoThrow(try InfoPlist.compose(device, over: nil))
    }

    /// An application's own keys never say what its `stateui.json` says: each of the identifier, version and build
    /// there is refused by its key and its file.
    func testTheApplicationsOwnKeysSayNoIdentity() throws {
        let own = FileManager.default.temporaryDirectory.appendingPathComponent("own-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: own) }
        let keys = InfoPlist.macOS(name: "Gallery", product: "GalleryAppKit", identity: Self.gallery, minimumSystem: "26.4")
        for key in InfoPlist.identityKeys {
            try PropertyListSerialization.data(fromPropertyList: [key: "1"], format: .xml, options: 0).write(to: own)
            XCTAssertThrowsError(try InfoPlist.compose(keys, over: own), key) {
                XCTAssertEqual(($0 as? ToolingError)?.code, .invalidConfiguration)
                XCTAssertTrue(($0 as? ToolingError)?.message.contains(key) == true, "\($0)")
            }
        }
    }
}
