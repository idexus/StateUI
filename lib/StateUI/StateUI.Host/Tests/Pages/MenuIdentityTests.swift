// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

private struct AuthoredMenuID: Hashable, CustomStringConvertible {
    let value: Int
    let words: String
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.value == rhs.value }
    func hash(into hasher: inout Hasher) { hasher.combine(value) }
    var description: String { words }
}

@MainActor
final class MenuIdentityTests: XCTestCase {
    func testEqualMenuValuesJoinDespiteDifferentDescriptions() throws {
        try menus(
            outer: [Menu("Outer") { MenuItem("One") }.id(AuthoredMenuID(value: 1, words: "outer"))],
            inner: [Menu("Inner") { MenuItem("Two") }.id(AuthoredMenuID(value: 1, words: "inner"))]
        ) { menus in
            XCTAssertEqual(menus.count, 1)
            XCTAssertEqual(menus.first?.title, "Outer")
            XCTAssertEqual(menus.first?.entries.filter { $0.kind == .item }.map(\.title), ["One", "Two"])
        }
    }

    func testDifferentMenuValuesStayApartDespiteEqualDescriptions() throws {
        try menus(
            outer: [Menu("Outer") { MenuItem("One") }.id(AuthoredMenuID(value: 1, words: "same"))],
            inner: [Menu("Inner") { MenuItem("Two") }.id(AuthoredMenuID(value: 2, words: "same"))]
        ) { menus in
            XCTAssertEqual(menus.map(\.title), ["Outer", "Inner"])
        }
    }

    func testAnEntryOverridesByItsValueRatherThanItsDescription() throws {
        try menus(
            outer: [Menu("Actions") {
                MenuItem("Outer").id(AuthoredMenuID(value: 1, words: "outer"))
            }.id("actions")],
            inner: [Menu("Actions") {
                MenuItem("Inner").id(AuthoredMenuID(value: 1, words: "inner"))
            }.id("actions")]
        ) { menus in
            XCTAssertEqual(menus.first?.entries.filter { $0.kind == .item }.map(\.title), ["Inner"])
        }
    }

    func testDifferentEntryValuesDoNotOverrideBecauseTheirDescriptionsMatch() throws {
        try menus(
            outer: [Menu("Actions") {
                MenuItem("Outer").id(AuthoredMenuID(value: 1, words: "same"))
            }.id("actions")],
            inner: [Menu("Actions") {
                MenuItem("Inner").id(AuthoredMenuID(value: 2, words: "same"))
            }.id("actions")]
        ) { menus in
            XCTAssertEqual(menus.first?.entries.filter { $0.kind == .item }.map(\.title), ["Outer", "Inner"])
        }
    }

    func testAStandardMenuKeepsItsExplicitRole() throws {
        try menus(
            outer: [Menu("Plik") { MenuItem("One") }.joins(.file)],
            inner: [Menu("Datei") { MenuItem("Two") }.joins(.file)]
        ) { menus in
            XCTAssertEqual(menus.count, 1)
            XCTAssertEqual(menus.first?.standard, .file)
        }
    }

    func testAnAuthoredStringIsNotAStandardMenuRole() throws {
        try menus(
            outer: [Menu("Own") { MenuItem("One") }.id("StandardMenu.file")],
            inner: []
        ) { menus in
            XCTAssertEqual(menus.count, 1)
            XCTAssertNil(menus.first?.standard)
        }
    }

    func testReplacingANamedMenuWithAnotherTypeClearsItsSemanticKey() throws {
        let differ = Differ()
        let first = differ.reconcile(nil, with: Menu("Menu") {}.id("same").node)
        let runtime = HostRuntime.still()
        runtime.tree.apply(first.patch, complete: true)
        let menu = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(menu.menuKey, .name("same"))

        let next = differ.reconcile(first.node, with: Text("Plain").id("same").node)
        XCTAssertTrue(next.patch.replace)
        runtime.tree.apply(next.patch, complete: false)
        let plain = try XCTUnwrap(runtime.tree.root)
        XCTAssertFalse(menu === plain)
        XCTAssertNil(plain.menuKey)
    }

    private func menus(outer: [Menu], inner: [Menu], _ check: ([MenuEntry]) throws -> Void) throws {
        func bar(_ menus: [Menu]) -> Node {
            Node(contract: MenuBarContract.self, children: menus.map(\.node))
        }
        let page = Node(contract: PageContract.self, id: "page", children: [Text("Page").node, bar(inner)])
        let stack = Node(contract: NavigationStackContract.self, id: "stack", children: [page, bar(outer)])
        let window = Node(contract: WindowContract.self, id: "window", children: [stack])
        let rendered = Differ().reconcile(nil, with: window)
        let runtime = HostRuntime.still()
        runtime.tree.apply(rendered.patch, complete: true)
        let standing = try XCTUnwrap(runtime.tree.root?.first(id: .manual("page")))
        try check(standing.chromeMenus.menus)
        withExtendedLifetime(rendered.node) {}
    }
}
