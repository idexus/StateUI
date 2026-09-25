// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import StateUIHostConformance
import XCTest

private enum Sheet: Hashable {
    case first, second
}

/// A page that presents sheets over its window, saying where it stands.
private struct SheetsPage: ContentView {
    let log: Received<String>
    @State private var sheets: [Sheet] = []
    @Environment private var window: WindowSession
    @Environment private var page: PageSession

    var content: any View {
        let log = log
        let window = window
        let page = page
        let sheets = $sheets
        return VStack {
            Label("beneath")
            Button("Present").onClicked { sheets.wrappedValue.append(.first) }
        }
        .onCreated {
            window.modalStack = ModalStack(sheets) { sheet in SheetPage(name: "\(sheet)", sheets: sheets) }
        }
        .onChanged(page.phase) { log.values.append("beneath \(page.phase)") }
    }
}

/// A page presented on a sheet, which presents another.
private struct SheetPage: ContentView {
    let name: String
    @Binding var sheets: [Sheet]
    @Environment private var page: PageSession

    var content: any View {
        let page = page
        let name = name
        return VStack {
            Label("on \(name)")
            Button("Another").onClicked { sheets.append(.second) }
        }
        .onCreated { page.title = name }
    }
}

final class WinUISheetTests: XCTestCase {
    /// A presented page stands on a sheet over the whole window, the page beneath hearing that it stopped showing;
    /// a page presented from the sheet stands on another, on top.
    func testAPresentedPageStandsOnASheetOverTheWindow() throws {
        try onUIThread {
            let log = Received<String>()
            let host = WinUIRenderer.running { SheetsPage(log: log) }
            let window = try XCTUnwrap(host.window)
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 0)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 1)
            XCTAssertTrue(host.views(WinUILabelView.self).map(\.text).contains("on first"))
            XCTAssertTrue(log.values.contains("beneath disappearing"), "\(log.values)")

            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            host.settle { stateui_winui_window_sheets(window.handle) == 2 }
            XCTAssertEqual(stateui_winui_window_sheets(window.handle), 2)
        }
    }

    /// Escape takes the top sheet away and the way back of a sheet with none of its own takes it away too: the
    /// window hears how many remain, and the page beneath shows again.
    func testEscapeAndTheWayBackTakeTheTopSheetAway() throws {
        try onUIThread {
            let log = Received<String>()
            let host = WinUIRenderer.running { SheetsPage(log: log) }
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
