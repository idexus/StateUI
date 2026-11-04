// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// AppKit looks for a view, and places an event, by frames alone; StateUI draws a view away from its frame through
/// its layer. Input meets the view where it is drawn.
@MainActor
final class AppKitDrawnInputTests: XCTestCase {
    /// A layout finds a child where its drawing moved it, and no longer where its frame lies; a child drawn as it
    /// lies is found as AppKit finds it.
    func testAHitReachesAChildWhereItIsDrawn() throws {
        let parent = AppKitHitTestView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let moved = AppKitHitTestView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        let still = AppKitHitTestView(frame: NSRect(x: 150, y: 0, width: 20, height: 20))
        parent.addSubview(moved)
        parent.addSubview(still)
        let drawing = AppKitViewDrawing(moved)
        var away = HostDrawingTransform.identity
        away.translationX = 100
        drawing.own = away
        XCTAssertEqual(try XCTUnwrap(moved.layer).transform.m41, 100, accuracy: 0.001)

        XCTAssertTrue(parent.hitTest(NSPoint(x: 110, y: 10)) === moved, "found where it is drawn")
        XCTAssertTrue(parent.hitTest(NSPoint(x: 10, y: 10)) === parent, "its frame's place is the layout's")
        XCTAssertTrue(parent.hitTest(NSPoint(x: 160, y: 10)) === still, "a child drawn as it lies")
        XCTAssertNil(parent.hitTest(NSPoint(x: 210, y: 10)), "beyond the layout")
    }

    /// A press meets a view where it is drawn: a click there is its tap, and one where its frame lies is not.
    func testAPressMeetsAViewWhereItIsDrawn() throws {
        let taps = Tapped()
        let renderer = AppKitRenderer.running {
            ZStack {
                Text("Moved").width(40).height(20).translationX(100).onTapped { taps.values.append("moved") }
            }
            .width(240).height(100)
        }
        defer { renderer.closeForTesting() }
        for controller in renderer.windowsForTesting { controller.window?.layoutIfNeeded() }
        let moved = try XCTUnwrap(renderer.nativeViews(AppKitTextView.self).first)
        let press = try XCTUnwrap(moved.gestureRecognizers.compactMap { $0 as? AppKitPressRecognizer }.first)
        let content = try XCTUnwrap(moved.window?.contentView)
        let frame = try XCTUnwrap(content.superview)
        XCTAssertTrue(moved.isDrawnAway)
        let middle = moved.convert(NSPoint(x: moved.bounds.midX, y: moved.bounds.midY), to: nil)
        let drawn = NSPoint(x: middle.x + 100, y: middle.y)

        XCTAssertTrue(content.hitTest(frame.convert(drawn, from: nil))?.isDescendant(of: moved) == true, "found where drawn")
        XCTAssertTrue(content.hitTest(frame.convert(middle, from: nil)) === moved.superview, "its frame's place is the layout's")
        try click(press, at: drawn)
        for _ in 0..<5 { renderer.runtime.pump.turn() }
        XCTAssertEqual(taps.values, ["moved"], "the click where it is drawn taps it")
        try click(press, at: middle)
        for _ in 0..<5 { renderer.runtime.pump.turn() }

        XCTAssertEqual(taps.values, ["moved"], "the one at its frame does not")
    }

    /// A press as a mouse makes it, down and up at `point` of the window.
    private func click(_ press: AppKitPressRecognizer, at point: NSPoint) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: press.view?.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
            type == .leftMouseDown ? press.mouseDown(with: event) : press.mouseUp(with: event)
        }
    }
}

/// The taps a page's handlers heard, in order.
private final class Tapped: @unchecked Sendable {
    var values: [String] = []
}
#endif
