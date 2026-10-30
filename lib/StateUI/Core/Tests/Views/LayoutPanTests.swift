// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A phase layout panned - two axes scrolled, one across and one down: the hand moves both whichever way it goes,
// and let go they rest together - beside two fingers spreading another axis at once.

import XCTest

@_spi(Host) @testable import StateUI

/// A board panned across and down, and how large it stands.
private struct Board: AxesPhase {
    var x = 0.0
    var y = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Board, Double>] { [\.x, \.y, \.zoom] }
}

/// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
private final class Handed {
    var boards: [Board] = []
}

@MainActor
final class LayoutPanTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// A board of three by three a hand pans a hundred points a unit, resting on each square, and two fingers spread
    /// as large as twice.
    private func tree(_ board: State<Board>, _ handed: Handed) -> Node {
        PhaseLayout([0, 1], phase: board.projectedValue) { Text("\($0)") } placements: { _, board in
            handed.boards.append(board)
            return [Placement(Rect(-board.x * 100, -board.y * 100, 40, 40)), Placement(.zero)]
        }
        .axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...2, snaps: .every(1))
        .axis(\.y, input: .scroll(.vertical, pointsPerUnit: 100), range: 0...2, snaps: .every(1))
        .axis(\.zoom, input: .magnification, range: 1...2, snaps: .limits)
        .motion(.eased(.milliseconds(160), .linear))
        .node
    }

    private func frames(_ count: Int = 30) {
        for _ in 0..<count { bench.cycle() }
    }

    /// A PAN IS HEARD EVERY WAY: the element says it pans, and no one way.
    func testAPanIsHeardEveryWay() throws {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        let layout = try XCTUnwrap(bench.laid(Renders(), { tree(board, handed) }).patch.first(.phaseLayout))

        XCTAssertEqual(layout.properties[.pans], .bool(true))
        XCTAssertNil(layout.properties[.handAxis])
        XCTAssertNotNil(layout.events?[.handMoved])
    }

    /// THE HAND MOVES BOTH AXES, each with its own way - left and up both on - and let go still, the run rests on
    /// the nearest square.
    func testTheHandMovesBothAxesAndRestsOnTheNearestSquare() {
        bench.walks = true
        let (board, handed, renders) = (State(wrappedValue: Board()), Handed(), Renders())
        func built() -> Node { tree(board, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-140, -60))
        XCTAssertEqual(handed.boards.last?.x ?? 0, 1.4, accuracy: 0.001)
        XCTAssertEqual(handed.boards.last?.y ?? 0, 0.6, accuracy: 0.001)

        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(board.wrappedValue, Board(x: 1, y: 1))
        XCTAssertEqual(handed.boards.last?.x ?? 0, 1, accuracy: 0.000_1)
        XCTAssertEqual(handed.boards.last?.y ?? 0, 1, accuracy: 0.000_1)
    }

    /// A THROW GOES ON BOTH WAYS, each axis with its part of the speed, to the square nearest where it would end.
    func testAThrowGoesOnBothWays() {
        let (board, handed, renders) = (State(wrappedValue: Board()), Handed(), Renders())
        func built() -> Node { tree(board, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-20, -10))
        // 600 points a second across is six units: half a second's light friction carries it to the far square; the
        // same throw down is not one.
        bench.hand(renders, built, .ended, speed: Point(-600, -10))
        frames(60)
        XCTAssertEqual(board.wrappedValue, Board(x: 1, y: 0), "across thrown on, down let go still")
    }

    /// A WHEEL'S NOTCHES STEP EACH AXIS their way.
    func testAWheelsNotchesStepEachAxis() {
        let (board, handed, renders) = (State(wrappedValue: Board()), Handed(), Renders())
        func built() -> Node { tree(board, handed) }
        let patch = bench.laid(renders, built).patch

        guard let stepped = patch.first(.phaseLayout)?.events?[.handStepped] else {
            return XCTFail("the layout hears no wheel")
        }
        XCTAssertTrue(renders.fire(stepped, with: MemberValues.encode(Point(-1, -2))))
        frames()
        XCTAssertEqual(board.wrappedValue, Board(x: 1, y: 2))
    }

    /// A PAN AND TWO FINGERS MOVE AT ONCE: the hand pans while the fingers spread, each its own axes.
    func testAPanAndTwoFingersMoveAtOnce() {
        let (board, handed, renders) = (State(wrappedValue: Board()), Handed(), Renders())
        func built() -> Node { tree(board, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.pinch(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-100, 0))
        bench.pinch(renders, built, .changed, scale: 2)
        XCTAssertEqual(handed.boards.last?.x ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(handed.boards.last?.zoom ?? 0, 2, accuracy: 0.001)

        bench.pinch(renders, built, .ended)
        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(board.wrappedValue, Board(x: 1, y: 0, zoom: 2))
    }

    /// AXES SCROLLED ACROSS AND DOWN ARE A PAN, heard every way; scrolled one way alone, a hand along the layout.
    func testAxesScrolledAcrossAndDownAreAPan() throws {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        func layout() -> PhaseLayout<[Int], Int, Board> {
            PhaseLayout([0], phase: board.projectedValue) { Text("\($0)") } placements: { _, board in
                handed.boards.append(board)
                return [Placement(Rect(0, 0, 40, 40))]
            }
            .axis(\.x, input: .scroll(.horizontal), range: 0...1, snaps: .limits)
        }

        let panned = try XCTUnwrap(Renders().settled(
            layout().axis(\.y, input: .scroll(.vertical), range: 0...1, snaps: .limits).node).first(.phaseLayout))
        XCTAssertEqual(panned.properties[.pans], .bool(true))
        XCTAssertNil(panned.properties[.handAxis])

        let scrolled = try XCTUnwrap(Renders().settled(
            layout().axis(\.y, input: .scroll(.horizontal), range: 0...1, snaps: .limits).node).first(.phaseLayout))
        XCTAssertNil(scrolled.properties[.pans], "two axes, one way")
        XCTAssertEqual(scrolled.properties[.handAxis], .enumeration(LayoutInput.Axis.horizontal.rawValue))
    }
}
