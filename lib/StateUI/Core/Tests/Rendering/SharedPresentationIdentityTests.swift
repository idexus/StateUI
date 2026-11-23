// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A shared presentation's number as it crosses: a transition id gives the number the core keeps for it and its scope,
/// the same for the view that leaves and the one that comes in one walk, never a number given again - and `.id()`,
/// who a view is, gives none.
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
                    VStack { Text("detail").transition(id: Item(number: item)) }
                } else {
                    Text("thumbnail").transition(id: Item(number: item))
                }
            }
        }
        .id("page")
        .node
    }

    /// The number the message says, of whichever text says one.
    private func number(in message: HostPatch) throws -> Int {
        try XCTUnwrap(
            message.subtree.filter { $0.type == .text }.compactMap { $0.properties[.sharedPresentation]?.int }.first,
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

    /// A SCOPE IS WHERE THE VIEWS OF ONE TRANSITION ID MEET: one id in one scope is one number, in two scopes two,
    /// and an id written with no scope is another number than the same id in one.
    func testATransitionIDsScopeIsPartOfItsNumber() throws {
        func number(_ text: some View) throws -> Int { try XCTUnwrap(text.node.props[.sharedPresentation]?.int) }
        let first = try number(Text("title").transition(id: Item(number: 4), scope: "card 1"))
        XCTAssertEqual(try number(Text("title").transition(id: Item(number: 4), scope: "card 1")), first, "the same pair")
        XCTAssertNotEqual(try number(Text("title").transition(id: Item(number: 4), scope: "card 2")), first, "another scope")
        XCTAssertNotEqual(try number(Text("title").transition(id: Item(number: 4))), first, "no scope")
    }

    /// AN ID IS WHO A VIEW IS, NOT WHAT IT IS DRAWN AS: `.id()` alone shares no presentation, and a list's items,
    /// keyed by their loop, share none either.
    func testAnIdAloneSharesNoPresentation() {
        let message = Renders().render(VStack {
            Text("thumbnail").id(Item(number: 3))
            ForEach([1, 2]) { Text("item \($0)") }
        }.node)
        XCTAssertEqual(message.subtree.compactMap { $0.properties[.sharedPresentation] }.count, 0)
    }
}
