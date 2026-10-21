// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A color as a toolkit holds it - one ARGB number, or four fractions of full - read and written the same on every
/// host.
final class ColorComponentTests: XCTestCase {
    /// A color packed in one number unpacks to its channels, alpha highest.
    func testAColorPackedInOneNumberUnpacks() {
        XCTAssertEqual(Color(argb: 0x80FF_4020), Color(red: 255, green: 64, blue: 32, alpha: 128))
        XCTAssertEqual(Color(argb: 0), Color(red: 0, green: 0, blue: 0, alpha: 0))
        XCTAssertEqual(Color(argb: 0xFFFF_FFFF), Color(red: 255, green: 255, blue: 255))
    }

    /// A color in fractions of full stands at its nearest channels, held to the range; what is no number is none.
    func testAColorInFractionsStandsAtItsNearestChannels() {
        XCTAssertEqual(Color(fractions: (1, 0.5, 0, 0.25)), Color(red: 255, green: 128, blue: 0, alpha: 64))
        XCTAssertEqual(Color(fractions: (2, -1, .nan, 1)), Color(red: 255, green: 0, blue: 0))
    }

    /// A color's channels as fractions of full, and back to the very same channels, for every channel there is.
    func testEveryChannelGoesToItsFractionAndBack() throws {
        let fractions = try XCTUnwrap(PropValue.color(red: 255, green: 51, blue: 0, alpha: 128).fractions)
        XCTAssertEqual(fractions.red, 1)
        XCTAssertEqual(fractions.green, 0.2, accuracy: 1e-12)
        XCTAssertEqual(fractions.blue, 0)
        XCTAssertEqual(fractions.alpha, 128 / 255.0, accuracy: 1e-12)
        XCTAssertNil(PropValue.number(1).fractions, "no color")

        for channel in UInt8.min...UInt8.max {
            XCTAssertEqual(ColorComponent.nearest(ColorComponent.fraction(channel)), channel)
        }
    }
}
