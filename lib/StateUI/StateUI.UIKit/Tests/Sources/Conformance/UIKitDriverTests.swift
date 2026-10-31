// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
@_spi(Host) import StateUIHost
import XCTest

/// What the conformance driver reads of a page is what the display's next pass shows.
@MainActor
final class UIKitDriverTests: XCTestCase {
    /// A place is read where UIKit lays the view out: a view a change moved, which no pass of UIKit's has laid out
    /// yet, is read where it goes.
    func testAPlaceIsReadWhereUIKitLaysTheViewOut() throws {
        let driver = UIKitDriver()
        defer { driver.finish() }
        let clock = TestClock()
        let width = State(wrappedValue: 40.0)
        let tree = driver.start(clock: clock, reducesMotion: false) {
            HStack {
                Rectangle()
                    .fill(.red)
                    .width(width.projectedValue)
                    .height(40)
                Rectangle()
                    .fill(.blue)
                    .width(40)
                    .height(40)
                    .id("after")
            }
            .spacing(0)
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        let after = try XCTUnwrap(tree.root?.first(id: .manual("after")))
        let start = try driver.place(of: after).x

        width.wrappedValue = 100
        for _ in 0..<12 {
            clock.now += 16
            driver.frame()
        }
        XCTAssertEqual(try driver.place(of: after).x - start, 60, accuracy: 0.5)
    }
}
