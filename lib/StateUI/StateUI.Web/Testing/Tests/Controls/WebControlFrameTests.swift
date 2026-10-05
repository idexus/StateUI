// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// What the browser draws over its whole box - a checkbox, a switch, an activity ring - stands at its own size inside
/// the frame its layout gives its view: the frame lands on the view's element, and none of it on the drawn one.
@MainActor
final class WebControlFrameTests: XCTestCase {
    /// A touch target's 44 points, given as the frame's least size, stretch no checkbox, switch or ring.
    func testADrawnControlTakesNoSizeOfItsFrame() {
        let layout = WebLayoutView(arrangement: .stack(.horizontal))
        let views: [WebDOMView] = [WebSwitchView(switch: false), WebSwitchView(switch: true), WebActivityView()]
        defer { for view in [layout] + views { view.detach() } }
        var framed = LayoutValues()
        framed.minimumWidth = 44
        framed.minimumHeight = 44
        layout.setItems(views.map { ($0, framed) })

        for view in views {
            XCTAssertEqual(WebPage.style(of: view.node, "min-width"), "44px", "the frame lands on the view")
            let drawn = WebPage.children(of: view.node)
            XCTAssertEqual(drawn.count, 1, "the view holds what the browser draws")
            guard let control = drawn.first else { continue }
            for size in ["width", "height", "min-width", "min-height"] {
                XCTAssertEqual(WebPage.style(of: control, size), "", "the drawn control takes no \(size) of the frame")
            }
        }
    }
}
