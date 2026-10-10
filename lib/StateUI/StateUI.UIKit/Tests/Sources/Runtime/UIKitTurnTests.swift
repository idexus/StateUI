// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@testable import StateUIUIKit
import XCTest

/// What a state says, read by the page's body.
private struct SaidPage: View {
    let said: State<String>

    var body: some View {
        Text(said.wrappedValue)
    }
}

/// The turn after each pass of the main run loop: what a pass wrote is on the screen when the pass is over.
final class UIKitTurnTests: XCTestCase {
    /// A write made by a job of the main queue - a resumed task, a post - is rendered in the pass that ran it,
    /// with nothing else asked of the host.
    @MainActor
    func testAWriteFromAJobRendersInThePassThatRanIt() {
        let said = State(wrappedValue: "before")
        let host = UIKitRenderer.running { SaidPage(said: said) }
        defer { host.finish() }
        host.startTurns()
        XCTAssertEqual(host.views(UIKitTextView.self).first?.text, "before")

        DispatchQueue.main.async { said.wrappedValue = "after" }

        // A run of the loop returns once its pass is over; the pass that ran the write is the last one run.
        for _ in 0..<100 where said.wrappedValue != "after" {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        XCTAssertEqual(host.views(UIKitTextView.self).first?.text, "after", "the pass that wrote it rendered it")
    }

    /// A post from another thread lands as a job of the main queue, and its pass renders it.
    @MainActor
    func testAPostFromAnotherThreadIsRendered() {
        let said = State(wrappedValue: "before")
        let host = UIKitRenderer.running { SaidPage(said: said) }
        defer { host.finish() }
        host.startTurns()
        let binding = said.projectedValue

        Task.detached { binding.post("posted") }

        for _ in 0..<100 where host.views(UIKitTextView.self).first?.text != "posted" {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        XCTAssertEqual(host.views(UIKitTextView.self).first?.text, "posted", "the post waits for an event")
    }
}
