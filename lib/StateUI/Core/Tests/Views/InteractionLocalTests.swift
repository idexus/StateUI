// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view's own press and drag as declarations: what the host is handed of them, what is refused, and the one effect
// a view keeps however often it is described.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class InteractionLocalTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The program the host was handed for the element `type` of `patch`.
    private func program(_ patch: HostPatch, _ type: NodeType = .rectangle) -> HostInteractionProgram? {
        guard case .replace(let program)? = (patch.type == type ? patch : patch.first(type))?.interaction else {
            return nil
        }
        return program
    }

    // MARK: - What the host is handed

    /// A PRESS IS HANDED AS THE NUMBERS IT MOVES AND WHAT ANSWERS ITS OFFSET, beside no value: the view moves no state.
    func testAPressIsHandedWithItsValuesAndItsEffect() throws {
        let patch = Renders().render(
            Rectangle()
                .interaction(.press(values: .scale) { _ in PresentationOffset(scaleX: 0.9, scaleY: 0.9) })
                .id("pressed")
                .node)

        let handed = try XCTUnwrap(program(patch))
        XCTAssertEqual(handed.values, [])
        XCTAssertEqual(handed.press?.values, .scale)
        let press = PressInput(
            phase: .began, location: Point(x: 10, y: 10), displacement: .zero, velocity: .zero,
            bounds: Rect(x: 0, y: 0, width: 20, height: 20))
        XCTAssertEqual(handed.press?.effect.offset(press), PresentationOffset(scaleX: 0.9, scaleY: 0.9))
        XCTAssertNil(handed.drag)
    }

    /// A DRAG IS HANDED AS ITS AXES AND ITS START.
    func testADragIsHandedWithItsAxesAndItsStart() throws {
        let patch = Renders().render(
            Rectangle().interaction(.drag(.vertical, begins: .directional)).id("dragged").node)

        XCTAssertEqual(program(patch)?.drag, HostDrag(axes: .vertical, begins: .directional))
        XCTAssertEqual(
            program(Renders().render(Rectangle().interaction(.drag(.both)).id("dragged").node))?.drag,
            HostDrag(axes: .both, begins: .immediately), "any way, at once, unless said")
    }

    /// A PRESS, A DRAG AND A VALUE STAND TOGETHER: one view answers a press, is taken by the hand and has a state
    /// moved, each by its own declaration.
    func testAPressADragAndAValueStandTogether() throws {
        let across = State(wrappedValue: 0.0)
        let patch = Renders().render(
            Rectangle()
                .interaction(.simultaneous([
                    .elasticPress(),
                    .drag(.vertical, begins: .longPress),
                    .value(across.projectedValue, input: .translation(.horizontal)),
                ]))
                .id("card")
                .node)

        let handed = try XCTUnwrap(program(patch))
        XCTAssertEqual(handed.values.count, 1)
        XCTAssertEqual(handed.press?.values, [.translation, .scale])
        XCTAssertEqual(handed.drag, HostDrag(axes: .vertical, begins: .longPress))
    }

    /// A MOTION LAYOUT HANDS ON THE PRESS AND THE DRAG WRITTEN ON IT, beside the values it reads for its own run.
    func testAMotionLayoutHandsOnItsOwnPressAndDrag() throws {
        let turn = State(wrappedValue: 0.0)
        let patch = Renders().render(
            MotionLayout([1], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
            }
            .interaction(.simultaneous([
                .value(turn.projectedValue, input: .translation(.horizontal)), .elasticPress(), .drag(.vertical),
            ]))
            .id("layout")
            .node)

        let handed = try XCTUnwrap(program(patch, .motionLayout))
        XCTAssertEqual(handed.values.count, 1)
        XCTAssertNotNil(handed.press)
        XCTAssertEqual(handed.drag, HostDrag(axes: .vertical, begins: .immediately))
    }

    // MARK: - The elastic press

    /// AN ELASTIC PRESS GROWS THE VIEW A LITTLE WHEREVER IT STANDS, PULLS IT TOWARD ITSELF AND STRETCHES IT THE WAY
    /// IT PULLS: at the middle the view is only grown; across, it is moved across and drawn wider, as tall as
    /// before; at a corner both ways, a press past the view held to its edge.
    func testAnElasticPressGrowsPullsAndStretchesTheWayItPulls() throws {
        let patch = Renders().render(
            Rectangle().interaction(.elasticPress(maximumOffset: 8, scale: 1.02, maximumScale: 1.1)).id("pressed").node)
        let effect = try XCTUnwrap(program(patch)?.press?.effect)
        let bounds = Rect(x: 0, y: 0, width: 100, height: 40)
        func offset(at point: Point) -> PresentationOffset {
            effect.offset(PressInput(phase: .changed, location: point, displacement: .zero, velocity: .zero, bounds: bounds))
        }

        XCTAssertEqual(offset(at: Point(x: 50, y: 20)), PresentationOffset(scaleX: 1.02, scaleY: 1.02), "at the middle")
        let right = offset(at: Point(x: 100, y: 20))
        XCTAssertEqual(right.translation, Point(x: 8, y: 0))
        XCTAssertEqual(right.scaleX, 1.1, accuracy: 0.000_1, "wider, the way it is pulled")
        XCTAssertEqual(right.scaleY, 1.02, accuracy: 0.000_1, "as tall as a press at its middle draws it")
        let below = offset(at: Point(x: 50, y: 40))
        XCTAssertEqual(below.scaleX, 1.02, accuracy: 0.000_1)
        XCTAssertEqual(below.scaleY, 1.1, accuracy: 0.000_1, "taller, pulled down")
        let corner = offset(at: Point(x: 400, y: -90))
        XCTAssertEqual(corner.translation, Point(x: 8, y: -8), "a press past the view is held to its edge")
        XCTAssertEqual(corner.scaleX, 1.1, accuracy: 0.000_1)
        XCTAssertEqual(corner.scaleY, 1.1, accuracy: 0.000_1)
    }

    /// AN ELASTIC PRESS HAS A SPRING OF ITS OWN, WHICH THE HOST IS HANDED: the view comes after the press on it. A
    /// press with an effect of the application's has none, and is there at once.
    func testAnElasticPressIsHandedWithASpringOfItsOwn() throws {
        let elastic = Renders().render(Rectangle().interaction(.elasticPress()).id("pressed").node)
        let plain = Renders().render(
            Rectangle().interaction(.press(values: .scale) { _ in .identity }).id("pressed").node)

        XCTAssertEqual(program(elastic)?.press?.spring, HostLayoutBody(milliseconds: 220, damping: 0.8, follows: true))
        XCTAssertNil(program(plain)?.press?.spring)
    }

    /// AN ELASTIC PRESS PULLS QUICKLY AT FIRST AND LESS AND LESS TOWARD THE EDGE, as a band stretched does: halfway
    /// to the edge it has pulled the view more than half its way, each step on adds less than the one before, and
    /// the two sides pull alike.
    func testAnElasticPressPullsLessAndLessTowardTheEdge() throws {
        let patch = Renders().render(
            Rectangle().interaction(.elasticPress(maximumOffset: 10, scale: 1, maximumScale: 1.2)).id("pressed").node)
        let effect = try XCTUnwrap(program(patch)?.press?.effect)
        let bounds = Rect(x: 0, y: 0, width: 200, height: 40)
        func pull(at x: Double) -> PresentationOffset {
            effect.offset(PressInput(
                phase: .changed, location: Point(x: x, y: 20), displacement: .zero, velocity: .zero, bounds: bounds))
        }
        let steps = stride(from: 100.0, through: 200, by: 25).map { pull(at: $0).translation.x }

        XCTAssertEqual(steps.first, 0)
        XCTAssertEqual(steps.last ?? 0, 10, accuracy: 0.000_1, "all the way at the edge")
        XCTAssertGreaterThan(steps[2], 7, "halfway there, well past half its way")
        let gains = zip(steps.dropFirst(), steps).map { $0 - $1 }
        XCTAssertTrue(zip(gains, gains.dropFirst()).allSatisfy { $0 > $1 }, "each step adds less than the one before")
        XCTAssertEqual(pull(at: 50).translation.x, -steps[2], accuracy: 0.000_1, "the other side alike")
        XCTAssertGreaterThan(pull(at: 150).scaleX, 1.1, "and grown more than half its way")
    }

    /// ONLY THE VALUES A PRESS NAMES ARE KEPT OF WHAT ITS EFFECT ANSWERS, and a number that is none is left out.
    func testOnlyTheNamedValuesOfAnOffsetAreKept() {
        let answered = PresentationOffset(translation: Point(x: 4, y: .nan), rotation: 30, scaleX: 2, scaleY: .infinity)

        XCTAssertEqual(answered.kept(.translation), PresentationOffset(translation: Point(x: 4, y: 0)))
        XCTAssertEqual(answered.kept([.rotation, .scale]), PresentationOffset(rotation: 30, scaleX: 2, scaleY: 1))
        XCTAssertEqual(answered.kept([]), .identity)
    }

    // MARK: - What is refused

    /// A DIRECTIONAL DRAG NAMES ONE AXIS: with both it could never tell its way from the other, so the hand takes
    /// the view no way and the author is told.
    func testADirectionalDragOfBothAxesIsRefused() throws {
        let patch = Renders().render(Rectangle().interaction(.drag(.both, begins: .directional)).id("dragged").node)

        XCTAssertNil(program(patch))
        XCTAssertTrue(hasComplained("An interaction's directional drag was given both axes"))
    }

    /// TWO PRESSES, OR TWO DRAGS, SAID AT ONCE ARE REFUSED TOGETHER: neither is the one the author meant.
    func testTwoPressesOrTwoDragsAtOnceAreRefusedTogether() throws {
        let patch = Renders().render(
            Rectangle()
                .interaction(.simultaneous([.elasticPress(), .elasticPress(), .drag(.vertical), .drag(.horizontal)]))
                .id("twice")
                .node)

        XCTAssertNil(program(patch), "nothing of it stands")
        XCTAssertTrue(hasComplained("An interaction says a press twice"))
        XCTAssertTrue(hasComplained("An interaction says a drag twice"))
    }

    // MARK: - Described again

    /// A VIEW DESCRIBED AGAIN ALIKE IS TOLD NOTHING, AND ITS NEWEST EFFECT ANSWERS: the host keeps one object for
    /// the view's press, which every description hands its own effect.
    func testAViewDescribedAgainKeepsOnePressWhoseNewestEffectAnswers() throws {
        let renders = Renders()
        func tree(_ scale: Double) -> Node {
            Rectangle()
                .interaction(.press(values: .scale) { _ in PresentationOffset(scaleX: scale, scaleY: scale) })
                .id("pressed")
                .node
        }
        let first = try XCTUnwrap(program(renders.render(tree(0.9)))?.press?.effect)

        let again = renders.render(tree(0.8))

        XCTAssertNil(again.first(.rectangle)?.interaction ?? again.interaction, "the same program: nothing is told")
        let press = PressInput(
            phase: .began, location: .zero, displacement: .zero, velocity: .zero, bounds: Rect(x: 0, y: 0, width: 10, height: 10))
        XCTAssertEqual(first.offset(press).scaleX, 0.8, "the object the host holds answers by the newest effect")
    }
}
