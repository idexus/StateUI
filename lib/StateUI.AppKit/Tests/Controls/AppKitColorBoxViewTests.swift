// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
import XCTest

final class AppKitColorBoxViewTests: XCTestCase {
    /// The box's colours reach the view, and its corners stand clockwise from the top left, as the host layer reads
    /// them.
    @MainActor
    func testTheCornersStandClockwise() {
        let view = AppKitColorBoxView()

        view.apply(background: .systemYellow, fill: .systemRed, corners: .corners(topLeft: 1, topRight: 2, bottomLeft: 3, bottomRight: 4))

        XCTAssertTrue(view.backgroundColor.isEqual(NSColor.systemYellow))
        XCTAssertTrue(view.fillColor.isEqual(NSColor.systemRed))
        XCTAssertEqual(view.radii, [1, 2, 4, 3])
    }

    /// Corners larger than the box round no more than half the side each rounds, so the outline stays the box's.
    func testOversizedRadiiStillDescribeTheViewsBounds() {
        let bounds = CGRect(x: 5, y: 7, width: 20, height: 10)

        let path = AppKitCorners.path(in: bounds, clockwise: [80, 70, 50, 60])

        XCTAssertEqual(path.boundingBoxOfPath, bounds)
    }
}

#endif
