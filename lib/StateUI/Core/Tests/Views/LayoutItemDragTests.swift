// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// One view of a motion layout taken by the hand by itself: the view drawn on top under the press, kept to the hand
/// over the others whatever its place becomes, let go back to its place under the layout's motion, or - past a
/// dismissal - flown on out of the room and its item told.
@MainActor
final class LayoutItemDragTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// What the application was told, a class so the closures that write it are not walked for state.
    private final class Told {
        var drags: [ItemDrag<String>] = []
        var dismissed: [String] = []
    }

    /// Three cards: A, and B over it a little to the right; C apart, turned an eighth of a turn.
    private func cards(
        _ told: Told, _ order: State<[String]>? = nil, dismissing: Bool = false, awaiting: Bool = false
    ) -> Node {
        let names = order?.wrappedValue ?? ["A", "B", "C"]
        let places: [String: Placement] = [
            "A": Placement(Rect(x: 0, y: 0, width: 100, height: 100)),
            "B": Placement(Rect(x: 50, y: 0, width: 100, height: 100), zIndex: 1),
            "C": Placement(Rect(x: 200, y: 0, width: 50, height: 50), transform: .rotate(45)),
        ]
        let layout = MotionLayout(names, parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { _, _ in
            names.enumerated().map { index, name in
                order == nil ? places[name] ?? Placement(.zero) : Placement(Rect(x: Double(index) * 60, y: 120, width: 50, height: 50))
            }
        }
        .onItemDragged { told.drags.append($0) }
        .layoutBodies(.onChange(response: .milliseconds(160)))
        if awaiting {
            // A dismissal that awaits, past any test's end: another while it runs is ignored.
            return layout.onItemDismissed(policy: .ignoreWhileRunning) { name in
                told.dismissed.append(name)
                try await Task.sleep(for: .seconds(60))
            }.node
        }
        return (dismissing ? layout.onItemDismissed { told.dismissed.append($0) } : layout).node
    }

    /// The run shown now.
    private func shown(_ renders: Renders, _ tree: () -> Node) -> [Placement] {
        bench.shown(renders.renderFromScratch(tree()))
    }

    /// A VIEW THROWN AWAY TELLS ITS ITEM, AND THE EVENT ENDS WITH THE LAYOUT'S HANDLERS: the host says which view
    /// has left the room; the layout tells the item it shows, and what the host waits for ends once they have run.
    /// Where the view flies meanwhile is the host's - the layout answers a place for it, as for every view.
    func testAViewThrownAwayTellsItsItemAndEndsWithItsHandlers() async {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told, dismissing: true) }
        _ = bench.laid(renders, tree)
        var ended = false

        XCTAssertTrue(bench.dismissed(renders, tree, child: 1) { ended = true })
        _ = await settle()

        XCTAssertEqual(told.dismissed, ["B"], "the item of the view at that place")
        XCTAssertTrue(ended, "every run the layout started has ended")
        XCTAssertEqual(shown(renders, tree)[1].bounds.y, 0, accuracy: 0.001, "the layout's place for it stands")
    }

    /// EVERY HANDLER OF THE HAND RUNS, in the order written: each drag's, and each dismissal's.
    func testEveryHandlerOfTheHandRunsInWritingOrder() async {
        let told = Told()
        let renders = Renders()
        func tree() -> Node {
            MotionLayout(["A", "B"], parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 100, height: 100)), Placement(Rect(x: 50, y: 0, width: 100, height: 100), zIndex: 1)]
            }
            .onItemDragged { told.drags.append($0) }
            .onItemDragged { told.drags.append($0) }
            .onItemDismissed { told.dismissed.append("first \($0)") }
            .onItemDismissed { told.dismissed.append("second \($0)") }
            .onItemDismissed(policy: .runConcurrently) { told.dismissed.append("third \($0)") }
            .node
        }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(x: 75, y: 50))
        XCTAssertEqual(told.drags.map(\.id), ["B", "B"], "both hear the hand take it")
        bench.item(renders, tree, .changed, at: Point(x: 75, y: -10))
        bench.item(renders, tree, .ended, at: Point(x: 75, y: -10))
        bench.dismissed(renders, tree, child: 1)
        _ = await settle()

        XCTAssertEqual(told.dismissed, ["first B", "second B", "third B"])
    }

    /// A DRAG THAT AWAITS GOES THROUGH ITS GATE: under `.ignoreWhileRunning` the moves while its first run awaits are
    /// heard by nobody, while a step written beside it hears every one.
    func testADragThatAwaitsGoesThroughItsGate() async {
        let told = Told()
        let renders = Renders()
        var awaited: [GesturePhase] = []
        func tree() -> Node {
            MotionLayout(["A", "B"], parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 100, height: 100)), Placement(Rect(x: 50, y: 0, width: 100, height: 100), zIndex: 1)]
            }
            .onItemDragged { told.drags.append($0) }
            .onItemDragged(policy: .ignoreWhileRunning) { drag in
                awaited.append(drag.phase)
                try await Task.sleep(for: .seconds(60))
            }
            .node
        }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(x: 75, y: 50))
        bench.item(renders, tree, .changed, at: Point(x: 80, y: 50))
        bench.item(renders, tree, .changed, at: Point(x: 85, y: 50))
        _ = await settle()

        XCTAssertEqual(told.drags.map(\.phase), [.began, .changed, .changed], "the step hears every move")
        XCTAssertEqual(awaited, [.began], "the moves while it awaits are ignored")
    }

    /// EACH DISMISSAL GOES THROUGH A GATE OF ITS OWN: one held under `.ignoreWhileRunning` keeps no other from running.
    func testEachDismissalHasAGateOfItsOwn() async {
        var heard: [Int] = []
        let renders = Renders()
        func tree() -> Node {
            MotionLayout(["A", "B"], parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 100, height: 100)), Placement(Rect(x: 50, y: 0, width: 100, height: 100), zIndex: 1)]
            }
            .onItemDismissed(policy: .ignoreWhileRunning) { _ in
                heard.append(1)
                try await Task.sleep(for: .seconds(60))
            }
            .onItemDismissed(policy: .ignoreWhileRunning) { _ in heard.append(2) }
            .node
        }
        _ = bench.laid(renders, tree)

        bench.dismissed(renders, tree, child: 1)
        _ = await settle()

        XCTAssertEqual(heard, [1, 2])
        _ = renders.render(VStack {}.node)
        _ = await settle()
    }

    /// A DISMISSAL NO LONGER WRITTEN ENDS ITS RUN as the layout is built without it, as an element's handler does.
    func testADismissalNoLongerWrittenEndsItsRun() async {
        let renders = Renders()
        let hears = State(true)
        let gate = Gate(.ignoreWhileRunning)
        func tree() -> Node {
            let layout = MotionLayout(["A", "B"], parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 100, height: 100)), Placement(Rect(x: 50, y: 0, width: 100, height: 100), zIndex: 1)]
            }
            return (hears.wrappedValue
                ? layout.onItemDismissed(gate: gate) { _ in try await Task.sleep(for: .seconds(60)) }
                : layout).node
        }
        _ = bench.laid(renders, tree)

        bench.dismissed(renders, tree, child: 1)
        _ = await settle()
        XCTAssertTrue(gate.isBusy, "the handler runs")

        hears.wrappedValue = false
        _ = renders.render(tree())
        await gate.waitWhileBusy()
        XCTAssertFalse(gate.isBusy, "its run ended with it")

        _ = renders.render(VStack {}.node)
        await gate.endEveryRun()
    }

    /// A DISMISSAL THAT AWAITS GOES THROUGH ITS GATE: while the first runs, a second view dismissed under
    /// `.ignoreWhileRunning` is not told - and its event ends at once, the first's still under way.
    func testADismissalThatAwaitsGoesThroughItsGate() async {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told, awaiting: true) }
        _ = bench.laid(renders, tree)
        var ended: [Int] = []

        bench.dismissed(renders, tree, child: 1) { ended.append(1) }
        _ = await settle()
        bench.dismissed(renders, tree, child: 0) { ended.append(0) }
        _ = await settle()

        XCTAssertEqual(told.dismissed, ["B"], "the second ignored while the first runs")
        XCTAssertEqual(ended, [0], "let go by the gate, it ends at once; the first still runs")
        _ = renders.render(VStack {}.node)
        _ = await settle()
    }

    /// A HAND STANDING STILL IS TOLD HOW LONG it has stood.
    func testAHandStandingStillIsToldHowLong() {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told) }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(x: 75, y: 50))
        bench.item(renders, tree, .changed, at: Point(x: 75, y: 50), still: 500)

        XCTAssertEqual(told.drags.last?.still, .milliseconds(500))
    }

    /// A HELD VIEW IS TOLD WHAT IT IS OVER AND HOW FAST THE HAND GOES: the item whose view is drawn on top under the
    /// hand, the held one passed over, nil over none; the hand's speed as the host layer tells it.
    func testAHeldViewIsToldWhatItIsOverAndHowFastTheHandGoes() {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told) }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(x: 25, y: 50))
        bench.item(renders, tree, .changed, at: Point(x: 125, y: 50), velocity: Point(x: 300, y: 0))
        bench.item(renders, tree, .changed, at: Point(x: 225, y: 25), velocity: Point(x: 200, y: -50))
        bench.item(renders, tree, .changed, at: Point(x: 400, y: 300))
        bench.item(renders, tree, .ended, at: Point(x: 400, y: 300), velocity: Point(x: -500, y: 0))

        XCTAssertEqual(told.drags.map(\.id), ["A", "A", "A", "A", "A"])
        XCTAssertEqual(told.drags.map(\.over), [nil, "B", "C", nil, nil], "B over A's place, C turned, then none")
        XCTAssertEqual(told.drags.map(\.velocity), [
            Point(x: 0, y: 0), Point(x: 300, y: 0), Point(x: 200, y: -50), Point(x: 0, y: 0), Point(x: -500, y: 0),
        ])
    }

    /// A VIEW MAKING ROOM IS NOT OVER THE HAND AGAIN: the hand is over the item whose place stands under it, so the
    /// view that gave the held one its place, still traveling off from under the hand, answers no second time.
    func testAViewMakingRoomIsNotOverTheHandAgain() {
        let told = Told()
        let order = State(wrappedValue: ["A", "B", "C"])
        let renders = Renders()
        func tree() -> Node {
            let names = order.wrappedValue
            return MotionLayout(names, parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { _, _ in
                names.indices.map { Placement(Rect(x: Double($0) * 60, y: 0, width: 50, height: 50)) }
            }
            .onItemDragged { drag in
                told.drags.append(drag)
                guard let over = drag.over, let from = order.wrappedValue.firstIndex(of: drag.id),
                      let to = order.wrappedValue.firstIndex(of: over) else { return }
                order.wrappedValue.remove(at: from)
                order.wrappedValue.insert(drag.id, at: to)
            }
            .layoutBodies(.onChange(response: .milliseconds(400)))
            .node
        }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(x: 25, y: 25))
        bench.item(renders, tree, .changed, at: Point(x: 85, y: 25))
        XCTAssertEqual(order.wrappedValue, ["B", "A", "C"], "over B, A takes its place")
        bench.item(renders, tree, .changed, at: Point(x: 86, y: 25))
        XCTAssertEqual(told.drags.last?.over, nil, "B goes to A's old place: under the hand stands A's own")
        XCTAssertEqual(order.wrappedValue, ["B", "A", "C"])
    }

    /// THE LAYOUT HEARS A VIEW'S DRAG WHERE SOMETHING ASKS TO BE TOLD OF IT, AND A VIEW THROWN AWAY WHERE SOMETHING
    /// ASKS FOR THAT: one that asks nothing hears neither - the view is still its host's to hold and to throw.
    func testTheLayoutHearsItsViewsDragWhereSomethingAsks() {
        let asking = Renders().render(cards(Told())).first(.motionLayout)
        let dismissing = Renders().render(
            MotionLayout(["A"], parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { _, _ in [Placement(.zero)] }
                .onItemDismissed { _ in }
                .node)
            .first(.motionLayout)
        let plain = Renders().render(MotionLayout(["A"], parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { _, _ in [Placement(.zero)] }.node)
            .first(.motionLayout)

        XCTAssertNotNil(asking?.events?[.itemDragUpdated])
        XCTAssertNil(asking?.events?[.itemDismissed])
        XCTAssertNotNil(dismissing?.events?[.itemDismissed])
        XCTAssertNil(dismissing?.events?[.itemDragUpdated], "a dismissal alone asks for no drag")
        XCTAssertNil(plain?.events?[.itemDragUpdated])
        XCTAssertNil(plain?.events?[.itemDismissed])
    }
}
