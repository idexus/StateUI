// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// The pointer as the browser gives it: a mouse comes over a view and leaves it; a finger's touch, which the browser
/// tells as a pointer coming over the view, hovers over nothing; a press is a tap only while it stays within its reach.
@MainActor
final class WebPointerTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testAFingerHoversOverNothing() throws {
        WebRenderer.shared?.leave()
        var heard: [String] = []
        let host = WebRenderer.running {
            Text("Over")
                .onPointerEntered { heard.append("entered") }
                .onPointerExited { heard.append("exited") }
                .onPointerPressed { _ in heard.append("pressed") }
        }
        host.step()
        let view = try XCTUnwrap(host.views(WebTextView.self).first)

        for (type, pointer) in [("pointerenter", "touch"), ("pointerdown", "touch"), ("pointerleave", "touch"),
                                ("pointerenter", "mouse"), ("pointerleave", "mouse")] {
            try WebBrowser.run("e.dispatchEvent(new PointerEvent('\(type)', { pointerId: 3, pointerType: '\(pointer)', "
                + "isPrimary: true }))", on: view.node)
        }
        for _ in 0..<3 { host.step() }

        XCTAssertEqual(heard, ["pressed", "entered", "exited"], "the finger's press alone, then the mouse coming and going")
    }

    /// A press taps as a button does: let go over the view it taps, let go away it taps nothing, and one that comes
    /// back over the view before it lets go taps; the view is pressed while the press stands over it. The page's
    /// click of a press is no second tap; a click no pointer made - the keyboard's, a screen reader's - taps.
    func testAPressTapsAsAButtonDoes() throws {
        WebRenderer.shared?.leave()
        var taps = 0
        let host = WebRenderer.running {
            VStack {
                ZStack { Text("Row") }
                    .width(200).height(40)
                    .onTapped { taps += 1 }
                    .visualState(.pressed) { $0.background(.green) }
                    .id("row")
            }
            .horizontalAlignment(.start)
        }
        host.step()
        let row = try XCTUnwrap((host.runtime.tree.root?.first(id: .manual("row"))?.native as? WebElement)?.view)

        func press(_ path: [Double], _ pointer: String, click: Bool = true) throws {
            let moves = path.dropFirst().dropLast().map { "e.dispatchEvent(new PointerEvent('pointermove', at(\($0))));" }
            try WebBrowser.run("""
                const box = e.getBoundingClientRect();
                const at = (y) => ({ pointerId: 4, pointerType: '\(pointer)', isPrimary: true, button: 0,
                  clientX: box.left + 100, clientY: box.top + 20 + y, bubbles: true });
                e.dispatchEvent(new PointerEvent('pointerdown', at(\(path[0]))));
                \(moves.joined(separator: "\n"))
                e.dispatchEvent(new PointerEvent('pointerup', at(\(path[path.count - 1]))));
                \(click ? "e.dispatchEvent(new MouseEvent('click', { detail: 1, bubbles: true }))" : "")
                """, on: row.node)
            for _ in 0..<3 { host.step() }
        }
        let background = { try WebBrowser.evaluate("getComputedStyle(e).backgroundColor", on: row.node) }

        try press([0, 0], "touch")
        XCTAssertEqual(taps, 1, "let go over the view: one tap, the page's click no second")
        try press([0, 60, 60], "touch", click: false)
        XCTAssertEqual(taps, 1, "slid off the view and let go away: nothing")
        try press([0, 60, 5, 5], "touch")
        XCTAssertEqual(taps, 2, "back over the view before it lets go: a tap")
        try press([0, 25, 25], "mouse")
        XCTAssertEqual(taps, 2, "a mouse let go just past the edge: nothing")

        try WebBrowser.run("""
            const box = e.getBoundingClientRect();
            e.dispatchEvent(new PointerEvent('pointerdown', { pointerId: 6, pointerType: 'touch', isPrimary: true,
              clientX: box.left + 100, clientY: box.top + 20, bubbles: true }))
            """, on: row.node)
        for _ in 0..<5 { host.step() }
        XCTAssertEqual(try background(), "rgb(0, 128, 0)", "pressed while the press stands over it")
        try WebBrowser.run("""
            const box = e.getBoundingClientRect();
            e.dispatchEvent(new PointerEvent('pointermove', { pointerId: 6, pointerType: 'touch', isPrimary: true,
              clientX: box.left + 100, clientY: box.top + 90, bubbles: true }))
            """, on: row.node)
        for _ in 0..<5 { host.step() }
        XCTAssertNotEqual(try background(), "rgb(0, 128, 0)", "out as it leaves")
        try WebBrowser.run("e.dispatchEvent(new PointerEvent('pointercancel', { pointerId: 6, pointerType: 'touch', bubbles: true }))", on: row.node)
        for _ in 0..<3 { host.step() }

        try WebBrowser.run("e.dispatchEvent(new MouseEvent('click', { detail: 0, bubbles: true }))", on: row.node)
        for _ in 0..<3 { host.step() }
        XCTAssertEqual(taps, 3, "a click no pointer made taps")
    }

    /// A SCROLL UNDER A PRESS TAKES IT: a row the finger pressed and the list scrolled under it taps nothing as the
    /// finger lets go over it, as iOS's WebKit tells the page no cancel of the press.
    func testAScrollUnderAPressTakesIt() throws {
        WebRenderer.shared?.leave()
        var taps = 0
        let host = WebRenderer.running {
            ScrollView {
                VStack {
                    ZStack { Text("Row") }
                        .width(200).height(40)
                        .onTapped { taps += 1 }
                        .id("row")
                    Space().height(2000)
                }
            }
        }
        host.step()
        let row = try XCTUnwrap((host.runtime.tree.root?.first(id: .manual("row"))?.native as? WebElement)?.view)

        try WebBrowser.run("""
            const box = e.getBoundingClientRect();
            const at = { pointerId: 8, pointerType: 'touch', isPrimary: true, button: 0,
              clientX: box.left + 100, clientY: box.top + 20, bubbles: true };
            e.dispatchEvent(new PointerEvent('pointerdown', at));
            // The finger goes up 50 points and the list with it: the row stays under the finger.
            const moved = { ...at, clientY: at.clientY - 50 };
            e.dispatchEvent(new PointerEvent('pointermove', moved));
            let scroller = e.parentElement;
            while (scroller && !(scroller.scrollHeight > scroller.clientHeight)) scroller = scroller.parentElement;
            scroller.scrollTop = 50;
            scroller.dispatchEvent(new Event('scroll'));
            e.dispatchEvent(new PointerEvent('pointerup', moved));
            """, on: row.node)
        for _ in 0..<3 { host.step() }

        XCTAssertEqual(taps, 0, "the list scrolled under the press: no tap")
        host.leave()
    }

    /// A list's item is tapped by the same press: let go away from it, nothing opens.
    func testAnItemIsTappedByThePress() throws {
        WebRenderer.shared?.leave()
        var opened: [String] = []
        let host = WebRenderer.running {
            ItemsView(["one", "two"]) { Text($0) }.onItemActivated { opened.append($0) }.height(200)
        }
        let item = "document.querySelector('[role=listitem]')"
        host.settle { (try? WebBrowser.truth("!!\(item)", on: 0)) == true }

        func press(to down: Double) throws {
            try WebBrowser.run("""
                const cell = \(item), box = cell.getBoundingClientRect();
                const at = (y) => ({ pointerId: 5, pointerType: 'touch', isPrimary: true,
                  clientX: box.left + 10, clientY: box.top + 5 + y, bubbles: true });
                cell.dispatchEvent(new PointerEvent('pointerdown', at(0)));
                cell.dispatchEvent(new PointerEvent('pointermove', at(\(down))));
                cell.dispatchEvent(new PointerEvent('pointerup', at(\(down))));
                cell.dispatchEvent(new MouseEvent('click', { detail: 1, bubbles: true }))
                """)
            for _ in 0..<3 { host.step() }
        }

        try press(to: 300)
        XCTAssertEqual(opened, [], "let go away from the item: nothing opens")
        try press(to: 2)
        XCTAssertEqual(opened.count, 1, "let go over it: it opens, once")
    }
}
