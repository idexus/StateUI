// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

/// What a state says, read by the page's body.
private struct SaidPage: View {
    let said: State<String>

    var body: some View {
        Text(said.wrappedValue)
    }
}

/// A page that asks the user, then says the answer.
private struct AskingPage: View {
    @State private var said = "asked"

    var body: some View {
        VStack {
            Text(said)
            Button("Confirm").onClicked(.ignoreWhileRunning) {
                let deleting = try await Dialogs.confirm("Delete draft?", message: "", accept: "Delete", cancel: "Keep")
                said = deleting ? "deleted" : "kept"
            }
        }
    }
}

/// The doorbell: a change no event of GTK's comes after is rendered by a turn the host posts to GLib's main loop -
/// with nothing but that loop turning.
final class GTKDoorbellTests: XCTestCase {
    /// A write on the UI thread that none of the host's entries made - an application's own callback - asks for its
    /// turn itself.
    func testAWriteNoEventFollowsIsRendered() {
        onUIThread {
            let said = State(wrappedValue: "before")
            let host = GTKRenderer.running { SaidPage(said: said) }
            GTKDoorbell.install()
            defer { CoreLink().postTurns(with: nil) }

            said.wrappedValue = "written"

            XCTAssertTrue(Self.loopShows("written", host), "the write waits for an event that never comes")
        }
    }

    /// A post from another thread lands as a job, whose queueing posts the turn on that thread.
    func testAPostFromAnotherThreadIsRendered() {
        onUIThread {
            let said = State(wrappedValue: "before")
            let host = GTKRenderer.running { SaidPage(said: said) }
            GTKDoorbell.install()
            defer { CoreLink().postTurns(with: nil) }
            let binding = said.projectedValue

            Task.detached { binding.post("posted") }

            XCTAssertTrue(Self.loopShows("posted", host), "the post waits for an event that never comes")
        }
    }

    /// An answer the user gives resumes its caller as a job, whose queueing posts the turn: the host takes no turn
    /// of its own after an answer.
    func testAnAnsweredQuestionIsRendered() throws {
        try onUIThread {
            let host = GTKRenderer.running { AskingPage() }
            GTKDoorbell.install()
            defer { CoreLink().postTurns(with: nil) }

            try XCTUnwrap(host.views(GTKButtonView.self).first { $0.text == "Confirm" }).click()
            for _ in 0..<200 where host.dialog == nil { GTKTestHost.pump(0.01) }
            try host.answer("Delete")

            XCTAssertTrue(Self.loopShows("deleted", host), "the answer waits for an event that never comes")
        }
    }

    /// Turns GLib's loop alone - no turn of the test's own - until the page shows `text`, at most two seconds; then
    /// a moment more, for a turn still posted to run before the next test.
    @MainActor
    private static func loopShows(_ text: String, _ host: GTKRenderer) -> Bool {
        defer { GTKTestHost.pump(0.05) }
        for _ in 0..<200 {
            if host.views(GTKTextView.self).map(\.text) == [text] { return true }
            GTKTestHost.pump(0.01)
        }
        return false
    }
}
