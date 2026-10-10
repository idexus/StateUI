// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import XCTest
@_spi(Host) import StateUI
@testable import StateUIAppKit

/// The turn after each pass of the main run loop: what a pass wrote is on the screen when the pass is over.
@MainActor
final class AppKitTurnTests: XCTestCase {
    /// A write made by a job of the main queue - a resumed task, a post - is rendered in the pass that ran it,
    /// with nothing else asked of the host.
    func testAWriteFromAJobRendersInThePassThatRanIt() throws {
        let said = Said()
        let renderer = AppKitRenderer.running { SaidPage(said: said) }
        defer { renderer.closeForTesting() }
        renderer.startTurns()
        let shown = { renderer.nativeViews(AppKitTextView.self).first?.textForTesting.string }
        XCTAssertEqual(shown(), "before")

        DispatchQueue.main.async { said.text = "after" }

        // A run of the loop returns once its pass is over; the pass that ran the write is the last one run.
        for _ in 0..<100 where said.text != "after" {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        XCTAssertEqual(shown(), "after", "the pass that wrote it rendered it")
    }

    /// A post from another thread lands as a job of the main queue, and its pass renders it.
    func testAPostFromAnotherThreadIsRendered() throws {
        let said = Said()
        let renderer = AppKitRenderer.running { SaidPage(said: said) }
        defer { renderer.closeForTesting() }
        renderer.startTurns()
        let shown = { renderer.nativeViews(AppKitTextView.self).first?.textForTesting.string }
        let binding = said.$text

        Task.detached { binding.post("posted") }

        for _ in 0..<100 where shown() != "posted" {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        XCTAssertEqual(shown(), "posted", "the post waits for an event")
    }

    /// A question the user answers resumes its caller as a job of the main queue, and the pass that ran it renders
    /// what the caller wrote - the host takes no turn of its own after an answer.
    func testAnAnsweredQuestionIsRenderedInThePassThatResumedItsCaller() throws {
        let renderer = AppKitRenderer.running { AskingPage() }
        defer { renderer.closeForTesting() }
        renderer.startTurns()
        let shown = { renderer.nativeViews(AppKitTextView.self).first?.textForTesting.string }

        try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first).clickForTesting()
        for _ in 0..<100 where renderer.actToolkit.showing == nil {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertTrue(try XCTUnwrap(renderer.actToolkit.showing).pressForTesting("Delete", typing: nil))
        for _ in 0..<100 where shown() != "deleted" {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        XCTAssertEqual(shown(), "deleted", "the answer waits for an event")
    }
}

/// What the page says, written from outside it.
@MainActor
private final class Said {
    @State var text = "before"
}

/// A page that asks the user, then says the answer.
private struct AskingPage: View {
    @State private var said = "asked"

    var body: some View {
        VStack {
            Text(said)
            Button("Confirm").onClicked(gate: .ignoreWhileRunning) {
                let deleting = try await Dialogs.confirm("Delete draft?", message: "", accept: "Delete", cancel: "Keep")
                said = deleting ? "deleted" : "kept"
            }
        }
    }
}

private struct SaidPage: View {
    let said: Said

    var body: some View {
        Text(said.text)
    }
}
#endif
