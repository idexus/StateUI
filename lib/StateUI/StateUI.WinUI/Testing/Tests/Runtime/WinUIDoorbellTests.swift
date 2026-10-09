// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

/// What a state says, read by the page's body.
private struct SaidPage: View {
    let said: State<String>

    var body: some View {
        Text(said.wrappedValue)
    }
}

/// The doorbell: a change no event of WinUI's comes after is rendered by a turn the host posts to the UI thread's
/// queue - with nothing but that thread's messages running.
final class WinUIDoorbellTests: XCTestCase {
    /// A write on the UI thread that none of the host's entries made - an application's own callback - asks for its
    /// turn itself.
    func testAWriteNoEventFollowsIsRendered() {
        onUIThread {
            let said = State(wrappedValue: "before")
            let host = WinUIRenderer.running { SaidPage(said: said) }
            WinUIDoorbell.install()
            defer { CoreLink().postTurns(with: nil) }

            said.wrappedValue = "written"

            XCTAssertTrue(Self.messagesShow("written", host), "the write waits for an event that never comes")
        }
    }

    /// A post from another thread lands as a job, whose queueing posts the turn on that thread.
    func testAPostFromAnotherThreadIsRendered() {
        onUIThread {
            let said = State(wrappedValue: "before")
            let host = WinUIRenderer.running { SaidPage(said: said) }
            WinUIDoorbell.install()
            defer { CoreLink().postTurns(with: nil) }
            let binding = said.projectedValue

            Task.detached { binding.post("posted") }

            XCTAssertTrue(Self.messagesShow("posted", host), "the post waits for an event that never comes")
        }
    }

    /// Runs the thread's messages alone - no turn of the test's own - until the page shows `text`, at most two
    /// seconds; then a moment more, for a turn still posted to run before the next test.
    @MainActor
    private static func messagesShow(_ text: String, _ host: WinUIRenderer) -> Bool {
        defer { WinUITestHost.pump(0.05) }
        for _ in 0..<200 {
            if host.views(WinUITextView.self).map(\.text) == [text] { return true }
            WinUITestHost.pump(0.01)
        }
        return false
    }
}
