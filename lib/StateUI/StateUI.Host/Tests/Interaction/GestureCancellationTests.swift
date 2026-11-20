// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A gesture taken away - by the platform, or by its view becoming no target - ends once, as cancelled: no throw,
/// no dismissal, no swipe, each thing it held back where it was bound, and nothing more of it heard.
/// Design: docs/design/host/interaction.md#a-hand-taken-away
@MainActor
final class GestureCancellationTests: XCTestCase {
    private let bench = LayoutBench()

    /// What a view's handlers were told, in order.
    private final class Told {
        var said: [String] = []
    }

    /// What `element` hears, and a frame after it; whether it took it.
    @discardableResult
    private func hear(_ input: HeardInput, on element: MountedElement) -> Bool {
        var took = false
        bench.cycle(on: element) { runtime, element in took = element.hear(input, in: runtime) }
        return took
    }

    /// A bar 200 by 40 the hand moves `value` along, a hundred points a unit, resting on whole units of 0 to 3 -
    /// thrown on let go, and waiting for the program's writes where `waits`.
    private func bar(_ value: State<Double>, waits: Bool = false) -> () -> Node {
        {
            VStack {
                Rectangle()
                    .width(200).height(40)
                    .interaction(
                        .value(value.projectedValue, input: .translation(.horizontal, unit: .points(100))).range(0...3)
                            .snaps(.every(1)).release(.projected(.eased(.milliseconds(400))))
                            .programWrites(waits ? .deferLatest : .interrupt))
            }
            .node
        }
    }

    // MARK: - A number under the hand

    /// A HAND TAKEN AWAY THROWS NOTHING, WHATEVER SPEED IT HAD: the number rests where it was bound, while the
    /// same hand letting go at that speed throws it on.
    func testAHandTakenAwayThrowsNothing() throws {
        func rest(_ last: GesturePhase) throws -> Double {
            let value = State(wrappedValue: 0.0, motion: .eased(.milliseconds(200)))
            bench.mounted(bar(value))
            let view = try XCTUnwrap(bench.element(.rectangle))
            hear(.hand(.began, moved: .zero, speed: nil), on: view)
            hear(.hand(.changed, moved: Point(x: 60, y: 0), speed: nil), on: view)
            hear(.hand(.changed, moved: Point(x: 60, y: 0), speed: nil), on: view)
            XCTAssertEqual(try XCTUnwrap(bench.journey(movedOn: view)).value[0], 1.2, accuracy: 0.001, "under the hand")

            hear(.hand(last, moved: .zero, speed: Point(x: 4_000, y: 0)), on: view)
            bench.frames(80)
            return value.wrappedValue
        }

        XCTAssertEqual(try rest(.cancelled), 1, "taken away: the rest it was bound for")
        XCTAssertGreaterThan(try rest(.ended), 1, "let go at that speed: thrown on")
    }

    /// A HAND THAT WAITS, TAKEN AWAY, GOES WHERE THE PROGRAM SENT THE NUMBER MEANWHILE.
    func testAHandThatWaitsTakenAwayGoesWhereTheProgramSent() throws {
        let value = State(wrappedValue: 0.0, motion: .eased(.milliseconds(200)))
        bench.mounted(bar(value, waits: true))
        let view = try XCTUnwrap(bench.element(.rectangle))
        hear(.hand(.began, moved: .zero, speed: nil), on: view)
        hear(.hand(.changed, moved: Point(x: 120, y: 0), speed: nil), on: view)

        value.wrappedValue = 3
        bench.cycle()
        XCTAssertEqual(try XCTUnwrap(bench.journey(movedOn: view)).value[0], 1.2, accuracy: 0.001, "the hand keeps it")

        hear(.hand(.cancelled, moved: .zero, speed: nil), on: view)
        bench.frames(80)
        XCTAssertEqual(try XCTUnwrap(bench.journey(movedOn: view)).value[0], 3, accuracy: 0.001)
        XCTAssertEqual(value.wrappedValue, 3)
    }

    // MARK: - Once

