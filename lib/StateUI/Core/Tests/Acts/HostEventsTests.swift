// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Events the HOST raises, typed, through `HostBoundary.raise` - subscriptions
// found, handlers queued on this library's executor and drained the way the
// host drains them.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class HostEventsTests: XCTestCase {
    /// A place a handler writes - a plain class captured in a test method,
    /// which is the capture that stays on this library's executor.
    private final class Heard {
        var lines: [String] = []
    }

    /// A subscribed handler hears a raise, with the values the host handed it
    /// as the types the event's contract declares.
    func testASubscribedHandlerHearsARaiseWithItsValues() {
        let heard = Heard()
        let subscription = HostEvents.on(TestEvents.batteryChanged) { level, charging in
            heard.lines.append("\(level) \(charging)")
        }
        defer { subscription.cancel() }

        HostBoundary.raise(TestEvents.batteryChanged, 0.87, true)
        deliver()

        XCTAssertEqual(heard.lines, ["0.87 true"])
    }

    /// Two handlers run in the order they were subscribed - the addHandler
    /// rule, on HostEvents' own registry.
    func testHandlersRunInTheOrderTheyWereSubscribed() {
        let heard = Heard()
        let first = HostEvents.on(TestEvents.ordered) { heard.lines.append("first") }
        let second = HostEvents.on(TestEvents.ordered) { heard.lines.append("second") }
        defer {
            first.cancel()
            second.cancel()
        }

        HostBoundary.raise(TestEvents.ordered)
        deliver()

        XCTAssertEqual(heard.lines, ["first", "second"])
    }

    /// A cancelled subscription hears nothing further, cancelling twice is
    /// harmless, and a raise nobody subscribed to is an ordinary one - the
    /// battery reports whether a page is watching or not.
    func testACancelledSubscriptionHearsNothing() {
        let heard = Heard()
        let subscription = HostEvents.on(TestEvents.cancelled) { online in
            heard.lines.append("\(online)")
        }

        subscription.cancel()
        subscription.cancel()

        HostBoundary.raise(TestEvents.cancelled, true)
        deliver()

        XCTAssertEqual(heard.lines, [])
    }

    /// A VIEW HEARS AN EVENT WHILE IT STANDS: subscribed as it is made - once, whatever renders follow - each
    /// raise run by the handler the last render wrote, and heard no more once the view leaves, with nothing to
    /// cancel by hand.
    func testAViewHearsAnEventWhileItStands() {
        let heard = Heard()
        let renders = Renders()
        func tree(_ word: String, showing: Bool = true) -> Node {
            VStack {
                if showing {
                    Text("Battery").onHostEvent(TestEvents.batteryChanged) { level, _ in
                        heard.lines.append("\(word) \(level)")
                    }
                }
            }.node
        }

        renders.render(tree("first"))
        renders.render(tree("second"))
        HostBoundary.raise(TestEvents.batteryChanged, 0.5, false)
        deliver()
        XCTAssertEqual(heard.lines, ["second 0.5"], "one subscription, the last render's handler")

        renders.render(tree("third", showing: false))
        HostBoundary.raise(TestEvents.batteryChanged, 0.25, false)
        deliver()
        XCTAssertEqual(heard.lines, ["second 0.5"], "gone with the view")
        XCTAssertEqual(
            HostEvents.dispatch(TestEvents.batteryChanged.token, [.number(0.1), .bool(false)]), 0,
            "and its subscription with it")
    }

    /// One value and none take the same call: what the raise carries is the
    /// member's payload, whatever its count.
    func testARaiseCarriesOneValueOrNone() {
        let heard = Heard()
        let one = HostEvents.on(TestEvents.connectivityChanged) { online in
            heard.lines.append("online \(online)")
        }
        let none = HostEvents.on(TestEvents.ordered) { heard.lines.append("ordered") }
        defer {
            one.cancel()
            none.cancel()
        }

        HostBoundary.raise(TestEvents.connectivityChanged, true)
        HostBoundary.raise(TestEvents.ordered)
        deliver()

        XCTAssertEqual(heard.lines, ["online true", "ordered"])
    }

    /// Any number of values is heard as it is raised: four, as the contract declares them - by a subscription and by
    /// a view alike.
    func testFourValuesAreHeardAsRaised() {
        let heard = Heard()
        let subscription = HostEvents.on(TestEvents.moved) { x, y, width, label in
            heard.lines.append("\(x) \(y) \(width) \(label)")
        }
        defer { subscription.cancel() }
        let renders = Renders()
        renders.render(Text("x").onHostEvent(TestEvents.moved) { _, _, _, label in heard.lines.append(label) }.node)
        defer { renders.render(VStack {}.node) }

        HostBoundary.raise(TestEvents.moved, 1, 2, 3, "pane")
        deliver()

        XCTAssertEqual(heard.lines, ["1.0 2.0 3.0 pane", "pane"])
    }

    /// A raise is one door in from any thread, as a post is: raised on another thread, the events are heard on the UI
    /// thread in the order raised.
    func testRaisesFromAnotherThreadAreHeardInTheOrderRaised() async throws {
        let heard = Heard()
        let subscription = HostEvents.on(TestEvents.connectivityChanged) { online in
            heard.lines.append("\(online)")
        }
        defer { subscription.cancel() }

        await Task.detached {
            HostBoundary.raise(TestEvents.connectivityChanged, true)
            HostBoundary.raise(TestEvents.connectivityChanged, false)
        }.value
        for _ in 0..<200 {
            guard heard.lines.count < 2 else { break }
            try await Task.sleep(for: .milliseconds(5))
        }

        XCTAssertEqual(heard.lines, ["true", "false"])
    }

    /// What was raised reaches its handlers now, as the job a raise books does, and the jobs the handlers started.
    private func deliver() {
        RaisedEvents.shared.deliver()
        stateUIRunJobs()
    }
}

/// The events these tests raise, declared the way an application declares its
/// own.
private enum TestEvents: ApplicationTier {
    static let name = "TestEvents"

    static let batteryChanged = ElementEvent<Self, (Double, Bool)>("batteryChanged")
    static let ordered = ElementEvent<Self, Void>("ordered")
    static let cancelled = ElementEvent<Self, Bool>("cancelled")
    static let connectivityChanged = ElementEvent<Self, Bool>("connectivityChanged")
    static let moved = ElementEvent<Self, (Double, Double, Double, String)>("moved")

    static let members: [any ContractMember] = [batteryChanged, ordered, cancelled, connectivityChanged, moved]
}
