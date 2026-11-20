// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A layout's rest as the element running its program sees it: no hand on its parameters, the parameters where they
/// are going, every view at its place - told once as the layout comes to it, with where the parameters rest.
/// Design: docs/design/host/layout.md#at-rest
@MainActor
final class ProgramRestTests: XCTestCase {
    private let bench = LayoutBench()

    /// Where a layout said it came to rest, each time.
    private final class Rests {
        var at: [Double] = []
    }

    /// Two views a hundred points apart, moved a hundred points a unit by the hand, which rests on whole units.
    private func tree(_ phase: State<Double>, _ rests: Rests) -> Node {
        MotionLayout([0, 1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
            (0..<2).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 10, height: 10)) }
        }
        .axis(range: 0...3, segments: .every(1))
        .interaction(
            .value(phase.projectedValue, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...3)
                .snaps(.every(1)).release(.projected(.eased(.milliseconds(200)))))
        .onSettled { rests.at.append($0) }
        .node
    }

    /// Frames until nothing moves, and the handlers they told run.
    private func rest() async {
        bench.frames(60)
        await bench.settle()
    }

    /// LAID OUT AT REST, A LAYOUT TELLS NOTHING: it never moved.
    func testLaidOutAtRestItTellsNothing() async {
        let (phase, rests) = (State(wrappedValue: 1.0), Rests())

        bench.laid { self.tree(phase, rests) }
        await rest()

        XCTAssertEqual(rests.at, [])
    }

    /// A JOURNEY OF THE PARAMETERS TELLS THE REST ONCE, where they rest: nothing on the way, nothing after.
    func testAJourneyOfTheParametersTellsTheRestOnce() async {
        let (phase, rests) = (State(wrappedValue: 0.0, motion: .eased(.milliseconds(200))), Rests())
        bench.laid { self.tree(phase, rests) }

        phase.wrappedValue = 2
        bench.frames(4)
        await bench.settle()
        XCTAssertEqual(rests.at, [], "on its way")

        await rest()
        XCTAssertEqual(rests.at, [2], "told where it rests")

        await rest()
        XCTAssertEqual(rests.at, [2], "once")
    }

    /// A HAND HOLDING THE RUN IS NO REST, however still it stands and wherever - on the very place it would rest
    /// at too: let go, the run is told once where it lands.
    func testAHandHoldingTheRunIsNoRest() async throws {
        let (phase, rests) = (State(wrappedValue: 0.0), Rests())
        bench.laid { self.tree(phase, rests) }

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -120, y: 0))
        bench.hand(.changed, moved: Point(x: 20, y: 0))
        await rest()
        let held = try XCTUnwrap(bench.journey)
        XCTAssertEqual(held.value, [1], "the hand holds it on a whole unit")
        XCTAssertEqual(held.destination, held.value, "where it would rest")
        XCTAssertEqual(rests.at, [], "held: no rest")

        bench.hand(.ended)
        await rest()
        XCTAssertEqual(rests.at, [1], "let go: where it lands")
    }
}
