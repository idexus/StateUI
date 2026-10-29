// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A phase layout's arithmetic asked at an axis's keyframes alone - its ends, its snaps and the keyframes given -
// the poses between them blended by identity, each asked once while what it was worked out with stands.

import XCTest

@_spi(Host) @testable import StateUI

/// A phase of two axes, both blended where both have keyframes.
private struct Square: AxesPhase {
    var x = 0.0
    var y = 0.0

    static var axes: [WritableKeyPath<Square, Double>] { [\.x, \.y] }
}

/// Where the arithmetic was asked, a class so the closure that writes it is not walked for state.
private final class Asked {
    var phases: [Double] = []
    var squares: [Square] = []
}

@MainActor
final class LayoutKeyframeTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// Two views: the first a hundred points across a unit of the phase and down by its square, the second ten
    /// points beside it, drawn over it at 7.
    private static func poses(_ phase: Double, gap: Double = 10) -> [Placement] {
        [Placement(Rect(phase * 100, phase * phase * 10, 10, 10)),
         Placement(Rect(phase * 100 + gap, 0, 10, 10), zIndex: 7)]
    }

    /// The two views over `phase`, its axis declared as the test says.
    private func tree(
        _ phase: State<Double>, _ asked: Asked, gap: State<Double>? = nil,
        _ declared: @escaping (PhaseLayout<[Int], Int, Double>) -> PhaseLayout<[Int], Int, Double>
    ) -> () -> Node {
        {
            let layout = PhaseLayout([0, 1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                asked.phases.append(at)
                return Self.poses(at, gap: gap?.wrappedValue ?? 10)
            }
            .motion(.eased(.milliseconds(160), .linear))
            return declared(gap.map { layout.following($0.projectedValue) } ?? layout).node
        }
    }

    /// The phase the host walks, set at `value`, and a frame after it.
    private func stand(_ worn: Int32, at value: Double) {
        moved(worn, to: value)
        bench.cycle()
    }

    private func worn(_ patch: HostPatch) throws -> Int32 {
        try XCTUnwrap(patch.first(.phaseLayout)?.driven?[.phase]?.state)
    }

    // MARK: - Asked at the keyframes

    /// THE ARITHMETIC IS ASKED AT THE KEYFRAMES ALONE, and between them each view goes straight from its pose at one
    /// to its pose at the next: half way down by the curve's ends, not by the arithmetic's square.
    func testTheArithmeticIsAskedAtTheKeyframesAlone() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) { $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1)) }
        let worn = try worn(bench.laid(renders, built).patch)

        for value in [0.25, 0.5, 1.5, 1.75] { stand(worn, at: value) }
        XCTAssertEqual(Set(asked.phases), [0, 1, 2])

        stand(worn, at: 0.5)
        let shown = bench.shown(renders.renderFromScratch(built()))
        XCTAssertEqual(shown[0].bounds.x, 50, accuracy: 1e-9)
        XCTAssertEqual(shown[0].bounds.y, 5, accuracy: 1e-9, "half way from 0 to 10, where the arithmetic says 2.5")
    }

    /// EACH POSE IS ASKED ONCE while what it was worked out with stands: frames to and fro ask nothing again.
    func testEachPoseIsAskedOnce() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) { $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1)) }
        let worn = try worn(bench.laid(renders, built).patch)

        for value in [0.2, 0.4, 1.2, 0.6, 1.8, 0.1] { stand(worn, at: value) }
        XCTAssertEqual(asked.phases.count, Set(asked.phases).count, "asked \(asked.phases)")
    }

    /// AT A KEYFRAME THE POSE IS THE ARITHMETIC'S OWN, never a curve's rounding of it.
    func testAtAKeyframeThePoseIsTheArithmeticsOwn() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) {
            $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1)).interpolation(.catmullRom)
        }
        let worn = try worn(bench.laid(renders, built).patch)

        stand(worn, at: 1)
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built())), PlacedRun(Self.poses(1)).placements)
    }

    /// THE SNAPS AND THE ENDS ARE KEYFRAMES: a rest is never a blend.
    func testTheSnapsAndTheEndsAreKeyframes() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) {
            $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .limits, snaps: [1.5])
        }
        let worn = try worn(bench.laid(renders, built).patch)

        stand(worn, at: 1)
        stand(worn, at: 1.75)
        XCTAssertEqual(Set(asked.phases), [0, 1.5, 2])
    }

    /// THE CURVE IS THE LAYOUT'S: through 0, 10 and 40 down, Catmull-Rom starts slower than a straight line.
    func testTheCurveIsTheLayouts() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) {
            $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1)).interpolation(.catmullRom)
        }
        let worn = try worn(bench.laid(renders, built).patch)

        stand(worn, at: 0.5)
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds.y, 3.75, accuracy: 1e-9)
    }

    // MARK: - Asked again

    /// A NEW ROOM ASKS AGAIN: the poses were worked out in the old one.
    func testANewRoomAsksAgain() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) { $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1)) }
        let patch = bench.laid(renders, built).patch
        let (worn, fed) = (try worn(patch), try XCTUnwrap(patch.first(.phaseLayout)?.driven?[.frame]?.state))

        stand(worn, at: 0.5)
        let before = asked.phases.count
        moved(fed, to: [0, 0, 400, 300])
        bench.cycle()
        XCTAssertEqual(Set(asked.phases.dropFirst(before)), [0, 1])
    }

    /// A WRITE TO A FOLLOWED STATE ASKS AGAIN, and the views land where the new poses say.
    func testAFollowedStateAsksAgain() throws {
        let (phase, gap, asked, renders) = (State(wrappedValue: 0.0), State(wrappedValue: 10.0), Asked(), Renders())
        let built = tree(phase, asked, gap: gap) {
            $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1))
        }
        let worn = try worn(bench.laid(renders, built).patch)

        stand(worn, at: 0.5)
        let before = asked.phases.count
        gap.wrappedValue = 30
        bench.cycle()
        XCTAssertEqual(Set(asked.phases.dropFirst(before)), [0, 1])
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[1].bounds.x, 80, accuracy: 1e-9)
    }

    /// A NEW DESCRIPTION ASKS AGAIN: its arithmetic is another.
    func testANewDescriptionAsksAgain() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) { $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1)) }
        let worn = try worn(bench.laid(renders, built).patch)

        stand(worn, at: 0.5)
        let before = asked.phases.count
        _ = renders.render(built())
        bench.cycle()
        XCTAssertEqual(Set(asked.phases.dropFirst(before)), [0, 1])
    }

    /// WHERE THE MOTION SET OUT ASKS AGAIN ONLY AN ARITHMETIC HANDED IT: the hand passing a snap sets the motion out
    /// from there anew.
    func testWhereTheMotionSetOutAsksAgainOnlyAnArithmeticHandedIt() {
        for readsFrom in [false, true] {
            Renderer.shared.clearStates()
            let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
            func built() -> Node {
                let layout = readsFrom
                    ? PhaseLayout([0, 1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, at, _ in
                        asked.phases.append(at)
                        return Self.poses(at)
                    }
                    : PhaseLayout([0, 1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                        asked.phases.append(at)
                        return Self.poses(at)
                    }
                return layout
                    .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...2, keyframes: .every(1),
                          snaps: .every(1))
                    .node
            }
            _ = bench.laid(renders, built)

            // One description, as the hand moving builds none: the bench's own hand builds one a report.
            guard let heard = renders.renderFromScratch(built()).first(.phaseLayout)?.events?[.handMoved] else {
                return XCTFail("the layout hears no hand")
            }
            func hand(_ gesture: GesturePhase, moved: Point = .zero) {
                XCTAssertTrue(renders.fire(heard, with: MemberValues.encode(gesture, moved, Point.zero)))
                bench.cycle()
            }
            hand(.began)
            for _ in 0..<8 { hand(.changed, moved: Point(-20, 0)) }

            let counted = Dictionary(asked.phases.map { ($0, 1) }, uniquingKeysWith: +)
            XCTAssertEqual(counted[1] ?? 0, readsFrom ? 2 : 1, "asked at 1 \(readsFrom ? "again" : "once")")
        }
    }

    // MARK: - The ends and the seam

    /// PAST AN END THE END'S STRAIGHT LINE GOES ON: the hand pulling past it still moves the views.
    func testPastAnEndTheEndsLineGoesOn() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) {
            $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1)).interpolation(.catmullRom)
        }
        let worn = try worn(bench.laid(renders, built).patch)

        stand(worn, at: -0.25)
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds.x, -25, accuracy: 1e-9)
        stand(worn, at: 2.5)
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds.y, 40 + 15, accuracy: 1e-9)
        XCTAssertEqual(Set(asked.phases), [0, 1, 2])
    }

    /// AN AXIS OF NO LENGTH HAS ONE KEYFRAME AND NO LINE TO GO ON: it is asked where it stands, so the hand pulling
    /// past its one place still moves the views.
    func testAnAxisOfNoLengthIsAskedWhereItStands() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) { $0.axis(\.self, input: .scroll(.horizontal), range: 0...0, keyframes: .every(1)) }
        let worn = try worn(bench.laid(renders, built).patch)

        stand(worn, at: -0.25)
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds.x, -25, accuracy: 1e-9)
    }

    /// AN AXIS THAT COMES ROUND BLENDS ACROSS ITS SEAM: a turn on is the same place, and the keyframe at the turn's
    /// end is asked there, as its own.
    func testAnAxisThatComesRoundBlendsAcrossItsSeam() throws {
        let (phase, asked, renders) = (State(wrappedValue: 0.0), Asked(), Renders())
        let built = tree(phase, asked) {
            $0.axis(\.self, input: .scroll(.horizontal), range: 0...3, keyframes: .every(1), circular: true)
        }
        let worn = try worn(bench.laid(renders, built).patch)

        stand(worn, at: 3.5)
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds.x, 50, accuracy: 1e-9, "0.5 a turn on")
        stand(worn, at: -0.5)
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds.x, 250, accuracy: 1e-9, "2.5 a turn back")
        XCTAssertEqual(Set(asked.phases), [0, 1, 2, 3])
    }

    // MARK: - Several axes

    /// TWO AXES WITH KEYFRAMES ARE A LATTICE: the arithmetic asked at its corners alone, the middle the four corners
    /// blended.
    func testTwoAxesWithKeyframesAreALattice() throws {
        let (square, asked, renders) = (State(wrappedValue: Square()), Asked(), Renders())
        func built() -> Node {
            PhaseLayout([0], phase: square.projectedValue) { Text("\($0)") } placements: { _, at in
                asked.squares.append(at)
                return [Placement(Rect(100 * (at.x * at.x + at.y * at.y), 0, 10, 10))]
            }
            .axis(\.x, input: .scroll(.horizontal), range: 0...1, keyframes: .limits)
            .axis(\.y, input: .scroll(.vertical), range: 0...1, keyframes: .limits)
            .node
        }
        let worn = try worn(bench.laid(renders, built).patch)

        moved(worn, to: [0.5, 0.5], mask: 0b11)
        bench.cycle()
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds.x, 100, accuracy: 1e-9)
        XCTAssertTrue(asked.squares.allSatisfy { [0, 1].contains($0.x) && [0, 1].contains($0.y) }, "\(asked.squares)")
    }

    /// AN AXIS WITHOUT KEYFRAMES STAYS LIVE beside one with them: asked where it stands, at the other's keyframes.
    func testAnAxisWithoutKeyframesStaysLive() throws {
        let (square, asked, renders) = (State(wrappedValue: Square()), Asked(), Renders())
        func built() -> Node {
            PhaseLayout([0], phase: square.projectedValue) { Text("\($0)") } placements: { _, at in
                asked.squares.append(at)
                return [Placement(Rect(100 * at.x, 100 * at.y, 10, 10))]
            }
            .axis(\.x, input: .scroll(.horizontal), range: 0...1, keyframes: .limits)
            .axis(\.y, input: .scroll(.vertical), range: 0...1)
            .node
        }
        let worn = try worn(bench.laid(renders, built).patch)

        moved(worn, to: [0.5, 0.3], mask: 0b11)
        bench.cycle()
        let last = asked.squares.suffix(2)
        XCTAssertEqual(Set(last.map(\.x)), [0, 1])
        XCTAssertEqual(last.map(\.y), [0.3, 0.3])
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds, Rect(50, 30, 10, 10))
    }

    // MARK: - What is wrong

    /// AN INTERPOLATION WITH NO KEYFRAMES blends nothing, and says so.
    func testAnInterpolationWithNoKeyframesIsSaid() {
        let (phase, asked) = (State(wrappedValue: 0.0), Asked())
        _ = Renders().render(tree(phase, asked) {
            $0.axis(\.self, input: .scroll(.horizontal), range: 0...2).interpolation(.catmullRom)
        }())

        XCTAssertTrue(hasComplained("an interpolation and no axis with keyframes"))
    }

    /// AN AXIS THAT COMES ROUND WITH KEYFRAMES AT ITS ENDS ALONE has one place a turn apart, and says so.
    func testAWrappingAxisWithKeyframesAtItsEndsAloneIsSaid() {
        let (phase, asked) = (State(wrappedValue: 0.0), Asked())
        _ = Renders().render(tree(phase, asked) {
            $0.axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .limits, circular: true)
        }())

        XCTAssertTrue(hasComplained("keyframes at its ends alone"))
    }
}
