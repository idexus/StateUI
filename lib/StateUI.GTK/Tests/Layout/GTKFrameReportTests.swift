// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// A box that says where it stands, into a state and to a handler, and a reader built from its own frame.
private struct FramesPage: ContentView {
    @State private var said = ""
    @State private var room = Rect(x: 0, y: 0, width: 0, height: 0)
    @State private var wide = false

    var content: any View {
        VStack {
            Label("said \(said)")
            Label("room \(Int(room.width))x\(Int(room.height))")
            ColorBox(.steelBlue)
                .width(wide ? 200 : 120)
                .height(60)
                .frame($room)
                .onFrameChanged { frame in said = "\(Int(frame.width))x\(Int(frame.height))" }
            FrameReader { frame in Label("reader \(Int(frame.width))") }
                .width(90)
                .height(20)
            Button("Widen").onClicked { wide = true }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// A page under its header bar: a stack at the top of its content, and a label at the stack's top.
private struct PlacedOnAPage: ContentView {
    let heard: Received<String>
    @Environment private var page: PageSession

    var content: any View {
        let page = self.page
        let heard = self.heard
        return VStack {
            Label("top").onFrameChanged(in: .global) { frame in heard.values.append("window \(Int(frame.y))") }
        }
        .onFrameChanged(in: .safeArea) { frame in heard.values.append("page \(Int(frame.y))") }
        .onCreated { page.title = "Placed" }
    }
}

final class GTKFrameReportTests: XCTestCase {
    /// A view the tree reads says where it stands once laid out: its state, its handler and a reader's content.
    func testAReadViewSaysWhereItStands() {
        onUIThread {
            let host = GTKRenderer.running { FramesPage() }
            let expected = ["said 120x60", "room 120x60", "reader 90"]
            host.settle { host.views(GTKLabelView.self).map(\.text) == expected }

            XCTAssertEqual(host.views(GTKLabelView.self).map(\.text), expected)
        }
    }

    /// A view that moves says where it stands again, and one that stands still says nothing twice.
    func testAViewThatMovesSaysItAgain() throws {
        try onUIThread {
            let host = GTKRenderer.running { FramesPage() }
            host.settle { host.views(GTKLabelView.self).first?.text == "said 120x60" }

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { host.views(GTKLabelView.self).first?.text == "said 200x60" }

            XCTAssertEqual(host.views(GTKLabelView.self).prefix(2).map(\.text), ["said 200x60", "room 200x60"])
        }
    }

    /// A view at the top of its page's content stands at zero from the page, and below the page's header bar in
    /// the window.
    func testThePagesCornerIsBeneathItsHeaderBar() throws {
        try onUIThread {
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
