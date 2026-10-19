// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// What the Web wrote of its register by hand.
final class WebRegisterTests: XCTestCase {
    /// What this host wrote of its register by hand is true of the contracts: no record names what its owner does
    /// not wear, none is written twice, a partial one says what is missing and a never says why.
    @MainActor
    func testTheRegisterThisHostWroteIsTrueOfTheContracts() {
        XCTAssertEqual(WebRealization.register.problems, [])
    }
}
