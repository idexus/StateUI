// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
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

final class WinUIFrameReportTests: XCTestCase {
    /// A view the tree reads says where it stands once laid out: its state, its handler and a reader's content.
    func testAReadViewSaysWhereItStands() throws {
        try onUIThread {
            let host = WinUIRenderer.running { FramesPage() }
            let expected = ["said 120x60", "room 120x60", "reader 90"]
            host.settle { host.views(WinUILabelView.self).map(\.text) == expected }

            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), expected)
        }
    }

    /// A view that moves says where it stands again, and one that stands still says nothing twice.
    func testAViewThatMovesSaysItAgain() throws {
        try onUIThread {
            let host = WinUIRenderer.running { FramesPage() }
            host.settle { host.views(WinUILabelView.self).first?.text == "said 120x60" }

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { host.views(WinUILabelView.self).first?.text == "said 200x60" }

            XCTAssertEqual(host.views(WinUILabelView.self).prefix(2).map(\.text), ["said 200x60", "room 200x60"])
        }
    }
}