    /// A GESTURE IS TAKEN AWAY ONCE: a second end of it - a platform telling a cancel and a lost capture both -
    /// says nothing and moves nothing, and so does an end of what never began.
    func testAGestureIsTakenAwayOnce() throws {
        let told = Told()
        bench.mounted {
            VStack {
                Rectangle()
                    .width(200).height(40)
                    .onPanUpdated { pan in told.said.append("pan \(pan.phase)") }
                    .onPinchUpdated { pinch in told.said.append("pinch \(pinch.phase)") }
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))

        hear(.drag(.ended, x: 0, y: 0, from: .zero), on: view)
        hear(.pinch(.cancelled, scale: 1, at: Point(x: 0.5, y: 0.5)), on: view)
        XCTAssertEqual(told.said, [], "an end of nothing under way")

        hear(.drag(.began, x: 0, y: 0, from: Point(x: 10, y: 10)), on: view)
        hear(.drag(.changed, x: 30, y: 0, from: Point(x: 10, y: 10)), on: view)
        hear(.drag(.cancelled, x: 30, y: 0, from: Point(x: 10, y: 10)), on: view)
        hear(.drag(.cancelled, x: 30, y: 0, from: Point(x: 10, y: 10)), on: view)
        hear(.drag(.ended, x: 30, y: 0, from: Point(x: 10, y: 10)), on: view)
        XCTAssertEqual(told.said, ["pan began", "pan changed", "pan cancelled"])

        told.said = []
        hear(.pinch(.began, scale: 1, at: Point(x: 0.5, y: 0.5)), on: view)
        hear(.pinch(.cancelled, scale: 1, at: Point(x: 0.5, y: 0.5)), on: view)
        hear(.pinch(.cancelled, scale: 1, at: Point(x: 0.5, y: 0.5)), on: view)
        XCTAssertEqual(told.said, ["pinch began", "pinch cancelled"])
    }

    /// A NUMBER TAKEN FROM THE HAND TWICE GOES ONCE: the second end finds nothing held.
    func testANumberTakenFromTheHandTwiceGoesOnce() throws {
        let value = State(wrappedValue: 0.0, motion: .eased(.milliseconds(200)))
        bench.mounted(bar(value))
        let view = try XCTUnwrap(bench.element(.rectangle))
        hear(.hand(.began, moved: .zero, speed: nil), on: view)
        hear(.hand(.changed, moved: Point(x: 120, y: 0), speed: nil), on: view)
        hear(.hand(.cancelled, moved: .zero, speed: nil), on: view)
        let going = try XCTUnwrap(bench.journey(movedOn: view))
        XCTAssertEqual(going.destination, [1], "bound for its rest")
        bench.cycle()
        let onItsWay = try XCTUnwrap(bench.journey(movedOn: view)).value[0]
        XCTAssertLessThan(onItsWay, 1.2, "on its way there")

        hear(.hand(.cancelled, moved: .zero, speed: nil), on: view)

        let after = try XCTUnwrap(bench.journey(movedOn: view))
        XCTAssertEqual(after.destination, going.destination)
        XCTAssertLessThanOrEqual(after.value[0], onItsWay, "gone on: not set out anew from under the hand")
        XCTAssertEqual(bench.runtime?.interactions.holds(view), false)
    }

    // MARK: - A view of its own

    /// A VIEW TAKEN FROM THE HAND PAST ITS DISMISSAL'S THRESHOLD IS NOT DISMISSED: it comes back, and nobody is
    /// told - where the same hand letting go there throws it out.
    func testAViewTakenFromTheHandIsNotDismissed() throws {
        func dismissals(_ last: GesturePhase) throws -> (told: Int, back: Double) {
            let told = Told()
            bench.mounted {
                VStack {
                    Rectangle()
                        .width(100).height(40)
                        .interaction(.drag(.vertical).dismissal(directions: .up, threshold: 20))
                        .onDismissed { _ in told.said.append("dismissed") }
                }
                .height(300)
                .node
            }
            let view = try XCTUnwrap(bench.element(.rectangle))
            hear(.hand(.began, moved: .zero, speed: nil, point: Point(x: 10, y: 10)), on: view)
            hear(.hand(.changed, moved: Point(x: 0, y: -60), speed: nil), on: view)
            XCTAssertEqual(view.drawingTransform.translationY, -60, "under the hand, past its threshold")

            hear(.hand(last, moved: .zero, speed: last == .ended ? Point(x: 0, y: 0) : nil), on: view)
            bench.frames(120)
            await_(told)
            return (told.said.count, view.drawingTransform.translationY)
        }

        let taken = try dismissals(.cancelled)
        XCTAssertEqual(taken.told, 0, "taken away: no dismissal")
        XCTAssertEqual(taken.back, 0, accuracy: 0.01, "back at its place")
        XCTAssertEqual(try dismissals(.ended).told, 1, "let go there: dismissed")
    }

