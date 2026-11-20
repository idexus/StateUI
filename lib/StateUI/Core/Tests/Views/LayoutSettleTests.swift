// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A motion layout tells every `onSettled` where its parameters stand once its host says it came to rest - each
/// handler through its own gate, in the order written. When a layout rests is its host's to say.
@MainActor
final class LayoutSettleTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
        bench.walks = true
    }

    private let bench = LayoutBench()

    /// What the layout told, a class so the closure that writes it is not walked for state.
    private final class Told {
        var phases: [Double] = []
    }

    /// Views a hundred apart a unit of the phase, telling `told` each rest.
    private func tree(_ phase: State<Double>, _ items: State<[Int]>, _ told: Told) -> Node {
        let count = items.wrappedValue.count
        return MotionLayout(items.wrappedValue, parameters: phase.traveling(.eased(.milliseconds(160)))) { Text("\($0)") } placements: { _, at in
            (0..<count).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 10, height: 10)) }
        }
        .layoutBodies(.onChange(response: .milliseconds(160)))
        .onSettled { told.phases.append($0) }
        .node
    }

    /// EACH HANDLER OF THE REST GOES THROUGH A GATE OF ITS OWN: one held under `.ignoreWhileRunning` keeps no other
    /// from running.
    func testEachHandlerOfTheRestHasAGateOfItsOwn() async {
        let (phase, renders) = (State(wrappedValue: 0.0), Renders())
        var heard: [Int] = []
        func built() -> Node {
            MotionLayout([0, 1, 2, 3], parameters: phase.traveling(.eased(.milliseconds(160)))) { Text("\($0)") } placements: { _, at in
                (0..<4).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 10, height: 10)) }
            }
            .onSettled(policy: .ignoreWhileRunning) { _ in
                heard.append(1)
                try await Task.sleep(for: .seconds(60))
            }
            .onSettled(policy: .ignoreWhileRunning) { _ in heard.append(2) }
            .node
        }
        _ = bench.laid(renders, built)

        bench.rested(renders, built, at: [1])
        _ = await settle()

        XCTAssertEqual(heard, [1, 2])
        _ = renders.render(VStack {}.node)
        _ = await settle()
    }

    /// A HANDLER OF THE REST NO LONGER WRITTEN ENDS ITS RUN as the layout is built without it, as an element's does.
    func testAHandlerOfTheRestNoLongerWrittenEndsItsRun() async {
        let (phase, hears, renders) = (State(wrappedValue: 0.0), State(true), Renders())
        let gate = Gate(.ignoreWhileRunning)
        func built() -> Node {
            let layout = MotionLayout([0, 1, 2, 3], parameters: phase.traveling(.eased(.milliseconds(160)))) { Text("\($0)") } placements: { _, at in
                (0..<4).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 10, height: 10)) }
            }
            return (hears.wrappedValue
                ? layout.onSettled(gate: gate) { _ in try await Task.sleep(for: .seconds(60)) }
                : layout).node
        }
        _ = bench.laid(renders, built)

        bench.rested(renders, built, at: [1])
        _ = await settle()
        XCTAssertTrue(gate.isBusy, "the handler runs")

        hears.wrappedValue = false
        _ = renders.render(built())
        await gate.waitWhileBusy()
        XCTAssertFalse(gate.isBusy, "its run ended with it")

        _ = renders.render(VStack {}.node)
        await gate.endEveryRun()
    }

    /// EVERY HANDLER OF THE REST RUNS, in the order written.
    func testEveryHandlerOfTheRestRunsInWritingOrder() async {
        let (phase, told, renders) = (State(wrappedValue: 0.0), Told(), Renders())
        func built() -> Node {
            MotionLayout([0, 1, 2, 3], parameters: phase.traveling(.eased(.milliseconds(160)))) { Text("\($0)") } placements: { _, at in
                (0..<4).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 10, height: 10)) }
            }
            .onSettled { told.phases.append($0) }
            .onSettled { told.phases.append($0 + 10) }
            .node
        }
        _ = bench.laid(renders, built)

        bench.rested(renders, built, at: [1])
        _ = await settle()

        XCTAssertEqual(told.phases, [1, 11])
    }

    /// A LAYOUT WITH NO `onSettled` HEARS NO REST: its host is asked for none.
    func testALayoutNobodyAsksHearsNoRest() {
        let (phase, renders) = (State(wrappedValue: 0.0), Renders())
        func plain() -> Node {
            MotionLayout([0, 1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, _ in
                [Placement(.zero), Placement(.zero)]
            }
            .node
        }
        _ = bench.laid(renders, plain)

        XCTAssertFalse(bench.rested(renders, plain, at: [0]))
    }
}
