// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A RUN OF PLACEMENTS ON DRIVEN STATE: where every view of a layout goes, as numbers
// the host wears on its own frames.
//
// The whole of what crosses is one registration and, from then on, lanes -
// twelve a view and three for the law. So what has to hold is that the twelve
// are the twelve the host reads by stride, that the law is at the END where a
// view's own numbers are always at `12 × index`, and that a layout placed this
// way describes not one property of a placement.
//
// The type is Types/Placement.swift; the host's half is MotionPlacement in
// StateUI.Runtime's MotionTargets.cs.

import XCTest
@testable import StateUI

final class PlacedRunTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    // MARK: - The lanes

    /// The twelve a placement carries are the twelve the host reads by stride,
    /// in that order - so the two spellings of one fact cannot drift while
    /// both exist.
    func testAPlacementCarriesTheSameTwelveThePackerWrites() {
        let placement = Placement(
            Rect(11, 22, 120, 170),
            transform: .translate(3, 4).scaleX(0.5),
            opacity: 0.75,
            shade: 0.25,
            zIndex: 3)

        let packed = UnsafeMutablePointer<Double>.allocate(capacity: PackedPlacement.fields)
        defer { packed.deallocate() }

        PackedPlacement.write(placement, into: packed, at: 0)

        guard case .lanes(let lanes) = placement.carried else {
            return XCTFail("a placement carries lanes")
        }

        XCTAssertEqual(lanes.count, PackedPlacement.fields)

        for lane in 0..<PackedPlacement.fields {
            XCTAssertEqual(lanes[lane], packed[lane], "lane \(lane)")
        }
    }

    /// And back: the picture those numbers draw is the picture that made them.
    ///
    /// A turn survives it, because the five numbers a view wears are enough to
    /// say one; a chain that never turned comes back to the bit.
    func testAPlacementComesBackFromItsLanes() throws {
        let flat = Placement(
            Rect(11, 22, 120, 170),
            transform: .translate(3, 4).scale(0.8),
            opacity: 0.75,
            shade: 0.25,
            zIndex: 3)

        let back = try XCTUnwrap(Placement(carried: flat.carried))

        XCTAssertEqual(back.bounds, flat.bounds)
        XCTAssertEqual(back.opacity, flat.opacity)
        XCTAssertEqual(back.shade, flat.shade)
        XCTAssertEqual(back.zIndex, flat.zIndex)
        // A sizing written after a move sizes the move too, so these are the
        // numbers the chain actually drew - and they come back exactly.
        XCTAssertEqual(back.transform.x, flat.transform.x)
        XCTAssertEqual(back.transform.y, flat.transform.y)
        XCTAssertEqual(back.transform.width, 0.8, "a sizing comes back to the bit")
        XCTAssertEqual(back.transform.height, 0.8)

        let turned = Placement(Rect(0, 0, 10, 10), transform: .rotate(30).scale(2))
        let again = try XCTUnwrap(Placement(carried: turned.carried))

        XCTAssertEqual(again.transform.rotation, 30, accuracy: 1e-9)
        XCTAssertEqual(again.transform.width, 2, accuracy: 1e-9)
        XCTAssertEqual(again.transform.height, 2, accuracy: 1e-9)
    }

    /// THE LAW IS LAST, which is what lets the host read one view's place by
    /// stride and know which view a dirty lane belongs to.
    func testARunCarriesItsViewsFirstAndItsLawLast() {
        let run = PlacedRun(
            [Placement(Rect(0, 0, 10, 10)), Placement(Rect(20, 0, 10, 10))],
            motion: .eased(400, .cubicIn))

        guard case .lanes(let lanes) = run.carried else {
            return XCTFail("a run carries lanes")
        }

        XCTAssertEqual(lanes.count, 2 * Placement.lanes + 3)
        XCTAssertEqual(lanes[Placement.lanes], 20, "the second view's numbers start at its stride")

        // 2 is a stated length on a stated curve; see StateLaw.
        XCTAssertEqual(Array(lanes.suffix(3)), [2, 400, Double(Easing.cubicIn.rawValue)])
    }

    /// And back, however many views it holds - including none at all, which is
    /// what a number that has never been written stands at.
    func testARunComesBackFromItsLanes() throws {
        let run = PlacedRun(
            [Placement(Rect(1, 2, 3, 4)), Placement(Rect(5, 6, 7, 8), opacity: 0.5)],
            motion: .spring(response: 300, damping: 0.7))

        let back = try XCTUnwrap(PlacedRun(carried: run.carried))

        XCTAssertEqual(back.placements.count, 2)
        XCTAssertEqual(back.placements[0].bounds, Rect(1, 2, 3, 4))
        XCTAssertEqual(back.placements[1].opacity, 0.5)
        XCTAssertEqual(back.motion, .spring(response: 300, damping: 0.7))

        XCTAssertEqual(PlacedRun(carried: .lanes([]))?.placements.count, 0)
        XCTAssertNil(PlacedRun(carried: .lanes([1, 2, 3, 4, 5])), "a width that is nobody's")
    }

    /// A RUN IS AS WIDE AS WHAT THE STATE HOLDS, so the type says nothing about
    /// how many lanes it takes and everything reads the bytes instead.
    func testARunOnAStateIsReadAtWhateverWidthItWasWritten() {
        let number = State(wrappedValue: PlacedRun(), asks: .never)

        XCTAssertEqual(PlacedRun.lanes, StateValueLanes.own)
        XCTAssertEqual(number.wrappedValue.placements.count, 0)

        number.wrappedValue = PlacedRun((0..<7).map { Placement(Rect(Double($0), 0, 10, 10)) })

        XCTAssertEqual(number.wrappedValue.placements.count, 7)
        XCTAssertEqual(number.wrappedValue.placements[6].bounds.x, 6)

        number.wrappedValue = PlacedRun([Placement(Rect(99, 0, 10, 10))])

        XCTAssertEqual(number.wrappedValue.placements.count, 1, "a run that shrank is read short")
        XCTAssertEqual(number.wrappedValue.placements[0].bounds.x, 99)
    }

    /// A DIRTY WORD RUNS OUT AT LANE 63, and everything past it shares the
    /// highest bit - so a run says exactly which of its first views moved and
    /// tells the rest together.
    func testARunSaysWhichViewMovedUntilTheBitsRunOut() {
        func run() -> PlacedRun {
            PlacedRun((0..<7).map { Placement(Rect(Double($0), 0, 10, 10)) })
        }

        func dirty(_ change: (inout PlacedRun) -> Void) -> UInt64 {
            let storage = HostStorage(StateImage.bytes(of: run().carried))
            var moved = run()

            change(&moved)

            return HostStorage.lay(StateImage.bytes(of: moved.carried), into: &storage.image)
        }

        // The second view's rectangle starts at lane 12, which has a bit.
        XCTAssertEqual(dirty { $0.placements[1].bounds.x = 500 }, 1 << 12)

        // The sixth's starts at lane 60, and still does.
        XCTAssertEqual(dirty { $0.placements[5].bounds.x = 500 }, 1 << 60)

        // The seventh's starts at lane 72, which is past the end of the word.
        XCTAssertEqual(dirty { $0.placements[6].bounds.x = 500 }, 1 << 63)
    }

    // MARK: - The tree

    /// A LAYOUT PLACED BY DRIVEN STATE DESCRIBES NO PLACEMENT AT ALL: the registration
    /// says which number, and not one of the twelve properties is on any child.
    func testADrivenPlacedLayoutDescribesNothingAboutWhereItsViewsGo() {
        let run = State(wrappedValue: PlacedRun(), asks: .never)
        let renders = Renders()

        let patch = renders.render(
            PlacedLayout([1, 2], id: \.self) { Label("\($0)") }
                .placement(run.projectedValue)
                .id("run")
                .body)

        func layout(_ patch: Patch) -> Patch? {
            if patch.type == .absoluteLayout { return patch }

            for child in patch.children {
                if let found = layout(child) { return found }
            }

            return nil
        }

        guard let placed = layout(patch) else { return XCTFail("no layout was described") }

        XCTAssertEqual(
            placed.driven?[.absoluteLayoutBounds],
            StateEntry(number: run.number, mode: .out, kind: .placement))

        XCTAssertEqual(placed.children.count, 2)

        for wrapper in placed.children {
            XCTAssertEqual(wrapper.type, .grid, "every face is wrapped, shaded or not")

            for named in [Prop.absoluteLayoutBounds, .opacity, .zIndex, .rotation, .scale] {
                XCTAssertNil(wrapper.props[named], "\(named.name) is the number's to say")
            }
        }
    }

    /// A SHADED RUN WRAPS TWO, and the shade is the second - which is the
    /// whole of how the host finds one, both children being the library's.
    func testAShadedDrivenLayoutPutsTheShadeSecond() {
        let run = State(wrappedValue: PlacedRun(), asks: .never)
        let renders = Renders()

        let patch = renders.render(
            PlacedLayout([1], id: \.self) { Label("\($0)") }
                .shade(BoxView(.black))
                .placement(run.projectedValue)
                .id("run")
                .body)

        func layout(_ patch: Patch) -> Patch? {
            if patch.type == .absoluteLayout { return patch }

            for child in patch.children {
                if let found = layout(child) { return found }
            }

            return nil
        }

        guard let wrapper = layout(patch)?.children.first else {
            return XCTFail("no wrapper was described")
        }

        XCTAssertEqual(wrapper.children.count, 2)
        XCTAssertEqual(wrapper.children[1].type, .boxView)
        XCTAssertNil(wrapper.children[1].props[.opacity], "the shade's own fade is the number's")
    }

    /// A ROOM IS A FEED: the host writes it, this side reads it, and no mode
    /// is offered because a view's frame is the layout's answer.
    func testAFrameIsRegisteredAsAFeedTheHostWrites() {
        let room = State(wrappedValue: Rect(0, 0, 0, 0), asks: .never)
        let renders = Renders()

        let patch = renders.render(BoxView().frame(room.projectedValue).id("box").body)

        XCTAssertEqual(
            patch.driven?[.frame],
            StateEntry(number: room.number, mode: .in, kind: .feed))
    }

    /// A DRAWING ORDER IS WRITTEN AS AN ORDER, never as the number the
    /// arithmetic answered: a run ranks its placements as it is built, so a z
    /// worked out from a value the reader is MOVING - which answers something
    /// new on every frame, while the order it expresses changes only when two
    /// views actually swap - is carried as the same run until the picture
    /// really changes. Measured on a fifteen-card run as 720 writes becoming
    /// 305, for the same picture.
    func testARunCarriesTheRankRatherThanTheNumber() {
        func run(_ at: Double) -> [Int] {
            PlacedRun((0..<3).map { index in
                Placement(
                    Rect(0, 0, 40, 40),
                    zIndex: 1000 - Int(abs(Double(index) - at) * 100))
            })
            .placements.map(\.zIndex)
        }

        XCTAssertEqual(run(0), [2, 1, 0], """
            the nearest view is drawn last, and what is carried is that \
            position rather than the thousand the arithmetic said
            """)

        XCTAssertEqual(
            run(0), run(0.2),
            "a value that moved without changing the order says the same run")

        XCTAssertNotEqual(
            run(0), run(1.2),
            "and one that swapped two views says a different one")
    }
}
