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
            .axis(\.self, input: .scroll(.horizontal), range: 0...2, snaps: .every(1))
            .width(300)
            .height(200)
        }
        let layout = "[...document.querySelectorAll('*')].find(n => n.style.touchAction === 'pan-y')"
        host.settle { (try? WebBrowser.truth("!!\(layout)", on: 0)) == true }

        XCTAssertTrue(try kept(layout, firstMove: (-20, 6), then: (-30, 25)), "along, then slanting: the layout's")
        XCTAssertFalse(try kept(layout, firstMove: (4, 20), then: (6, 40)), "across: the page's")
    }

    /// A HAND THE LAYOUT TOOK, OR MAY STILL TAKE, STARTS NO DRAG OF THE BROWSER'S OWN: a picture under it would be
    /// dragged away by the browser past a few points - Chrome's own threshold, under the hand's drag distance - the
    /// pointer taken away from the layout, its lift never told; a hand the layout let go by leaves the browser's drag
    /// be.
    func testAHandTheLayoutTookStartsNoDragOfTheBrowsersOwn() throws {
        let host = WebRenderer.running {
            LayoutEngine([0, 1, 2]) { Text("\($0)") } placements: { room, phase in
                (0..<3).map { Placement(Rect((Double($0) - phase) * 100, 0, 100, room.height)) }
            }
            .phase(State(wrappedValue: 0.0).projectedValue)
            .axis(\.self, input: .scroll(.horizontal), range: 0...2, snaps: .every(1))
            .itemDrag(begins: .held)
            .width(300)
            .height(200)
        }
        let layout = "[...document.querySelectorAll('*')].find(n => n.style.touchAction === 'pan-y')"
        host.settle { (try? WebBrowser.truth("!!\(layout)", on: 0)) == true }

        func dragStarted(after moves: [(Double, Double)]) throws -> Bool {
            try WebBrowser.truth("""
                (() => {
                  const node = \(layout), box = node.getBoundingClientRect();
                  const at = (x, y) => ({ pointerId: 7, pointerType: 'mouse', button: 0, isPrimary: true,
                    clientX: box.left + 150 + x, clientY: box.top + 100 + y, bubbles: true, cancelable: true });
                  node.dispatchEvent(new PointerEvent('pointerdown', at(0, 0)));
                  \(moves.map { "node.dispatchEvent(new PointerEvent('pointermove', at(\($0.0), \($0.1))));" }.joined())
                  const drag = new Event('dragstart', { bubbles: true, cancelable: true });
                  node.firstElementChild.dispatchEvent(drag);
                  node.dispatchEvent(new PointerEvent('pointerup', at(0, 0)));
                  return !drag.defaultPrevented;
                })()
                """, on: 0)
        }

        XCTAssertFalse(try dragStarted(after: [(-20, 2)]), "the run's hand")
        XCTAssertFalse(try dragStarted(after: [(-3, 0)]), "a hand the layout may still take")
        XCTAssertTrue(try dragStarted(after: [(2, 20)]), "a hand across the layout, left to the page")
    }

    /// ⌥/ALT AND A DRAG ARE TWO FINGERS: a mouse pressed with Alt and dragged twice as far from the layout's middle
    /// spreads its magnification twice as large - the press and its mirror about the middle.
    func testAnAltDragIsTwoFingers() throws {
        let zoom = State(wrappedValue: 1.0)
        let host = WebRenderer.running {
            LayoutEngine([0, 1, 2]) { Text("\($0)") } placements: { room, at in
                (0..<3).map { Placement(Rect(Double($0) * 100, 0, 100 * at, room.height)) }
            }
            .phase(zoom.projectedValue)
            .axis(\.self, input: .magnification, range: 1...3, snaps: [2])
            .width(300)
            .height(200)
        }
        let layout = "[...document.querySelectorAll('*')].find(n => n.style.touchAction === 'none')"
        host.settle { (try? WebBrowser.truth("!!\(layout)", on: 0)) == true }

        _ = try WebBrowser.truth("""
            (() => {
              const node = \(layout), box = node.getBoundingClientRect();
              const at = (x) => ({ pointerId: 9, pointerType: 'mouse', button: 0, isPrimary: true, altKey: true,
                clientX: box.left + 150 + x, clientY: box.top + 100, bubbles: true, cancelable: true });
              node.dispatchEvent(new PointerEvent('pointerdown', at(50)));
              node.dispatchEvent(new PointerEvent('pointermove', at(100)));
              return true;
            })()
            """, on: 0)
        host.settle { zoom.wrappedValue == 2 }

        XCTAssertEqual(zoom.wrappedValue, 2, "twice as far from the middle: twice as large")
    }

    /// A FINGER HELD STILL ASKS FOR A VIEW'S MENU, ONE DRAGGED SLOWLY ASKS FOR NONE: how far it went is measured from
    /// where it pressed, so steps each too short to count add up to a drag - on a view that takes the touch from the
    /// page, which pans it, and calls the press off, no more.
    func testAFingerDraggedSlowlyAsksForNoMenu() throws {
        let host = WebRenderer.running {
            Rectangle().fill(.blue).width(200).height(200)
                .onPanUpdated { _ in }
                .contextMenu { MenuItem("Copy") }
                .id("shape")
        }
        let shape = try XCTUnwrap((host.runtime.tree.root?.first(id: .manual("shape"))?.native as? WebElement)?.view)
        host.settle { (try? WebBrowser.number("e.getBoundingClientRect().width", on: shape.node)) == 200 }
        let open = "[...document.querySelectorAll('.stateui-menu')].some((m) => m.matches(':popover-open'))"
        let rang = "window.heldAsLong === true"

        // Read once a timer as long as the hold, set by the same press after the page's own, has rung: the hold has
        // rung by then, or the drag called it off - however late the page's timers run.
        func asksForTheMenu(steps: Int, of step: Double) throws -> Bool {
            try WebBrowser.run("""
                window.heldAsLong = false;
                e.addEventListener("pointerdown", () => setTimeout(() => { window.heldAsLong = true; }, \(HandReading.hold)),
                  { once: true })
                """, on: shape.node)
            let left = try XCTUnwrap(WebBrowser.number("e.getBoundingClientRect().left", on: shape.node))
            let top = try XCTUnwrap(WebBrowser.number("e.getBoundingClientRect().top", on: shape.node))
            let pressed = Point(x: left + 40, y: top + 100)
            WebBrowser.ask([("touch", .words("touchStart")), ("points", .points([pressed]))])
            for each in 0..<steps {
                let at = Point(x: pressed.x + step * Double(each + 1), y: pressed.y)
                WebBrowser.ask([("touch", .words("touchMove")), ("points", .points([at]))])
            }
            host.settle { (try? WebBrowser.truth(rang, on: 0)) == true }
            XCTAssertTrue(try WebBrowser.truth(rang, on: 0), "the press reached the shape")
            let asked = try WebBrowser.truth(open, on: 0)
            WebBrowser.ask([("touch", .words("touchEnd")), ("points", .points([]))])
            try WebBrowser.run("document.querySelectorAll('.stateui-menu').forEach((m) => m.hidePopover?.())")
            return asked
        }

        XCTAssertTrue(try asksForTheMenu(steps: 0, of: 0), "a finger held still")
        XCTAssertFalse(try asksForTheMenu(steps: 10, of: 3), "a finger dragged 30 points, 3 a step")
        host.leave()
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
