// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
import Foundation
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// A page that asks the host the time of day, its zone, and zones' distances from UTC on a winter's and a summer's
/// day; then a zone nobody knows; then a word to a screen reader.
private struct AskingPage: ContentView {
    @State private var said = ""

    var content: any View {
        VStack {
            Label(said)
            Button("Time").onClicked {
                let time = try await ClockTime.now()
                let zone = try await TimeZoneInfo.local()
                let tokyo = try await TimeZoneInfo.utcOffset(of: "Asia/Tokyo")
                let winter = try await TimeZoneInfo.utcOffset(
                    of: "Europe/Warsaw", on: CalendarDate(year: 2026, month: 1, day: 15))
                let summer = try await TimeZoneInfo.utcOffset(
                    of: "Europe/Warsaw", on: CalendarDate(year: 2026, month: 7, day: 15))
                said = "\((0..<24).contains(time.hour)) \(zone.contains("/")) \(tokyo.components.seconds / 60) "
                    + "\(winter.components.seconds / 60) \(summer.components.seconds / 60)"
            }
            Button("Nowhere").onClicked {
                do {
                    _ = try await TimeZoneInfo.utcOffset(of: "Nowhere/Else")
                    said = "answered"
                } catch {
                    said = "refused"
                }
            }
            Button("Say").onClicked {
                try await ScreenReader.announce("done")
                said = "announced"
            }
        }
    }
}

/// A field a button puts the keyboard's focus on, and another takes it off.
private struct FocusPage: ContentView {
    @Aim(TextField.self) private var field
    @State private var words = ""
    @State private var said = ""

    var content: any View {
        VStack {
            Label(said)
            TextField($words).aim(field)
            Button("Focus").onClicked { said = "took \(try await field.focus())" }
            Button("Unfocus").onClicked {
                try await field.unfocus()
                said = "let go"
            }
        }
    }
}

final class WinUIActsTests: XCTestCase {
    /// The host answers the time of day and its zone, and a zone's distance from UTC on the day asked - summer
    /// time included.
    func testTheHostAnswersTheTimeAndTheZones() throws {
        try onUIThread {
            let host = WinUIRenderer.running { AskingPage() }

            try host.press("Time")
            host.settle { host.said != "" }

            XCTAssertEqual(host.said, "true true 540 60 120")
        }
    }

    /// A zone the host does not know fails the act, which the caller hears as an error.
    func testAZoneNobodyKnowsIsRefused() throws {
        try onUIThread {
            let host = WinUIRenderer.running { AskingPage() }

            try host.press("Nowhere")
            host.settle { host.said != "" }

            XCTAssertEqual(host.said, "refused")
        }
    }

    /// A word to a screen reader is said, and the caller goes on.
    func testAWordToAScreenReaderIsSaid() throws {
        try onUIThread {
            let host = WinUIRenderer.running { AskingPage() }

            try host.press("Say")
            host.settle { host.said != "" }

            XCTAssertEqual(host.said, "announced")
        }
    }

    /// A field aimed at takes the keyboard's focus, and lets it go when asked.
    func testAFieldTakesTheFocusAndLetsItGo() throws {
        try onUIThread {
            let host = WinUIRenderer.running { FocusPage() }
            let field = try XCTUnwrap(host.views(WinUITextFieldView.self).first)

            try host.press("Focus")
            host.settle { host.said != "" }
            XCTAssertEqual(host.said, "took true")
            XCTAssertTrue(stateui_winui_focused(field.handle))

            try host.press("Unfocus")
            host.settle { host.said == "let go" }
            XCTAssertFalse(stateui_winui_focused(field.handle))
        }
    }

    /// The kept values' store reads back what it was given, whatever the words hold, and the same values write the
    /// same file.
    func testTheStoreReadsBackWhatItKept() {
        onUIThread {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-winui-store").path
            stateui_winui_set_store(folder)
            defer { stateui_winui_set_store("") }

            let values = ["com.example.name": "Zażółć\tgęślą\njaźń \\ end", "com.example.on": "true"]
            WinUIPersistence.write(values)

            XCTAssertEqual(WinUIPersistence.read(), values)
            XCTAssertEqual(WinUIPersistence.word(of: .number(3), kind: .integer), "3")
            XCTAssertEqual(WinUIPersistence.word(of: .bool(false), kind: .boolean), "false")
            XCTAssertNil(WinUIPersistence.word(of: .string("x"), kind: .number))
        }
    }
}

private extension WinUIRenderer {
    /// What the page's first label says.
    var said: String {
        views(WinUILabelView.self).first?.text ?? ""
    }

    /// Presses the button of that caption.
    func press(_ caption: String) throws {
        try XCTUnwrap(views(WinUIButtonView.self).first { $0.text == caption }).invoke()
    }
}
