// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// A whole number crossing to the host where an `Int` has 32 bits.
final class WebWholeNumberTests: XCTestCase {
    /// AN INT ON THE WEB IS NEVER PAST 2^53: it has 32 bits, so every one crosses whole and nothing is said - where
    /// shifting one 53 places in 32 bits measured nought, every whole number but nought was said past it.
    @MainActor
    func testAWholeNumberCrossesWholeOnTheWeb() {
        _ = 1.carried
        _ = Int.max.propValue

        XCTAssertFalse(hasComplained("past 2^53"))
    }

    /// A READING HELD BACK LONGER THAN AN INT COUNTS IN MILLISECONDS - past twenty-four days on the Web - is held
    /// back the longest it counts; one just inside is its own.
    func testALongCadenceIsTheLongestAnIntHolds() {
        XCTAssertEqual(Cadence.every(.milliseconds(Int64(Int32.max))).window, Int(Int32.max))
        XCTAssertEqual(Cadence.every(.seconds(30 * 86_400)).window, Int.max, "thirty days")
        XCTAssertEqual(Cadence.every(.seconds(Int64.max)).window, Int.max)
    }
}
