// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view's own drag: when the hand takes it, how it stays under the hand - along its axes, over the others, pinned
// in its layout's room whatever its place does - and how it goes back let go.

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

@MainActor
final class LocalDragTests: XCTestCase {
    private let bench = LayoutBench()

    /// The hand at `phase` as a toolkit tells `element` - how far it moved since its last report, a press going
    /// down at `point`, lifting at `speed` - and a frame after it; whether the element took it.
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

    /// A rectangle 100 by 40 the hand takes as `drag` says, in a stack.
    private func dragged(_ drag: Interaction) -> () -> Node {
        { VStack { Rectangle().width(100).height(40).interaction(drag) }.node }
    }

    // MARK: - A view no layout program places

    /// A VIEW TAKEN AT ONCE STAYS UNDER THE HAND ALONG ITS AXES, and is where its layout puts it again let go: a
    /// drag across moves it across, however far the hand strays down.
    func testAViewTakenAtOnceStaysUnderTheHandAlongItsAxes() throws {
        bench.mounted(dragged(.drag(.horizontal)))
        let view = try XCTUnwrap(bench.element(.rectangle))
        XCTAssertTrue(view.hearing.contains(.hand))

        hand(.began, point: Point(x: 10, y: 10), on: view)
        XCTAssertTrue(hand(.changed, moved: Point(x: 30, y: 12), on: view))
        XCTAssertEqual(view.drawingTransform.translationX, 30)
        XCTAssertEqual(view.drawingTransform.translationY, 0, "its drag goes across alone")

        hand(.changed, moved: Point(x: -10, y: 0), on: view)
        XCTAssertEqual(view.drawingTransform.translationX, 20)

        hand(.ended, speed: .zero, on: view)
        XCTAssertEqual(view.drawingTransform.translationX, 0)
    }

    /// A DIRECTIONAL DRAG LEAVES A FIRST MOVE ACROSS ITS AXIS TO WHAT STANDS BEHIND THE VIEW, and takes one along it.
    func testADirectionalDragLeavesAFirstMoveAcrossToWhatStandsBehind() throws {
        bench.mounted(dragged(.drag(.vertical, begins: .directional)))
        let view = try XCTUnwrap(bench.element(.rectangle))

        hand(.began, point: Point(x: 10, y: 10), on: view)
        XCTAssertFalse(hand(.changed, moved: Point(x: 30, y: 4), on: view), "across: not the view's")
        XCTAssertEqual(view.drawingTransform.translationY, 0)
        hand(.ended, speed: .zero, on: view)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        XCTAssertTrue(hand(.changed, moved: Point(x: 4, y: 30), on: view), "along its axis")
        XCTAssertEqual(view.drawingTransform.translationY, 30)
        XCTAssertEqual(view.drawingTransform.translationX, 0)
    }

    /// A LONG PRESS TAKES THE VIEW ONCE IT HAS STOOD STILL ITS TIME, then any way; a move before it is not the view's.
    func testALongPressTakesTheViewOnceItStoodStill() throws {
        bench.mounted(dragged(.drag(.both, begins: .longPress)))
        let view = try XCTUnwrap(bench.element(.rectangle))

        hand(.began, point: Point(x: 10, y: 10), on: view)
        XCTAssertFalse(hand(.changed, moved: Point(x: 30, y: 0), on: view), "moved before it stood its time")
        hand(.ended, speed: .zero, on: view)
        XCTAssertEqual(view.drawingTransform.translationX, 0)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        bench.frames(Int(HandReading.longPress / 16) + 2)
        XCTAssertTrue(hand(.changed, moved: Point(x: 30, y: 20), on: view))
        XCTAssertEqual(view.drawingTransform.translationX, 30)
        XCTAssertEqual(view.drawingTransform.translationY, 20)
    }

