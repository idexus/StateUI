// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// One view of a layout engine taken by the hand by itself: the view drawn on top under the press, kept to the hand
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
        _ told: Told, _ order: State<[String]>? = nil, dismissing: Bool = false, awaiting: Bool = false,
        motion: Motion = .eased(.milliseconds(160), .linear)
    ) -> Node {
        let names = order?.wrappedValue ?? ["A", "B", "C"]
        let places: [String: Placement] = [
            "A": Placement(Rect(0, 0, 100, 100)),
            "B": Placement(Rect(50, 0, 100, 100), zIndex: 1),
            "C": Placement(Rect(200, 0, 50, 50), transform: .rotate(45)),
        ]
        let engine = LayoutEngine(names) { Text($0) } placements: { _, _ in
            names.enumerated().map { index, name in
                order == nil ? places[name] ?? Placement(.zero) : Placement(Rect(Double(index) * 60, 120, 50, 50))
            }
        }
        .itemDrag(begins: .held)
        .onItemDragged { told.drags.append($0) }
        .motion(motion)
        if awaiting {
            // A dismissal that awaits, past any test's end: another while it runs is ignored.
            return engine.onItemDismissed(.up, beyond: 50, policy: .ignoreWhileRunning) { name in
                told.dismissed.append(name)
                try await Task.sleep(for: .seconds(60))
            }.node
        }
        return (dismissing ? engine.onItemDismissed(.up, beyond: 50) { told.dismissed.append($0) } : engine).node
    }

    /// The run shown now.
    private func shown(_ renders: Renders, _ tree: () -> Node) -> [Placement] {
        bench.shown(renders.renderFromScratch(tree()))
    }

    /// THE PRESS TAKES THE VIEW DRAWN ON TOP UNDER IT, its place turned as it is drawn.
    func testThePressTakesTheViewDrawnOnTopUnderIt() {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told) }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(75, 50))
        XCTAssertEqual(told.drags.last?.item, "B", "B over A")
        bench.item(renders, tree, .ended, at: Point(75, 50))
        for _ in 0..<20 { bench.cycle() }

        // An eighth of a turn stands C's corner ten points above its square: a point there is C's.
        bench.item(renders, tree, .began, at: Point(225, -8))
        XCTAssertEqual(told.drags.last?.item, "C", "turned as it is drawn")
        XCTAssertEqual(told.drags.last?.at, Point(225, -8))
        XCTAssertEqual(told.drags.last?.room, Rect(0, 0, 300, 200))
    }

    /// A HELD VIEW KEEPS TO THE HAND, drawn over every other; the others stand.
    func testAHeldViewKeepsToTheHandOverTheOthers() {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told) }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(75, 50))
        bench.item(renders, tree, .changed, at: Point(105, 90))
        let run = shown(renders, tree)

        XCTAssertEqual(run[1].bounds, Rect(80, 40, 100, 100), "B moved as the hand moved")
        XCTAssertGreaterThan(run[1].zIndex, max(run[0].zIndex, run[2].zIndex), "over every other")
        XCTAssertEqual(run[0].bounds, Rect(0, 0, 100, 100), "A stands")
        XCTAssertEqual(told.drags.map(\.at), [Point(75, 50), Point(105, 90)], "told as it takes it and moves it")
    }

    /// A HELD VIEW STAYS UNDER THE HAND AS THE ORDER CHANGES: its place moves under it, the others travel to theirs.
    func testAHeldViewStaysUnderTheHandAsTheOrderChanges() {
        let told = Told()
        let order = State(wrappedValue: ["A", "B", "C"])
        let renders = Renders()
        func tree() -> Node { cards(told, order) }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(25, 145))
        bench.item(renders, tree, .changed, at: Point(95, 145))
        order.wrappedValue = ["B", "A", "C"]
        _ = renders.render(tree())
        for _ in 0..<3 { bench.cycle() }
        let run = shown(renders, tree)

        XCTAssertEqual(run[1].bounds.x, 70, accuracy: 0.001, "A under the hand, not at its new place")
        XCTAssertGreaterThan(run[0].bounds.x, 0, "B on its way to A's old place")
        XCTAssertLessThan(run[0].bounds.x, 60)
    }

    /// LET GO, THE VIEW COMES BACK TO ITS PLACE under the layout's motion, from where the hand left it.
    func testLetGoTheViewComesBackToItsPlace() {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told) }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(75, 50))
        bench.item(renders, tree, .changed, at: Point(155, 50))
        bench.item(renders, tree, .ended, at: Point(155, 50))
        let first = shown(renders, tree)[1].bounds.x
        for _ in 0..<5 { bench.cycle() }
        let halfway = shown(renders, tree)[1].bounds.x
        for _ in 0..<10 { bench.cycle() }

        XCTAssertEqual(first, 130, accuracy: 0.001, "from where the hand left it")
        XCTAssertEqual(halfway, 90, accuracy: 0.001, "half its way in half the motion")
        XCTAssertEqual(shown(renders, tree)[1].bounds.x, 50, accuracy: 0.001, "at its place")
    }

    /// LET GO FAR ENOUGH, THE VIEW FLIES ON OUT OF THE ROOM, and its item is told once it has left; short of it, it
    /// comes back and nothing is told.
    func testLetGoFarEnoughTheViewFliesOutAndItsItemIsTold() async {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told, dismissing: true) }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(75, 50))
        bench.item(renders, tree, .changed, at: Point(75, 20))
        bench.item(renders, tree, .ended, at: Point(75, 20))
        for _ in 0..<20 { bench.cycle() }
        _ = await settle()
        XCTAssertEqual(told.dismissed, [], "short of the dismissal")
        XCTAssertEqual(shown(renders, tree)[1].bounds.y, 0, accuracy: 0.001, "back at its place")

        bench.item(renders, tree, .began, at: Point(75, 50))
        bench.item(renders, tree, .changed, at: Point(75, -10))
        bench.item(renders, tree, .ended, at: Point(75, -10))
        bench.cycle()
        let flying = shown(renders, tree)[1].bounds.y
        for _ in 0..<40 { bench.cycle() }
        _ = await settle()

        XCTAssertLessThan(flying, -60, "on its way up")
        XCTAssertLessThanOrEqual(shown(renders, tree)[1].bounds.y, -100, "out of the room")
        XCTAssertEqual(told.dismissed, ["B"], "told once")
    }

    /// A DISMISSAL THAT AWAITS GOES THROUGH ITS GATE: while the first runs, a second view dismissed under
    /// `.ignoreWhileRunning` flies out and its item is not told.
    func testADismissalThatAwaitsGoesThroughItsGate() async {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told, awaiting: true) }
        _ = bench.laid(renders, tree)

        for start in [Point(75, 50), Point(25, 50)] {
            bench.item(renders, tree, .began, at: start)
            bench.item(renders, tree, .changed, at: Point(start.x, -10))
            bench.item(renders, tree, .ended, at: Point(start.x, -10))
            for _ in 0..<40 { bench.cycle() }
            _ = await settle()
        }

        XCTAssertEqual(told.dismissed, ["B"], "the second ignored while the first runs")
    }

    /// A HELD VIEW WEARS ITS PLACE'S LOOK WHERE THE HAND HOLDS IT: the arithmetic may lift it - larger, turned -
    /// and it stays under the hand; the application is told as the hand takes it and as it lets it go.
    func testAHeldViewWearsItsPlacesLookWhereTheHandHoldsIt() {
        let told = Told()
        let lift = State(wrappedValue: 1.0)
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine(["A", "B"]) { Text($0) } placements: { _, _ in
                [Placement(Rect(0, 0, 100, 100)), Placement(Rect(50, 0, 100, 100), transform: .scale(lift.wrappedValue))]
            }
            .itemDrag(begins: .held)
            .onItemDragged { told.drags.append($0) }
            .following(lift.projectedValue)
            .node
        }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(125, 50))
        bench.item(renders, tree, .changed, at: Point(155, 90))
        lift.wrappedValue = 1.2
        bench.cycle()
        let held = shown(renders, tree)[1]

        XCTAssertEqual(held.transform, .scale(1.2), "lifted as its place says")
        XCTAssertEqual(held.bounds, Rect(80, 40, 100, 100), "under the hand")
        bench.item(renders, tree, .ended, at: Point(155, 90))
        XCTAssertEqual(told.drags.map(\.phase), [.began, .changed, .ended])
    }

    /// A HAND STANDING STILL IS TOLD HOW LONG it has stood.
    func testAHandStandingStillIsToldHowLong() {
        let told = Told()
        let renders = Renders()
        func tree() -> Node { cards(told) }
        _ = bench.laid(renders, tree)

        bench.item(renders, tree, .began, at: Point(75, 50))
        bench.item(renders, tree, .changed, at: Point(75, 50), still: 500)

        XCTAssertEqual(told.drags.last?.still, .milliseconds(500))
    }

    /// THE LAYOUT SAYS HOW THE HAND TAKES ONE OF ITS VIEWS, and hears that hand; one that says nothing hears none.
    func testTheLayoutSaysHowTheHandTakesOneOfItsViews() {
        let renders = Renders()
        let taking = renders.render(cards(Told())).first(.layoutEngine)
        let plain = Renders().render(LayoutEngine(["A"]) { Text($0) } placements: { _, _ in [Placement(.zero)] }.node)
            .first(.layoutEngine)

        XCTAssertEqual(taking?.props[.itemDrag], ItemDragStart.held.propValue)
        XCTAssertNotNil(taking?.events?[.itemMoved])
        XCTAssertNil(plain?.props[.itemDrag])
        XCTAssertNil(plain?.events?[.itemMoved])
    }
}
