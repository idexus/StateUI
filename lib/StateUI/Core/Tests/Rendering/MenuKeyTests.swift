// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization
import XCTest
@_spi(Host) @testable import StateUI

private final class MenuKeyOwner: Hashable {
    let value: Int
    init(_ value: Int) { self.value = value }
    static func == (lhs: MenuKeyOwner, rhs: MenuKeyOwner) -> Bool { lhs.value == rhs.value }
    func hash(into hasher: inout Hasher) { hasher.combine(value) }
}

@MainActor
final class MenuKeyTests: XCTestCase {
    func testMenuKeysAccompanyCompleteDescriptionsAndNotPartialChanges() throws {
        let renders = Renders()
        let first = renders.render(Menu("One") {}.id(1).node)
        let key = try XCTUnwrap(first.menuKey)
        let changed = renders.render(Menu("Two") {}.id(1).node)
        XCTAssertNil(changed.menuKey)
        XCTAssertEqual(first.merging(changed).menuKey, key)
        XCTAssertEqual(renders.renderFromScratch(Menu("Two") {}.id(1).node).menuKey, key)

        let replaced = renders.render(MenuItem("Entry").id(1).node)
        XCTAssertTrue(replaced.replace)
        XCTAssertEqual(replaced.menuKey, key)
        let plain = renders.render(Text("Plain").id(1).node)
        XCTAssertTrue(plain.replace)
        XCTAssertNil(plain.menuKey)
        XCTAssertNil(replaced.merging(plain).menuKey)
    }

    func testTheLastLiveMenuReleasesItsIdentityAndAReinsertionGetsANewKey() throws {
        let renders = Renders()
        var owner: MenuKeyOwner? = MenuKeyOwner(1)
        weak let released = owner
        func tree(_ owner: MenuKeyOwner?, count: Int) -> Node {
            let bars = owner.map { owner in
                (0..<count).map { index in
                    Node(contract: MenuBarContract.self, id: "bar\(index)", children: [Menu("Menu") {}.id(owner).node])
                }
            } ?? []
            return Node(contract: PageContract.self, id: "page", children: bars)
        }
        let first = renders.render(tree(owner, count: 2)).subtree.filter { $0.type == .menu }.compactMap(\.menuKey)
        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(first[0], first[1])
        owner = nil
        XCTAssertNotNil(released)

        _ = renders.render(tree(released, count: 1))
        XCTAssertNotNil(released, "one live declaration still owns the shared key")
        _ = renders.render(tree(nil, count: 0))
        XCTAssertNil(released, "the lookup book must not own an authored identity")

        let returned = renders.render(tree(MenuKeyOwner(1), count: 1)).subtree.first { $0.type == .menu }?.menuKey
        XCTAssertNotNil(returned)
        XCTAssertNotEqual(returned, first[0])
    }

    func testEqualLiveSetMenuIdentitiesProduceTheSameSemanticKey() throws {
        let values = (0..<64).map { _ in Set(0..<16) }
        let keys = try values.map { value in
            try XCTUnwrap(Renders().render(Menu("Menu") {}.id(value).node).menuKey)
        }
        XCTAssertEqual(Set(keys).count, 1)
    }

    /// A menu joins the platform's by `.joins` alone: a `StandardMenu` given to `.id` is a value like any other, and
    /// `.id` after a join is said and leaves the join standing.
    func testOnlyAJoinNamesThePlatformsMenu() throws {
        let heard = Mutex<[String]>([])
        Complaints.route { words in heard.withLock { $0.append(words) } }
        defer { Complaints.route(to: nil) }

        XCTAssertEqual(Renders().render(Menu("Plik") {}.joins(.file).node).menuKey, .standard(.file))
        let byId = try XCTUnwrap(Renders().render(Menu("Plik") {}.id(StandardMenu.file).node).menuKey)
        XCTAssertNotEqual(byId, .standard(.file), "an id joins none of the platform's menus")

        XCTAssertEqual(Renders().render(Menu("Plik") {}.joins(.file).id("plik").node).menuKey, .standard(.file))
        XCTAssertEqual(heard.withLock { $0.count }, 1, "the id beside the join is said")
    }

    func testAnUnbuiltListAimDoesNotInventAnItemToken() async throws {
        _ = drainedActs()
        do {
            try await Aim(ItemsView<Int>.self).scroll(to: 500)
            XCTFail("an unbuilt list has no target")
        } catch StateUIError.aimOnNoView {
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        XCTAssertTrue(drainedActs().isEmpty)
    }
}
