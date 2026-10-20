// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// An identity a class instance gives: its description is its type's name, whatever instance it is.
private final class Ticket: Hashable {
    let number: Int

    init(_ number: Int) { self.number = number }

    static func == (one: Ticket, other: Ticket) -> Bool { one.number == other.number }

    func hash(into hasher: inout Hasher) { hasher.combine(number) }
}

/// A menu entry's identity a class instance gives: its description is its type's name, whatever instance it is.
private final class MenuChoice: Hashable {
    let number: Int

    init(_ number: Int) { self.number = number }

    static func == (one: MenuChoice, other: MenuChoice) -> Bool { one.number == other.number }

    func hash(into hasher: inout Hasher) { hasher.combine(number) }
}

/// Who a view is: the value an identity was written from, compared as that value, and its name in the patch.
@MainActor
final class IdentityTests: XCTestCase {
    /// Two siblings written with one identity are told apart by a variant - and that is said: the second never keeps
    /// the first's state.
    func testTwoSiblingsWithOneIdentityAreSaid() {
        let renders = Renders()

        renders.render(VStack {
            ForEach([7, 7], id: \.self) { number in Text("\(number)") }
        }.node)

        XCTAssertTrue(hasComplained("share the identity \"7\""))
    }

    /// Two different identities that describe themselves alike - a class prints its type's name - are two elements,
    /// each following its own value through a new order, and nothing is said: an identity is matched as its value.
    func testTwoIdentitiesDescribedAlikeAreTwoElements() {
        let renders = Renders()
        func list(_ tickets: [Ticket]) -> Node {
            VStack { ForEach(tickets, id: \.self) { ticket in Text("\(ticket.number)") } }.node
        }
        let (one, two) = (Ticket(1), Ticket(2))

        let first = renders.render(list([one, two])).children.map(\.id)
        let second = renders.render(list([two, one])).arrangement

        XCTAssertNotEqual(first[0], first[1], "two elements")
        XCTAssertEqual(second, [first[1], first[0]], "each followed its own ticket")
        XCTAssertFalse(hasComplained("Ticket"), "nothing to say")
    }

    /// A marker written with an id stays itself when another is put before it: matched by its id, not by its place
    /// among the map's markers.
    func testAMarkerKeepsItsElementByItsId() {
        let renders = Renders()
        func map(_ names: [String]) -> Node {
            Map().markers { names.map { Marker($0).id($0) } }.node
        }

        let first = renders.render(map(["A", "B"])).children.map(\.id)
        let second = renders.render(map(["C", "A", "B"])).children.map(\.id)

        XCTAssertEqual(Array(second.dropFirst()), first, "A and B kept their elements")
        XCTAssertFalse(first.contains(second[0]), "C is a new one")
    }

    /// A menu entry's id is told by its value, as every other identity is: two that describe themselves alike are
    /// two entries, and nothing is said.
    func testAMenuEntrysIdIsItsValue() {
        let renders = Renders()

        let entries = renders.render(Text("Row").contextMenu {
            MenuItem("One").id(MenuChoice(1))
            MenuItem("Two").id(MenuChoice(2))
        }.node).subtree.filter { $0.type == .menuItem }.map(\.id)

        XCTAssertEqual(Set(entries).count, 2, "two entries")
        XCTAssertFalse(hasComplained("MenuChoice"), "nothing to say")
    }

    /// Distinct identities that describe themselves apart say nothing.
    func testDistinctIdentitiesSayNothing() {
        let renders = Renders()

        renders.render(VStack {
            ForEach(["identityA", "identityB"], id: \.self) { name in Text(name) }
        }.node)

        XCTAssertFalse(hasComplained("\"identityA\""))
    }
}
