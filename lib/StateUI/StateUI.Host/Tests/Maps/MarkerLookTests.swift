// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A marker of each kind wears one hue and one symbol on every host drawing it.
final class MarkerLookTests: XCTestCase {
    func testEachKindWearsItsHueAndSymbol() {
        XCTAssertEqual(MarkerLook(.generic), MarkerLook(hue: .red, sfSymbol: nil))
        XCTAssertEqual(MarkerLook(.place), MarkerLook(hue: .blue, sfSymbol: "building.2.fill"))
        XCTAssertEqual(MarkerLook(.saved), MarkerLook(hue: .yellow, sfSymbol: "star.fill"))
        XCTAssertEqual(MarkerLook(.searchResult), MarkerLook(hue: .purple, sfSymbol: "magnifyingglass"))
    }
}
