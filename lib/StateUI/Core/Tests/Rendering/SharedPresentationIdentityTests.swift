// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A shared presentation's numbers as they cross: a transition id and its scope give the numbers the core keeps for
/// them, the same for the view that leaves and the one that comes in one walk, never a number given again - and
/// `.id()`, who a view is, gives none.
@MainActor
final class SharedPresentationIdentityTests: XCTestCase {
    /// An identity of this test's own: no other test's views wear one, so the numbers they keep are its alone.
    private struct Item: Hashable {
        let number: Int
    }

    /// A stack holding a thumbnail of `item`, or its detail in a holder of its own, as `detailed` says - or neither.
    private static func page(_ item: Int?, detailed: Bool) -> Node {
        VStack {
            if let item {
                if detailed {
                    VStack { Text("detail").transitionID(Item(number: item)) }
                } else {
                    Text("thumbnail").transitionID(Item(number: item))
                }
            }
        }
        .id("page")
        .node
    }

    /// The number the message says, of whichever text says one.
    private func number(in message: HostPatch) throws -> Int {
        try XCTUnwrap(
            message.subtree.filter { $0.type == .text }.compactMap { $0.properties[.transitionID]?.int }.first,
            "no number in the message")
    }

    /// THE VIEW THAT LEAVES AND THE ONE THAT COMES IN ONE WALK CROSS UNDER ONE NUMBER - another element in another
    /// holder, the same id.
    func testTheLeavingAndTheComingViewCrossUnderOneNumber() throws {
        let renders = Renders()
        let thumbnail = try number(in: renders.render(Self.page(7, detailed: false)))

        let second = renders.render(Self.page(7, detailed: true))
        XCTAssertEqual(try number(in: second), thumbnail, "the detail, another element, under the thumbnail's number")
        XCTAssertEqual(second.subtree.filter { $0.properties[.text] == .string("detail") }.count, 1)

        XCTAssertEqual(try number(in: renders.render(Self.page(7, detailed: false))), thumbnail, "and back")
    }

    /// ANOTHER ID IS ANOTHER NUMBER, AND AN ID NOBODY WEARS IS FORGOTTEN: written again in a later walk it crosses
    /// under a new number - no number is given twice.
    func testAnIdNobodyWearsIsForgottenAndNoNumberGivenTwice() throws {
        let renders = Renders()
        let seven = try number(in: renders.render(Self.page(7, detailed: false)))
        let eight = try number(in: renders.render(Self.page(8, detailed: false)))
        XCTAssertNotEqual(seven, eight)

        renders.render(Self.page(nil, detailed: false))
        let again = try number(in: renders.render(Self.page(8, detailed: false)))
        XCTAssertFalse([seven, eight].contains(again), "worn by nobody for a walk: another number")
    }

    /// AN ID AND ITS SCOPE CROSS AS TWO NUMBERS, WRITTEN IN EITHER ORDER: the same id is one number whatever its
    /// scope, another scope another number, and a view naming no scope crosses with none.
    func testATransitionIDAndItsScopeCrossAsTwoNumbersInEitherOrder() throws {
        func numbers(_ text: some View) -> [Int?] {
            [text.node.props[.transitionID]?.int, text.node.props[.transitionScope]?.int]
        }
        let first = numbers(Text("title").transitionID(Item(number: 4)).transitionScope("card 1"))
        XCTAssertNotNil(first[0], "the id's number")
        XCTAssertNotNil(first[1], "the scope's number")
        XCTAssertEqual(numbers(Text("title").transitionScope("card 1").transitionID(Item(number: 4))), first,
                       "the same written the other way round")
        let other = numbers(Text("title").transitionID(Item(number: 4)).transitionScope("card 2"))
        XCTAssertEqual(other[0], first[0], "the same id")
        XCTAssertNotEqual(other[1], first[1], "another scope")
        XCTAssertNil(numbers(Text("title").transitionID(Item(number: 4)))[1], "no scope")
    }

    /// What the library said, as a test hears it.
    private final class Heard: @unchecked Sendable {
        var words: [String] = []
    }

    /// A SCOPE WITH NO TRANSITION ID makes the view one with nothing, and is said once.
    func testAScopeWithNoTransitionIDIsSaid() {
        let heard = Heard()
        Complaints.route(to: { heard.words.append($0) })
        defer { Complaints.route(to: nil) }
        Renders().render(VStack { Text("title").transitionScope("a card alone") }.node)
        XCTAssertTrue(heard.words.contains { $0.contains("\"a card alone\" and no transition id") }, "\(heard.words)")
    }

    /// AN ID IS WHO A VIEW IS, NOT WHAT IT IS DRAWN AS: `.id()` alone shares no presentation, and a list's items,
    /// keyed by their loop, share none either.
    func testAnIdAloneSharesNoPresentation() {
        let message = Renders().render(VStack {
            Text("thumbnail").id(Item(number: 3))
            ForEach([1, 2]) { Text("item \($0)") }
        }.node)
        XCTAssertEqual(message.subtree.compactMap { $0.properties[.transitionID] }.count, 0)
    }
}
