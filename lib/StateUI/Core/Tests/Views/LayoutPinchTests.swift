// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Two fingers over a phase layout: a magnification multiplied by how far they spread, a rotation a unit every so
// many degrees they turn, both at once, each let go onto a target of its own.

import XCTest

@_spi(Host) @testable import StateUI

/// A phase two fingers move: how far a dial is turned, and how near it stands.
private struct Dial: AxesPhase {
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
        var layout = PhaseLayout([0, 1, 2, 3], phase: dial.projectedValue) { Text("\($0)") } placements: { _, dial in
            handed.dials.append(dial)
            return (0..<4).map { _ in Placement(Rect(0, 0, 40, 40)) }
        }
        .axis(\.zoom, input: .magnification, range: 0.5...2, snaps: [1])
        .axis(\.turn, input: .rotation(degreesPerUnit: 90), range: 0...4, snaps: .every(1), wraps: true)
        .motion(.eased(.milliseconds(160), .linear))
        if itemDrag { layout = layout.itemDrag(begins: .held) }
        return layout.node
    }

    private func frames(_ count: Int = 30) {
        for _ in 0..<count { bench.cycle() }
    }

    /// THE ELEMENT SAYS WHICH FINGERS IT HEARS, and hears them as one.
    func testTheElementSaysWhichFingersItHears() throws {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        let layout = try XCTUnwrap(bench.laid(Renders(), { tree(dial, handed) }).patch.first(.phaseLayout))

        XCTAssertEqual(layout.properties[.magnifies], .bool(true))
        XCTAssertEqual(layout.properties[.rotates], .bool(true))
        XCTAssertNotNil(layout.events?[.pinchMoved])
        XCTAssertNil(layout.properties[.handAxis], "no hand along the layout")
    }

    /// SPREADING FINGERS MULTIPLY THE MAGNIFICATION: their distance doubled doubles it - and the target named is the
    /// nearest by its logarithm, 2 for 1.5, not the 1 a plain distance would name first.
    func testSpreadingFingersMultiplyTheMagnification() {
        let (dial, handed, renders) = (State(wrappedValue: Dial()), Handed(), Renders())
        func built() -> Node { tree(dial, handed) }
        _ = bench.laid(renders, built)

        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, scale: 1.5)
        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 1.5, accuracy: 0.000_1)
        XCTAssertEqual(dial.wrappedValue.zoom, 2, "nearer 2 than 1 by the logarithm")

        bench.pinch(renders, built, .changed, scale: 4.0 / 3)
        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 2, accuracy: 0.000_1, "1.5 and a third more: twice the size")
    }

    /// PINCHING IN PAST THE SMALLEST GIVES LESS AND LESS, by the logarithm, and let go it comes back onto it.
    func testPinchingInPastTheSmallestGivesLessAndLess() {
        let (dial, handed, renders) = (State(wrappedValue: Dial()), Handed(), Renders())
        func built() -> Node { tree(dial, handed) }
        _ = bench.laid(renders, built)

        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, scale: 0.25)
        let zoom = handed.dials.last?.zoom ?? 0
        XCTAssertLessThan(zoom, 0.5, "past the smallest")
        XCTAssertGreaterThan(zoom, 0.5 * exp(-0.75), "never three quarters of a unit of its logarithm past it")

        bench.pinch(renders, built, .ended)
        frames()
        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 0.5, accuracy: 0.000_1, "back onto it")
    }

    /// TURNING FINGERS MOVE THE ROTATION'S AXIS a unit every `degreesPerUnit`, clockwise on, and let go still it
    /// comes onto the nearest target.
    func testTurningFingersMoveTheRotationsAxis() {
        let (dial, handed, renders) = (State(wrappedValue: Dial()), Handed(), Renders())
        func built() -> Node { tree(dial, handed) }
        _ = bench.laid(renders, built)

        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, degrees: 45)
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 0.5, accuracy: 0.000_1)
        bench.pinch(renders, built, .changed, degrees: 80)
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 125.0 / 90, accuracy: 0.000_1)

        bench.pinch(renders, built, .ended)
        frames()
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 1, accuracy: 0.000_1)
        XCTAssertEqual(dial.wrappedValue.turn, 1)
    }

    /// THE FINGERS MOVE BOTH AXES AT ONCE, each its own: one report spreading and turning.
    func testTheFingersMoveBothAxesAtOnce() {
        let (dial, handed, renders) = (State(wrappedValue: Dial()), Handed(), Renders())
        func built() -> Node { tree(dial, handed) }
        _ = bench.laid(renders, built)

        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, scale: 2, degrees: 90)
        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 2, accuracy: 0.000_1)
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 1, accuracy: 0.000_1)

        bench.pinch(renders, built, .ended)
        frames()
        XCTAssertEqual(dial.wrappedValue, Dial(turn: 1, zoom: 2))
    }

    /// LET GO WITH SPEED, AN AXIS GOES ON to the target nearest where it would end; let go still, onto the nearest.
    func testAFlickGoesOnToTheTargetNearestItsEnd() {
        let (dial, handed, renders) = (State(wrappedValue: Dial()), Handed(), Renders())
        func built() -> Node { tree(dial, handed) }
        _ = bench.laid(renders, built)

        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, degrees: 18)
        // 360 degrees a second is four units: a light friction carries it some half a unit on, past halfway.
        bench.pinch(renders, built, .ended, speed: Point(0, 360))
        frames()
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 1, accuracy: 0.000_1, "flicked on")

        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, degrees: 18)
        bench.pinch(renders, built, .ended)
        frames()
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 1, accuracy: 0.000_1, "let go still, back onto the nearest")
    }

    /// A VIEW HELD BY ITSELF KEEPS THE HAND: the fingers move nothing while it does.
    func testAViewHeldByItselfKeepsTheHand() {
        let (dial, handed, renders) = (State(wrappedValue: Dial()), Handed(), Renders())
        func built() -> Node { tree(dial, handed, itemDrag: true) }
        _ = bench.laid(renders, built)

        bench.item(renders, built, .began, at: Point(20, 20))
        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, scale: 2, degrees: 90)

        XCTAssertEqual(handed.dials.last?.zoom ?? 0, 1, accuracy: 0.000_1)
        XCTAssertEqual(handed.dials.last?.turn ?? 0, 0, accuracy: 0.000_1)
    }

    /// AN AXIS DECLARED AGAIN TAKES THE OTHER'S PLACE: its input with it.
    func testAnAxisDeclaredAgainTakesTheOthersPlace() throws {
        let (dial, handed) = (State(wrappedValue: Dial()), Handed())
        let layout = PhaseLayout([0], phase: dial.projectedValue) { Text("\($0)") } placements: { _, dial in
            handed.dials.append(dial)
            return [Placement(Rect(0, 0, 40, 40))]
        }
        .axis(\.zoom, input: .scroll(.horizontal), range: 1...2)
        .axis(\.zoom, input: .magnification, range: 1...2)

        let element = try XCTUnwrap(Renders().settled(layout.node).first(.phaseLayout))
        XCTAssertNil(element.properties[.handAxis], "the scroll's place taken")
        XCTAssertEqual(element.properties[.magnifies], .bool(true))
    }
}
