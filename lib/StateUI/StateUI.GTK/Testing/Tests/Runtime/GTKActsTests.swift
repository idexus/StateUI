// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

/// A page that asks the host the time of day, its zone, and zones' distances from UTC on a winter's and a summer's
/// day; then a zone nobody knows; then a word to a screen reader.
private struct AskingPage: View {
    @State private var said = ""

    var body: some View {
        VStack {
            Text(said)
            Button("Time").onClicked(gate: .ignoreWhileRunning) {
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
            Button("Nowhere").onClicked(gate: .ignoreWhileRunning) {
                do {
                    _ = try await TimeZoneInfo.utcOffset(of: "Nowhere/Else")
                    said = "answered"
                } catch {
                    said = "refused"
                }
            }
            Button("Say").onClicked(gate: .ignoreWhileRunning) {
                try await ScreenReader.announce("done")
                said = "announced"
            }
        }
    }
}

/// A field a button puts the keyboard's focus on, and another takes it off.
private struct FocusPage: View {
    @Aim(TextField.self) private var field
    @State private var words = ""
    @State private var said = ""

    var body: some View {
        VStack {
            Text(said)
            TextField($words).aim(field)
            Button("Focus").onClicked(gate: .ignoreWhileRunning) { said = "took \(try await field.focus())" }
            Button("Unfocus").onClicked(gate: .ignoreWhileRunning) {
                try await field.unfocus()
                said = "let go"
            }
        }
    }
}

/// A page whose buttons ask the user each kind of question, saying every answer after the last.
private struct QuestionsPage: View {
    @State private var said = ""

    var body: some View {
        VStack {
            Text(said)
            Button("Alert").onClicked(gate: .ignoreWhileRunning) {
                try await Dialogs.alert("Saved", message: "The draft is kept")
                said += "alerted; "
            }
            Button("Confirm").onClicked(gate: .ignoreWhileRunning) {
                let accepted = try await Dialogs.confirm(
                    "Delete draft?", message: "It goes for good", accept: "Delete", cancel: "Keep")
                said += "confirmed \(accepted); "
            }
            Button("Choose").onClicked(gate: .ignoreWhileRunning) {
                let chosen = try await Dialogs.chooseAction(
                    "Share via", cancel: "Cancel", destruction: "Delete", buttons: ["Mail", "Message"])
                said += "chose \(chosen ?? "nothing"); "
            }
            Button("Prompt").onClicked(gate: .ignoreWhileRunning) {
                let typed = try await Dialogs.prompt("Rename", placeholder: "Name", initialValue: "Draft")
                said += "typed \(typed ?? "nothing"); "
            }
        }
    }
}

@MainActor
final class GTKActsTests: XCTestCase {
    /// The host answers the time of day and its zone, and a zone's distance from UTC on the day asked - summer
    /// time included.
    func testTheHostAnswersTheTimeAndTheZones() throws {
        try onUIThread {
            let host = GTKRenderer.running { AskingPage() }

            try host.press("Time")
            host.settle { host.said != "" }

            XCTAssertEqual(host.said, "true true 540 60 120")
        }
    }

    /// A zone the host does not know fails the act, which the caller hears as an error.
    func testAZoneNobodyKnowsIsRefused() throws {
        try onUIThread {
            let host = GTKRenderer.running { AskingPage() }

            try host.press("Nowhere")
            host.settle { host.said != "" }

            XCTAssertEqual(host.said, "refused")
        }
    }

    /// A word to a screen reader is said, and the caller goes on.
    func testAWordToAScreenReaderIsSaid() throws {
        try onUIThread {
            let host = GTKRenderer.running { AskingPage() }

            try host.press("Say")
            host.settle { host.said != "" }

            XCTAssertEqual(host.said, "announced")
        }
    }

    /// A field aimed at takes the keyboard's focus, and lets it go when asked - GTK leaves it nowhere.
    func testAFieldTakesTheFocusAndLetsItGo() throws {
        try onUIThread {
            let host = GTKRenderer.running { FocusPage() }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)

            try host.press("Focus")
            host.settle { host.said != "" }
            XCTAssertEqual(host.said, "took true")
            XCTAssertTrue(field.holdsFocus)

            try host.press("Unfocus")
            host.settle { host.said == "let go" }
            XCTAssertFalse(field.holdsFocus)
        }
    }

    /// A question cancelled answers so: a confirmation not accepted, a choice the cancelling caption, a prompt
    /// nothing; a choice dismissed by Escape, nothing chosen.
    func testACancelledQuestionAnswersSo() throws {
        try onUIThread {
            let host = GTKRenderer.running { QuestionsPage() }

            try host.press("Confirm")
            try host.answer("Keep")
            try host.press("Choose")
            try host.answer("Cancel")
            try host.press("Prompt")
            try host.answer("Cancel")
            try host.press("Choose")
            try host.dismiss()
            let expected = "confirmed false; chose Cancel; typed nothing; chose nothing; "
            host.settle { host.said == expected }

            XCTAssertEqual(host.said, expected)
        }
    }

    /// A prompt's field holds the keyboard as its dialog shows, so the user types at once.
    func testAPromptsFieldTakesTheKeyboard() throws {
        try onUIThread {
            let host = GTKRenderer.running { QuestionsPage() }

            try host.press("Prompt")
            let dialog = try XCTUnwrap(host.dialog)
            let focus = try XCTUnwrap(adw_dialog_get_focus(dialog.of(AdwDialog.self)))

            XCTAssertNotNil(gtk_widget_get_ancestor(focus, gtk_entry_get_type()), "the focus is the field, or its text")
            try host.answer("Cancel")
        }
    }

    /// The kept values' file reads back what was written to it, whatever the words hold.
    func testTheFileReadsBackWhatItKept() {
        onUIThread {
            let file = String(cString: g_get_tmp_dir()) + "/stateui-gtk-tests/kept values.txt"
            let kept = KeptValuesText("com.example.name\tZażółć\\tgęślą\ncom.example.on\ttrue\n")

            XCTAssertTrue(GTKKeptValues.write(kept, to: file))
            XCTAssertEqual(GTKKeptValues.read(file), kept)
            XCTAssertEqual(GTKKeptValues.file(for: "any"), file, "the tests keep their values aside")
        }
    }
}

private extension GTKRenderer {
    /// What the page's first label says.
    var said: String {
        views(GTKTextView.self).first?.text ?? ""
    }

    /// Presses the button of that caption.
    func press(_ caption: String) throws {
        try XCTUnwrap(views(GTKButtonView.self).first { $0.text == caption }).click()
        settle { true }
    }
}

private extension GTKTextFieldView {
    /// Whether the keyboard's focus stands in the field.
    var holdsFocus: Bool {
        guard let root = gtk_widget_get_root(widget), let focus = gtk_root_get_focus(root) else { return false }
        return focus == widget || gtk_widget_is_ancestor(focus, widget) != 0
    }
}
