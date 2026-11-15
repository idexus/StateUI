// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A box blurring what lies behind it stops blurring as its look says another: a color, a gradient's outline, none -
/// read off the page's own element.
@MainActor
final class WebBoxBlurTests: XCTestCase {
    func testABlurGoesWithTheLookThatSaidIt() throws {
        let blur = WebBox(material: HostMaterial(Material.blur(.thin).propValue))
        let gradient = Brush.linearGradient([GradientStop(.red, 0), GradientStop(.blue, 1)]).propValue
        let looks = [
            WebBox(fill: Material.color(.red).propValue), WebBox(stroke: gradient, lineWidth: 2), WebBox(),
        ]
        let view = WebDOMView(tag: "div")
        defer { view.release() }

        let filter = { try WebBrowser.evaluate("e.style.backdropFilter || e.style.webkitBackdropFilter", on: view.node) }
        for look in looks {
            view.setBox(blur)
            XCTAssertEqual(try filter(), "blur(18px) saturate(180%)")
            view.setBox(look)
            XCTAssertNil(try filter(), "\(look)")
        }
    }
}
