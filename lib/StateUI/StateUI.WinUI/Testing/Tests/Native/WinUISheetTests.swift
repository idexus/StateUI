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
    /// A sheet's card stands as large as its page - here its least, its words few - and one holding a stack, whose
    /// pages come and go, at a dialog's standard size, held within the window.
    func testACardStandsAsLargeAsItsPageAndAStacksAtTheStandardSize() throws {
        try onUIThread {
            @MainActor func card(_ host: WinUIRenderer) throws -> [Double] {
                let sheet = try XCTUnwrap(host.windows.first?.sheetsForTesting.first)
                return try XCTUnwrap(WinUIStrings.read { stateui_winui_read(sheet.handle, "card", $0, $1) })
                    .split(separator: ",").compactMap { Double($0) }
            }
            let host = WinUIRenderer.running {
                Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) { Text("A note") }
            }
            host.settle { (try? card(host))?.first ?? 0 > 0 }
            XCTAssertEqual(try card(host), [320, 184], "its least")

            let stacked = WinUIRenderer.running {
                Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Text("Root") } destination: { _ in Text("Next") }
                }
            }
            stacked.settle { (try? card(stacked))?.first ?? 0 > 320 }
            let room = try XCTUnwrap(stacked.window?.content).laidOutFrame
            let standard = try card(stacked)
            XCTAssertEqual(standard[0], min(548, room.width - 96), accuracy: 1, "the standard width within the window")
            XCTAssertEqual(standard[1], min(640, room.height - 96), accuracy: 48, "the standard height within it")
        }
    }

    /// A stack in a sheet brings its bar to the card's head: the top page's title, the way back to the page beneath
    /// and the close button, which takes the sheet away, false onto its state.
    func testAStackInASheetBringsItsBarToTheCard() throws {
        try onUIThread {
            let (shows, path) = (State(wrappedValue: true), State(wrappedValue: [Int]()))
            let host = WinUIRenderer.running {
                Text("Beneath").sheet(isPresented: shows.projectedValue) {
                    NavigationStack(path.projectedValue) {
                        Text("Root").title("Root")
                    } destination: { number in
                        Text("Page \(number)").title("Pushed")
                    }
                }
            }
            let window = try XCTUnwrap(host.window)
            host.settle { stateui_winui_window_sheets(window.handle) == 1 }
            let sheet = try XCTUnwrap(host.windows.first?.sheetsForTesting.first)
            @MainActor func head(_ what: String) -> String? { WinUIStrings.read { stateui_winui_read(sheet.handle, what, $0, $1) } }
            XCTAssertEqual(head("title"), "Root")
            XCTAssertEqual(head("back"), "0", "no way back from the root")
            XCTAssertEqual(head("close"), "1")

            path.wrappedValue = [1]
            host.settle { head("title") == "Pushed" }
            XCTAssertEqual(head("back"), "1")

            sheet.chose(-1)
            host.settle { path.wrappedValue.isEmpty }
            XCTAssertEqual(path.wrappedValue, [], "back to the root")

            sheet.chose(-2)
            host.settle { stateui_winui_window_sheets(window.handle) == 0 }
            XCTAssertFalse(shows.wrappedValue, "the sheet closed")
        }
    }

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
