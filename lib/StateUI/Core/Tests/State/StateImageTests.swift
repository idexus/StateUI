// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@testable import StateUI

/// How a value lies on the image: eight little-endian bytes a lane - every bit of its pattern - or text as its length
/// and UTF-8; and the lanes read back where the bytes stop short.
final class StateImageTests: XCTestCase {
    /// A LANE IS ITS BIT PATTERN, LOWEST BYTE FIRST: one, minus nought and a NaN with a payload of its own.
    func testALaneIsItsBitPatternLowestByteFirst() {
        let payload = Double(bitPattern: 0x7FF8_0000_0000_ABCD)
        XCTAssertEqual(
            StateImage.bytes(of: .lanes([1, -0.0, payload])),
            [0, 0, 0, 0, 0, 0, 0xF0, 0x3F,
             0, 0, 0, 0, 0, 0, 0, 0x80,
             0xCD, 0xAB, 0, 0, 0, 0, 0xF8, 0x7F])
    }

    /// THE LANES COME BACK BIT FOR BIT, and a lane the bytes stop short of is nought in what is missing.
    func testTheLanesComeBackBitForBit() throws {
        let lanes = [1.5, -0.0, Double(bitPattern: 0x7FF8_0000_0000_ABCD), -Double.infinity, .leastNonzeroMagnitude]
        guard case .lanes(let back) = StateImage.carried(of: StateImage.bytes(of: .lanes(lanes)), lanes: 5) else {
            return XCTFail("no lanes")
        }
        XCTAssertEqual(back.map(\.bitPattern), lanes.map(\.bitPattern))

        guard case .lanes(let short) = StateImage.carried(of: [1, 2, 3, 4, 5, 6, 7, 8, 9], lanes: 3) else {
            return XCTFail("no lanes")
        }
        XCTAssertEqual(short.map(\.bitPattern), [0x0807_0605_0403_0201, 9, 0])
        XCTAssertEqual(StateImage.lane(1, of: [1, 2, 3, 4, 5, 6, 7, 8, 9]).bitPattern, 9)
        XCTAssertEqual(StateImage.lane(2, of: [1, 2, 3, 4, 5, 6, 7, 8, 9]).bitPattern, 0)
    }

    /// AN IMAGE OF ITS OWN WIDTH has as many lanes as it has eight bytes.
    func testAnImageOfItsOwnWidthHasAsManyLanesAsEightBytes() {
        guard case .lanes(let lanes) = StateImage.carried(of: StateImage.bytes(of: .lanes([2, 3])), lanes: -1) else {
            return XCTFail("no lanes")
        }
        XCTAssertEqual(lanes, [2, 3])
    }

    /// NUMBERS LAID OVER AN IMAGE go from their lane on, and what runs past its end is left out.
    func testNumbersLaidOverAnImageStopAtItsEnd() {
        var bytes = StateImage.bytes(of: .lanes([0, 0, 0]))
        StateImage.lay([1, 2], at: 2, into: &bytes)

        XCTAssertEqual(bytes.count, 24)
        XCTAssertEqual(StateImage.carried(of: bytes, lanes: 3), .lanes([0, 0, 1]))
    }

    /// TEXT LIES AS ITS LENGTH AND ITS UTF-8.
    func testTextLiesAsItsLengthAndItsUTF8() {
        let bytes = StateImage.bytes(of: .text("żółw"))

        XCTAssertEqual(Array(bytes.prefix(4)), [7, 0, 0, 0])
        XCTAssertEqual(StateImage.carried(of: bytes, lanes: 0), .text("żółw"))
    }
}
