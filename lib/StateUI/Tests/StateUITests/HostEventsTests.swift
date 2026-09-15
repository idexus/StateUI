// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Events the HOST raises by name, driven through the real
// export: bytes in, subscriptions found, handlers queued on this library's
// executor and drained the way the host drains them.

import XCTest
@_spi(Host) @testable import StateUI

final class HostEventsTests: XCTestCase {
    /// A place a handler writes - a plain class captured in a test method,
    /// which is the capture that stays on this library's executor.
    private final class Heard {
        var lines: [String] = []
    }

    /// A subscribed handler hears a raise, with the values the host wrote as
    /// the types the event's contract declares - and the export answers how
    /// many heard it.
    func testASubscribedHandlerHearsARaiseWithItsValues() {
        let heard = Heard()
        let subscription = HostEvents.on(TestEvents.batteryChanged) { level, charging in
            heard.lines.append("\(level) \(charging)")
        }
        defer { subscription.cancel() }

        XCTAssertEqual(raise("Test.BatteryChanged", [.number(0.87), .bool(true)]), 1)
        stateUIRunJobs()

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

        XCTAssertEqual(raise("Test.Ordered", []), 2)
        stateUIRunJobs()

        XCTAssertEqual(heard.lines, ["first", "second"])
    }

    /// A cancelled subscription hears nothing further, cancelling twice is
    /// harmless, and a raise nobody subscribed to is an ordinary zero - the
    /// battery reports whether a page is watching or not.
    func testACancelledSubscriptionHearsNothing() {
        let heard = Heard()
        let subscription = HostEvents.on(TestEvents.cancelled) { online in
            heard.lines.append("\(online)")
        }

        subscription.cancel()
        subscription.cancel()

        XCTAssertEqual(raise("Test.Cancelled", [.bool(true)]), 0)
        stateUIRunJobs()

        XCTAssertEqual(heard.lines, [])
    }

    /// A buffer that will not read is refused whole, and the export says so
    /// with -1 - which the session reports as version skew.
    func testAnUnreadableBufferAnswersMinusOne() {
        let garbage: [UInt8] = [99, 1, 2, 3]

        let answer = garbage.withUnsafeBufferPointer { bytes in
            stateui_dispatch_host_event(bytes.baseAddress, Int32(bytes.count))
        }

        XCTAssertEqual(answer, -1)
    }

    // MARK: - Support

    /// Raises an event through the real export, bytes and all, and answers
    /// what the export answered.
    private func raise(_ name: String, _ values: [PropValue]) -> Int32 {
        var out: [UInt8] = []
        out.u8(Wire.version)
        out.string(name)
        out.u8(UInt8(values.count))
        for value in values { out.value(value) }

        return out.withUnsafeBufferPointer { bytes in
            stateui_dispatch_host_event(bytes.baseAddress, Int32(bytes.count))
        }
    }
}

/// The events these tests raise, declared the way an application declares its
/// own.
private enum TestEvents: ApplicationTier {
    static let name = "Test"

    static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Test.BatteryChanged")
    static let ordered = ElementEvent<Self, Void>("Test.Ordered")
    static let cancelled = ElementEvent<Self, Bool>("Test.Cancelled")

    static let members: [any ContractMember] = [batteryChanged, ordered, cancelled]
}
