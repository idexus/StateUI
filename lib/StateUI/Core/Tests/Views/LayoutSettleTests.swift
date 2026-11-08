// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A motion layout tells once that its run came to rest - no hand holding it, the phase at its destination, every view
/// at its place - with the phase it rests at, whatever moved it; laid out at rest, it tells nothing.
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

    /// Views a hundred apart a unit of the phase, snapping to each unit, telling `told` each rest.
    private func tree(_ phase: State<Double>, _ items: State<[Int]>, _ told: Told) -> Node {
        let count = items.wrappedValue.count
        return MotionLayout(items.wrappedValue, parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
            (0..<count).map { Placement(Rect((Double($0) - at) * 100, 0, 10, 10)) }
        }
        .axis(\.self, input: .scroll(.horizontal, lengthPerUnit: 100), range: 0...3, snaps: .every(1))
        .parameterMotion(.eased(.milliseconds(160)))
        .dynamics(.spring(response: .milliseconds(160)))
        .onSettled { told.phases.append($0) }
        .node
    }

    /// EACH HANDLER OF THE REST GOES THROUGH A GATE OF ITS OWN: one held under `.ignoreWhileRunning` keeps no other
    /// from running.
    func testEachHandlerOfTheRestHasAGateOfItsOwn() async {
        let (phase, renders) = (State(wrappedValue: 0.0), Renders())
        var heard: [Int] = []
        func built() -> Node {
            MotionLayout([0, 1, 2, 3], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                (0..<4).map { Placement(Rect((Double($0) - at) * 100, 0, 10, 10)) }
            }
            .axis(\.self, input: .scroll(.horizontal, lengthPerUnit: 100), range: 0...3, snaps: .every(1))
            .parameterMotion(.eased(.milliseconds(160)))
            .onSettled(policy: .ignoreWhileRunning) { _ in
                heard.append(1)
                try await Task.sleep(for: .seconds(60))
            }
            .onSettled(policy: .ignoreWhileRunning) { _ in heard.append(2) }
            .node
        }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-100, 0))
        bench.hand(renders, built, .ended)
        for _ in 0..<80 { bench.cycle() }
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
            let layout = MotionLayout([0, 1, 2, 3], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                (0..<4).map { Placement(Rect((Double($0) - at) * 100, 0, 10, 10)) }
            }
            .axis(\.self, input: .scroll(.horizontal, lengthPerUnit: 100), range: 0...3, snaps: .every(1))
            .parameterMotion(.eased(.milliseconds(160)))
            return (hears.wrappedValue
                ? layout.onSettled(gate: gate) { _ in try await Task.sleep(for: .seconds(60)) }
                : layout).node
        }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-100, 0))
        bench.hand(renders, built, .ended)
        for _ in 0..<80 { bench.cycle() }
        _ = await settle()
        XCTAssertTrue(gate.isBusy, "the handler runs")

        hears.wrappedValue = false
        _ = renders.render(built())
        await gate.waitWhileBusy()
        XCTAssertFalse(gate.isBusy, "its run ended with it")

        _ = renders.render(VStack {}.node)
        await gate.endEveryRun()
    }

    /// A REST TOLD AFTER THE FRAME STARTS NO HANDLER THAT WENT MEANWHILE: the layout built without it before the told
    /// rest runs, nothing of it starts.
    func testARestToldAfterItsHandlerWentStartsNothing() async {
        let (phase, hears, renders) = (State(wrappedValue: 0.0), State(true), Renders())
        let gate = Gate(.ignoreWhileRunning)
        var heard = 0
        func built() -> Node {
            let layout = MotionLayout([0, 1, 2, 3], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                (0..<4).map { Placement(Rect((Double($0) - at) * 100, 0, 10, 10)) }
            }
            .axis(\.self, input: .scroll(.horizontal, lengthPerUnit: 100), range: 0...3, snaps: .every(1))
            .parameterMotion(.eased(.milliseconds(160)))
            return (hears.wrappedValue
                ? layout.onSettled(gate: gate) { _ in
                    heard += 1
                    try await Task.sleep(for: .seconds(60))
                }
                : layout).node
        }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-100, 0))
        bench.hand(renders, built, .ended)
        for _ in 0..<80 { bench.cycle() }
        // The rest is told after the frame; the layout is built without the handler before it is.
        hears.wrappedValue = false
        _ = renders.render(built())
        _ = await settle()

        XCTAssertEqual(heard, 0, "the handler went before the rest was told")
        XCTAssertFalse(gate.isBusy)
        _ = renders.render(VStack {}.node)
        await gate.endEveryRun()
    }

    /// EVERY HANDLER OF THE REST RUNS, in the order written.
    func testEveryHandlerOfTheRestRunsInWritingOrder() async {
        let (phase, told, renders) = (State(wrappedValue: 0.0), Told(), Renders())
        func built() -> Node {
            MotionLayout([0, 1, 2, 3], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                (0..<4).map { Placement(Rect((Double($0) - at) * 100, 0, 10, 10)) }
            }
            .axis(\.self, input: .scroll(.horizontal, lengthPerUnit: 100), range: 0...3, snaps: .every(1))
            .parameterMotion(.eased(.milliseconds(160)))
            .onSettled { told.phases.append($0) }
            .onSettled { told.phases.append($0 + 10) }
            .node
        }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-100, 0))
        bench.hand(renders, built, .ended)
        for _ in 0..<80 { bench.cycle() }
        _ = await settle()

        XCTAssertEqual(told.phases, [1, 11])
    }

    /// LAID OUT AT REST, IT TELLS NOTHING.
    func testLaidOutAtRestItTellsNothing() async {
        let (phase, items, told, renders) = (State(wrappedValue: 0.0), State(wrappedValue: [0, 1, 2, 3]), Told(), Renders())
        func built() -> Node { tree(phase, items, told) }
        _ = bench.laid(renders, built)

        for _ in 0..<20 { bench.cycle() }
        _ = await settle()
        XCTAssertEqual(told.phases, [])
    }

    /// A RUN THROWN TELLS ITS REST ONCE, at the target it comes to rest on - not while the hand holds it, nor while it
    /// goes on.
    func testARunThrownTellsItsRestOnce() async {
        let (phase, items, told, renders) = (State(wrappedValue: 0.0), State(wrappedValue: [0, 1, 2, 3]), Told(), Renders())
        func built() -> Node { tree(phase, items, told) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-60, 0))
        bench.hand(renders, built, .ended, velocity: Point(-1_200, 0))
        for _ in 0..<3 { bench.cycle() }
        _ = await settle()
        XCTAssertEqual(told.phases, [], "not while it goes on")

        for _ in 0..<80 { bench.cycle() }
        _ = await settle()
        XCTAssertEqual(told.phases, [2], "once, where it rests")
    }

    /// A CHANGE TELLS THE REST ONCE ITS VIEWS STAND AT THEIR PLACES: the phase still, the views a change moved come
    /// onto their places first.
    func testAChangeTellsTheRestOnceItsViewsStandAtTheirPlaces() async {
        let (phase, items, told, renders) = (State(wrappedValue: 0.0), State(wrappedValue: [0, 1, 2, 3]), Told(), Renders())
        func built() -> Node { tree(phase, items, told) }
        _ = bench.laid(renders, built)

        items.wrappedValue = [1, 2, 3]
        _ = renders.render(built())
        for _ in 0..<3 { bench.cycle() }
        _ = await settle()
        XCTAssertEqual(told.phases, [], "the others closing up")

        for _ in 0..<60 { bench.cycle() }
        _ = await settle()
        XCTAssertEqual(told.phases, [0], "at their places, the phase where it stood")
    }
}
