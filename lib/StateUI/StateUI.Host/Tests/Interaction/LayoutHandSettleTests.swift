// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A motion layout the hand moves tells its rest once: not while the hand holds it, however still, nor while a
/// throw goes on - at the snap it comes to rest on.
@MainActor
final class LayoutHandSettleTests: XCTestCase {
    private let bench = LayoutBench()

    /// What the layout told, a class so the closure that writes it is not walked for state.
    private final class Told {
        var phases: [Double] = []
    }

    /// Views a hundred apart a unit of the phase, snapping to each unit, telling `told` each rest.
    private func tree(_ phase: State<Double>, _ told: Told) -> Node {
        let moved = phase.traveling(.eased(.milliseconds(160)))
        return MotionLayout([0, 1, 2, 3], parameters: moved) { Text("\($0)") } placements: { _, at in
            (0..<4).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 10, height: 10)) }
        }
        .interaction(
            .value(moved, input: .translation(.horizontal, unit: .points(100)))
                .reversed(true).range(0...3).snaps(.every(1))
                .release(.projected(.eased(.milliseconds(400)))))
        .layoutBodies(.none)
        .onSettled { told.phases.append($0) }
        .node
    }

    /// A RUN THROWN TELLS ITS REST ONCE, at the snap it comes to rest on - not while it goes on.
    func testARunThrownTellsItsRestOnce() async {
        let (phase, told) = (State(wrappedValue: 0.0), Told())
        func built() -> Node { tree(phase, told) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -60, y: 0))
        bench.hand(.ended, velocity: Point(x: -1_200, y: 0))
        bench.frames(3)
        await bench.settle()
        XCTAssertEqual(told.phases, [], "not while it goes on")

        bench.frames(80)
        await bench.settle()
        XCTAssertEqual(told.phases, [2], "once, where it rests")
    }

    /// A HAND HOLDING THE RUN STILL IS NO REST: on a snap or between two, standing as long as it likes, the layout
    /// tells nothing until the hand lets go and the run stands.
    func testAHandHoldingTheRunStillIsNoRest() async {
        let (phase, told) = (State(wrappedValue: 0.0), Told())
        func built() -> Node { tree(phase, told) }
        bench.laid(built)

        bench.hand(.began)
        bench.frames(20)
        await bench.settle()
        XCTAssertEqual(told.phases, [], "taken on a snap, and held there")

        bench.hand(.changed, moved: Point(x: -100, y: 0))
        bench.frames(20)
        await bench.settle()
        XCTAssertEqual(told.phases, [], "moved onto the next snap, and held there")

        bench.hand(.ended)
        bench.frames(20)
        await bench.settle()
        XCTAssertEqual(told.phases, [1], "let go, at rest")
    }
}
