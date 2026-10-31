// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A toggle's words stand beside it in its `<label>`, so they name it and a click on them turns it. The browser lays
/// out, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebToggleTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// A switch's words stand at its start and the switch at its end; a check box's after its box; and a click on
    /// a switch's words turns it.
    func testATogglesWordsStandBesideIt() throws {
        let on = State(wrappedValue: false)
        let host = WebRenderer.running {
            VStack {
                Switch(on.projectedValue).text("Wi-Fi").width(300)
                CheckBox(true).text("agree").textCase(.uppercase).width(300)
            }
            .horizontalAlignment(.start)
        }
        let toggles = host.views(WebSwitchView.self)
        XCTAssertEqual(toggles.count, 2)
        guard toggles.count == 2 else { return }
        let (toggle, box) = (toggles[0], toggles[1])
        host.settle { (try? Self.place(of: "input", in: toggle)) ?? 0 > 0.5 }

        XCTAssertEqual(try WebBrowser.evaluate("e.textContent", on: toggle.node), "Wi-Fi")
        XCTAssertEqual(try WebBrowser.evaluate("e.textContent", on: box.node), "AGREE")
        XCTAssertGreaterThan(try Self.place(of: "input", in: toggle), 0.8, "the switch at the end")
        XCTAssertLessThan(try Self.place(of: "span", in: toggle), 0.5, "the words from the start")
        XCTAssertLessThan(try Self.place(of: "input", in: box), 0.2, "the box at the start")
        XCTAssertEqual(
            try WebBrowser.evaluate("e.querySelector('input').labels[0].textContent", on: toggle.node), "Wi-Fi",
            "the words label the switch")

        _ = try WebBrowser.evaluate("(e.querySelector('span').click(), null)", on: toggle.node)
        host.settle { on.wrappedValue }
        XCTAssertTrue(on.wrappedValue, "a click on the words turns it")
    }

    /// Right to left, a switch's words stand at its start on the right and the switch at its end on the left.
    func testASwitchsWordsMirrorRightToLeft() throws {
        let host = WebRenderer.running {
            VStack { Switch(false).text("Wi-Fi").width(300) }
                .layoutDirection(.rightToLeft)
                .horizontalAlignment(.start)
        }
        let toggle = try XCTUnwrap(host.views(WebSwitchView.self).first)
        host.settle { (try? Self.place(of: "input", in: toggle)) ?? 1 < 0.5 }

        XCTAssertLessThan(try Self.place(of: "input", in: toggle), 0.2, "the switch at the end, on the left")
        XCTAssertGreaterThan(try Self.place(of: "span", in: toggle), 0.5, "the words from the start, on the right")
    }

    /// Where `part` stands across the toggle's label, as a part of its width: its middle.
    private static func place(of part: String, in view: WebSwitchView) throws -> Double {
        try WebBrowser.number("""
            ((r, p) => (p.left - r.left + p.width / 2) / r.width)(\
            e.getBoundingClientRect(), e.querySelector('\(part)').getBoundingClientRect())
            """, on: view.node) ?? -1
    }
}
