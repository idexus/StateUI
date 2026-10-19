// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
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
        let made = Self.elements(of: runtime, ["early", "late"])
        runtime.frames.follow(late, of: made[1], reads: true)
        runtime.frames.follow(early, of: made[0], reads: true)
        runtime.frames.serve(scroller, order: 5)
        XCTAssertTrue(runtime.frames.wantsFrames)

        runtime.frames.commit(now: 16)
        XCTAssertEqual(log.values, ["scroller moved", "early stands", "late stands"])
        XCTAssertFalse(runtime.frames.wantsFrames, "the scroller said all, and nothing moved since")

        runtime.frames.follow(late, of: made[1], reads: false)
        runtime.frames.laidOut()
        log.values = []
        runtime.frames.commit(now: 32)
        XCTAssertEqual(log.values, ["early stands"])
    }

    /// What was laid out says where it stands at once, where the toolkit tells it before it draws - and says it
    /// again on no frame after; a scroller still moves on the display's frame alone.
    func testWhatWasLaidOutSaysWhereItStandsAtOnce() {
        let runtime = HostRuntime.still()
        let log = Received()
        let (reader, scroller) = (Said("reader", log), Said("scroller", log))
        runtime.frames.follow(reader, of: Self.elements(of: runtime, ["reader"])[0], reads: true)
        runtime.frames.serve(scroller, order: 2)

        XCTAssertTrue(runtime.frames.reportLaidOut(), "something was laid out, and said so")
        XCTAssertEqual(log.values, ["reader stands"])
        XCTAssertFalse(runtime.frames.reportLaidOut(), "nothing laid out since")

        runtime.frames.commit(now: 16)
        XCTAssertEqual(log.values, ["reader stands", "scroller moved"])
    }

    /// An element that leaves the tree is followed no more - its view may live on a while, held by the toolkit, and
    /// says nothing.
    func testAnElementThatLeavesIsFollowedNoMore() {
        let runtime = HostRuntime.still()
        let log = Received()
        let (kept, gone) = (Said("kept", log), Said("gone", log))
        let made = Self.elements(of: runtime, ["kept", "gone"])
        runtime.frames.follow(kept, of: made[0], reads: true)
        runtime.frames.follow(gone, of: made[1], reads: true)

        _ = Self.elements(of: runtime, ["kept"])
        runtime.frames.laidOut()
        runtime.frames.commit(now: 16)

        XCTAssertEqual(log.values, ["kept stands"])
    }

    /// The elements `names` stand in `runtime`'s tree, in that order - the tree before replaced.
    private static func elements(of runtime: HostRuntime, _ names: [String]) -> [MountedElement] {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged(names.map { HostPatch(id: .manual($0), type: .text) })
        runtime.tree.apply(stack, complete: true)
        return names.compactMap { runtime.tree.root?.first(id: .manual($0)) }
    }
}
