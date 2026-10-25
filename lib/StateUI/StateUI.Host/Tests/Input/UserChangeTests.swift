// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host carries what the user changes: the value a state takes.
@MainActor
final class UserChangeTests: XCTestCase {
    /// A reported value becomes the value a state carries: words as text, flags, numbers, choices and colors as
    /// lanes - a color's four channels as fractions of full, as a color state lays them.
    func testAReportedValueIsTheValueAStateCarries() {
        XCTAssertEqual(HostStateValue(carrying: .string("Ada")), .text("Ada"))
        XCTAssertEqual(HostStateValue(carrying: .name("size")), .text("size"))
        XCTAssertEqual(HostStateValue(carrying: .bool(true)), .lanes([1]))
        XCTAssertEqual(HostStateValue(carrying: .number(0.5)), .lanes([0.5]))
        XCTAssertEqual(HostStateValue(carrying: .numbers([1, 2])), .lanes([1, 2]))
        XCTAssertEqual(HostStateValue(carrying: .enumeration(3)), .lanes([3]))
        XCTAssertEqual(HostStateValue(carrying: .color(red: 255, green: 0, blue: 51, alpha: 255)), .lanes([1, 0, 0.2, 1]))
        XCTAssertEqual(HostStateValue(carrying: Color(hex: 0x336699, opacity: 0.4).propValue),
                       Color(hex: 0x336699, opacity: 0.4).carried)
        XCTAssertNil(HostStateValue(carrying: .nothing))
    }
}
