// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@testable import StateUIWeb
import XCTest

/// The page calls the program again when it asked: a browser counts a timer's delay in 32 bits, so a wait past
/// twenty-four days is asked for in parts, each woken to find its time not come and asking for the rest.
@MainActor
final class WebWakeTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// The first part of a long wait ending, the program finds its time not come: nothing kept for later runs, and
    /// the page is asked again for the rest, in parts as before.
    func testTheEndOfAWaitsFirstPartAsksForTheRest() throws {
        let host = WebRenderer.running { Text("Waiting") }
        defer { host.finish() }
        // The page's timer as it would be past its first part: the first long one ends at once, the rest as asked.
        _ = try WebBrowser.evaluate("""
            (globalThis.asked = [], globalThis.endedEarly = 0, globalThis.timerAsBefore = setTimeout,
             globalThis.setTimeout = (run, delay, ...rest) => {
               if (delay < 1e9) return timerAsBefore(run, delay, ...rest);
               asked.push(delay);
               if (endedEarly > 0) return timerAsBefore(run, delay, ...rest);
               endedEarly += 1;
               return timerAsBefore(() => { asked.push('ended'); run() }, 0, ...rest);
             },
             '')
            """, on: 0)
        defer { _ = try? WebBrowser.evaluate("(globalThis.setTimeout = timerAsBefore, '')", on: 0) }
        var woke = false
        let sleeper = Task { @MainActor in
            try await Task.sleep(for: .seconds(30 * 86_400))
            woke = true
        }
        defer { sleeper.cancel() }

        for _ in 0..<5 { host.step() }

        XCTAssertEqual(try WebBrowser.evaluate("String(endedEarly)", on: 0), "1", "the first part ended")
        let asked = try XCTUnwrap(WebBrowser.evaluate("asked.join(',')", on: 0)).split(separator: ",")
        XCTAssertEqual(asked.prefix(3), ["2147483647", "ended", "2147483647"], "the first part, then the rest: \(asked)")
        XCTAssertEqual(Set(asked.filter { $0 != "ended" }), ["2147483647"], "every part as long as a timer counts")
        XCTAssertFalse(woke, "nothing kept for later ran before its time")
    }

    func testAWaitPastWhatATimerCountsIsAskedForInParts() throws {
        _ = try WebBrowser.evaluate("""
            (globalThis.asked = [], globalThis.timerAsBefore = setTimeout,
             globalThis.setTimeout = (run, delay, ...rest) => { asked.push(delay); return timerAsBefore(run, delay, ...rest) },
             '')
            """, on: 0)
        defer { _ = try? WebBrowser.evaluate("(globalThis.setTimeout = timerAsBefore, '')", on: 0) }

        WebRelay.wake(after: 30 * 86_400_000)
        WebRelay.wake(after: 1_000)

        XCTAssertEqual(try WebBrowser.evaluate("asked.join(',')", on: 0), "2147483647,1000")
    }
}
