// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

@MainActor
final class GTKPixelBoundsTests: XCTestCase {
    /// A size GTK cannot hold - finite, but past its 32-bit pixels - stands empty, and the tree goes on past it.
    func testAViewWiderThanGTKHoldsStandsEmptyAndTheTreeGoesOn() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Text("wide").width(3e9)
                    Text("after")
                }
            }
            XCTAssertEqual(host.views(GTKTextView.self).count, 2, "the tree stood past the unholdable width")
        }
    }

    /// GTK's pixels: sizes and coordinates within 32 bits, a margin within the 16 GTK keeps of it.
    func testPixelsKeepWithinWhatGTKHolds() {
        XCTAssertEqual(GTKPixels.size(12.4), 12)
        XCTAssertEqual(GTKPixels.size(12.2, rounding: .up), 13)
        for points in [3e9, -5, .nan, .infinity] {
            XCTAssertEqual(GTKPixels.size(points), 0, "\(points)")
        }
        XCTAssertEqual(GTKPixels.distance(-7.6, rounding: .up), -7)
        XCTAssertEqual(GTKPixels.distance(-3e9), 0)
        XCTAssertEqual(GTKPixels.margin(Double(Int16.max)), Int32(Int16.max))
        XCTAssertEqual(GTKPixels.margin(Double(Int16.max) + 1), 0, "GTK refuses a margin past 16 bits")
    }
}