    /// LET GO, A VIEW THAT IS A BODY COMES BACK FROM UNDER THE HAND AS ONE, where no layout program places it: it
    /// sets out where the hand left it, and is at its place after its spring; a view of no body is there at once.
    func testLetGoAViewThatIsABodyComesBackAsOne() throws {
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .interaction(.drag(.both))
                    .layoutBody(.onChange(response: .milliseconds(300), damping: 1))
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 40, y: 20), on: view)
        hand(.ended, speed: .zero, on: view)
        XCTAssertEqual(view.drawingTransform.translationX, 40, accuracy: 0.000_1, "the frame it is let go: where it was")

        bench.frames(4)
        XCTAssertLessThan(view.drawingTransform.translationX, 40)
        XCTAssertGreaterThan(view.drawingTransform.translationX, 0, "on its way back")
        bench.frames(120)
        XCTAssertEqual(view.drawingTransform.translationX, 0, accuracy: 0.01)
        XCTAssertEqual(view.drawingTransform.translationY, 0, accuracy: 0.01)
    }

    // MARK: - A view a layout program places

    /// A row of three views 100 by 40, 120 apart, moved left by the turn, each taken up and down by the hand,
    /// coming onto its place as `bodies` says.
    private func row(_ turn: State<Double>, bodies: LayoutBody) -> () -> Node {
        {
            MotionLayout([0, 1, 2], parameters: turn.projectedValue) { _ in
                Rectangle().interaction(.drag(.vertical))
            } placements: { _, turn in
                (0..<3).map { Placement(Rect(x: Double($0) * 120 - turn * 50, y: 40, width: 100, height: 40)) }
            }
            .layoutBodies(bodies)
            .node
        }
    }

    /// THE HAND IS MEASURED IN A SPACE IT DOES NOT MOVE: a view the hand takes comes after it, so its own room is no
    /// measure of the hand - a view in a stack is measured in the stack, a layout's view in the layout, which
    /// stands still whatever its program does with the holder the view stands in.
    func testTheHandIsMeasuredInASpaceItDoesNotMove() throws {
        bench.mounted(dragged(.drag(.both)))
        let view = try XCTUnwrap(bench.element(.rectangle))
        XCTAssertTrue(view.handSpace === view.parent, "the stack it stands in")

        let row = LayoutBench()
        row.laid(self.row(State(wrappedValue: 0.0), bodies: .none))
        let layout = try XCTUnwrap(row.layout)
        let placed = try XCTUnwrap(layout.children[1].children.first)
        XCTAssertTrue(placed.handSpace === layout, "the layout, not the holder its program moves")
        XCTAssertFalse(placed.parent === layout)
    }

    /// A LAYOUT'S VIEW STAYS UNDER THE HAND WHILE ITS PLACE MOVES, OVER THE OTHERS: taken as it was shown, pinned to
    /// the hand in the layout's room - the program moving the row moves the others and leaves it - and ranked
    /// above them.
    func testALayoutsViewStaysUnderTheHandWhileItsPlaceMoves() throws {
        let turn = State(wrappedValue: 0.0)
        bench.laid(row(turn, bodies: .none))
        let layout = try XCTUnwrap(bench.layout)
        let view = try XCTUnwrap(layout.children[1].children.first)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 7, y: 30), on: view)
        XCTAssertEqual(layout.programPlaces[1].bounds, Rect(x: 120, y: 70, width: 100, height: 40), "down with the hand")
        XCTAssertGreaterThan(layout.programPlaces[1].zIndex, layout.programPlaces[0].zIndex)
        XCTAssertGreaterThan(layout.programPlaces[1].zIndex, layout.programPlaces[2].zIndex)

        turn.wrappedValue = 1
        bench.frames(40)

        XCTAssertEqual(layout.programPlaces[0].bounds.x, -50, "the row moved under it")
        XCTAssertEqual(layout.programPlaces[2].bounds.x, 190)
        XCTAssertEqual(layout.programPlaces[1].bounds, Rect(x: 120, y: 70, width: 100, height: 40), "the held one stays")
    }

    /// THE LAYOUT IS TOLD THE HAND AS THE VIEW'S DRAG TAKES IT: a view taken up and down is told where it stands
    /// and how fast it goes that way alone, however the hand strays across - so a dismissal and a flight the
    /// layout makes of it go the way the view went.
    func testTheLayoutIsToldTheHandAlongTheDragsAxesAlone() throws {
        final class Told { var drags: [ItemDrag<Int>] = [] }
        let (turn, told) = (State(wrappedValue: 0.0), Told())
        bench.laid {
            MotionLayout([0, 1, 2], parameters: turn.projectedValue) { _ in
                Rectangle().interaction(.drag(.vertical))
            } placements: { _, _ in
                (0..<3).map { Placement(Rect(x: Double($0) * 120, y: 40, width: 100, height: 40)) }
            }
            .onItemDragged { told.drags.append($0) }
            .node
        }
        let view = try XCTUnwrap(bench.layout?.children[1].children.first)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 25, y: 30), on: view)
        hand(.ended, speed: Point(x: 300, y: -400), on: view)

        XCTAssertEqual(told.drags.map(\.id), [1, 1, 1])
        XCTAssertEqual(told.drags.map(\.at), [
            Point(x: 130, y: 50), Point(x: 130, y: 80), Point(x: 130, y: 80),
        ], "where the hand took it, then down with it and no way across")
        XCTAssertEqual(told.drags.last?.velocity, Point(x: 0, y: -400), "its speed that way alone")
    }

    /// LET GO, A VIEW OF NO BODY IS AT ITS PLACE AT ONCE, in the others' order again.
    func testLetGoAViewOfNoBodyIsAtItsPlaceAtOnce() throws {
        let turn = State(wrappedValue: 0.0)
        bench.laid(row(turn, bodies: .none))
        let layout = try XCTUnwrap(bench.layout)
        let view = try XCTUnwrap(layout.children[1].children.first)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: 30), on: view)
        hand(.ended, speed: Point(x: 0, y: 400), on: view)

        XCTAssertEqual(layout.programPlaces[1].bounds, Rect(x: 120, y: 40, width: 100, height: 40))
        XCTAssertEqual(layout.programPlaces[1].zIndex, layout.programPlaces[0].zIndex)
    }

    /// LET GO, A BODY SETS OUT FROM UNDER THE HAND AT THE HAND'S SPEED AND COMES BACK: going on the way the hand
    /// went before its spring turns it, then onto its place.
    func testLetGoABodySetsOutAtTheHandsSpeedAndComesBack() throws {
        let turn = State(wrappedValue: 0.0)
        bench.laid(row(turn, bodies: .onChange(response: .milliseconds(400), damping: 1)))
        let layout = try XCTUnwrap(bench.layout)
        let view = try XCTUnwrap(layout.children[1].children.first)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: 30), on: view)
        hand(.ended, speed: Point(x: 0, y: 600), on: view)
        XCTAssertEqual(layout.programPlaces[1].bounds.y, 70, "the frame it is let go: where the hand left it")
        XCTAssertTrue(layout.programBodiesMove)

        bench.frames(2)
        XCTAssertGreaterThan(layout.programPlaces[1].bounds.y, 70, "going on at the hand's speed")

        bench.frames(120)
        XCTAssertEqual(layout.programPlaces[1].bounds.y, 40, accuracy: 0.05)
        XCTAssertFalse(layout.programBodiesMove)
    }

    /// A HAND TAKEN AWAY PUTS THE VIEW BACK WITH NO SPEED.
    func testAHandTakenAwayPutsTheViewBack() throws {
        let turn = State(wrappedValue: 0.0)
        bench.laid(row(turn, bodies: .onChange(response: .milliseconds(400), damping: 1)))
        let layout = try XCTUnwrap(bench.layout)
        let view = try XCTUnwrap(layout.children[1].children.first)

        hand(.began, point: Point(x: 10, y: 10), on: view)
        hand(.changed, moved: Point(x: 0, y: 30), on: view)
        hand(.cancelled, on: view)
        bench.frames(2)

        XCTAssertLessThan(layout.programPlaces[1].bounds.y, 70, "coming back at once, carried on by no speed")
    }
}
