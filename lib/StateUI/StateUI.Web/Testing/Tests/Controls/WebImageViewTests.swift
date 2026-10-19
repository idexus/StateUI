// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A picture filling its room reaches two pixels past each edge, under its parent's clip: WebKit draws a covering
/// picture rounded inward, and what is laid over it would show at the seam. A drawing filling it holds no size of
/// its own, which WebKit would draw it at.
@MainActor
final class WebImageViewTests: XCTestCase {
    func testAFillingPictureReachesPastEachEdge() {
        let layout = WebLayoutView(arrangement: .grid)
        let picture = WebImageView()
        defer { for view in [layout, picture] { view.detach() } }
        picture.apply(picture: nil, aspect: .fill)
        layout.setItems([(picture, { LayoutValues() })])

        XCTAssertEqual(WebPage.style(of: picture.node, "margin-block-end"), "-2px", "two pixels past its bottom")
        XCTAssertEqual(WebPage.style(of: picture.node, "margin-inline-start"), "-2px", "and past its start")
        XCTAssertEqual(WebPage.style(of: picture.node, "max-height"), "calc(100% + 4px)", "no room holds it back")

        picture.apply(picture: nil, aspect: .fit)
        XCTAssertEqual(WebPage.style(of: picture.node, "margin-block-end"), "", "a fitted picture stands in its room")
        XCTAssertEqual(WebPage.style(of: picture.node, "max-height"), "100%")
    }

    /// A PICTURE IS NOT THE BROWSER'S TO DRAG: a native picture moves with nothing until the application offers a
    /// drag, and the browser's own - the photo under a hand or two fingers dragged off as a ghost - takes the pointer
    /// away from what the user moves.
    func testAPictureIsNotTheBrowsersToDrag() {
        let picture = WebImageView()
        defer { picture.detach() }

        XCTAssertEqual(WebPage.attribute(of: picture.node, "draggable"), "false")
    }

    /// A FILLING DRAWING HOLDS NO SIZE OF ITS OWN: WebKit, holding an SVG's size, lays its drawing out at the box's
    /// and fits it whole inside it, so `cover` covers nothing - a portrait drawing in a square room stood narrow, its
    /// room's rounded corners clipping nothing. A fitted drawing, and a filling bitmap, hold their size.
    func testAFillingDrawingHoldsNoSizeOfItsOwn() {
        let picture = WebImageView()
        defer { picture.detach() }

        picture.apply(picture: .file("card.svg"), aspect: .fill)
        XCTAssertEqual(WebPage.style(of: picture.node, "contain"), "none", "a drawing covering its room")

        picture.apply(picture: .file("card.svg"), aspect: .fit)
        XCTAssertEqual(WebPage.style(of: picture.node, "contain"), "", "a drawing fitted in it")

        picture.apply(picture: .file("photo.jpg"), aspect: .fill)
        XCTAssertEqual(WebPage.style(of: picture.node, "contain"), "", "a bitmap covering it")
    }
}
