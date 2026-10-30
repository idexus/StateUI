// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A layout a hand moves, as every host hears it: the hand and the wheel said as the toolkit tells them reach the
/// layout's run, a throw goes on to the target nearest its end, and a wheel is let go by a frame that finds it still.
@MainActor
final class HandHearingTests: XCTestCase {
    /// A LAYOUT A HAND MOVES HEARS THE HAND, and nothing else of it: the run moves with it, and let go with speed it
    /// travels on to the target nearest where the throw would end.
    func testALayoutAHandMovesHearsTheHand() throws {
        let (runtime, clock) = running()
        let ring = try ring(in: runtime)

        XCTAssertEqual(ring.hearing, [.hand])

        ring.hear(.hand(.began, moved: .zero, speed: nil), in: runtime)
        ring.hear(.hand(.changed, moved: Point(-140, 0), speed: nil), in: runtime)
        frames(runtime, clock, until: 32)
        XCTAssertEqual(handed.last ?? 0, 1.4, accuracy: 0.001, "the run where the hand holds it")

        // 1,000 points a second to the left is 10 cards a second: about a card and a third on.
        ring.hear(.hand(.ended, moved: .zero, speed: Point(-1_000, 0)), in: runtime)
        frames(runtime, clock, until: 6_000)
        XCTAssertEqual(handed.last ?? 0, 3, accuracy: 0.001, "the target nearest where the throw would end")
    }

    /// THE HAND'S MOVES BETWEEN TWO FRAMES REACH THE LAYOUT AS ONE: a toolkit telling the hand faster than the
    /// display draws - 120 times a second, or a burst a busy thread held back - moves the run once a frame by all of
    /// them, rather than working the layout out for each.
    func testTheHandsMovesBetweenTwoFramesReachTheLayoutAsOne() throws {
        let (runtime, clock) = running()
        let ring = try ring(in: runtime)

        ring.hear(.hand(.began, moved: .zero, speed: nil), in: runtime)
        frames(runtime, clock, until: 32)

        // One move, then a frame: what a frame works out.
        var before = handed.count
        ring.hear(.hand(.changed, moved: Point(-3, 0), speed: nil), in: runtime)
        frames(runtime, clock, until: 48)
        let once = handed.count - before

        // Ten moves before the next frame, short of halfway to the next card: none worked out until it, and then
        // no more than for one.
        before = handed.count
        for _ in 0..<10 { ring.hear(.hand(.changed, moved: Point(-3, 0), speed: nil), in: runtime) }
        XCTAssertEqual(handed.count, before, "worked out for none of them yet")

        frames(runtime, clock, until: 64)
        XCTAssertEqual(handed.last ?? 0, 0.33, accuracy: 0.001, "by all of them")
        XCTAssertLessThanOrEqual(handed.count - before, once, "no more than for one")
    }

    /// A WHEEL IS LET GO BY A FRAME THAT FINDS IT STILL: it tells no lift, so the runtime's frames pace it, and the
    /// run travels on to the nearest target.
    func testAWheelIsLetGoByAFrameThatFindsItStill() throws {
        let (runtime, clock) = running()
        let ring = try ring(in: runtime)

        ring.hear(.wheel(Point(-140, 0)), in: runtime)
        frames(runtime, clock, until: 64)
        XCTAssertTrue(runtime.handPace.isOpen, "a wheel moving is open")
        XCTAssertEqual(handed.last ?? 0, 1.4, accuracy: 0.001)

        frames(runtime, clock, until: 1_000)
        XCTAssertFalse(runtime.handPace.isOpen, "let go once it stood still")
        XCTAssertEqual(handed.last ?? 0, 1, accuracy: 0.001, "and the run on the nearest card")
    }