    /// Lets the handlers a frame told run.
    private func await_(_ told: Told) {
        for _ in 0..<20 { bench.runtime?.pump.turn() }
    }

    /// A RUN TAKEN AWAY AS ITS VIEW STOPPED BEING A TARGET IS HEARD NO MORE, THOUGH THE VIEW IS ONE AGAIN BEFORE
    /// THE RUN ENDS: it ends at the first step heard after, once, and the next press dragged is told whole.
    func testARunTakenAwayIsHeardNoMoreThoughItsViewIsATargetAgain() throws {
        let (told, enabled) = (Told(), State(wrappedValue: true))
        bench.mounted {
            VStack {
                Rectangle()
                    .width(200).height(40)
                    .onPanUpdated { pan in told.said.append("pan \(pan.phase)") }
                    .onSwiped { _ in told.said.append("swiped") }
            }
            .isEnabled(enabled.wrappedValue)
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))
        let at = Point(x: 10, y: 10)

        hear(.drag(.began, x: 0, y: 0, from: at), on: view)
        enabled.wrappedValue = false
        bench.render()
        XCTAssertFalse(hear(.drag(.changed, x: 30, y: 0, from: at), on: view))
        XCTAssertEqual(told.said, ["pan began", "pan cancelled"], "ended at the first step after")

        enabled.wrappedValue = true
        bench.render()
        XCTAssertFalse(hear(.drag(.changed, x: 90, y: 0, from: at), on: view), "that drag is the view's no more")
        hear(.drag(.ended, x: 120, y: 0, from: at), on: view)
        XCTAssertEqual(told.said, ["pan began", "pan cancelled"], "and its end is no swipe")

        hear(.drag(.began, x: 0, y: 0, from: at), on: view)
        hear(.drag(.ended, x: 120, y: 0, from: at), on: view)
        XCTAssertEqual(Array(told.said.suffix(3)), ["pan began", "pan ended", "swiped"], "the next is told whole")
    }

    // MARK: - No target

    /// A VIEW DRAWN AT NO SIZE IS NO TARGET: nothing begins on it or on what it holds, and what began before it
    /// shrank ends there, as cancelled.
    func testAViewDrawnAtNoSizeIsNoTarget() throws {
        let (told, scale) = (Told(), State(wrappedValue: 1.0, motion: .none))
        bench.mounted {
            VStack {
                Rectangle()
                    .width(200).height(40)
                    .onPanUpdated { pan in told.said.append("pan \(pan.phase)") }
                    .onTapped { told.said.append("tapped") }
            }
            .scale(scale.projectedValue)
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))
        let (at, size) = (Point(x: 10, y: 10), LayoutSize(width: 200, height: 40))

        hear(.drag(.began, x: 0, y: 0, from: at), on: view)
        scale.wrappedValue = 0
        bench.cycle()
        XCTAssertFalse(hear(.drag(.changed, x: 30, y: 0, from: at), on: view), "its holder is drawn at no size")
        hear(.drag(.ended, x: 30, y: 0, from: at), on: view)
        XCTAssertEqual(told.said, ["pan began", "pan cancelled"], "what began ends as cancelled, never a swipe")

        told.said = []
        XCTAssertFalse(hear(.press(.began, at: at, size: size, byFinger: false), on: view))
        hear(.press(.ended, at: at, size: size, byFinger: false), on: view)
        XCTAssertFalse(hear(.drag(.began, x: 0, y: 0, from: at), on: view))
        XCTAssertEqual(told.said, [], "nothing begins on it")

        scale.wrappedValue = 1
        bench.cycle()
        hear(.press(.began, at: at, size: size, byFinger: false), on: view)
        hear(.press(.ended, at: at, size: size, byFinger: false), on: view)
        XCTAssertEqual(told.said, ["tapped"], "drawn again, a target again")
    }
}
