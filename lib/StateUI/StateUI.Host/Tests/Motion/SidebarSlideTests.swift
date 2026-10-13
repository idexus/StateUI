// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A sidebar sliding in and out frame by frame: how far it has come climbs to where it is going and rests there, a
/// slide turned back bends from where it stands, less motion arrives at once, and the pane and the page stand as
/// far as it has come.
@MainActor
final class SidebarSlideTests: XCTestCase {
    private var clock = 0.0
    private let animator = Animator()
    private lazy var slide = SidebarSlide(animator: animator, now: { self.clock }, reducesMotion: { false })

    private func frame(at time: Double) {
        clock = time
        slide.follow(animator.advance(to: time))
    }

    func testASidebarSlidesInFrameByFrameAndRests() {
        var seen: [(Double, Bool)] = []
        slide.slide(1, from: 0, shown: true) { seen.append(($0, $1)) }
        XCTAssertEqual(seen.map(\.0), [0], "it sets out from where it stands")

        frame(at: SidebarSlide.milliseconds / 2)
        frame(at: SidebarSlide.milliseconds)
        XCTAssertEqual(seen.count, 3)
        XCTAssertGreaterThan(seen[1].0, 0, "on its way")
        XCTAssertLessThan(seen[1].0, 1)
        XCTAssertEqual(seen.last?.0, 1)
        XCTAssertEqual(seen.last?.1, true, "it rests where it was going")
        XCTAssertFalse(animator.isMoving)
    }

    func testASlideTurnedBackBendsFromWhereItStands() {
        var seen: [Double] = []
        slide.slide(1, from: 0, shown: true) { shown, _ in seen.append(shown) }
        frame(at: SidebarSlide.milliseconds / 2)
        let halfway = try? XCTUnwrap(seen.last)

        slide.slide(1, from: 0, shown: false) { shown, _ in seen.append(shown) }
        XCTAssertEqual(seen.last, halfway, "it turns back from where it stands, not from where it began")
        frame(at: SidebarSlide.milliseconds * 2)
        XCTAssertEqual(seen.last, 0)
    }

    func testLessMotionArrivesAtOnce() {
        let still = SidebarSlide(animator: animator, now: { 0 }, reducesMotion: { true })
        var seen: [(Double, Bool)] = []
        still.slide(1, from: 0, shown: true) { seen.append(($0, $1)) }
        XCTAssertEqual(seen.map(\.0), [1])
        XCTAssertEqual(seen.map(\.1), [true])
        XCTAssertFalse(animator.isMoving)
    }

    func testThePaneAndThePageStandAsFarAsItHasCome() {
        XCTAssertEqual(SidebarSlide.paneWidth(0.25, of: 320), 80)
        XCTAssertEqual(SidebarSlide.paneWidth(1.5, of: 320), 320, "never past its width")
        XCTAssertEqual(
            SidebarSlide.page(inPane: 80, width: 320, height: 600), Rect(x: -240, y: 0, width: 320, height: 600),
            "the page at its whole width, its trailing edge at the pane's")
    }
}
