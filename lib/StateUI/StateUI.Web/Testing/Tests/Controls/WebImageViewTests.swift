// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A picture filling its room reaches two pixels past each edge, under its parent's clip: WebKit draws a covering
/// picture rounded inward, and what is laid over it would show at the seam.
@MainActor
final class WebImageViewTests: XCTestCase {
    func testAFillingPictureReachesPastEachEdge() {
        let layout = WebLayoutView(arrangement: .grid)
        let picture = WebImageView()
        defer { for view in [layout, picture] { view.detach() } }
        picture.apply(source: nil, aspect: .fill)
        layout.setItems([(picture, LayoutValues())])

        XCTAssertEqual(WebPage.style(of: picture.node, "margin-block-end"), "-2px", "two pixels past its bottom")
        XCTAssertEqual(WebPage.style(of: picture.node, "margin-inline-start"), "-2px", "and past its start")
        XCTAssertEqual(WebPage.style(of: picture.node, "max-height"), "calc(100% + 4px)", "no room holds it back")

        picture.apply(source: nil, aspect: .fit)
        XCTAssertEqual(WebPage.style(of: picture.node, "margin-block-end"), "", "a fitted picture stands in its room")
        XCTAssertEqual(WebPage.style(of: picture.node, "max-height"), "100%")
    }
}
