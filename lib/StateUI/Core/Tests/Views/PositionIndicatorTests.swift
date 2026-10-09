// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The row of dots is made of colour boxes every host already draws, so there
// is nothing in a host to check it against and everything worth pinning is
// here.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class PositionIndicatorTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// Every node of `type` in a patch, in order, however deep.
    private func nodes(_ type: NodeType, in patch: HostPatch) -> [HostPatch] {
        (patch.type == type ? [patch] : []) + patch.children.flatMap { nodes(type, in: $0) }
    }

    /// The dots a view describes.
    private func dots(_ view: some View) -> [HostPatch] {
        nodes(.colorBox, in: Renders().render(VStack { view }.node))
    }

    /// As many dots as the count, each the size it is given, the current one in its own colour.
    func testTheCountIsTheDotsTheCurrentOneMarked() {
        let row = dots(PositionIndicator().count(5).position(2).indicatorColor(.gray).currentIndicatorColor(.red)
            .indicatorSize(10))

        XCTAssertEqual(row.count, 5)
        XCTAssertEqual(row.map { $0.properties[.color] }, [Color.gray, .gray, .red, .gray, .gray].map { $0.propValue })
        XCTAssertEqual(row.map { $0.properties[.width] }, Array(repeating: .number(10), count: 5))
        XCTAssertEqual(row.map { $0.properties[.height] }, Array(repeating: .number(10), count: 5))
    }

    /// No more dots show than the cap lets, a run holding the position as near its middle as the ends allow.
    func testNoMoreDotsShowThanTheCapTheCurrentAmongThem() {
        let shown = { (position: Int) in
            PositionIndicator.shown(count: 12, position: position, maximumVisible: 5, hidesSingle: true)
        }
        XCTAssertEqual(shown(0), 0..<5)
        XCTAssertEqual(shown(6), 4..<9)
        XCTAssertEqual(shown(11), 7..<12)
        XCTAssertEqual(PositionIndicator.shown(count: 3, position: 1, maximumVisible: 5, hidesSingle: true), 0..<3)
        XCTAssertEqual(PositionIndicator.shown(count: 4, position: 0, maximumVisible: 0, hidesSingle: true), 0..<1)

        let row = dots(PositionIndicator().count(12).position(6).maximumVisible(5).currentIndicatorColor(.red))
        XCTAssertEqual(row.count, 5)
        XCTAssertEqual(row.firstIndex { $0.properties[.color] == Color.red.propValue }, 2)
    }

    /// One lonely dot is hidden unless the row asks for it; no items, no dots.
    func testALoneDotIsHiddenUnlessAskedFor() {
        XCTAssertEqual(dots(PositionIndicator().count(1)).count, 0)
        XCTAssertEqual(dots(PositionIndicator().count(1).hidesForSinglePage(false)).count, 1)
        XCTAssertEqual(dots(PositionIndicator()).count, 0)
    }

    /// A dot is round, a square has square corners.
    func testADotIsRoundASquareIsNot() {
        let round = dots(PositionIndicator().count(2).indicatorSize(8)).first?.properties[.cornerRadius]
        let square = dots(PositionIndicator().count(2).indicatorSize(8).indicatorShape(.square)).first?
            .properties[.cornerRadius]

        XCTAssertNotEqual(round, square)
        XCTAssertEqual(square, dots(ColorBox().cornerRadius(0)).first?.properties[.cornerRadius])
        XCTAssertEqual(round, dots(ColorBox().cornerRadius(4)).first?.properties[.cornerRadius])
    }

    /// Items are their own marks: one each, the current one whole and the others faded.
    func testItemsAreTheirOwnMarks() {
        let patch = Renders().render(VStack {
            PositionIndicator(["one", "two", "three"]) { name in Text(name) }.position(1)
        }.node)
        let marks = nodes(.text, in: patch)

        XCTAssertEqual(marks.map { $0.properties[.text] }, ["one", "two", "three"].map { .string($0) })
        XCTAssertEqual(marks.map { $0.properties[.opacity] }, [.number(0.4), .number(1), .number(0.4)])
    }

    /// A count given from a state builds the row again as the state changes.
    func testACountFromAStateBuildsTheRowAgain() {
        let count = State(wrappedValue: 2)
        let renders = Renders()
        let tree = { VStack { PositionIndicator().count(count.projectedValue) }.node }
        XCTAssertEqual(nodes(.colorBox, in: renders.render(tree())).count, 2)

        count.wrappedValue = 4
        XCTAssertEqual(nodes(.colorBox, in: renders.renderFromScratch(tree())).count, 4)
    }
}
