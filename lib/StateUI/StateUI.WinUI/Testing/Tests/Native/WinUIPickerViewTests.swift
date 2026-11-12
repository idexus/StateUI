// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUIPickerViewTests: XCTestCase {
    /// A segment row that left the tree is nobody's to choose in: assistive technology still holding one of its
    /// segments chooses through it, the choice reaches no state, and the window goes on.
    func testASegmentHeldAfterItsRowLeftChoosesNothing() throws {
        try onUIThread {
            let shown = State(wrappedValue: true)
            let mode = State(wrappedValue: "Stays")
            let host = WinUIRenderer.running {
                VStack {
                    if shown.wrappedValue {
                        Picker(["Stays", "Follows"], selection: mode.projectedValue).presentation(.segmented)
                    }
                    Button("Hide").onClicked { shown.wrappedValue = false }
                }
            }
            let picker = try XCTUnwrap(host.views(WinUIPickerView.self).first)
            let peer = try XCTUnwrap(stateui_winui_segment_peer(picker.handle, 1))
            defer { stateui_winui_release(peer) }

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            _ = host.runtime.core.runJobs()
            host.settle { host.views(WinUIPickerView.self).isEmpty }
            XCTAssertTrue(host.views(WinUIPickerView.self).isEmpty, "the row left")

            _ = stateui_winui_peer_select(peer)
            WinUITestHost.pump(0.5)

            XCTAssertEqual(mode.wrappedValue, "Stays")
        }
    }
}
