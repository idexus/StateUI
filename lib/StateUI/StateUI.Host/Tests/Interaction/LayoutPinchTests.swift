// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Two fingers over a motion layout: a magnification multiplied by how far they spread, a rotation a unit every so
// many degrees they turn, both at once, each let go onto a target of its own.

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A phase two fingers move: how far a dial is turned, and how near it stands.
private struct Dial: LayoutParameters {
    var turn = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Dial, Double>] { [\.turn, \.zoom] }
}

/// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
private final class Handed {
    var dials: [Dial] = []
}

@MainActor
final class LayoutPinchTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// Four views a dial turns - a unit every 90 degrees, round and round - and spreads, resting at half, whole and
    /// twice its size.
    private func tree(_ dial: State<Dial>, _ handed: Handed, itemDrag: Bool = false) -> Node {
        var layout = MotionLayout([0, 1, 2, 3], parameters: dial.traveling(.eased(.milliseconds(160), curve: .linear))) { Text("\($0)") } placements: { _, dial in
            handed.dials.append(dial)
            return (0..<4).map { _ in Placement(Rect(0, 0, 40, 40)) }
        }
        .interaction(
            .simultaneous([
                Interaction.value(dial.traveling(.eased(.milliseconds(160), curve: .linear)), axis: \.zoom, input: .magnification).range(0.5...2).snaps([1]),
                Interaction.value(dial.traveling(.eased(.milliseconds(160), curve: .linear)), axis: \.turn, input: .rotation(degreesPerUnit: 90)).range(0...4).snaps(.every(1)).periodic(true),
            ])
                .release(.projected(.eased(.milliseconds(400), curve: .cubicOut))))
        if itemDrag { layout = layout.itemDrag(begins: .longPress) }
        return layout.node
    }


    /// THE ELEMENT SAYS WHICH FINGERS IT HEARS, and hears them as one.
    func testTheElementSaysWhichFingersItHears() throws {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        bench.laid { self.tree(dial, handed) }
        let layout = try XCTUnwrap(bench.layout)

        XCTAssertEqual(layout.hearing, [.pinches, .rotations])
        XCTAssertNil(layout.handWay, "no hand along the layout")
    }

    /// SPREADING FINGERS MULTIPLY THE MAGNIFICATION: their distance doubled doubles it - and the target named is the
    /// nearest by its logarithm, 2 for 1.5, not the 1 a plain distance would name first.
    func testSpreadingFingersMultiplyTheMagnification() {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        func built() -> Node { tree(dial, handed) }
        bench.laid(built)

        bench.pinch(.began)
        bench.pinch(.changed, scale: 1.5)
        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 1.5, accuracy: 0.000_1)
        XCTAssertEqual(dial.wrappedValue.zoom, 2, "nearer 2 than 1 by the logarithm")

        bench.pinch(.changed, scale: 4.0 / 3)
        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 2, accuracy: 0.000_1, "1.5 and a third more: twice the size")
    }

    /// PINCHING IN PAST THE SMALLEST GIVES LESS AND LESS, by the logarithm, and let go it comes back onto it.
    func testPinchingInPastTheSmallestGivesLessAndLess() {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        func built() -> Node { tree(dial, handed) }
        bench.laid(built)

        bench.pinch(.began)
        bench.pinch(.changed, scale: 0.25)
        let zoom = handed.dials.last?.zoom ?? 0
        XCTAssertLessThan(zoom, 0.5, "past the smallest")
        XCTAssertGreaterThan(zoom, 0.5 * exp(-0.75), "never three quarters of a unit of its logarithm past it")

        bench.pinch(.ended)
        bench.frames()
        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 0.5, accuracy: 0.000_1, "back onto it")
    }

    /// TURNING FINGERS MOVE THE ROTATION'S AXIS a unit every `degreesPerUnit`, clockwise on, and let go still it
    /// comes onto the nearest target.
    func testTurningFingersMoveTheRotationsAxis() {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        func built() -> Node { tree(dial, handed) }
        bench.laid(built)

        bench.pinch(.began)
        bench.pinch(.changed, degrees: 45)
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 0.5, accuracy: 0.000_1)
        bench.pinch(.changed, degrees: 80)
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 125.0 / 90, accuracy: 0.000_1)

        bench.pinch(.ended)
        bench.frames()
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 1, accuracy: 0.000_1)
        XCTAssertEqual(dial.wrappedValue.turn, 1)
    }

    /// THE FINGERS MOVE BOTH AXES AT ONCE, each its own: one report spreading and turning.
    func testTheFingersMoveBothAxesAtOnce() {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        func built() -> Node { tree(dial, handed) }
        bench.laid(built)

        bench.pinch(.began)
        bench.pinch(.changed, scale: 2, degrees: 90)
        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 2, accuracy: 0.000_1)
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 1, accuracy: 0.000_1)

        bench.pinch(.ended)
        bench.frames()
        XCTAssertEqual(dial.wrappedValue, Dial(turn: 1, zoom: 2))
    }

    /// LET GO WITH SPEED, AN AXIS GOES ON to the target nearest where it would end; let go still, onto the nearest.
    func testAFlickGoesOnToTheTargetNearestItsEnd() {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        func built() -> Node { tree(dial, handed) }
        bench.laid(built)

        bench.pinch(.began)
        bench.pinch(.changed, degrees: 18)
        // 360 degrees a second is four units: a light friction carries it some half a unit on, past halfway.
        bench.pinch(.ended, velocity: Point(0, 360))
        bench.frames()
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 1, accuracy: 0.000_1, "flicked on")

        bench.pinch(.began)
        bench.pinch(.changed, degrees: 18)
        bench.pinch(.ended)
        bench.frames()
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 1, accuracy: 0.000_1, "let go still, back onto the nearest")
    }

    /// A VIEW HELD BY ITSELF KEEPS THE HAND: the fingers move nothing while it does.
    func testAViewHeldByItselfKeepsTheHand() throws {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        func built() -> Node { tree(dial, handed, itemDrag: true) }
        bench.laid(built)

        let (layout, runtime) = (try XCTUnwrap(bench.layout), try XCTUnwrap(bench.runtime))

        // A press standing still a long press's time holds the view under it.
        layout.hear(.hand(.began, moved: .zero, speed: nil, point: Point(20, 20)), in: runtime)
        bench.frames(40)
        XCTAssertTrue(layout.holdsItem)

        layout.hear(.pinch(.began, scale: 1, at: Point(0.5, 0.5)), in: runtime)
        layout.hear(.pinch(.changed, scale: 2, at: Point(0.5, 0.5)), in: runtime)
        layout.hear(.rotation(.changed, degrees: 90), in: runtime)
        bench.frames(4)

        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 1, accuracy: 0.000_1)
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 0, accuracy: 0.000_1)
    }
}
