// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view thrown away: what dismisses it, how it leaves the room that holds it, what its handlers are told, and how
// it comes back where nobody removed it.

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

@MainActor
final class DismissalTests: XCTestCase {
    private let bench = LayoutBench()

    /// What the handlers were told, a class so the closures that write it are not walked for state.
    private final class Told {
        var dismissals: [Dismissal] = []
    }

    /// The hand at `phase` as a toolkit tells `element`, and a frame after it; whether the element took it.
    @discardableResult
    private func hand(
        _ phase: GesturePhase, moved: Point = .zero, speed: Point? = nil, point: Point? = nil, on element: MountedElement
    ) -> Bool {
        var took = false
        bench.cycle(on: element) { runtime, element in
            took = element.hear(.hand(phase, moved: moved, speed: speed, point: point), in: runtime)
        }
        return took
    }

    /// A card 100 by 40 standing 80 points down a stack 300 by 200, thrown up past thirty points, `told` hearing
    /// it: the card, once both are laid out.
    private func card(_ told: Told, handled: @escaping @MainActor () async -> Void = {}) throws -> MountedElement {
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .interaction(.drag(.vertical).dismissal(directions: .up, threshold: 30))
                    .onDismissed(policy: .runConcurrently) { dismissal in
                        told.dismissals.append(dismissal)
                        await handled()
                    }
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))
        let stack = try XCTUnwrap(view.parent)
        XCTAssertTrue(view.readsOwnFrame && stack.readsOwnFrame, "the room it leaves is read off where both stand")
        bench.cycle(on: view) { runtime, view in
            stack.reportFrame([0, 0, 300, 200, 0, 0, 0, 0], in: runtime)
            view.reportFrame([0, 80, 100, 40, 0, 80, 0, 0], in: runtime)
        }
        return view
    }

    /// A VIEW TAKEN PAST ITS THRESHOLD FLIES ON OUT OF THE ROOM THAT HOLDS IT, AND IS TOLD ONCE IT IS OUT: no
    /// sooner, the way it went and the hand's speed - and, nobody removing it, it comes back to its place.
    func testAViewTakenPastItsThresholdLeavesItsRoomAndIsTold() async throws {
        let told = Told()
        let view = try card(told)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: -40), on: view)
        hand(.ended, speed: Point(x: 0, y: -200), on: view)
        XCTAssertEqual(told.dismissals, [], "still in its room")
        XCTAssertNotNil(view.flight)

        bench.frames(40)
        XCTAssertEqual(told.dismissals, [Dismissal(direction: .up, velocity: Point(x: 0, y: -200))])
        XCTAssertLessThanOrEqual(view.drawingTransform.translationY, -120, "wholly out: 80 down the room, 40 tall")
        XCTAssertNil(view.flight, "its way out ended")

        await bench.settle()
        bench.frames(120)
        XCTAssertEqual(view.drawingTransform.translationY, 0, accuracy: 0.01, "nobody removed it: back at its place")
        XCTAssertFalse(view.awaitsDismissal)
    }

    /// A THROW DISMISSES A VIEW THE HAND TOOK NO FURTHER THAN ITS THRESHOLD: where it stands and what its law
    /// carries at the hand's speed count together; a view let go slowly short of it goes back, told nothing.
    func testAThrowDismissesAndASlowLetGoDoesNot() async throws {
        let told = Told()
        let view = try card(told)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: -10), on: view)
        hand(.ended, speed: Point(x: 0, y: -40), on: view)
        bench.frames(60)
        XCTAssertEqual(told.dismissals, [], "ten points and a slow hand")
        XCTAssertEqual(view.drawingTransform.translationY, 0, accuracy: 0.01)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: -10), on: view)
        hand(.ended, speed: Point(x: 0, y: -1_500), on: view)
        bench.frames(40)
        XCTAssertEqual(told.dismissals.map(\.direction), [.up], "thrown")

        // Down is no way the dismissal names, however far.
        await bench.settle()
        bench.frames(120)
        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: 90), on: view)
        hand(.ended, speed: Point(x: 0, y: 900), on: view)
        bench.frames(60)
        XCTAssertEqual(told.dismissals.count, 1)
    }

    /// A HAND TAKING THE VIEW ON ITS WAY OUT ENDS THE FLIGHT WITH NOTHING TOLD, and holds it where it stood.
    func testAHandAgainInterruptsTheFlightAndNothingIsTold() throws {
        let told = Told()
        let view = try card(told)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: -40), on: view)
        hand(.ended, speed: Point(x: 0, y: -200), on: view)
        bench.frames(2)
        let stood = view.drawingTransform.translationY
        XCTAssertLessThan(stood, -40, "on its way")

        hand(.began, point: Point(x: 10, y: 10), on: view)
        XCTAssertNil(view.flight, "caught where it stood")
        XCTAssertEqual(view.drawingTransform.translationY, stood, accuracy: 0.000_1)
        hand(.changed, moved: Point(x: 0, y: 12), on: view)
        XCTAssertEqual(view.drawingTransform.translationY, stood + 12, accuracy: 0.000_1, "under the hand from there")

        bench.frames(60)
        XCTAssertEqual(told.dismissals, [], "a flight a hand ended tells nothing")
    }

    /// A VIEW THAT IS OUT HEARS NOTHING UNTIL ITS HANDLERS HAVE ENDED, and comes back only then.
    func testAViewAwaitingItsHandlersHearsNothing() async throws {
        let told = Told()
        let (waits, lets) = AsyncStream<Void>.makeStream()
        let view = try card(told) { for await _ in waits { break } }

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: -40), on: view)
        hand(.ended, speed: Point(x: 0, y: -200), on: view)
        bench.frames(40)
        await bench.settle()
        XCTAssertEqual(told.dismissals.count, 1)
        XCTAssertTrue(view.awaitsDismissal, "its handler still runs")
        XCTAssertFalse(hand(.began, point: Point(x: 10, y: 10), on: view), "it hears nothing meanwhile")
        bench.frames(60)
        XCTAssertLessThanOrEqual(view.drawingTransform.translationY, -120, "and stays out")

        lets.yield()
        for _ in 0..<200 {
            guard view.awaitsDismissal else { break }
            await Task.yield()
        }
        bench.frames(120)
        XCTAssertFalse(view.awaitsDismissal)
        XCTAssertEqual(view.drawingTransform.translationY, 0, accuracy: 0.01, "left standing: back at its place")
    }

    /// A HANDLER STILL RUNNING HOLDS NO RUNTIME: what a dismissal waits for may outlive its window, and its end
    /// then says nothing to a runtime that is gone - held, the old runtime would wake its clock into whatever
    /// runs next.
    func testAHandlerStillRunningHoldsNoRuntime() async throws {
        let told = Told()
        let (waits, lets) = AsyncStream<Void>.makeStream()
        let view = try card(told) { for await _ in waits { break } }
        weak var runtime = bench.runtime

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: -40), on: view)
        hand(.ended, speed: Point(x: 0, y: -200), on: view)
        bench.frames(40)
        XCTAssertTrue(view.awaitsDismissal)

        // Another tree is mounted: the window of the first is gone, its handler still awaiting.
        bench.mounted { VStack {}.node }
        XCTAssertNil(runtime, "nothing the handler waits in holds the runtime it was told through")

        lets.yield()
        for _ in 0..<50 { await Task.yield() }
    }

    /// A VIEW NOBODY HEARS COMES BACK AT ONCE IT IS OUT: a dismissal with no handler is a throw and a return.
    func testAViewNobodyHearsComesBack() throws {
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .interaction(.drag(.vertical).dismissal(directions: .up, threshold: 30))
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))
        let stack = try XCTUnwrap(view.parent)
        bench.cycle(on: view) { runtime, view in
            stack.reportFrame([0, 0, 300, 200, 0, 0, 0, 0], in: runtime)
            view.reportFrame([0, 80, 100, 40, 0, 80, 0, 0], in: runtime)
        }

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: -40), on: view)
        hand(.ended, speed: Point(x: 0, y: -200), on: view)
        bench.frames(200)

        XCTAssertFalse(view.awaitsDismissal)
        XCTAssertEqual(view.drawingTransform.translationY, 0, accuracy: 0.01)
    }

    /// A LAYOUT'S VIEW THROWN AWAY LEAVES THE LAYOUT'S ROOM, AND ITS LAYOUT IS TOLD WHICH: the view's own drag says
    /// the dismissal, the layout's handler hears the item - and, nobody removing it, the view is back at its place.
    func testALayoutsViewThrownAwayTellsItsLayout() async throws {
        final class Items { var dismissed: [Int] = [] }
        let (turn, told) = (State(wrappedValue: 0.0), Items())
        bench.laid {
            MotionLayout([0, 1, 2], parameters: turn.projectedValue) { _ in
                Rectangle().interaction(.drag(.vertical).dismissal(directions: .up, threshold: 20))
            } placements: { _, _ in
                (0..<3).map { Placement(Rect(x: Double($0) * 120, y: 40, width: 100, height: 40)) }
            }
            .onItemDismissed { told.dismissed.append($0) }
            .node
        }
        let layout = try XCTUnwrap(bench.layout)
        let view = try XCTUnwrap(layout.children[1].children.first)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: -30), on: view)
        hand(.ended, speed: Point(x: 0, y: -300), on: view)
        XCTAssertEqual(told.dismissed, [], "still in the room")

        bench.frames(60)
        XCTAssertEqual(told.dismissed, [1], "the view at that place")
        XCTAssertLessThanOrEqual(layout.programPlaces[1].bounds.y + 40, 0, "out of the layout's room")
        XCTAssertEqual(layout.programPlaces[0].bounds.y, 40, "the others stand")
        XCTAssertTrue(view.awaitsDismissal, "until the layout's handlers have ended")

        for _ in 0..<200 {
            guard view.awaitsDismissal else { break }
            await Task.yield()
        }
        bench.frames(160)
        XCTAssertEqual(layout.programPlaces[1].bounds.y, 40, accuracy: 0.01, "nobody removed it: back at its place")
    }

    /// THE WAY OUT ENDS, WHATEVER IT MEETS: its pace is the room's length in the law's time at the least, and a
    /// view whose room nothing laid out is out once that time has run twice.
    func testAnOperationOutOfARoomIsFinite() {
        let room = LayoutSize(width: 300, height: 200)
        var slow = PresentationOperation(
            .outside(.up), from: Point(x: 0, y: -40), speed: .zero, pace: 300, room: room, at: 0)
        XCTAssertEqual(slow.velocity.y, -200 / 0.3, accuracy: 0.001, "no slower than the room in its law's time")
        var frames = 0
        while !slow.step(to: Double(frames + 1) * 16, frame: Rect(x: 0, y: 80, width: 100, height: 40), room: room) {
            frames += 1
            XCTAssertLessThan(frames, 40)
        }
        XCTAssertLessThanOrEqual(80 + slow.offset.y + 40, 0, "wholly out")

        let fast = PresentationOperation(
            .outside(.left), from: .zero, speed: Point(x: -3_000, y: 0), pace: 300, room: room, at: 0)
        XCTAssertEqual(fast.velocity.x, -3_000, "the hand's speed where it is the faster")

        var unlaid = PresentationOperation(.outside(.down), from: .zero, speed: .zero, pace: 300, room: .init(width: 0, height: 0), at: 0)
        XCTAssertFalse(unlaid.step(to: 500, frame: nil, room: nil))
        XCTAssertTrue(unlaid.step(to: 600, frame: nil, room: nil), "out after twice its time")
    }
}
