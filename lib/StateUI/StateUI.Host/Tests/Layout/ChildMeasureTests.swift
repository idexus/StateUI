// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How a layout measures a child, the same on every host.
@MainActor
final class ChildMeasureTests: XCTestCase {
    /// A stated width is the width a child is measured at, within its bounds; with none, the offer, no wider than
    /// its most width.
    func testAChildIsOfferedItsStatedWidthElseTheOfferWithinItsMost() {
        var values = LayoutValues()
        values.width = 120
        values.maximumWidth = 80
        XCTAssertEqual(values.offer(300), 80)

        values.width = nil
        XCTAssertEqual(values.offer(300), 80)
        XCTAssertEqual(values.offer(50), 50)
        values.maximumWidth = nil
        XCTAssertNil(values.offer(nil))
    }

    /// A child stating a width is measured at the width it is placed at: within its bounds and the room offered,
    /// so its words wrap where they stand - a toolkit measuring until its layout settles (WinUI) gives up on a child
    /// measured at one width and placed at another.
    func testAChildStatingAWidthIsMeasuredAtTheWidthItIsPlacedAt() {
        var values = LayoutValues()
        for stated in [30.0, 120, 416, 504] {
            for (minimum, maximum) in [(nil, nil), (60.0, nil), (nil, 80.0), (60.0, 80.0)] as [(Double?, Double?)] {
                for room in [100.0, 416] {
                    values.width = stated
                    values.minimumWidth = minimum
                    values.maximumWidth = maximum
                    let placed = Extent.of(
                        option: values.horizontal, stated: stated, natural: 0, available: room,
                        minimum: minimum, maximum: maximum)
                    XCTAssertEqual(values.offer(room), placed, "\(stated) stated, \(room) offered")
                }
            }
        }
        values.width = 504
        values.minimumWidth = nil
        values.maximumWidth = nil
        XCTAssertEqual(values.offer(nil), 504, "with no room said, its own width")
    }

    /// A child stating no width is measured at the width it is placed at too: words filling their lines wrap where
    /// they stand, whatever its bounds say - a least width past its most one winning, as it wins its place.
    func testAChildStatingNoWidthIsMeasuredAtTheWidthItIsPlacedAt() {
        var values = LayoutValues()
        /// Words filling whatever width they are offered, five hundred points of them in lines ten high.
        func words(_ width: Double?) -> LayoutSize {
            let wide = width ?? 500
            return LayoutSize(width: wide, height: (500 / wide).rounded(.up) * 10)
        }
        for (minimum, maximum) in [(nil, 80.0), (60.0, 80.0), (100.0, 20.0), (100.0, nil)] as [(Double?, Double?)] {
            for room in [50.0, 300] {
                values.minimumWidth = minimum
                values.maximumWidth = maximum
                let offered = values.offer(room)
                let placed = values.sized(words(offered))
                XCTAssertEqual(offered, placed.width, "\(minimum ?? 0)...\(maximum ?? .infinity) in \(room)")
                XCTAssertEqual(placed.height, words(placed.width).height, "wrapped where it stands")
            }
        }
    }

    /// A child's size is its stated size before what it measured, within its bounds.
    func testAChildsSizeIsItsStatedSizeBeforeItsMeasuredOne() {
        var values = LayoutValues()
        values.height = 40
        values.minimumWidth = 30
        let size = values.sized(LayoutSize(width: 10, height: 99))
        XCTAssertEqual(size.width, 30)
        XCTAssertEqual(size.height, 40)
    }
}