    /// A WHEEL'S NOTCH STEPS THE RUN to the next card, whatever the card's size: the layout hears it as a step, not
    /// as a distance, and the run travels there.
    func testAWheelsNotchStepsTheRun() throws {
        let (runtime, clock) = running()
        let ring = try ring(in: runtime)

        XCTAssertTrue(ring.hear(.notch(Point(-1, 0)), in: runtime))
        frames(runtime, clock, until: 1_000)
        XCTAssertEqual(handed.last ?? 0, 1, accuracy: 0.001, "the next card")

        ring.hear(.notch(Point(-1, 0)), in: runtime)
        ring.hear(.notch(Point(-1, 0)), in: runtime)
        frames(runtime, clock, until: 2_000)
        XCTAssertEqual(handed.last ?? 0, 3, accuracy: 0.001, "a card a notch")
    }

    /// A LAYOUT MIRRORED RIGHT TO LEFT HEARS THE HAND TURNED: laid out right to left, the hand moving right moves the
    /// run on as moving left does left to right - and a layout placing as written hears the hand as it is.
    func testALayoutMirroredRightToLeftHearsTheHandTurned() throws {
        for mirrors in [true, false] {
            let (runtime, clock) = running(RightToLeftApplication(mirrors: mirrors))
            let ring = try ring(in: runtime)

            ring.hear(.hand(.began, moved: .zero, speed: nil), in: runtime)
            ring.hear(.hand(.changed, moved: Point(140, 0), speed: nil), in: runtime)
            frames(runtime, clock, until: 32)

            if mirrors {
                XCTAssertEqual(handed.last ?? 0, 1.4, accuracy: 0.001, "moved on, as the hand goes in the mirror")
            } else {
                XCTAssertLessThan(handed.last ?? 0, 0, "back past the first card, as written")
            }
        }
    }

    /// THE VIEW UNDER THE HAND OF A MIRRORED LAYOUT IS THE ONE DRAWN THERE: the hand at the right edge takes the
    /// view the run wrote at the left, and the author is told the point as the arithmetic reads it.
    func testTheViewUnderTheHandOfAMirroredLayoutIsTheOneDrawnThere() throws {
        let (runtime, clock) = running(RightToLeftApplication(mirrors: true))
        let ring = try ring(in: runtime)

        ring.hear(.hand(.began, moved: .zero, speed: nil, point: Point(295, 5)), in: runtime)
        ring.hear(.hand(.changed, moved: Point(0, 30), speed: nil, point: Point(295, 35)), in: runtime)
        frames(runtime, clock, until: 64)

        let drag = try XCTUnwrap(dragged.first)
        XCTAssertEqual(drag.item, 0, "the view drawn at the right edge")
        XCTAssertEqual(drag.at.x, 5, accuracy: 0.001, "the point mirrored about the room's width")
    }

    /// Display frames until `end`, sixteen milliseconds apart, the clock standing at each.
    private func frames(_ runtime: HostRuntime, _ clock: HandClock, until end: Double) {
        while clock.time < end {
            clock.time += 16
            runtime.displayCycle.frame(now: clock.time)
            runtime.pump.turn()
        }
    }

    private func running(_ application: some Application = HandApplication()) -> (HostRuntime, HandClock) {
        handed = []
        tapped = 0
        dragged = []
        stateUIUseApp(application)
        let clock = HandClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        try? ring(in: runtime).reportFrame([0, 0, 300, 200, 0, 0, 0, 0], in: runtime)
        frames(runtime, clock, until: 16)
        return (runtime, clock)
    }

    /// A HAND TAKING THE TOUCH TAKES EVERY PRESS UNDER WAY IN THE LAYOUT: a press on it, or on a view it holds, let
    /// go once the hand moved the run, taps nothing - a swipe across the cards opens none.
    func testAHandTakingTheTouchTakesThePressesInIt() throws {
        let (runtime, clock) = running(TappedHandApplication())
        let ring = try ring(in: runtime)
        let card = try XCTUnwrap(ring.first(type: .text))
        let size = LayoutSize(width: 10, height: 10)

        for pressed in [ring, card] { pressed.hear(.press(.began, at: Point(5, 5), size: size, byFinger: true), in: runtime) }
        ring.hear(.hand(.began, moved: .zero, speed: nil), in: runtime)
        ring.hear(.hand(.changed, moved: Point(-140, 0), speed: nil), in: runtime)
        for pressed in [ring, card] { pressed.hear(.press(.ended, at: Point(5, 5), size: size, byFinger: true), in: runtime) }
        ring.hear(.hand(.ended, moved: .zero, speed: nil), in: runtime)
        frames(runtime, clock, until: 600)

        XCTAssertEqual(tapped, 0, "the hand took the presses: no tap")
    }

