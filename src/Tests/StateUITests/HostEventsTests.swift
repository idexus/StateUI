// Events the HOST raises by name - the push channel, driven through the real
// export: bytes in, subscriptions found, handlers queued on this library's
// executor and drained the way the host drains them.

import XCTest
@testable import StateUI

final class HostEventsTests: XCTestCase {
    /// A place a handler writes - a plain class captured in a test method,
    /// which is the capture that stays on this library's executor.
    private final class Heard {
        var payloads: [[PropValue]] = []
        var order: [String] = []
    }

    /// A subscribed handler hears a raise, with the payload the host wrote -
    /// and the export answers how many heard it.
    func testASubscribedHandlerHearsARaiseWithItsPayload() {
        let heard = Heard()
        let subscription = HostEvents.on(Event("Test.BatteryChanged")) { payload in
            heard.payloads.append(payload)
        }
        defer { subscription.cancel() }

        XCTAssertEqual(raise("Test.BatteryChanged", [.number(0.87), .bool(true)]), 1)
        stateUIRunJobs()

        XCTAssertEqual(heard.payloads, [[.number(0.87), .bool(true)]])
    }

    /// Two handlers run in the order they were subscribed - the addHandler
    /// rule, on the channel's own registry.
    func testHandlersRunInTheOrderTheyWereSubscribed() {
        let heard = Heard()
        let first = HostEvents.on(Event("Test.Ordered")) { _ in heard.order.append("first") }
        let second = HostEvents.on(Event("Test.Ordered")) { _ in heard.order.append("second") }
        defer {
            first.cancel()
            second.cancel()
        }

        XCTAssertEqual(raise("Test.Ordered", []), 2)
        stateUIRunJobs()

        XCTAssertEqual(heard.order, ["first", "second"])
    }

    /// A cancelled subscription hears nothing further, cancelling twice is
    /// harmless, and a raise nobody subscribed to is an ordinary zero - the
    /// battery reports whether a page is watching or not.
    func testACancelledSubscriptionHearsNothing() {
        let heard = Heard()
        let subscription = HostEvents.on(Event("Test.Cancelled")) { payload in
            heard.payloads.append(payload)
        }

        subscription.cancel()
        subscription.cancel()

        XCTAssertEqual(raise("Test.Cancelled", [.bool(true)]), 0)
        stateUIRunJobs()

        XCTAssertEqual(heard.payloads, [])
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
