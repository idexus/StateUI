// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A sidebar sliding in and out frame by frame: how far it has come climbs to where it is going and rests there, a
/// slide turned back bends from where it stands, one following a toolkit's slide keeps its motion and its time, less
/// motion arrives at once, and the pane and the page stand as far as it has come.
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

    /// Either way it eases out: fast first, slow as it arrives.
    func testItEasesOutEitherWay() {
        var opening: [Double] = []
        slide.slide(1, from: 0, shown: true) { shown, _ in opening.append(shown) }
        frame(at: SidebarSlide.milliseconds / 2)
        XCTAssertGreaterThan(opening.last ?? 0, 0.5, "in, more than half the way at half the time")

        frame(at: SidebarSlide.milliseconds * 2)
        var closing: [Double] = []
        slide.slide(1, from: 1, shown: false) { shown, _ in closing.append(shown) }
        frame(at: SidebarSlide.milliseconds * 2.5)
        XCTAssertLessThan(closing.last ?? 1, 0.5, "out, more than half the way at half the time")
    }

    /// A frame coming late - the first ones of a page measured at new widths - moves a slide one longest frame's
    /// way, not the whole time it was late: the slide slows rather than skipping.
    func testALateFrameSlowsTheSlideRatherThanSkippingIt() {
        var seen: [Double] = []
        slide.slide(1, from: 0, shown: true) { shown, _ in seen.append(shown) }
        clock = SidebarSlide.milliseconds * 3
        slide.pace(now: clock)
        slide.follow(animator.advance(to: clock))

        let expected = Animation(
            from: [0], destination: [1], velocity: [0], motion: .eased(UInt(SidebarSlide.milliseconds), .cubicOut),
            began: 0).position(at: SidebarSlide.longestFrame).value[0]
        XCTAssertEqual(seen.last ?? 0, expected, accuracy: 1e-9, "one longest frame's way")
        XCTAssertTrue(animator.isMoving, "still on its way")
    }

    /// Following a toolkit's own slide, it moves by the toolkit's motion and keeps its time: a late frame is not
    /// slowed, as the toolkit's sidebar is not.
    func testASlideFollowingAToolkitKeepsItsMotionAndItsTime() {
        let toolkit = Motion.spring(response: 340)
        var seen: [Double] = []
        slide.slide(1, from: 0, shown: true, following: toolkit) { shown, _ in seen.append(shown) }
        clock = 120
        slide.pace(now: clock)
        slide.follow(animator.advance(to: clock))

        let expected = Animation(from: [0], destination: [1], velocity: [0], motion: toolkit, began: 0)
            .position(at: 120).value[0]
        XCTAssertEqual(seen.last ?? 0, expected, accuracy: 1e-9, "where the toolkit's sidebar stands")
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
