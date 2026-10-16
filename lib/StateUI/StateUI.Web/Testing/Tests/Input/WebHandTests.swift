// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// The hand over a layout as the browser gives it: whose a touch is, the layout's or the page's own pan.
@MainActor
final class WebHandTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// A TOUCH THE LAYOUT TOOK IS KEPT FROM THE PAGE: its first move along the layout's axis makes it the layout's,
    /// and the browser's own pan never takes it after - a slant on the way included; a touch whose first move runs
    /// across stays the page's.
    func testATouchTheLayoutTookIsKeptFromThePage() throws {
        let host = WebRenderer.running {
            LayoutEngine([0, 1, 2]) { Text("\($0)") } placements: { room, phase in
                (0..<3).map { Placement(Rect((Double($0) - phase) * 100, 0, 100, room.height)) }
            }
            .phase(State(wrappedValue: 0.0).projectedValue)
            .input(.scroll(.horizontal))
            .snapTargets([0, 1, 2])
            .width(300)
            .height(200)
        }
        let layout = "[...document.querySelectorAll('*')].find(n => n.style.touchAction === 'pan-y')"
        host.settle { (try? WebBrowser.truth("!!\(layout)", on: 0)) == true }

        XCTAssertTrue(try kept(layout, firstMove: (-20, 6), then: (-30, 25)), "along, then slanting: the layout's")
        XCTAssertFalse(try kept(layout, firstMove: (4, 20), then: (6, 40)), "across: the page's")
    }

    /// Whether the page's pan was kept from a touch pressed on `layout`, moved by `firstMove` and then `then`: the
    /// touch's moves after its first, as the browser would pan them.
    private func kept(_ layout: String, firstMove: (Double, Double), then: (Double, Double)) throws -> Bool {
        func pointer(_ type: String, _ x: Double, _ y: Double) -> String {
            "node.dispatchEvent(new PointerEvent('\(type)', { pointerId: 7, pointerType: 'touch', isPrimary: true, "
                + "clientX: box.left + 150 + \(x), clientY: box.top + 100 + \(y), bubbles: true, cancelable: true }))"
        }
        let touchMove = "(() => { const touch = new Event('touchmove', { bubbles: true, cancelable: true }); "
            + "node.dispatchEvent(touch); return touch.defaultPrevented; })()"
        return try WebBrowser.truth("""
            (() => {
              const node = \(layout), box = node.getBoundingClientRect();
              \(pointer("pointerdown", 0, 0));
              \(pointer("pointermove", firstMove.0, firstMove.1));
              const first = \(touchMove);
              \(pointer("pointermove", then.0, then.1));
              const second = \(touchMove);
              \(pointer("pointerup", then.0, then.1));
              return first && second;
            })()
            """, on: 0)
    }
}
