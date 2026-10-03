// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

private enum Sheet: Hashable {
    case first, second
}

/// The page beneath the window's sheets, presenting the first and saying where it stands.
private struct SheetsPage: View {
    let log: Received<String>
    @Binding var sheets: [Sheet]

    var body: some View {
        let sheets = $sheets
        return VStack {
            Text("beneath")
            Button("Present").onClicked { sheets.wrappedValue.append(.first) }
        }
        .loggingPhases(log, as: "beneath")
    }
}

/// The window's sheets over a page saying where it stands.
private func sheetsOver(_ sheets: State<[Sheet]>, log: Received<String>) -> ModalStack {
    ModalStack(sheets.projectedValue) {
        SheetsPage(log: log, sheets: sheets.projectedValue)
    } destination: { sheet in
        SheetPage(name: "\(sheet)", sheets: sheets.projectedValue)
    }
}

/// A page presented on a sheet, which presents another.
private struct SheetPage: View {
    let name: String
    @Binding var sheets: [Sheet]

    var body: some View {
        VStack {
            Text("on \(name)")
            Button("Another").onClicked { sheets.append(.second) }
        }
        .title(name)
    }
}

final class WinUISheetTests: XCTestCase {
    /// Escape takes the top sheet away and the way back of a sheet with none of its own takes it away too: the
    /// window hears how many remain, and the page beneath shows again.
    func testEscapeAndTheWayBackTakeTheTopSheetAway() throws {
        try onUIThread {
            let (sheets, log) = (State(wrappedValue: [Sheet]()), Received<String>())
            let host = WinUIRenderer.running { sheetsOver(sheets, log: log) }
            let window = try XCTUnwrap(host.window)
            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            host.settle { stateui_winui_window_sheets(window.handle) == 2 }

            window.titleBar.chose(-3)
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 1, "Escape took the top away")

            window.titleBar.chose(-1)
            host.settle { stateui_winui_window_sheets(window.handle) == 0 }
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 0, "the way back took the last away")
            XCTAssertEqual(Array(log.values.suffix(2)), ["beneath appearing", "beneath navigatedTo"], "shown again, as a move")
        }
    }
}
