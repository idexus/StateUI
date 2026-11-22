// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A shared presentation's number as it crosses: an id written by hand gives the number the core keeps for its value,
/// the same for the view that leaves and the one that comes in one walk, never a number given again - and a list's
/// item, keyed by its loop, gives none.
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
                    VStack { Text("detail").id(Item(number: item)) }
                } else {
                    Text("thumbnail").id(Item(number: item))
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

    /// ONLY AN ID WRITTEN BY HAND SHARES A PRESENTATION: a list's items, keyed by their loop, cross under none.
    func testAListsItemSharesNoPresentation() {
        let message = Renders().render(VStack { ForEach([1, 2]) { Text("item \($0)") } }.node)
        XCTAssertEqual(message.subtree.compactMap { $0.properties[.sharedPresentation] }.count, 0)
    }
}