    /// A TAP UNDER A STILL HAND IS A TAP: the hand over the layout hears the press go down and stand still, and the
    /// card's press let go over it taps.
    func testAStillHandLeavesAPressItsTap() throws {
        let (runtime, clock) = running(TappedHandApplication())
        let ring = try ring(in: runtime)
        let card = try XCTUnwrap(ring.first(type: .text))
        let size = LayoutSize(width: 10, height: 10)

        card.hear(.press(.began, at: Point(5, 5), size: size, byFinger: true), in: runtime)
        ring.hear(.hand(.began, moved: .zero, speed: nil), in: runtime)
        ring.hear(.hand(.changed, moved: .zero, speed: nil), in: runtime)
        ring.hear(.hand(.ended, moved: .zero, speed: nil), in: runtime)
        card.hear(.press(.ended, at: Point(5, 5), size: size, byFinger: true), in: runtime)
        frames(runtime, clock, until: 600)

        XCTAssertEqual(tapped, 1, "the hand moved nothing: the card's press taps")
    }

    /// The page's layout, where the tree mounted it.
    private func ring(in runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(type: .motionLayout))
    }
}

/// Where the run stood each time its arithmetic was handed the phase.
@MainActor private var handed: [Double] = []

/// How many taps the layout and its cards heard.
@MainActor private var tapped = 0

/// What the layout's drags of one view told: the view and the point.
@MainActor private var dragged: [(item: Int, at: Point)] = []

/// A clock the test winds.
@MainActor
private final class HandClock: FrameClock {
    var time = 0.0
    lazy var now: () -> Double = { [unowned self] in time }
    var held = false
    var onFrame: ((Double) -> Void)?
}

private struct HandPage: View {
    @State private var turn = 0.0

    var body: some View {
        MotionLayout([0, 1, 2, 3, 4], parameters: $turn) { Text("\($0)") } placements: { _, phase in
            handed.append(phase)
            return (0..<5).map { _ in Placement(Rect(0, 0, 10, 10)) }
        }
        .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...4, snaps: .every(1))
        .motion(.eased(.milliseconds(200), .linear))
    }
}

private struct HandApplication: Application {
    var body: some Scene { WindowGroup { HandPage() } }
}

/// A run of cards a hand moves, the layout and each card hearing a tap.
private struct TappedHandPage: View {
    @State private var turn = 0.0

    var body: some View {
        MotionLayout([0, 1, 2, 3, 4], parameters: $turn) { Text("\($0)").onTapped { tapped += 1 } } placements: { _, _ in
            (0..<5).map { _ in Placement(Rect(0, 0, 10, 10)) }
        }
        .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...4, snaps: .every(1))
        .onItemTapped { _ in tapped += 1 }
    }
}

private struct TappedHandApplication: Application {
    var body: some Scene { WindowGroup { TappedHandPage() } }
}

/// A run of cards laid out right to left, mirrored or placed as written, the hand taking one card by moving across.
private struct RightToLeftPage: View {
    let mirrors: Bool
    @State private var turn = 0.0

    var body: some View {
        MotionLayout([0, 1, 2, 3, 4], parameters: $turn) { Text("\($0)") } placements: { _, phase in
            handed.append(phase)
            return (0..<5).map { Placement(Rect(Double($0) * 20, 0, 10, 10)) }
        }
        .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...4, snaps: .every(1))
        .motion(.eased(.milliseconds(200), .linear))
        .mirrorsRightToLeft(mirrors)
        .itemDrag(begins: .perpendicular)
        .onItemDragged { drag in dragged.append((drag.item, drag.at)) }
        .layoutDirection(.rightToLeft)
    }
}

private struct RightToLeftApplication: Application {
    let mirrors: Bool

    var body: some Scene { WindowGroup { RightToLeftPage(mirrors: mirrors) } }
}
