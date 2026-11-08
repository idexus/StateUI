// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUITesting
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUIDriverLifetimeTests: XCTestCase {
    func testAClosedDriverLeavesALaterDriversFileDialogOpen() throws {
        try onUIThread {
            let old = WinUIDriver()
            let oldWindow = TestWindow(driver: old) { Text("old") }
            try oldWindow.closeNow()

            let next = WinUIDriver()
            var answered = false
            let nextWindow = TestWindow(driver: next) { AskingFilePage { _ in answered = true } }
            defer { try? nextWindow.closeNow() }
            let button = try XCTUnwrap(next.renderer?.views(WinUIButtonView.self).first)
            stateui_winui_button_invoke(button.handle)
            let appearanceDeadline = ContinuousClock.now + .seconds(5)
            while stateui_winui_file_dialog() < 0, ContinuousClock.now < appearanceDeadline { next.step() }
            XCTAssertGreaterThanOrEqual(stateui_winui_file_dialog(), 0, "the successor's native file dialog appeared")
            guard stateui_winui_file_dialog() >= 0 else { return }
            XCTAssertFalse(answered)

            old.close()
            for _ in 0..<5 { next.step() }

            XCTAssertGreaterThanOrEqual(stateui_winui_file_dialog(), 0,
                                       "a repeated old close must not cancel the successor's dialog")
            XCTAssertFalse(answered, "the successor still awaits its own user")

            try nextWindow.closeNow()
            XCTAssertLessThan(stateui_winui_file_dialog(), 0, "the owning window closes its own dialog")
        }
    }
}

private struct AskingFilePage: View {
    @Environment(\.window) private var window
    let answered: @MainActor (ChosenFile?) -> Void

    init(answered: @escaping @MainActor (ChosenFile?) -> Void) {
        self.answered = answered
    }

    var body: some View {
        Button("Open").onClicked(policy: .ignoreWhileRunning) {
            answered(try await window.openFile())
        }
    }
}
