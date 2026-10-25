// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The color a picker reports, alike on every host: the user's choice at its nearest channels, opaque where the
/// picker does not choose opacity.
final class ColorChoiceTests: XCTestCase {
    func testAChoiceIsReportedAtItsNearestChannels() {
        XCTAssertEqual(ColorChoice.reported((0.2, 0.4, 0.6, 1), choosesOpacity: true), Color(hex: 0x336699))
        XCTAssertEqual(ColorChoice.reported((1.2, -0.1, .nan, 1), choosesOpacity: true), Color(hex: 0xFF0000),
                       "a channel past full held to full, one under nought or no number to none")
    }

    func testOpacityIsReportedOnlyWhereThePickerChoosesIt() {
        XCTAssertEqual(ColorChoice.reported((0.2, 0.4, 0.6, 0.4), choosesOpacity: true),
                       Color(hex: 0x336699, opacity: 0.4))
        XCTAssertEqual(ColorChoice.reported((0.2, 0.4, 0.6, 0.4), choosesOpacity: false), Color(hex: 0x336699),
                       "opaque where the picker does not choose opacity")
    }
}
