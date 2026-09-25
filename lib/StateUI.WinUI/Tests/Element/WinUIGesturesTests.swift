// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
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
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

final class WinUIGesturesTests: XCTestCase {
    /// A row that answers a tap is pressed by assistive technology as a tap; a stack that answers nothing is not.
    func testATappedRowIsPressedByAssistiveTechnology() throws {
        try onUIThread {
            let host = WinUIRenderer.running { TapsPage(count: 1) }
            let rows = host.views(WinUIStackView.self)
            let row = try XCTUnwrap(rows.dropFirst().first)
            let plain = try XCTUnwrap(rows.last)

            XCTAssertTrue(row.press())
            XCTAssertTrue(row.press())
            XCTAssertFalse(plain.press(), "a stack answering nothing is no button")
            host.settle { host.texts.first == "taps 2" }

            XCTAssertEqual(host.texts.first, "taps 2")
        }
    }

    /// A row that answers a tap is hit where it draws nothing, past its words; a stack that answers nothing is not.
    func testATappedRowIsHitWhereItDrawsNothing() throws {
        try onUIThread {
            let host = WinUIRenderer.running { TapsPage(count: 1) }
            let rows = host.views(WinUIStackView.self)

            XCTAssertTrue(try XCTUnwrap(rows.dropFirst().first).hits(190, 20))
            XCTAssertFalse(try XCTUnwrap(rows.last).hits(190, 20))
        }
    }

    /// A quick run of taps answers each time it reaches the count asked for; a press made by assistive
    /// technology answers at once.
    func testARunOfTapsAnswersAtItsCount() throws {
        try onUIThread {
            let host = WinUIRenderer.running { TapsPage(count: 2) }
            let row = try XCTUnwrap(host.views(WinUIStackView.self).dropFirst().first)

            for run in 1...4 { row.heard(.tap(run: run)) }
            host.settle { host.texts.first == "taps 2" }
            XCTAssertEqual(host.texts.first, "taps 2")

            row.heard(.tap(run: 0))
            host.settle { host.texts.first == "taps 3" }
            XCTAssertEqual(host.texts.first, "taps 3")
        }
    }

    /// A press dragged moves the state it carries from where it stood, says its phases and totals, and a swipe is
    /// told when it ends having gone far enough a way the view listens for.
    func testADragMovesItsStateAndEndsAsASwipe() throws {
        try onUIThread {
            let host = WinUIRenderer.running { DragPage() }
            let box = try XCTUnwrap(host.views(WinUIColorBoxView.self).first)

            box.heard(.drag(phase: 0, x: 0, y: 0))
            box.heard(.drag(phase: 1, x: -60, y: 5))
            box.heard(.drag(phase: 2, x: -60, y: 5))
            let expected = "x -50 pan 0 0; pan 1 -60; pan 2 0; swiped 2; "
            host.settle { host.texts.first == expected }

            XCTAssertEqual(host.texts.first, expected)
        }
    }

    /// A drag too short, or going a way the view does not listen for, is no swipe.
    func testADragThatWentNowhereItListensForIsNoSwipe() throws {
        try onUIThread {
            let host = WinUIRenderer.running { DragPage() }
            let box = try XCTUnwrap(host.views(WinUIColorBoxView.self).first)

            for moved in [(20.0, 0.0), (0.0, -80.0)] {
                box.heard(.drag(phase: 0, x: 0, y: 0))
                box.heard(.drag(phase: 2, x: moved.0, y: moved.1))
            }
            host.settle { host.texts.first?.contains("pan 2 0; pan 0 0; pan 2 0;") == true }

            XCTAssertFalse(host.texts.first?.contains("swiped") ?? true, host.texts.first ?? "")
        }
    }

    /// A pinch says its scale since the last and where it is; the pointer says where it moved.
    func testAPinchAndThePointerSayWhereTheyAre() throws {
        try onUIThread {
            let host = WinUIRenderer.running { DragPage() }
            let box = try XCTUnwrap(host.views(WinUIColorBoxView.self).first)

            box.heard(.pinch(phase: 1, scale: 1.5, at: Point(x: 0.25, y: 0.75)))
            box.heard(.pointer(.pointerMoved, Point(x: 12, y: 7)))
            let expected = "x 10 pinch 1.5 at 0.25; moved 12,7; "
            host.settle { host.texts.first == expected }

            XCTAssertEqual(host.texts.first, expected)
        }
    }

    /// A view listens for what its handlers ask, and stops once it leaves the tree.
    func testAViewListensForWhatItsHandlersAskAndStopsAsItLeaves() throws {
        try onUIThread {
            let host = WinUIRenderer.running { TapsPage(count: 1) }
            let rows = host.views(WinUIStackView.self)
            let row = try XCTUnwrap(rows.dropFirst().first)
            XCTAssertEqual(row.hearing, UInt32(StateUIHearingTaps.rawValue))
            XCTAssertEqual(try XCTUnwrap(rows.last).hearing, 0)
            let listening = stateui_winui_listeners()

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { stateui_winui_listeners() == listening - 1 }

            XCTAssertEqual(stateui_winui_listeners(), listening - 1)
            XCTAssertEqual(row.hearing, 0)
        }
    }
}

private extension WinUIRenderer {
    /// The words every label shows, in order.
    var texts: [String] {
        views(WinUILabelView.self).map(\.text)
    }
}
