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
        for _ in 0..<200 where heard.lines.count < 2 { try await Task.sleep(for: .milliseconds(5)) }

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
    static let name = "Test"

    static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Test.BatteryChanged")
    static let ordered = ElementEvent<Self, Void>("Test.Ordered")
    static let cancelled = ElementEvent<Self, Bool>("Test.Cancelled")
    static let connectivityChanged = ElementEvent<Self, Bool>("Test.ConnectivityChanged")

    static let members: [any ContractMember] = [batteryChanged, ordered, cancelled, connectivityChanged]
}
