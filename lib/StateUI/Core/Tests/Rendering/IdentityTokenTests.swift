// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

private struct DescribedElementID: Hashable, CustomStringConvertible {
    let value: Int
    let words: String
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.value == rhs.value }
    func hash(into hasher: inout Hasher) { hasher.combine(value) }
    var description: String { words }
}

private struct TokenCounter: View {
    @State private var count = 0
    var body: some View { Button("\(count)").onClicked { count += 1 } }
}

@MainActor
final class IdentityTokenTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    func testEqualLiveSetIdentitiesProduceTheSameInitialChildToken() throws {
        let values = (0..<64).map { _ in Set(0..<16) }
        XCTAssertEqual(Set(values).count, 1)
        let tokens = try values.map { value in
            try XCTUnwrap(Renders().render(VStack { Text("One").id(value) }.node).children.first?.id)
        }
        XCTAssertEqual(Set(tokens).count, 1)
    }

    func testEqualNumericIdentitiesProduceTheSameInitialToken() throws {
        let values = [AnyHashable(Int(1)), AnyHashable(UInt(1)), AnyHashable(Double(1)), AnyHashable(Float(1))]
        XCTAssertEqual(Set(values).count, 1)
        let tokens = try values.map { value in
            try XCTUnwrap(Renders().render(VStack { Text("One").id(value) }.node).children.first?.id)
        }
        XCTAssertEqual(Set(tokens).count, 1)
    }

    func testAnInternalRootMatchesTheIdentityValueRatherThanItsDescription() {
        let renders = Renders()
        let first = renders.render(Text("One").id(DescribedElementID(value: 1, words: "first")).node)
        let same = renders.render(Text("One").id(DescribedElementID(value: 1, words: "second")).node)
        let other = renders.render(Text("One").id(DescribedElementID(value: 2, words: "second")).node)
        XCTAssertEqual(same.id, first.id)
        XCTAssertNotEqual(other.id, same.id)
    }

    func testAddingOrRemovingAnAuthoredIdentityStartsANewElement() throws {
        for startsIdentified in [false, true] {
            let renders = Renders()
            func tree(identified: Bool) -> Node {
                var child = TokenCounter().node
                if identified { child.identify(Set([1, 2])) }
                return stack([child], id: "root")
            }
            let first = try XCTUnwrap(renders.render(tree(identified: startsIdentified)).children.first)
            renders.fire(try XCTUnwrap(first.events?[.clicked]))
            let written = renders.revisit(changed: Renderer.shared.pendingChanges)
            XCTAssertEqual(written.child(first.id)?.props[.text], .string("1"))

            let changed = try XCTUnwrap(renders.render(tree(identified: !startsIdentified)).children.first)
            XCTAssertNotEqual(changed.id, first.id)
            XCTAssertEqual(changed.props[.text], .string("0"))
        }
    }

    func testAllocatedTokensFollowValuesThroughReorderResyncAndReinsertion() {
        let renders = Renders()
        func tree(_ values: [Int], words: String = "same") -> Node {
            VStack {
                ForEach(values.map { DescribedElementID(value: $0, words: words) }) { _ in Text("One") }
            }.node
        }
        let first = renders.render(tree([1, 2])).children.map(\.id)
        XCTAssertEqual(Set(first).count, 2)
        XCTAssertEqual(renders.render(tree([2, 1], words: "changed")).arrangement, Array(first.reversed()))
        XCTAssertEqual(renders.renderFromScratch(tree([2, 1])).children.map(\.id), Array(first.reversed()))
        _ = renders.render(tree([2]))
        let returned = renders.render(tree([1, 2])).children.map(\.id)
        XCTAssertNotEqual(returned[0], first[0])
        XCTAssertEqual(returned[1], first[1])
    }

    func testAuthoredStringNamesRemainDistinctFromAllocatedTokens() {
        let patch = Renders().render(VStack {
            Text("Named").id("1")
            Text("Allocated").id(1)
        }.node)
        XCTAssertEqual(patch.children[0].id, .manual("1"))
        XCTAssertNotEqual(patch.children[0].id, patch.children[1].id)
    }
}
