// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A RUN OF PLACEMENTS: where every view of a layout goes, as the layout's program hands it to the host - what the
// tree says of a motion layout, and how a run ranks its views.
//
// The types are in Types/Layout, PlacedRun.swift and Placement.swift; the program is
// Core/Boundary/HostLayoutProgram.swift.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class PlacedRunTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    // MARK: - The tree

    /// A MOTION LAYOUT DESCRIBES NO PLACEMENT AT ALL: it runs a layout program
    /// the host reads the run from, no state carries a place, and not one of
    /// the twelve properties is on any child - every view wrapped.
    func testAMotionLayoutDescribesNothingAboutWhereItsViewsGo() {
        let renders = Renders()

        let patch = renders.render(
            MotionLayout([1, 2], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [] }
                .id("run")
                .node)

        guard let placed = Self.layout(patch) else { return XCTFail("no layout was described") }

        XCTAssertNotNil(placed.program, "the layout runs a program")
        XCTAssertNil(placed.driven?[.area], "no state carries the run")
        XCTAssertNil(placed.driven?[.frame], "nor the room")
        XCTAssertEqual(placed.children.count, 2, "two views")

        for wrapper in placed.children.prefix(2) {
            XCTAssertEqual(wrapper.type, .grid, "every face is wrapped, shaded or not")

            for named in [Prop.area, .opacity, .zIndex, .rotation, .scale] {
                XCTAssertNil(wrapper.props[named], "\(named.name) is the number's to say")
            }
        }
    }

    /// A SHADED RUN WRAPS TWO, and the shade is the second - which is the
    /// whole of how the host finds one, both children being the library's.
    func testAShadedLayoutPutsTheShadeSecond() {
        let renders = Renders()

        let patch = renders.render(
            MotionLayout([1], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [] }
                .shade {
                    Rectangle()
                        .fill(.black)
                }
                .id("run")
                .node)

        guard let wrapper = Self.layout(patch)?.children.first else {
            return XCTFail("no wrapper was described")
        }

        XCTAssertEqual(wrapper.children.count, 2)
        XCTAssertEqual(wrapper.children[1].type, .rectangle)
        XCTAssertNil(wrapper.children[1].props[.opacity], "the shade's own fade is the number's")
    }

    /// The motion layout's element in a message.
    private static func layout(_ patch: HostPatch) -> HostPatch? {
        if patch.type == .motionLayout { return patch }

        for child in patch.children {
            if let found = layout(child) { return found }
        }

        return nil
    }

    /// A ROOM IS A FEED: the host writes it, this side reads it, and no mode
    /// is offered because a view's frame is the layout's answer.
    func testAFrameIsRegisteredAsAFeedTheHostWrites() {
        let room = State(wrappedValue: Rect(0, 0, 0, 0))
        let renders = Renders()

        let patch = renders.render(Rectangle().frame(into: room.projectedValue).id("box").node)

        XCTAssertEqual(
            patch.driven?[.frame],
            HostStateBinding(state: room.number, mode: .in, kind: .feed, laneKind: .number))
    }

    /// A DRAWING ORDER IS WRITTEN AS AN ORDER, never as the number the
    /// arithmetic answered: a run ranks its placements as it is built, so a z
    /// worked out from a value the user is MOVING - which answers something
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
