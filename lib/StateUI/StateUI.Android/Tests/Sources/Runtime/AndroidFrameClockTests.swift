// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUIAndroid
import XCTest

final class AndroidFrameClockTests: XCTestCase {
    static var allTests: [(String, (AndroidFrameClockTests) -> () throws -> Void)] {
        [
            ("testAHandWoundClockTakesNoFrameOfTheDisplays", testAHandWoundClockTakesNoFrameOfTheDisplays),
        ]
    }

    /// A HAND-WOUND CLOCK TAKES NO FRAME OF THE DISPLAY'S: the choreographer's callback reaches the one current clock,
    /// and a frame an earlier clock asked for, stamped on the monotonic clock, would run the runtime ahead of the
    /// test's time for good - every animation after it standing still.
    func testAHandWoundClockTakesNoFrameOfTheDisplays() {
        onMainActor {
            let clock = AndroidFrameClock(now: { 0 }, ticksWithTheDisplay: false)
            var heard: [Double] = []
            clock.onFrame = { heard.append($0) }
            clock.held = true

            clock.frame(201_399_315)

            XCTAssertEqual(heard, [], "the display's frame, stamped on another clock, went by")
        }
    }
}
