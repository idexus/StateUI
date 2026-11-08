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
        defer { renderer.finish() }
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

    /// The hand pressed on a view flattened before it lets go, never having moved, is taken away; on a view drawn
    /// whole it is let go.
    func testAStillHandOnAViewFlattenedUnderItIsTakenAway() throws {
        for flattened in [true, false] {
            let stage = ViewToFlatten()
            defer { stage.window.orderOut(nil) }
            var heard: [GesturePhase] = []
            let reader = AppKitHandReader { input in
                if case .hand(let phase, _, _, _, _) = input { heard.append(phase) }
                return true
            }
            stage.view.addGestureRecognizer(reader.dragging)

            reader.dragging.mouseDown(with: try event(.leftMouseDown, at: stage.middle, in: stage.window))
            if flattened { stage.flatten() }
            reader.dragging.mouseUp(with: try event(.leftMouseUp, at: stage.middle, in: stage.window))

            XCTAssertEqual(heard, flattened ? [.began, .cancelled] : [.began, .ended], "flattened: \(flattened)")
        }
    }

    /// The hand dragged on a view flattened under it is taken away once, as the drag tells its next step: its
    /// release tells nothing more.
    func testAHandDraggedOnAViewFlattenedUnderItIsTakenAwayOnce() throws {
        let stage = ViewToFlatten()
        defer { stage.window.orderOut(nil) }
        var heard: [GesturePhase] = []
        let reader = AppKitHandReader { input in
            if case .hand(let phase, _, _, _, _) = input { heard.append(phase) }
            return true
        }
        stage.view.addGestureRecognizer(reader.dragging)

        reader.dragging.mouseDown(with: try event(.leftMouseDown, at: stage.middle, in: stage.window))
        stage.flatten()
        reader.dragging.recognized(.changed, at: stage.middle, moved: NSPoint(x: 10, y: 0))
        reader.dragging.recognized(.ended, at: stage.middle, moved: NSPoint(x: 10, y: 0))
        reader.dragging.mouseUp(with: try event(.leftMouseUp, at: stage.middle, in: stage.window))

        XCTAssertEqual(heard, [.began, .cancelled])
    }

    /// A click of a run of taps let go on a view flattened under it is no tap; on a view drawn whole it is one.
    func testAClickOnAViewFlattenedUnderItIsNoTap() throws {
        for flattened in [true, false] {
            let stage = ViewToFlatten()
            defer { stage.window.orderOut(nil) }
            var taps = 0
            let tap = AppKitTapRecognizer { if case .tap = $0 { taps += 1 } }
            tap.countsRuns = true
            stage.view.addGestureRecognizer(tap)

            if flattened { stage.flatten() }
            actionSent(by: tap, during: try event(.leftMouseUp, at: stage.middle, in: stage.window))

            XCTAssertEqual(taps, flattened ? 0 : 1, "flattened: \(flattened)")
        }
    }

    /// A press held on a view flattened under it before the hold's time is no hold; on a view drawn whole it is one.
    func testAPressHeldOnAViewFlattenedUnderItIsNoHold() throws {
        for flattened in [true, false] {
            let stage = ViewToFlatten()
            defer { stage.window.orderOut(nil) }
            var holds = 0
            let hold = AppKitHoldRecognizer { if case .hold = $0 { holds += 1 } }
            stage.view.addGestureRecognizer(hold)

            if flattened { stage.flatten() }
            hold.recognized(.began, at: stage.middle)

            XCTAssertEqual(holds, flattened ? 0 : 1, "flattened: \(flattened)")
        }
    }

    /// A rotation under way on a view flattened under it is taken away; on a view drawn whole it ends.
    func testARotationOnAViewFlattenedUnderItIsTakenAway() throws {
        for flattened in [true, false] {
            let stage = ViewToFlatten()
            defer { stage.window.orderOut(nil) }
            var heard: [GesturePhase] = []
            let rotation = AppKitRotationRecognizer { if case .rotation(let phase, _) = $0 { heard.append(phase) } }
            stage.view.addGestureRecognizer(rotation)

            rotation.recognized(.began, degrees: 0, at: stage.middle)
            if flattened { stage.flatten() }
            rotation.recognized(.changed, degrees: 10, at: stage.middle)
            rotation.recognized(.ended, degrees: 10, at: stage.middle)

            XCTAssertEqual(heard, flattened ? [.began, .cancelled] : [.began, .changed, .ended], "flattened: \(flattened)")
        }
    }

    /// A pinch under way on a view flattened under it is taken away; on a view drawn whole it ends.
    func testAPinchOnAViewFlattenedUnderItIsTakenAway() throws {
        for flattened in [true, false] {
            let stage = ViewToFlatten()
            defer { stage.window.orderOut(nil) }
            var heard: [GesturePhase] = []
            let pinch = AppKitPinchRecognizer { if case .pinch(let phase, _, _) = $0 { heard.append(phase) } }
            stage.view.addGestureRecognizer(pinch)

            pinch.recognized(.began, magnification: 0, at: stage.middle)
            if flattened { stage.flatten() }
            pinch.recognized(.changed, magnification: 0.2, at: stage.middle)
            pinch.recognized(.ended, magnification: 0.2, at: stage.middle)

            XCTAssertEqual(heard, flattened ? [.began, .cancelled] : [.began, .changed, .ended], "flattened: \(flattened)")
        }
    }

    /// A drag under way on a view flattened under it is taken away; on a view drawn whole it ends.
    func testADragOnAViewFlattenedUnderItIsTakenAway() throws {
        for flattened in [true, false] {
            let stage = ViewToFlatten()
            defer { stage.window.orderOut(nil) }
            var heard: [GesturePhase] = []
            let pan = AppKitPanRecognizer { if case .drag(let phase, _, _, _) = $0 { heard.append(phase) } }
            stage.view.addGestureRecognizer(pan)
            let on = NSPoint(x: stage.middle.x + 10, y: stage.middle.y)

            pan.recognized(.began, at: stage.middle, moved: .zero)
            if flattened { stage.flatten() }
            pan.recognized(.changed, at: on, moved: NSPoint(x: 10, y: 0))
            pan.recognized(.ended, at: on, moved: NSPoint(x: 10, y: 0))

            XCTAssertEqual(heard, flattened ? [.began, .cancelled] : [.began, .changed, .ended], "flattened: \(flattened)")
        }
    }

    /// A gesture taken away from a view flattened under it - as it begins or as it goes on - tells nothing more of
    /// AppKit's gesture, the view drawn whole again, to its end; the next is heard whole. A drag, a pinch, a rotation
    /// and the hand alike.
    func testAGestureTakenAwayTellsNothingMoreOfItsPlatformGesture() throws {
        for family in ["drag", "pinch", "rotation", "hand"] {
            for flattenedAs in [GesturePhase.began, .changed] {
                let stage = ViewToFlatten()
                defer { stage.window.orderOut(nil) }
                let gesture = try driven(family, on: stage)
                let named = "\(family), flattened as it \(flattenedAs == .began ? "begins" : "goes on")"

                if flattenedAs == .began { stage.flatten() }
                gesture.begin()
                stage.flatten()
                gesture.step()
                stage.drawWhole()
                gesture.step()
                gesture.end()
                XCTAssertEqual(gesture.heard.phases, flattenedAs == .began ? [] : [.began, .cancelled], named)

                gesture.heard.phases = []
                gesture.begin()
                gesture.step()
                gesture.end()
                XCTAssertEqual(gesture.heard.phases, [.began, .changed, .ended], "\(named): the next")
            }
        }
    }

    /// The pointer over a view flattened under it is told to have left, once, and nothing more; over a view drawn
    /// whole it moves and lets go.
    func testThePointerOverAViewFlattenedUnderItHasLeft() throws {
        for flattened in [true, false] {
            let stage = ViewToFlatten()
            defer { stage.window.orderOut(nil) }
            var heard: [Event] = []
            let pointer = AppKitPointerRecognizer { if case .pointer(let event, _, _) = $0 { heard.append(event) } }
            pointer.install(on: stage.view)

            pointer.mouseEntered(with: try event(.mouseMoved, at: stage.middle, in: stage.window))
            if flattened { stage.flatten() }
            pointer.mouseMoved(with: try event(.mouseMoved, at: stage.middle, in: stage.window))
            pointer.mouseUp(with: try event(.leftMouseUp, at: stage.middle, in: stage.window))

            XCTAssertEqual(
                heard, flattened ? [.pointerEntered, .pointerExited] : [.pointerEntered, .pointerMoved, .pointerReleased],
                "flattened: \(flattened)")
        }
    }

    /// AppKit sends `recognizer`'s action to its target, as it does as the recognizer moves on - `event` the
    /// application's current one, where given: a recognizer of AppKit's own follows only the events a shown window
    /// hands it.
    private func actionSent(by recognizer: NSGestureRecognizer, during event: NSEvent? = nil) {
        guard let action = recognizer.action else { return XCTFail("\(recognizer) has no action") }
        let application = NSApplication.shared
        if let event {
            application.postEvent(event, atStart: true)
            let current = application.nextEvent(matching: .any, until: .distantPast, inMode: .default, dequeue: true)
            XCTAssertTrue(current === application.currentEvent && current?.type == event.type, "\(String(describing: current))")
        }
        application.sendAction(action, to: recognizer.target, from: recognizer)
    }

    /// `family`'s recognizer on `stage`'s view, driven as AppKit tells its gesture: its beginning, a step and its end.
    private func driven(_ family: String, on stage: ViewToFlatten) throws -> DrivenGesture {
        let heard = HeardPhases()
        let on = NSPoint(x: stage.middle.x + 10, y: stage.middle.y)
        let moved = NSPoint(x: 10, y: 0)
        switch family {
        case "drag":
            let pan = AppKitPanRecognizer { if case .drag(let phase, _, _, _) = $0 { heard.phases.append(phase) } }
            stage.view.addGestureRecognizer(pan)
            return DrivenGesture(
                heard: heard, begin: { pan.recognized(.began, at: stage.middle, moved: .zero) },
                step: { pan.recognized(.changed, at: on, moved: moved) },
                end: { pan.recognized(.ended, at: on, moved: moved) })
        case "pinch":
            let pinch = AppKitPinchRecognizer { if case .pinch(let phase, _, _) = $0 { heard.phases.append(phase) } }
            stage.view.addGestureRecognizer(pinch)
            return DrivenGesture(
                heard: heard, begin: { pinch.recognized(.began, magnification: 0, at: stage.middle) },
                step: { pinch.recognized(.changed, magnification: 0.2, at: stage.middle) },
                end: { pinch.recognized(.ended, magnification: 0.2, at: stage.middle) })
        case "rotation":
            let rotation = AppKitRotationRecognizer { if case .rotation(let phase, _) = $0 { heard.phases.append(phase) } }
            stage.view.addGestureRecognizer(rotation)
            return DrivenGesture(
                heard: heard, begin: { rotation.recognized(.began, degrees: 0, at: stage.middle) },
                step: { rotation.recognized(.changed, degrees: 10, at: stage.middle) },
                end: { rotation.recognized(.ended, degrees: 10, at: stage.middle) })
        default:
            let reader = AppKitHandReader { input in
                if case .hand(let phase, _, _, _, _) = input { heard.phases.append(phase) }
                return true
            }
            stage.view.addGestureRecognizer(reader.dragging)
            let down = try event(.leftMouseDown, at: stage.middle, in: stage.window)
            let up = try event(.leftMouseUp, at: on, in: stage.window)
            return DrivenGesture(
                heard: heard, begin: { reader.dragging.mouseDown(with: down) },
                step: { reader.dragging.recognized(.changed, at: on, moved: moved) },
                end: {
                    reader.dragging.recognized(.ended, at: on, moved: moved)
                    reader.dragging.mouseUp(with: up)
                })
        }
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

/// A window holding one view of StateUI's, 40 points square, with its drawing - what a test flattens under input.
@MainActor
private struct ViewToFlatten {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered,
        defer: false)
    let view = AppKitHitTestView(frame: NSRect(x: 20, y: 20, width: 40, height: 40))
    let drawing: AppKitViewDrawing

    init() {
        window.contentView = AppKitHitTestView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        window.contentView?.addSubview(view)
        drawing = AppKitViewDrawing(view)
    }

    /// The view's middle, in the window.
    var middle: NSPoint { view.convert(NSPoint(x: 20, y: 20), to: nil) }

    /// Flattens the view to a line: its drawing has no inverse.
    func flatten() {
        var flat = HostDrawingTransform.identity
        flat.scaleX = 0
        drawing.own = flat
    }

    /// Draws the view whole again, as it lies.
    func drawWhole() {
        drawing.own = .identity
    }
}

/// The phases a recognizer told the host, in order.
@MainActor
private final class HeardPhases {
    var phases: [GesturePhase] = []
}

/// A recognizer driven as AppKit tells its gesture - its beginning, a step and its end - and what it told the host.
@MainActor
private struct DrivenGesture {
    let heard: HeardPhases
    let begin: () -> Void
    let step: () -> Void
    let end: () -> Void
}
#endif
