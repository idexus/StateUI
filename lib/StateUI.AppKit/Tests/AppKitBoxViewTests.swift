// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitBoxViewTests: XCTestCase {
    @MainActor
    func testAUniformRadiusReachesEveryCorner() {
        let view = AppKitBoxView()

        view.apply(background: .systemYellow, fill: .systemRed, cornerRadius: .number(6))

        XCTAssertTrue(view.backgroundColor.isEqual(NSColor.systemYellow))
        XCTAssertTrue(view.fillColor.isEqual(NSColor.systemRed))
        XCTAssertEqual(
            view.cornerRadii,
            AppKitCornerRadii(topLeft: 6, topRight: 6, bottomLeft: 6, bottomRight: 6))
    }

    @MainActor
    func testFourRadiiKeepStateUIsCornerOrder() {
        let view = AppKitBoxView()

        view.apply(background: nil, fill: nil, cornerRadius: .numbers([1, 2, 3, 4]))

        XCTAssertTrue(view.backgroundColor.isEqual(NSColor.clear))
        XCTAssertTrue(view.fillColor.isEqual(NSColor.clear))
        XCTAssertEqual(
            view.cornerRadii,
            AppKitCornerRadii(topLeft: 1, topRight: 2, bottomLeft: 3, bottomRight: 4))
    }

    @MainActor
    func testInvalidRadiiBecomeSquareCorners() {
        let view = AppKitBoxView()

        view.apply(
            background: nil,
            fill: .systemBlue,
            cornerRadius: .numbers([-1, .infinity, .nan, 8]))

        XCTAssertEqual(
            view.cornerRadii,
            AppKitCornerRadii(topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 8))
    }

    func testOversizedRadiiStillDescribeTheViewsBounds() {
        let bounds = CGRect(x: 5, y: 7, width: 20, height: 10)
        let radii = AppKitCornerRadii(
            topLeft: 80,
            topRight: 70,
            bottomLeft: 60,
            bottomRight: 50)

        XCTAssertEqual(radii.path(in: bounds).boundingBoxOfPath, bounds)
    }
}

#endif
