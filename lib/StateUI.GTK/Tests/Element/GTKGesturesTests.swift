// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

/// A row that counts its taps - `count` of them in a quick run make one - beside a stack that answers nothing.
private struct TapsPage: ContentView {
    let count: Int
    @State private var taps = 0
    @State private var shown = true

    var content: any View {
        VStack {
            Label("taps \(taps)")
            if shown {
                HStack { Label("row") }
                    .width(200)
                    .height(40)
                    .onTapped(count: count) { taps += 1 }
            }
            HStack { Label("plain") }
                .width(200)
                .height(40)
            Button("Hide").onClicked { shown = false }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// A box a press drags across, a swipe told apart, and what the pan, the pinch and the pointer said last.
private struct DragPage: ContentView {
    @State private var x = 10.0
    @State private var said = ""

    var content: any View {
        VStack {
            Label("x \(Int(x)) \(said)")
            ColorBox(.steelBlue)
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
            let box = try XCTUnwrap(host.views(GTKColorBoxView.self).first)
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
            let box = try XCTUnwrap(host.views(GTKColorBoxView.self).first)
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
            let box = try XCTUnwrap(host.views(GTKColorBoxView.self).first)
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

    /// A view listens for what its handlers ask, and its controllers come off once it leaves the runtime.tree.
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
        views(GTKLabelView.self).map(\.text)
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
