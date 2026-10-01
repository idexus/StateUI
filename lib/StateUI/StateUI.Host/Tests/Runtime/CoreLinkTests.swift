// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What a runtime tells the core through its one line.
final class CoreLinkTests: XCTestCase {
    override func tearDown() {
        HostBoundary.setRealization(HostRealization())
        super.tearDown()
    }

    /// A runtime says its registry and the library's elements it shows none of: every other element of the library's
    /// is realized, and so is what the registry names.
    func testARuntimeRealizesTheLibrarysElementsButThoseItNames() {
        CoreLink().setRealization(
            HostRealization(
                elements: ["Label", "Test.Lamp"],
                members: [HostRealizedMember(element: "Application", owner: "Test", member: "Test.BatteryChanged")]),
            unrealized: ["Map"])

        XCTAssertNil(HostRealizations.unrealized(ButtonContract.nodeType))
        XCTAssertNil(HostRealizations.unrealized(PageContract.nodeType))
        XCTAssertNil(HostRealizations.unrealized("Test.Lamp"))
        XCTAssertEqual(HostRealizations.unrealized(MapContract.nodeType), "the host realizes no `Map`.")
        XCTAssertNil(HostRealizations.unraised(owner: "Test", event: "Test.BatteryChanged"))
    }
}
