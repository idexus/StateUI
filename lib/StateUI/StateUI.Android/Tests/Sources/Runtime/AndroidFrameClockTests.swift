// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUIAndroid
import XCTest

final class AndroidFrameClockTests: XCTestCase {
    static var allTests: [(String, (AndroidFrameClockTests) -> () throws -> Void)] {
        [
            ("testAHandWoundClockTakesNoFrameOfTheDisplays", testAHandWoundClockTakesNoFrameOfTheDisplays),
            ("testAClockAfterAnotherTakesEachFrameOnce", testAClockAfterAnotherTakesEachFrameOnce),
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

    /// A clock made while another waits for a frame - an activity made again - takes each of the display's frames
    /// once: the one callback is asked for once, whichever clock asked.
    func testAClockAfterAnotherTakesEachFrameOnce() {
        onMainActor {
            let first = AndroidFrameClock()
            first.held = true
            let second = AndroidFrameClock()
            var times: [Double] = []
            second.onFrame = { times.append($0) }
            second.held = true

            TestWindow.run(for: 200)
            second.held = false
            TestWindow.run(for: 50)

            XCTAssertGreaterThan(times.count, 2, "the display's frames came")
            XCTAssertEqual(times.count, Set(times).count, "and none twice")
        }
    }
}
