// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import StateUIConformance
import XCTest

/// A box that says where it stands, into a state and to a handler, and a reader built from its own frame.
private struct FramesPage: View {
    @State private var said = ""
    @State private var room = Rect(x: 0, y: 0, width: 0, height: 0)
    @State private var wide = false

    var body: some View {
        VStack {
            Text("said \(said)")
            Text("room \(Int(room.width))x\(Int(room.height))")
            Rectangle()
                .fill(.steelBlue)
                .width(wide ? 200 : 120)
                .height(60)
                .frame(into: $room)
                .onFrameChanged { frame in said = "\(Int(frame.width))x\(Int(frame.height))" }
            GeometryReader { frame in Text("reader \(Int(frame.width))") }
                .width(90)
                .height(20)
            Button("Widen").onClicked { wide = true }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// A page under its header bar: a stack at the top of its content, and a label at the stack's top.
private struct PlacedOnAPage: View {
    let heard: Received<String>

    var body: some View {
        let heard = self.heard
        return VStack {
            Text("top").onFrameChanged(in: .global) { frame in heard.values.append("window \(Int(frame.y))") }
        }
        .onFrameChanged(in: .safeArea) { frame in heard.values.append("page \(Int(frame.y))") }
        .pageTitle("Placed")
    }
}

@MainActor
final class GTKFrameReportTests: XCTestCase {
    /// A view the tree reads says where it stands once laid out: its state, its handler and a reader's content.
    func testAReadViewSaysWhereItStands() {
        onUIThread {
            let host = GTKRenderer.running { FramesPage() }
            let expected = ["said 120x60", "room 120x60", "reader 90"]
            host.settle { host.views(GTKTextView.self).map(\.text) == expected }

            XCTAssertEqual(host.views(GTKTextView.self).map(\.text), expected)
        }
    }

    /// A view the tree reads says where it stands in the frame's layout that placed it, before the frame is drawn:
    /// no display frame comes between - a sidebar's slide lays a page out every frame. A frame its readers said in
    /// hears nothing more, one that laid the window out again moving nothing among them, so the layout widening it
    /// comes in a frame they said nothing in yet.
    func testAViewSaysWhereItStandsInTheLayoutThatPlacedIt() throws {
        try onUIThread {
            let wide = State(wrappedValue: false)
            let heard = Received<Double>()
            let host = GTKRenderer.running {
                VStack {
                    Rectangle()
                        .fill(.steelBlue)
                        .width(wide.wrappedValue ? 200 : 120)
                        .height(60)
                        .onEvent(ViewContract.frameChanged) { heard.values.append($0[2]) }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.settle { heard.values.last == 120 }
            let window = host.window ?? GTKTestHost.window

            let clock = try XCTUnwrap(gtk_widget_get_frame_clock(window.widget))
            gdk_frame_clock_begin_updating(clock)
            defer { gdk_frame_clock_end_updating(clock) }
            let frame = { Int64(gdk_frame_clock_get_frame_counter(clock)) }
            let saidIn = { GTKWindow.reportedFrame(of: window.number) ?? -1 }
            gtk_widget_queue_resize(window.widget)
            XCTAssertTrue(
                GTKTestHost.pump(until: { saidIn() == frame() }),
                "a frame laid the window out again: said in \(saidIn()), frame \(frame())")
            XCTAssertTrue(
                GTKTestHost.pump(until: { saidIn() < frame() }),
                "a frame its readers said nothing in: said in \(saidIn()), frame \(frame())")

            wide.wrappedValue = true
            host.runtime.pump.turn()
            GTKTestHost.emit(clock, "layout")
            XCTAssertEqual(heard.values.last, 200, "said in the layout that widened it: said in \(saidIn()), frame \(frame())")

            // The layout repeats once for what was said, and ends: a frame's readers say once.
            wide.wrappedValue = false
            host.runtime.pump.turn()
            GTKTestHost.emit(clock, "layout")
            XCTAssertEqual(heard.values.last, 200, "nothing more said in the same frame")
        }
    }

    /// A view says nothing of where it stands before a layout places it: the first report its handler hears is
    /// where it is laid out.
    func testAViewSaysNothingBeforeItIsLaidOut() {
        onUIThread {
            let heard = Received<[Double]>()
            let host = GTKRenderer.running {
                VStack {
                    Rectangle()
                        .fill(.steelBlue)
                        .width(120)
                        .height(60)
                        .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.settle { !heard.values.isEmpty }

            XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 0, 120, 60])
        }
    }

    /// A view that moves says where it stands again, and one that stands still says nothing twice.
    func testAViewThatMovesSaysItAgain() throws {
        try onUIThread {
            let host = GTKRenderer.running { FramesPage() }
            host.settle { host.views(GTKTextView.self).first?.text == "said 120x60" }

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { host.views(GTKTextView.self).first?.text == "said 200x60" }

            XCTAssertEqual(host.views(GTKTextView.self).prefix(2).map(\.text), ["said 200x60", "room 200x60"])
        }
    }

    /// A view at the top of its page's content stands at zero from the page, and below the page's header bar in
    /// the window.
    func testThePagesCornerIsBeneathItsHeaderBar() {
        onUIThread {
            let heard = Received<String>()
            let host = GTKRenderer.running { PlacedOnAPage(heard: heard) }
            let lastWindow = { heard.values.last { $0.hasPrefix("window") }.flatMap { Int($0.dropFirst(7)) } ?? 0 }
            host.settle { lastWindow() > 0 }

            let window = lastWindow()
            XCTAssertGreaterThan(window, 30, "the header bar stands above the page's content \(heard.values)")
            XCTAssertEqual(heard.values.last { $0.hasPrefix("page") }, "page 0", "\(heard.values)")
        }
    }
}
