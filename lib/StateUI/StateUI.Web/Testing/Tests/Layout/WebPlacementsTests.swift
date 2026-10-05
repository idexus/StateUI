// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A child the browser lays out somewhere new travels there from where it stood, by the host layer's layout motion.
@MainActor
final class WebPlacementsTests: XCTestCase {
    private var now = 0.0
    private let animator = Animator()
    private lazy var motion = LayoutMotion(animator: animator, now: { [unowned self] in now }, reducesMotion: { false })
    private let placements = WebPlacements()

    /// A stack of two children, standing where the page laid them out, under a motion of 200 ms.
    private func stack() -> (WebLayoutView, WebDOMView, WebDOMView) {
        let layout = WebLayoutView(arrangement: .stack(.vertical))
        let (first, second) = (WebDOMView(tag: "div"), WebDOMView(tag: "div"))
        motion.applicationMotion = .eased(200, .linear)
        layout.placing = placements
        layout.places.layoutMotion = motion
        placements.follow(layout)
        WebPage.layOut(layout.node, at: Rect(x: 0, y: 0, width: 100, height: 100))
        layout.setItems([first, second].map { ($0, LayoutValues()) }, travellers: [(1, nil), (2, nil)])
        WebPage.layOut(first.node, at: Rect(x: 0, y: 0, width: 100, height: 40))
        WebPage.layOut(second.node, at: Rect(x: 0, y: 40, width: 100, height: 40))
        placements.settle()
        return (layout, first, second)
    }

    private func frame(at time: Double) {
        now = time
        motion.follow(animator.advance(to: time))
        placements.settle()
    }

    /// The second child laid out 60 points lower is drawn where it stood, halfway there at half the time, and at
    /// rest where the page laid it out, drawn over nothing.
    func testAChildLaidOutElsewhereTravelsFromWhereItStood() {
        let (layout, first, second) = stack()
        defer { for view in [layout, first, second] { view.detach() } }
        XCTAssertEqual(WebPage.style(of: second.node, "transform"), "", "the first arrangement arrives")

        placements.beforeChange()
        layout.places.patchArrived()
        layout.setItems([first, second].map { ($0, LayoutValues()) }, travellers: [(1, nil), (2, nil)])
        WebPage.layOut(second.node, at: Rect(x: 0, y: 100, width: 100, height: 40))
        placements.settle()
        XCTAssertEqual(WebPage.style(of: second.node, "transform"), "translate(0px, -60px)")
        XCTAssertEqual(WebPage.style(of: first.node, "transform"), "", "a child the page left in place stands")

        frame(at: 100)
        XCTAssertEqual(WebPage.style(of: second.node, "transform"), "translate(0px, -30px)")

        frame(at: 200)
        XCTAssertEqual(WebPage.style(of: second.node, "transform"), "")
    }

    /// A child laid out wider is drawn at the widths it passes through, its end margin keeping its slot's room; at
    /// rest its own CSS stands again.
    func testAChildLaidOutWiderGrowsInsideItsSlot() {
        let (layout, first, second) = stack()
        defer { for view in [layout, first, second] { view.detach() } }

        placements.beforeChange()
        layout.places.patchArrived()
        layout.setItems([first, second].map { ($0, LayoutValues()) }, travellers: [(1, nil), (2, nil)])
        WebPage.layOut(first.node, at: Rect(x: 0, y: 0, width: 200, height: 40))
        placements.settle()
        frame(at: 100)

        XCTAssertEqual(WebPage.style(of: first.node, "width"), "150px")
        XCTAssertEqual(WebPage.style(of: first.node, "margin-inline-end"), "calc(0px + 50px)")

        frame(at: 200)
        XCTAssertEqual(WebPage.style(of: first.node, "width"), "")
        XCTAssertEqual(WebPage.style(of: first.node, "margin-inline-end"), "")
    }
}
