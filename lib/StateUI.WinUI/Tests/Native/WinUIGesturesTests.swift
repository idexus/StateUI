// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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

    /// The relay listens by the host layer's own bits, which a view hands it as they are.
    func testTheRelayListensByTheHostLayersBits() {
        XCTAssertEqual(Hearing.taps.rawValue, UInt32(StateUIHearingTaps.rawValue))
        XCTAssertEqual(Hearing.pointer.rawValue, UInt32(StateUIHearingPointer.rawValue))
        XCTAssertEqual(Hearing.drags.rawValue, UInt32(StateUIHearingDrags.rawValue))
        XCTAssertEqual(Hearing.pinches.rawValue, UInt32(StateUIHearingPinches.rawValue))
    }

    /// A view listens for what its handlers ask, and stops once it leaves the tree.
    func testAViewListensForWhatItsHandlersAskAndStopsAsItLeaves() throws {
        try onUIThread {
            let host = WinUIRenderer.running { TapsPage(count: 1) }
            let rows = host.views(WinUIStackView.self)
            let row = try XCTUnwrap(rows.dropFirst().first)
            XCTAssertEqual(row.hearing, .taps)
            XCTAssertEqual(try XCTUnwrap(rows.last).hearing, [])
            let listening = stateui_winui_listeners()

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { stateui_winui_listeners() == listening - 1 }

            XCTAssertEqual(stateui_winui_listeners(), listening - 1)
            XCTAssertEqual(row.hearing, [])
        }
    }
}

private extension WinUIRenderer {
    /// The words every label shows, in order.
    var texts: [String] {
        views(WinUILabelView.self).map(\.text)
    }
}
