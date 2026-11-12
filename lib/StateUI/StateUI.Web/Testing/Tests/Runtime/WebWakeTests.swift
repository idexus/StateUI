// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@testable import StateUIWeb
import XCTest

/// The page calls the program again when it asked: a browser counts a timer's delay in 32 bits, so a wait past
/// twenty-four days is asked for in parts, each woken to find its time not come and asking for the rest.
@MainActor
final class WebWakeTests: XCTestCase {
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
