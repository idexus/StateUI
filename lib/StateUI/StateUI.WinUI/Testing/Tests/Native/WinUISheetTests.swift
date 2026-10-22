// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

/// The page beneath the window's sheets, presenting the first and saying where it stands.
private struct SheetsPage: View {
    let log: Received<String>
    let first: State<Bool>
    let second: State<Bool>

    var body: some View {
        let first = self.first
        return VStack {
            Text("beneath")
            Button("Present").onClicked { first.wrappedValue = true }
        }
        .loggingPhases(log, as: "beneath")
        .sheet(isPresented: first.projectedValue) { SheetPage(presents: second) }
    }
}

/// A page presented on a sheet, which presents another.
private struct SheetPage: View {
    let presents: State<Bool>

    var body: some View {
        let presents = self.presents
        return VStack {
            Text("on first")
            Button("Another").onClicked { presents.wrappedValue = true }
        }
        .title("first")
        .sheet(isPresented: presents.projectedValue) { Text("on second").title("second") }
    }
}

final class WinUISheetTests: XCTestCase {
    /// Escape takes the top sheet away and the way back of a sheet with none of its own takes it away too: each
    /// writes false onto its state, and the page beneath shows again.
    func testEscapeAndTheWayBackTakeTheTopSheetAway() throws {
        try onUIThread {
            let (first, second, log) = (State(wrappedValue: false), State(wrappedValue: false), Received<String>())
            let host = WinUIRenderer.running { SheetsPage(log: log, first: first, second: second) }
            let window = try XCTUnwrap(host.window)
            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            host.settle { stateui_winui_window_sheets(window.handle) == 2 }

            window.titleBar.chose(-3)
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 1, "Escape took the top away")
            XCTAssertEqual([first.wrappedValue, second.wrappedValue], [true, false])

            window.titleBar.chose(-1)
            host.settle { stateui_winui_window_sheets(window.handle) == 0 }
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 0, "the way back took the last away")
            XCTAssertFalse(first.wrappedValue)
            XCTAssertEqual(Array(log.values.suffix(2)), ["beneath appearing", "beneath navigatedTo"], "shown again, as a move")
        }
    }
}
