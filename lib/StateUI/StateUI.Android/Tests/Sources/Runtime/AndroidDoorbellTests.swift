// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

/// What a state says, read by the page's body.
private struct SaidPage: View {
    let said: State<String>

    var body: some View {
        Text(said.wrappedValue)
    }
}

/// The doorbell: a change no event of Android's comes after is rendered by a turn the host rings onto the main
/// looper - with nothing but that looper turning.
final class AndroidDoorbellTests: XCTestCase {
    static var allTests: [(String, (AndroidDoorbellTests) -> () throws -> Void)] {
        [
            ("testAWriteNoEventFollowsIsRendered", testAWriteNoEventFollowsIsRendered),
            ("testAPostFromAnotherThreadIsRendered", testAPostFromAnotherThreadIsRendered),
        ]
    }

    /// A write on the UI thread that none of the host's entries made - an application's own callback - asks for its
    /// turn itself.
    func testAWriteNoEventFollowsIsRendered() {
        onMainActor {
            let said = State(wrappedValue: "before")
            let host = AndroidRenderer.running { SaidPage(said: said) }
            AndroidDoorbell.install()
            defer { CoreLink().postTurns(with: nil) }

            said.wrappedValue = "written"

            XCTAssertTrue(Self.looperShows("written", host), "the write waits for an event that never comes")
        }
    }

    /// A post from another thread lands as a job; the doorbell's thread wakes for it and rings the turn.
    func testAPostFromAnotherThreadIsRendered() {
        onMainActor {
            let said = State(wrappedValue: "before")
            let host = AndroidRenderer.running { SaidPage(said: said) }
            AndroidDoorbell.install()
            defer { CoreLink().postTurns(with: nil) }
            let binding = said.projectedValue

            Task.detached { binding.post("posted") }

            XCTAssertTrue(Self.looperShows("posted", host), "the post waits for an event that never comes")
        }
    }

    /// Runs the main looper alone - no turn of the test's own - until the page shows `text`, at most two seconds;
    /// then a moment more, for a turn still rung to run before the next test.
    @MainActor
    private static func looperShows(_ text: String, _ host: AndroidRenderer) -> Bool {
        defer { TestWindow.run(for: 50) }
        for _ in 0..<200 {
            if host.views(AndroidTextView.self).map(\.text) == [text] { return true }
            TestWindow.run(for: 10)
        }
        return false
    }
}
