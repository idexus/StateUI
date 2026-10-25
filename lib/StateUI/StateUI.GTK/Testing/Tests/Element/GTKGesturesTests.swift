// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

/// A row that counts its taps - `count` of them in a quick run make one - beside a stack that answers nothing.
private struct TapsPage: View {
    let count: Int
    @State private var taps = 0
    @State private var shown = true

    var body: some View {
        VStack {
            Text("taps \(taps)")
            if shown {
                HStack { Text("row") }
                    .width(200)
                    .height(40)
                    .onTapped(count: count) { taps += 1 }
            }
            HStack { Text("plain") }
                .width(200)
                .height(40)
            Button("Hide").onClicked { shown = false }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// A row held - waiting a minute - or tapped, and what it heard; a row held after a moment.
private struct HoldPage: View {
    @State private var said = ""

    var body: some View {
        VStack {
            Text("said \(said)")
            HStack { Text("long") }
                .width(200)
                .height(40)
                .onTapped { said += "tapped; " }
                .onHeld(minimum: .seconds(60)) { said += "held; " }
            HStack { Text("short") }
                .width(200)
                .height(40)
                .onHeld(minimum: .milliseconds(1)) {}
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// A box a press drags across, a swipe told apart, and what the pan, the pinch and the pointer said, in order.
private struct DragPage: View {
    @State private var x = 10.0
    @State private var said = ""

    var body: some View {
        VStack {
            Text("x \(Int(x)) \(said)")
            Rectangle()
                .fill(.steelBlue)
                .width(100)
                .height(100)
                .panX($x)
                .onPanUpdated { pan in said += "pan \(pan.phase.rawValue) \(Int(pan.totalX)); " }
                .onSwiped(direction: [.left, .right]) { direction in said += "swiped \(direction.rawValue); " }
                .onPinchUpdated { pinch in said += "pinch \(pinch.scale) at \(pinch.scaleOrigin.x); " }
                .onPointerMoved { point in said += "moved \(Int(point.x)),\(Int(point.y)); " }
                .onPointerPressed { point in said += "pressed \(Int(point.x)); " }
                .onPointerReleased { point in said += "released \(Int(point.x)); " }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

@MainActor
final class GTKGesturesTests: XCTestCase {
    /// A click on a row that answers a tap is a tap, past its words where it draws nothing; a press that moved past
    /// the drag threshold, or is let go beside the row, is none.
    func testAClickIsATapWhereItHasNotMoved() throws {
        try onUIThread {
            let host = GTKRenderer.running { TapsPage(count: 1) }
            let row = try XCTUnwrap(host.views(GTKStackView.self).dropFirst().first)
            let taps = try XCTUnwrap(row.listening?.controllers[.taps]?.first)

            GTKTestHost.emit(taps, "pressed", [1, 190, 20])
            GTKTestHost.emit(taps, "released", [1, 190, 20])
            host.settle { host.texts.first == "taps 1" }
            XCTAssertEqual(host.texts.first, "taps 1")

            let listening = try XCTUnwrap(row.listening)
            listening.tapPressed(at: Point(x: 20, y: 20))
            listening.tapStopped(at: Point(x: 60, y: 20))
            listening.tapReleased(nil, run: 1, at: Point(x: 20, y: 20))
            listening.tapPressed(at: Point(x: 20, y: 20))
            listening.tapReleased(nil, run: 1, at: Point(x: 260, y: 20))
            GTKTestHost.emit(taps, "pressed", [1, 20, 20])
            GTKTestHost.emit(taps, "released", [1, 20, 20])
            host.settle { host.texts.first == "taps 2" }

            XCTAssertEqual(host.texts.first, "taps 2", "only the last press was a tap")
        }
    }

    /// GTK hits a row across its bounds, past its words, where it draws nothing.
    /// GTK waits from half to twice its long-press time and refuses any other factor: a view's time beyond
    /// either stands at that end. A press held is no tap as it lets go; the next press taps again.
    func testAHoldWaitsWithinGTKsRangeAndIsNoTap() throws {
        try onUIThread {
            let host = GTKRenderer.running { HoldPage() }
            let rows = Array(host.views(GTKStackView.self).dropFirst())
            let listening = try XCTUnwrap(rows.first?.listening)
            let time = try XCTUnwrap(listening.holdTime)
            let gtks = time / 2
            XCTAssertGreaterThan(gtks, 0)
            XCTAssertEqual(rows.dropFirst().first?.listening?.holdTime, gtks / 2, "half GTK's time, the least it waits")

            let taps = try XCTUnwrap(listening.controllers[.taps]?.first)
            let hold = try XCTUnwrap(listening.controllers[.holds]?.first)
            GTKTestHost.emit(taps, "pressed", [1, 20, 20])
            GTKTestHost.emit(hold, "pressed", [20, 20])
            GTKTestHost.emit(taps, "released", [1, 20, 20])
            host.settle { host.texts.first == "said held; " }
            XCTAssertEqual(host.texts.first, "said held; ", "held, and its release no tap")

            GTKTestHost.emit(taps, "pressed", [1, 20, 20])
            GTKTestHost.emit(taps, "released", [1, 20, 20])
            host.settle { host.texts.first == "said held; tapped; " }
            XCTAssertEqual(host.texts.first, "said held; tapped; ")
        }
    }

    func testARowIsHitWhereItDrawsNothing() throws {
        try onUIThread {
            let host = GTKRenderer.running { TapsPage(count: 1) }
            let row = try XCTUnwrap(host.views(GTKStackView.self).dropFirst().first)

            XCTAssertEqual(gtk_widget_pick(row.widget, 190, 20, GTK_PICK_DEFAULT), row.widget)
        }
    }

    /// A row that answers a tap is pressed by assistive technology as a tap; a stack that answers nothing is not.
    func testATappedRowIsPressedByAssistiveTechnology() throws {
        try onUIThread {
            let host = GTKRenderer.running { TapsPage(count: 2) }
            let rows = host.views(GTKStackView.self)
            let row = try XCTUnwrap(rows.dropFirst().first)
            let plain = try XCTUnwrap(rows.last)

            row.press()
            row.press()
            plain.press()
            host.settle { host.texts.first == "taps 2" }

            XCTAssertEqual(host.texts.first, "taps 2", "each press is one tap, whatever count the row asks for")
            XCTAssertEqual(plain.hearing, [])
        }
    }

    /// A quick run of taps answers each time it reaches the count asked for.
    func testARunOfTapsAnswersAtItsCount() throws {
        try onUIThread {
            let host = GTKRenderer.running { TapsPage(count: 2) }
            let row = try XCTUnwrap(host.views(GTKStackView.self).dropFirst().first)
            let taps = try XCTUnwrap(row.listening?.controllers[.taps]?.first)

            for run in 1...4 {
                GTKTestHost.emit(taps, "pressed", [Double(run), 20, 20])
                GTKTestHost.emit(taps, "released", [Double(run), 20, 20])
            }
            host.settle { host.texts.first == "taps 2" }

            XCTAssertEqual(host.texts.first, "taps 2")
        }
    }

    /// A press dragged moves the state it carries from where it stood, says its phases and totals, and a swipe is
    /// told when it ends having gone far enough a way the view listens for; the pointer's press says where it went
    /// down and where it was let go.
    func testADragMovesItsStateAndEndsAsASwipe() throws {
        try onUIThread {
            let host = GTKRenderer.running { DragPage() }
            let box = try XCTUnwrap(host.views(GTKShapeView.self).first)
            let drag = try XCTUnwrap(box.listening?.controllers[.drags]?.first)
            let press = try XCTUnwrap(box.listening?.controllers[.pointer]?.last)

            GTKTestHost.emit(press, "drag-begin", [70, 50])
            GTKTestHost.emit(drag, "drag-begin", [70, 50])
            GTKTestHost.emit(drag, "drag-update", [-60, 5])
            GTKTestHost.emit(drag, "drag-end", [-60, 5])
            GTKTestHost.emit(press, "drag-end", [-60, 5])
            let expected = "x -50 pressed 70; pan 0 0; pan 1 -60; pan 2 0; swiped 2; released 10; "
            host.settle { host.texts.first == expected }

            XCTAssertEqual(host.texts.first, expected)
        }
    }

    /// A press that has not gone past the drag threshold is no drag; one gone a way the view does not listen for
    /// is no swipe.
    func testADragThatWentNowhereItListensForIsNoSwipe() throws {
        try onUIThread {
            let host = GTKRenderer.running { DragPage() }
            let box = try XCTUnwrap(host.views(GTKShapeView.self).first)
            let drag = try XCTUnwrap(box.listening?.controllers[.drags]?.first)

            GTKTestHost.emit(drag, "drag-begin", [0, 0])
            GTKTestHost.emit(drag, "drag-update", [2, 1])
            GTKTestHost.emit(drag, "drag-end", [2, 1])
            GTKTestHost.emit(drag, "drag-begin", [0, 0])
            GTKTestHost.emit(drag, "drag-update", [0, -80])
            GTKTestHost.emit(drag, "drag-end", [0, -80])
            let expected = "x 10 pan 0 0; pan 1 0; pan 2 0; "
            host.settle { host.texts.first == expected }

            XCTAssertEqual(host.texts.first, expected)
        }
    }

    /// A pinch says its scale since the last step and where it is; the pointer says where it moved.
    func testAPinchAndThePointerSayWhereTheyAre() throws {
        try onUIThread {
            let host = GTKRenderer.running { DragPage() }
            let box = try XCTUnwrap(host.views(GTKShapeView.self).first)
            let zoom = try XCTUnwrap(box.listening?.controllers[.pinches]?.first)
            let motion = try XCTUnwrap(box.listening?.controllers[.pointer]?.first)

            GTKTestHost.emit(zoom, "scale-changed", [1.5])
            GTKTestHost.emit(zoom, "scale-changed", [3])
            GTKTestHost.emit(motion, "motion", [12, 7])
            let expected = "x 10 pinch 1.5 at 0.5; pinch 2.0 at 0.5; moved 12,7; "
            host.settle { host.texts.first == expected }

            XCTAssertEqual(host.texts.first, expected)
        }
    }

    /// ALT AND A DRAG ARE TWO FINGERS: a view that hears a pinch hears a press with Alt - and one without it, it
    /// leaves - as the press and its mirror about its middle: twice as far from the middle, twice the spread.
    func testAnAltDragIsTwoFingers() throws {
        try onUIThread {
            let host = GTKRenderer.running { DragPage() }
            let box = try XCTUnwrap(host.views(GTKShapeView.self).first)
            let listening = try XCTUnwrap(box.listening)
            XCTAssertNotNil(listening.mirroredDrag, "a drag of its own for the press with Alt")
            XCTAssertTrue(GTKListening.takesMirrored(GDK_ALT_MASK))
            XCTAssertFalse(GTKListening.takesMirrored(GdkModifierType(0)), "a press without Alt is the view's own")

            listening.mirrored(.began, at: Point(x: 75, y: 50), middle: Point(x: 50, y: 50))
            listening.mirrored(.changed, at: Point(x: 100, y: 50), middle: Point(x: 50, y: 50))
            let expected = "x 10 pinch 1.0 at 0.5; pinch 2.0 at 0.5; "
            host.settle { host.texts.first == expected }

            XCTAssertEqual(host.texts.first, expected)
        }
    }

    /// A view listens for what its handlers ask, and its controllers come off once it leaves the tree.
    func testAViewListensForWhatItsHandlersAskAndStopsAsItLeaves() throws {
        try onUIThread {
            let host = GTKRenderer.running { TapsPage(count: 1) }
            let rows = host.views(GTKStackView.self)
            let row = try XCTUnwrap(rows.dropFirst().first)
            let before = row.controllerCount
            XCTAssertEqual(row.hearing, .taps)
            XCTAssertEqual(try XCTUnwrap(rows.last).hearing, [])

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { row.hearing.isEmpty }

            XCTAssertEqual(row.hearing, [])
            XCTAssertEqual(row.controllerCount, before - 1)
        }
    }
}

private extension GTKRenderer {
    /// The words every label shows, in order.
    var texts: [String] {
        views(GTKTextView.self).map(\.text)
    }
}

private extension GTKView {
    /// Presses the view as assistive technology does, through its panel's action.
    func press() {
        gtk_widget_activate_action_variant(widget, GTKPanel.pressAction, nil)
    }

    /// How many controllers the widget holds.
    var controllerCount: Int {
        let controllers = gtk_widget_observe_controllers(widget)
        defer { g_object_unref(UnsafeMutableRawPointer(controllers)) }
        return Int(g_list_model_get_n_items(controllers))
    }
}
