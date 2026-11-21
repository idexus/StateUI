// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A view of an authored identity that is no name, written again where it left: the render says which one it
/// returns as, so a host finds the one it still keeps leaving.
@MainActor
final class ReturningIdentityTests: XCTestCase {
    private static let fades = Transition.symmetric(.opacity)

    /// A holder of a line of each kind of identity, each written where its flag says.
    private static func page(
        number: Bool = false, unique: UUID? = nil, items: [Int] = [], named: Bool = false, plain: Bool = false
    ) -> Node {
        VStack {
            Text("stands")
            if number { Text("number").transition(fades).id(7) }
            if let unique { Text("unique").transition(fades).id(unique) }
            if named { Text("named").transition(fades).id("named") }
            if plain { Text("plain").id(8) }
            ForEach(items) { item in Text("item \(item)").transition(fades) }
        }
        .id("holder").node
    }

    /// Two holders, each with the numbered line where its flag says - the second holder itself where `second`
    /// is not nil.
    private static func holders(first: Bool, second: Bool?) -> Node {
        VStack {
            VStack {
                if first { Text("number").transition(fades).id(7) }
            }
            .id("one")
            if let second {
                VStack {
                    if second { Text("number").transition(fades).id(7) }
                }
                .id("two")
            }
        }
        .id("root").node
    }

    private func patch(_ words: String, in message: HostPatch) throws -> HostPatch {
        try XCTUnwrap(message.subtree.first { $0.properties[.text] == .string(words) }, "no \(words) in the message")
    }

    /// The id the element showing `words` in `message` returns as, as the render says it.
    private func returnsAs(_ words: String, in message: HostPatch, of renders: Renders) throws -> ElementID? {
        renders.returnsAs(try patch(words, in: message).id)
    }

    /// A NUMBER, A UUID AND A LIST'S ITEM WRITTEN AGAIN WHERE THEY LEFT SAY WHICH ONE THEY RETURN AS - the id of
    /// the life that left, under a number of their own - and go on saying the earliest: whichever life a host
    /// still keeps leaving is known by it.
    func testAnIdentityWrittenAgainSaysWhichOneItReturnsAs() throws {
        let renders = Renders()
        let unique = UUID()
        let words = ["number", "unique", "item 2"]
        let first = renders.render(Self.page(number: true, unique: unique, items: [1, 2]))
        let left = try words.map { try patch($0, in: first).id }
        XCTAssertEqual(try words.map { try returnsAs($0, in: first, of: renders) }, [nil, nil, nil], "a first life returns as nobody")
        XCTAssertNil(try returnsAs("item 1", in: first, of: renders))

        renders.render(Self.page(items: [1]))
        let back = renders.render(Self.page(number: true, unique: unique, items: [1, 2]))
        for (words, former) in zip(words, left) {
            XCTAssertEqual(try returnsAs(words, in: back, of: renders), former, "\(words) returns as the one that left")
            XCTAssertNotEqual(try patch(words, in: back).id, former, "under a number of its own")
        }

        renders.render(Self.page(items: [1]))
        let again = renders.render(Self.page(number: true, unique: unique, items: [1, 2]))
        XCTAssertEqual(try words.map { try returnsAs($0, in: again, of: renders) }, left, "known by its earliest life")
        XCTAssertEqual(Set(try words.map { try patch($0, in: again).id }).intersection(left), [], "and a number of its own again")
    }

    /// WHAT RETURNS AS NOBODY: a name, which is the same in every life; a view that declared no transition, which
    /// no host keeps; one written under another holder; and one under a holder that left meanwhile. An element
    /// that left is in the table no more.
    func testWhatReturnsAsNobody() throws {
        let renders = Renders()
        renders.render(Self.page(named: true, plain: true))
        renders.render(Self.page())
        let back = renders.render(Self.page(named: true, plain: true))
        XCTAssertEqual(try patch("named", in: back).id, .manual("named"))
        XCTAssertNil(try returnsAs("named", in: back, of: renders), "its name says it")
        XCTAssertNil(try returnsAs("plain", in: back, of: renders), "nothing keeps a view of no transition")

        let moved = Renders()
        moved.render(Self.holders(first: true, second: false))
        moved.render(Self.holders(first: false, second: false))
        let other = moved.render(Self.holders(first: false, second: true))
        XCTAssertNil(try returnsAs("number", in: other, of: moved), "another holder")

        let remade = Renders()
        remade.render(Self.holders(first: false, second: true))
        remade.render(Self.holders(first: false, second: false))
        remade.render(Self.holders(first: false, second: nil))
        let anew = remade.render(Self.holders(first: false, second: true))
        XCTAssertNil(try returnsAs("number", in: anew, of: remade), "a holder made again keeps nothing of the one before")

        let gone = Renders()
        gone.render(Self.page(number: true))
        gone.render(Self.page())
        let came = try patch("number", in: gone.render(Self.page(number: true))).id
        XCTAssertNotNil(gone.returnsAs(came))
        gone.render(Self.page())
        XCTAssertNil(gone.returnsAs(came), "one that left is in the table no more")
    }

    /// A HOLDER REMEMBERS AS MANY AS A WINDOW KEEPS LEAVING AT ONCE, the oldest forgotten first.
    func testAHolderRemembersAsManyAsAWindowKeeps() throws {
        let renders = Renders()
        let all = Array(0...Transition.keptAtOnce)
        let first = renders.render(Self.page(items: all))
        renders.render(Self.page())
        let back = renders.render(Self.page(items: all))

        XCTAssertNil(try returnsAs("item 0", in: back, of: renders), "the oldest is remembered no more")
        XCTAssertEqual(try returnsAs("item 1", in: back, of: renders), try patch("item 1", in: first).id)
        XCTAssertEqual(
            try all.filter { try returnsAs("item \($0)", in: back, of: renders) != nil }.count, Transition.keptAtOnce)
    }
}
