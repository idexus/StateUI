// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidItemCellTests: XCTestCase {
    static var allTests: [(String, (AndroidItemCellTests) -> () throws -> Void)] {
        [
            ("testAChosenItemIsDrawnOnTheAccentAtAFifth", testAChosenItemIsDrawnOnTheAccentAtAFifth),
        ]
    }

    /// A chosen item stands on a band of the theme's accent at a fifth of its strength; one not chosen on nothing.
    func testAChosenItemIsDrawnOnTheAccentAtAFifth() {
        onMainActor {
            _ = AndroidRenderer.running { Text("Cells") }
            let cell = AndroidItemCell(item: true)
            let accent = UInt32(bitPattern: Java.callStaticInt(
                JavaAPI.environment, JavaAPI.accent, .object(AndroidRenderer.context)))

            Java.call(cell.reference, TestJava.setActivated, .bool(true))
            XCTAssertEqual(Self.band(of: cell), accent & 0x00FF_FFFF | 0x3300_0000)

            Java.call(cell.reference, TestJava.setActivated, .bool(false))
            XCTAssertNil(Self.band(of: cell))
        }
    }

    /// The color the cell's background draws as it stands now; nil for none.
    @MainActor
    private static func band(of cell: AndroidItemCell) -> UInt32? {
        Java.frame {
            guard let background = Java.callObject(cell.reference, TestJava.getBackground),
                  let current = Java.callObject(background, TestJava.getCurrent)
            else { return nil }
            return UInt32(bitPattern: Java.callInt(current, TestJava.getColor))
        }
    }
}
