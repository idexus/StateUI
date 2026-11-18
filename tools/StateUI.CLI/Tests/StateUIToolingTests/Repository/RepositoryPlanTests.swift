// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

/// The plans of a checkout's suites.
final class RepositoryPlanTests: XCTestCase {
    /// The portable plan holds the owner packages in their order; the native one the host suites a machine runs, on a
    /// Mac the applications built as AppKit heads after AppKit's.
    func testAPlanHoldsItsSuitesInOrder() {
        XCTAssertEqual(RepositoryPlan.portable.map(\.0), ["core", "host-layer", "conformance", "testing", "gallery", "helloworld", "tool"])
        XCTAssertEqual(RepositoryPlan.native(on: "macos"), ["host:appkit", "apps:appkit", "host:uikit", "host:android", "host:web"])
        XCTAssertEqual(RepositoryPlan.native(on: "linux"), ["host:gtk", "host:web"])
        XCTAssertEqual(RepositoryPlan.native(on: "windows"), ["host:winui"])
    }

    /// A device a native plan is given goes to the host it is a device of - an iPhone's name to UIKit's suite, an
    /// Android serial to Android's - the other host taking its own; a name of neither's is refused.
    func testADeviceGoesToItsHostAlone() throws {
        let uikit = [Destination(id: "C899", udid: "C899", name: "iPhone 18 Pro", kind: .simulator, version: "27.0")]
        let android = [Destination(id: "190a991d", udid: "190a991d", name: "CPH2363", kind: .device, version: "15")]
        XCTAssertEqual(try RepositoryPlan.devices("iPhone 18 Pro", uikit: uikit, android: android), [.uikit: "iPhone 18 Pro"])
        XCTAssertEqual(try RepositoryPlan.devices("C899", uikit: uikit, android: android), [.uikit: "C899"])
        XCTAssertEqual(try RepositoryPlan.devices("190a991d", uikit: uikit, android: android), [.android: "190a991d"])
        XCTAssertEqual(try RepositoryPlan.devices(nil, uikit: uikit, android: android), [:])
        XCTAssertThrowsError(try RepositoryPlan.devices("Pixel 9", uikit: uikit, android: android))
    }
}
