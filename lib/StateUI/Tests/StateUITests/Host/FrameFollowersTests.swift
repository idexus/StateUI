// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// Something the display's frames serve, saying when they did.
@MainActor
private final class Said: FramedScroller, FrameReporter {
    let name: String
    let log: Received
    var wantsFrames = true

    init(_ name: String, _ log: Received) {
        self.name = name
        self.log = log
    }

    func frame(now: Double) {
        log.values.append("\(name) moved")
        wantsFrames = false
    }

    func reportFrame() {
        log.values.append("\(name) stands")
    }
}

/// What was said, in order.
@MainActor
private final class Received {
    var values: [String] = []
}

/// What the display's frames serve besides the core's cycle.
@MainActor
final class FrameFollowersTests: XCTestCase {
    /// On a frame, every moving scroller says what it did, then every element whose frame is read says where it
    /// stands, each in the order it was made; a scroller that has said all is let go, and so is an element no
    /// longer read.
    func testAFrameHearsTheScrollersThenTheFramesReadInOrder() {
        let runtime = HostRuntime.still()
        let log = Received()
        let (late, early, scroller) = (Said("late", log), Said("early", log), Said("scroller", log))
        runtime.frames.follow(late, order: 9, reads: true)
        runtime.frames.follow(early, order: 2, reads: true)
        runtime.frames.serve(scroller, order: 5)
        XCTAssertTrue(runtime.frames.wantsFrames)

        runtime.frames.commit(now: 16)
        XCTAssertEqual(log.values, ["scroller moved", "early stands", "late stands"])
        XCTAssertFalse(runtime.frames.wantsFrames, "the scroller said all, and nothing moved since")

        runtime.frames.follow(late, order: 9, reads: false)
        runtime.frames.laidOut()
        log.values = []
        runtime.frames.commit(now: 32)
        XCTAssertEqual(log.values, ["early stands"])
    }
}
