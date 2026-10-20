// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What a host shows as unsupported, decided the same on every host from what its registry makes.
@MainActor
final class UnsupportedTests: XCTestCase {
    /// An element no registration makes shows as unsupported, unless it is a page or an arrangement of pages, an
    /// overlay, or something presented with no view of its own.
    func testWhatNoRegistrationMakesShowsAsUnsupported() {
        let registry = DrawnChildrenTests.registry

        XCTAssertFalse(registry.showsUnsupported(ShelfContract.nodeType), "made by its registration")
        XCTAssertTrue(registry.showsUnsupported(.slider), "made by none")
        XCTAssertFalse(registry.showsUnsupported(.page), "a page")
        XCTAssertFalse(registry.showsUnsupported(.navigationStack), "an arrangement of pages")
        XCTAssertFalse(registry.showsUnsupported(.overlay))
        XCTAssertFalse(registry.showsUnsupported(.toolbarItem), "presented with no view of its own")
    }
}
