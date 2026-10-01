// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import XCTest

/// A ticked box whose tint a click turns from red to blue.
private struct TintedPage: ContentView {
    @State private var blue = false

    var content: some View {
        VStack {
            CheckBox(true).tint(blue ? Color("#0000FF") : Color("#FF0000"))
            Button("Blue").onClicked { blue = true }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

final class WinUITintTests: XCTestCase {
    private static let red: UInt32 = 0xFFFF_0000

    /// Each control fills with its tint what WinUI fills with the accent: a ticked box, a switch's track while it
    /// is on, and a slider's track up to its thumb.
    func testEachControlFillsWithItsTint() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    CheckBox(true).tint(Color("#FF0000"))
                    Switch(true).tint(Color("#FF0000"))
                    Slider(0.5).tint(Color("#FF0000")).width(200)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let box = try XCTUnwrap(host.views(WinUICheckBoxView.self).first)
            let toggle = try XCTUnwrap(host.views(WinUISwitchView.self).first)
            let slider = try XCTUnwrap(host.views(WinUISliderView.self).first)
            host.settle { box.pixels(at: [(4, 10)]) == [Self.red] }

            XCTAssertEqual(box.pixels(at: [(4, 10)]), [Self.red], "the ticked box")
            XCTAssertEqual(toggle.pixels(at: [(8, 19)]), [Self.red], "the track while on")
            XCTAssertEqual(slider.pixels(at: [(20, 16)]), [Self.red], "the track up to the thumb")
        }
    }

    /// A tint changed after the control is drawn is drawn by the brushes that stand in its resources, which take the
    /// new colour: its theme is not read again, as a tint travelling frame by frame would have it read each frame.
    func testATintChangedLaterIsDrawn() throws {
        try onUIThread {
            let host = WinUIRenderer.running { TintedPage() }
            let box = try XCTUnwrap(host.views(WinUICheckBoxView.self).first)
            host.settle { box.pixels(at: [(4, 10)]) == [Self.red] }
            let read = stateui_winui_themes_read_again()

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { box.pixels(at: [(4, 10)]) == [0xFF00_00FF] }

            XCTAssertEqual(box.pixels(at: [(4, 10)]), [0xFF00_00FF])
            XCTAssertEqual(stateui_winui_themes_read_again(), read, "the theme read again")
        }
    }

    /// A tint first written after the control is drawn with the accent is drawn, and taken away the accent comes
    /// back: the template reads a resource that comes or goes only as its theme is read.
    func testATintWrittenOrTakenAwayLaterIsDrawn() throws {
        try onUIThread {
            let tinted = State(wrappedValue: false)
            let host = WinUIRenderer.running {
                let box = CheckBox(true)
                return VStack { tinted.wrappedValue ? box.tint(Color("#FF0000")) : box }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let box = try XCTUnwrap(host.views(WinUICheckBoxView.self).first)
            host.layOut()
            let accent = box.pixels(at: [(4, 10)])
            XCTAssertNotEqual(accent, [Self.red])

            tinted.wrappedValue = true
            host.settle { box.pixels(at: [(4, 10)]) == [Self.red] }
            XCTAssertEqual(box.pixels(at: [(4, 10)]), [Self.red], "tinted")

            tinted.wrappedValue = false
            host.settle { box.pixels(at: [(4, 10)]) == accent }
            XCTAssertEqual(box.pixels(at: [(4, 10)]), accent, "the accent again")
        }
    }

    /// A control the tree tints nothing reads as tinted with nothing - not with the theme's accent, which its own
    /// resources do not hold.
    func testAControlTintedWithNothingReadsNoTint() throws {
        try onUIThread {
            let host = WinUIRenderer.running { VStack { CheckBox(true) } }
            let box = try XCTUnwrap(host.views(WinUICheckBoxView.self).first)
            XCTAssertEqual(WinUIStrings.read { stateui_winui_read(box.handle, "tint", $0, $1) }, "")
        }
    }
}
