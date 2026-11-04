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

    /// A drawing that flattens a view - to a point, to a line - has no inverse: no point of the layout lands in the
    /// view, so a hit at its frame's place is the layout's, through a flattened ancestor too, and a view drawn tiny
    /// is found at its dot alone; a view turned over by a negative scale is found where it is drawn.
    func testAFlattenedViewTakesNoHit() throws {
        let parent = AppKitHitTestView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let point = AppKitHitTestView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        let inner = AppKitHitTestView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        let line = AppKitHitTestView(frame: NSRect(x: 50, y: 0, width: 20, height: 20))
        let tiny = AppKitHitTestView(frame: NSRect(x: 100, y: 0, width: 20, height: 20))
        let turned = AppKitHitTestView(frame: NSRect(x: 150, y: 0, width: 20, height: 20))
        for view in [point, line, tiny, turned] { parent.addSubview(view) }
        point.addSubview(inner)
        let drawings = [point, line, tiny, turned].map(AppKitViewDrawing.init)
        var toAPoint = HostDrawingTransform.identity, toALine = toAPoint, small = toAPoint, over = toAPoint
        (toAPoint.scaleX, toAPoint.scaleY) = (0, 0)
        toALine.scaleX = 0
        (small.scaleX, small.scaleY) = (0.01, 0.01)
        over.scaleX = -1
        for (drawing, own) in zip(drawings, [toAPoint, toALine, small, over]) { drawing.own = own }

        XCTAssertNil(drawings[0].undrawn(Point(5, 5)), "a plane flattened to a point has no inverse")
        XCTAssertNil(drawings[1].undrawn(Point(55, 5)), "nor one flattened to a line")
        XCTAssertTrue(parent.hitTest(NSPoint(x: 5, y: 5)) === parent, "nothing of the flattened view lands there")
        XCTAssertTrue(parent.hitTest(NSPoint(x: 10, y: 10)) === parent, "not even at its point: it shows nothing")
        XCTAssertTrue(parent.hitTest(NSPoint(x: 55, y: 5)) === parent, "a view flattened to a line")
        XCTAssertTrue(parent.hitTest(NSPoint(x: 110, y: 10)) === tiny, "a tiny view is found at its dot")
        XCTAssertTrue(parent.hitTest(NSPoint(x: 105, y: 5)) === parent, "and nowhere else in its frame")
        XCTAssertTrue(parent.hitTest(NSPoint(x: 155, y: 5)) === turned, "a view turned over is found where it is drawn")
    }

    /// A press begun on a view that is flattened under it ends as cancelled: the press is not let go in the view,
    /// where no point lands any more, nor where its frame alone would put it.
    func testAPressOnAViewFlattenedUnderItIsCancelled() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered,
            defer: false)
        defer { window.orderOut(nil) }
        let root = AppKitHitTestView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        window.contentView = root
        let view = AppKitHitTestView(frame: NSRect(x: 20, y: 20, width: 40, height: 40))
        root.addSubview(view)
        var heard: [GesturePhase] = []
        let press = AppKitPressRecognizer { if case .press(let phase, _, _, _) = $0 { heard.append(phase) } }
        view.addGestureRecognizer(press)
        let drawing = AppKitViewDrawing(view)
        let middle = view.convert(NSPoint(x: 20, y: 20), to: nil)

        press.mouseDown(with: try event(.leftMouseDown, at: middle, in: window))
        var flat = HostDrawingTransform.identity
        (flat.scaleX, flat.scaleY) = (0, 0)
        drawing.own = flat
        press.mouseUp(with: try event(.leftMouseUp, at: middle, in: window))

        XCTAssertEqual(heard, [.began, .cancelled], "the view under the press is flattened: the press is taken away")
    }

    /// A press as a mouse makes it, down and up at `point` of the window.
    private func click(_ press: AppKitPressRecognizer, at point: NSPoint) throws {
        let window = try XCTUnwrap(press.view?.window)
        press.mouseDown(with: try event(.leftMouseDown, at: point, in: window))
        press.mouseUp(with: try event(.leftMouseUp, at: point, in: window))
    }

    /// A mouse event of `type` at `point` of `window`.
    private func event(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }
}

/// The taps a page's handlers heard, in order.
private final class Tapped: @unchecked Sendable {
    var values: [String] = []
}
#endif
