// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A motion layout panned - two axes scrolled, one across and one down: the hand moves both whichever way it goes,
// and let go they rest together - beside two fingers spreading another axis at once.

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A board panned across and down, and how large it stands.
private struct Board: LayoutParameters {
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
    private func tree(_ board: State<Board>, _ handed: Handed, downFirst: Bool = false) -> Node {
        let moved = board.traveling(.eased(.milliseconds(160), curve: .linear))
        let across = Interaction.value(moved, axis: \.x, input: .translation(.horizontal, unit: .points(100)))
            .reversed(true).range(0...2).snaps(.every(1))
        let down = Interaction.value(moved, axis: \.y, input: .translation(.vertical, unit: .points(100)))
            .reversed(true).range(0...2).snaps(.every(1))
        let zoom = Interaction.value(moved, axis: \.zoom, input: .magnification).range(1...2).snaps(.endpoints)
        return MotionLayout([0, 1], parameters: moved) { Text("\($0)") } placements: { _, board in
            handed.boards.append(board)
            return [Placement(Rect(-board.x * 100, -board.y * 100, 40, 40)), Placement(.zero)]
        }
        .interaction(
            .simultaneous((downFirst ? [down, across] : [across, down]) + [zoom])
                .release(.projected(.eased(.milliseconds(400)))))
        .node
    }


    /// A PAN IS HEARD EVERY WAY: the element says it pans, and no one way.
    func testAPanIsHeardEveryWay() throws {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        bench.laid { self.tree(board, handed) }
        let layout = try XCTUnwrap(bench.layout)

        XCTAssertEqual(layout.handWay, .everyWay)
        XCTAssertTrue(layout.hearing.contains(.hand))
    }

    /// THE HAND MOVES BOTH AXES, each with its own way - left and up both on - and let go still, the run rests on
    /// the nearest square.
    func testTheHandMovesBothAxesAndRestsOnTheNearestSquare() {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        func built() -> Node { tree(board, handed) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, -60))
        XCTAssertEqual(handed.boards.last?.x ?? 0, 1.4, accuracy: 0.001)
        XCTAssertEqual(handed.boards.last?.y ?? 0, 0.6, accuracy: 0.001)

        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(board.wrappedValue, Board(x: 1, y: 1))
        XCTAssertEqual(handed.boards.last?.x ?? 0, 1, accuracy: 0.000_1)
        XCTAssertEqual(handed.boards.last?.y ?? 0, 1, accuracy: 0.000_1)
    }

    /// A THROW GOES ON BOTH WAYS, each axis with its part of the speed, to the square nearest where it would end.
    func testAThrowGoesOnBothWays() {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        func built() -> Node { tree(board, handed) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-20, -10))
        // 600 points a second across is six units: half a second's light friction carries it to the far square; the
        // same throw down is not one.
        bench.hand(.ended, velocity: Point(-600, -10))
        bench.frames(60)
        XCTAssertEqual(board.wrappedValue, Board(x: 1, y: 0), "across thrown on, down let go still")
    }

    /// AXES LET GO TOGETHER GO ON BY ONE LAW, whatever order they were declared in: across thrown on, down let go
    /// still, the parameters travel alike frame by frame.
    func testAxesLetGoTogetherGoOnByOneLawWhateverTheirOrder() {
        func journey(downFirst: Bool) -> [Board] {
            let (board, handed) = (State(wrappedValue: Board()), Handed())
            func built() -> Node { tree(board, handed, downFirst: downFirst) }
            bench.laid(built)
            bench.hand(.began)
            bench.hand(.changed, moved: Point(-20, -30))
            bench.hand(.ended, velocity: Point(-600, 0))
            handed.boards.removeAll()
            bench.frames(8)
            return handed.boards
        }
        let (acrossFirst, downFirst) = (journey(downFirst: false), journey(downFirst: true))

        XCTAssertFalse(acrossFirst.isEmpty)
        XCTAssertEqual(acrossFirst.map(\.y), downFirst.map(\.y), "the way down goes as the way across does")
        XCTAssertEqual(acrossFirst.map(\.x), downFirst.map(\.x))
    }

    /// A WHEEL'S NOTCHES STEP EACH AXIS their way.
    func testAWheelsNotchesStepEachAxis() {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        func built() -> Node { tree(board, handed) }
        bench.laid(built)

        bench.step(Point(-1, -2))
        bench.frames()
        XCTAssertEqual(board.wrappedValue, Board(x: 1, y: 2))
    }

    /// A WHEEL THE HOST SAYS NO NOTCHES OF - not a number, endless - steps nothing and never stops the application.
    func testAWheelOfNoNumberStepsNothing() {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        func built() -> Node { tree(board, handed) }
        bench.laid(built)

        bench.step(Point(.nan, .infinity))
        bench.frames()
        XCTAssertEqual(board.wrappedValue, Board())
    }

    /// TWO FINGERS THE HOST SAYS NO NUMBERS OF - a scale endless, degrees and a speed not a number - move nothing.
    func testTwoFingersOfNoNumberMoveNothing() {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        func built() -> Node { tree(board, handed) }
        bench.laid(built)

        bench.pinch(.began)
        bench.pinch(.changed, scale: .infinity, degrees: .nan)
        bench.pinch(.ended, velocity: Point(.nan, .infinity))
        bench.frames()
        XCTAssertEqual(board.wrappedValue, Board())
    }

    /// A PAN AND TWO FINGERS MOVE AT ONCE: the hand pans while the fingers spread, each its own axes.
    func testAPanAndTwoFingersMoveAtOnce() {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        func built() -> Node { tree(board, handed) }
        bench.laid(built)

        bench.hand(.began)
        bench.pinch(.began)
        bench.hand(.changed, moved: Point(-100, 0))
        bench.pinch(.changed, scale: 2)
        XCTAssertEqual(handed.boards.last?.x ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(handed.boards.last?.zoom ?? 0, 2, accuracy: 0.001)

        bench.pinch(.ended)
        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(board.wrappedValue, Board(x: 1, y: 0, zoom: 2))
    }

    /// AXES SCROLLED ACROSS AND DOWN ARE A PAN, heard every way; scrolled one way alone, a hand along the layout.
    func testAxesScrolledAcrossAndDownAreAPan() throws {
        let (board, handed) = (State(wrappedValue: Board()), Handed())
        func layout(down: Orientation) -> MotionLayout<[Int], Int, Board> {
            MotionLayout([0], parameters: board.projectedValue) { Text("\($0)") } placements: { _, board in
                handed.boards.append(board)
                return [Placement(Rect(0, 0, 40, 40))]
            }
            .interaction(.simultaneous([
                .value(board.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .frontItem))
                    .range(0...1).snaps(.endpoints),
                .value(board.projectedValue, axis: \.y, input: .translation(down, unit: .frontItem))
                    .range(0...1).snaps(.endpoints),
            ]))
        }

        bench.laid { layout(down: .vertical).node }
        XCTAssertEqual(bench.layout?.handWay, .everyWay)

        let scrolled = LayoutBench()
        scrolled.laid { layout(down: .horizontal).node }
        XCTAssertEqual(scrolled.layout?.handWay, .horizontal, "two axes, one way")
    }
}
