// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A shared transition's scope and key as they cross: numbers the core gives the authored identities, the same
/// for the view that leaves and the one that enters in one walk, and never a number given again.
@MainActor
final class SharedTransitionIdentityTests: XCTestCase {
    /// A scope holding a thumbnail or a detail of `item`, as `detailed` says - or neither.
    private static func page(_ item: Int?, detailed: Bool, scope: String = "catalog") -> Node {
        VStack {
            if let item {
                if detailed {
                    Text("detail").sharedTransition(item)
                } else {
                    Text("thumbnail").sharedTransition(item)
                }
            }
        }
        .transitionScope(scope).id("scope").node
    }

    /// The key the message says, of whichever view says one.
    private func key(in message: HostPatch) throws -> Int {
        try XCTUnwrap(message.subtree.compactMap { $0.properties[.sharedTransition]?.int }.first, "no key in the message")
    }

    /// THE VIEW THAT LEAVES AND THE ONE THAT ENTERS IN ONE WALK CROSS UNDER ONE NUMBER - another element, the same
    /// key - and their scope under a number of its own, said once as it stands.
    func testTheLeavingAndTheEnteringViewCrossUnderOneNumber() throws {
        let renders = Renders()
        let first = renders.render(Self.page(7, detailed: false))
        let scope = try XCTUnwrap(first.properties[.transitionScope]?.int)
        let thumbnail = try key(in: first)

        let second = renders.render(Self.page(7, detailed: true))
        XCTAssertEqual(try key(in: second), thumbnail, "the detail, another element, under the thumbnail's number")
        XCTAssertEqual(second.subtree.filter { $0.properties[.text] == .string("detail") }.count, 1)
        XCTAssertNil(second.properties[.transitionScope], "the scope stands: its number is said no more")

        let back = renders.render(Self.page(7, detailed: false))
        XCTAssertEqual(try key(in: back), thumbnail, "and back")
        XCTAssertNotEqual(thumbnail, scope)
    }

    /// ANOTHER KEY IS ANOTHER NUMBER, AND A KEY NOBODY WEARS IS FORGOTTEN: written again in a later walk it crosses
    /// under a new number - no number is given twice.
    func testAKeyNobodyWearsIsForgottenAndNoNumberGivenTwice() throws {
        let renders = Renders()
        let seven = try key(in: renders.render(Self.page(7, detailed: false)))
        let eight = try key(in: renders.render(Self.page(8, detailed: false)))
        XCTAssertNotEqual(seven, eight)

        renders.render(Self.page(nil, detailed: false))
        let again = try key(in: renders.render(Self.page(8, detailed: false)))
        XCTAssertFalse([seven, eight].contains(again), "worn by nobody for a walk: another number")
    }
}
