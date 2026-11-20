// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a layout's arithmetic measures: the room it offers a view, the views it is handed, the host's measure asked
// once a view and a room in a working-out, and the layout's own size.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class LayoutMeasurementTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// What a host's measure was asked, a class so the closure that writes it is not walked for state.
    private final class Asked {
        var rooms: [[Double?]] = []
        var sizes: [LayoutSize] = []
    }

    /// A measure answering ten points a place across and twenty high, noting what it was asked.
    private func measure(noting asked: Asked) -> HostChildMeasure {
        { place, width, height in
            asked.rooms.append([Double(place), width, height])
            return HostChildMeasured(size: LayoutSize(width: Double(place + 1) * 10, height: 20), firstBaseline: 15)
        }
    }

    // MARK: - The room offered

    /// A SIDE LEFT OUT OFFERS NOTHING; one below nought is nought; one that is no number offers nothing and is said.
    func testAProposalHoldsItsSides() {
        XCTAssertEqual(LayoutProposal(), LayoutProposal(width: nil, height: nil))
        XCTAssertEqual(LayoutProposal(width: -4, height: 30).width, 0)
        XCTAssertEqual(LayoutProposal(width: -4, height: 30).height, 30)

        let endless = LayoutProposal(width: .infinity, height: .nan)
        XCTAssertNil(endless.width)
        XCTAssertNil(endless.height)
        XCTAssertTrue(hasComplained("A LayoutProposal was given a side that is no number"))
    }

    // MARK: - The views

    /// THE VIEWS ARE THE ITEMS', IN THEIR ORDER, found by place and by identity; an identity no item has finds none.
    func testTheViewsAreTheItemsInOrder() {
        let views = LayoutSubviews(["ring", "grid", "pile"], measuring: nil)

        XCTAssertEqual(views.map(\.id), ["ring", "grid", "pile"])
        XCTAssertEqual(views.count, 3)
        XCTAssertEqual(views[1].id, "grid")
        XCTAssertEqual(views[id: "pile"]?.id, "pile")
        XCTAssertNil(views[id: "deck"])
        XCTAssertEqual(views.reversed().map(\.id), ["pile", "grid", "ring"], "a collection walked either way")
    }

    /// A VIEW NOTHING MEASURES IS NOUGHT, and rests no words.
    func testAViewNothingMeasuresIsNought() {
        let view = LayoutSubviews([1], measuring: nil)[0]

        XCTAssertEqual(view.sizeThatFits(width: 100), .zero)
        XCTAssertNil(view.firstBaseline())

        let unsaid = LayoutSubviews([1], measuring: LayoutMeasuring())[0]
        XCTAssertEqual(unsaid.sizeThatFits(), .zero, "before a host said its measure")
    }

    // MARK: - The host's measure

    /// THE ARITHMETIC IS HANDED THE VIEWS AND MEASURES THEM THROUGH THE HOST: each view by its place, in the room
    /// offered - both sides of it.
    func testTheArithmeticMeasuresItsViewsThroughTheHost() {
        let asked = Asked()
        let (_, _) = bench.laid(Renders(), {
            MotionLayout(["a", "b"], parameters: State(wrappedValue: 0.0).projectedValue) { Text($0) } placements: { context, _ in
                context.subviews.map { view in
                    let size = view.sizeThatFits(width: 120, height: 40)
                    return Placement(Rect(0, 0, size.width, view.firstBaseline(width: 120, height: 40) ?? 0))
                }
            }
            .node
        })
        bench.program?.measuredBy(measure(noting: asked))
        bench.cycle()

        XCTAssertEqual(bench.placed.map(\.bounds), [Rect(0, 0, 10, 15), Rect(0, 0, 20, 15)])
        XCTAssertEqual(asked.rooms, [[0, 120, 40], [1, 120, 40]], "once a view: the baseline asked nothing more")
    }

    /// A VIEW AND A ROOM ARE ASKED ONCE IN A WORKING-OUT, and again in the next: nothing measured outlives it.
    func testAMeasureIsAskedOnceInAWorkingOut() {
        let measuring = LayoutMeasuring()
        let asked = Asked()
        measuring.measure = measure(noting: asked)
        let view = LayoutSubviews([1], measuring: measuring)[0]

        measuring.begin()
        _ = view.sizeThatFits(width: 50)
        _ = view.sizeThatFits(width: 50)
        _ = view.firstBaseline(width: 50)
        XCTAssertEqual(asked.rooms.count, 1)

        _ = view.sizeThatFits(width: 50, height: 10)
        XCTAssertEqual(asked.rooms.count, 2, "another room is another measure, by either side")

        measuring.begin()
        _ = view.sizeThatFits(width: 50)
        XCTAssertEqual(asked.rooms.count, 3, "asked again in the next working-out")
    }

    /// AN ANSWER THAT IS NO SIZE IS NOUGHT, and said.
    func testAMeasureThatIsNoSizeIsNought() {
        let measuring = LayoutMeasuring()
        measuring.measure = { _, _, _ in HostChildMeasured(size: LayoutSize(width: .nan, height: -5), firstBaseline: 3) }
        measuring.begin()

        XCTAssertEqual(LayoutSubviews([1], measuring: measuring)[0].sizeThatFits(), .zero)
        XCTAssertTrue(hasComplained("A view measured for a layout answered a size that is none"))
    }

    // MARK: - The layout's own size

    /// A LAYOUT SAYS NO SIZE OF ITS OWN UNLESS IT MEASURES: its program answers none, and the layout takes the room
    /// it is given.
    func testALayoutSaysNoSizeUnlessItMeasures() {
        _ = bench.laid(Renders(), {
            MotionLayout([1], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [] }.node
        })

        XCTAssertNil(bench.program?.measure)
    }

    /// `measure` ANSWERS THE LAYOUT'S SIZE from the room offered, the views and the parameters as they stand.
    func testMeasureAnswersTheLayoutsSize() throws {
        let asked = Asked()
        let dial = State(wrappedValue: 2.0)
        _ = bench.laid(Renders(), {
            MotionLayout(["a", "b"], parameters: dial.projectedValue) { Text($0) } placements: { _, _ in [] }
                .measure { context, dial in
                    let widest = context.subviews.map { $0.sizeThatFits().width }.max() ?? 0
                    return LayoutSize(width: context.proposal.width ?? widest, height: dial * 10)
                }
                .node
        })
        let measure = try XCTUnwrap(bench.program?.measure)
        bench.program?.measuredBy(self.measure(noting: asked))

        XCTAssertEqual(measure(nil, nil), LayoutSize(width: 20, height: 20), "the widest view, the parameters' height")
        XCTAssertEqual(measure(90, nil), LayoutSize(width: 90, height: 20), "the width offered")
    }

    /// A SIZE THAT IS NONE IS NOUGHT ALONG THAT SIDE, and said.
    func testAMeasuredSizeThatIsNoneIsNought() throws {
        _ = bench.laid(Renders(), {
            MotionLayout([1], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [] }
                .measure { _, _ in LayoutSize(width: -3, height: .infinity) }
                .node
        })

        XCTAssertEqual(try XCTUnwrap(bench.program?.measure)(nil, nil), LayoutSize(width: 0, height: 0))
        XCTAssertTrue(hasComplained("A MotionLayout's measure answered a size that is none"))
    }
}
