// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// One split view's sidebar sliding on the runtime's frames: it sets out once, stands its column each frame with its
/// page at the whole width, rests shown or folded, turns back from where it stands, carries what the tree says of
/// it, and keeps the column's width only while it stands.
@MainActor
final class SplitSlideTests: XCTestCase {
    private var clock = 0.0
    private let animator = Animator()
    private lazy var runtimeSlide = SidebarSlide(animator: animator, now: { self.clock }, reducesMotion: { false })
    private var events: [String] = []

    private func split(width: Double = 260) -> SplitSlide {
        let split = SplitSlide(slide: runtimeSlide, mount: 1, width: width)
        split.begin = { [unowned self] shows in events.append("begin \(shows)") }
        split.stand = { [unowned self] pane, page in events.append("stand \(Int(pane.rounded())) \(Int(page))") }
        split.rest = { [unowned self] shown in events.append("rest \(shown)") }
        return split
    }

    /// The display's frames, one each 16 ms, until `time`.
    private func frames(until time: Double) {
        while clock < time {
            clock = min(clock + 16, time)
            runtimeSlide.pace(now: clock)
            runtimeSlide.follow(animator.advance(to: clock))
        }
    }

    func testASlideSetsOutStandsEachFrameAndRests() {
        let split = split()
        split.slide(to: true)
        XCTAssertEqual(events, ["begin true", "stand 0 260"], "it sets out from where it stands")
        XCTAssertTrue(split.carries(true), "the tree saying it shows is the slide's own")
        XCTAssertFalse(split.carries(false))

        frames(until: 48)
        frames(until: SidebarSlide.milliseconds + 48)
        XCTAssertEqual(events.last, "rest true")
        XCTAssertEqual(events.filter { $0.hasPrefix("begin") }.count, 1)
        XCTAssertTrue(events.dropLast().last?.hasPrefix("stand 260") == true, "the last frame stands it whole")
        XCTAssertFalse(split.carries(true), "at rest the tree says what it says")
    }

    func testASlideTurnedBackGoesTheOtherWayFromWhereItStands() {
        let split = split()
        XCTAssertTrue(split.toggled(shown: false), "a folded sidebar toggles in")
        split.slide(to: true)
        frames(until: 48)
        XCTAssertFalse(split.toggled(shown: false), "toggled again amid its slide in, it goes out")
        split.slide(to: false)
        XCTAssertEqual(events.filter { $0.hasPrefix("begin") }.count, 1, "a slide under way sets out no more")
        frames(until: clock + 2000)
        XCTAssertEqual(events.last, "rest false")
    }

    func testTheColumnsWidthIsKeptOnlyWhileItStands() {
        let split = split(width: 260)
        split.columnStood(300)
        split.slide(to: false)
        split.columnStood(120)
        frames(until: clock + 2000)
        split.slide(to: true)
        XCTAssertEqual(events.last, "stand 0 300", "the width it last stood at, not one it slid through")
    }
}
