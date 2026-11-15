// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class AppleSDKTests: XCTestCase {
    /// A simulator's head and a device's are built for triples and SDKs of their own, so in contexts of their own -
    /// one application, one compiler, two scratch folders.
    func testASimulatorsBuildAndADevicesAreContextsOfTheirOwn() {
        XCTAssertEqual(AppleSDK.Platform(.simulator).triple(.arm64, floor: "26.4"), "arm64-apple-ios26.4-simulator")
        XCTAssertEqual(AppleSDK.Platform(.device).triple(.arm64, floor: "26.4"), "arm64-apple-ios26.4")
        XCTAssertEqual(AppleSDK.Platform.macOS.triple(.x86_64, floor: "26.4"), "x86_64-apple-macosx26.4")
        XCTAssertEqual(AppleSDK.Platform(.simulator).bundleName, "iPhoneSimulator")
        XCTAssertEqual(AppleSDK.Platform(.device).bundleName, "iPhoneOS")

        let simulator = AppleSDK(platform: .iOSSimulator, version: "27.1", path: "/Xcode/iPhoneSimulator.sdk")
        let device = AppleSDK(platform: .iOS, version: "27.1", path: "/Xcode/iPhoneOS.sdk")
        let context = { (sdk: AppleSDK) in
            BuildContext(
                application: URL(fileURLWithPath: "/Apps/Notes"), product: "NotesUIKit", host: .uikit, configuration: .debug,
                architecture: .arm64, compiler: "Swift version 6.4.2", sdk: sdk.identity, library: URL(fileURLWithPath: "/StateUI"))
        }
        XCTAssertNotEqual(context(simulator).scratch, context(device).scratch)
        XCTAssertEqual(context(simulator).scratch, context(simulator).scratch)
    }

    #if os(macOS)
    /// The selected Xcode holds the macOS SDK and both of iOS's.
    func testTheSelectedXcodeHoldsTheSDKsAHeadNeeds() async throws {
        for platform in [AppleSDK.Platform.macOS, .iOSSimulator, .iOS] {
            let found = await AppleSDK.find(platform)
            let sdk = try XCTUnwrap(found, "\(platform)")
            XCTAssertTrue(sdk.path.hasSuffix(".sdk"), sdk.path)
            XCTAssertFalse(sdk.version.isEmpty)
        }
    }
    #endif
}
