// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a page hangs on its bars: the toolbar and the desktop menu bar.
//
// Both are lists of things that are NOT views, so they have no case in
// ControlTests - this is where every modifier they declare is covered. A page
// declares its toolbar groups where their state lives and writes its menus
// into its session; what it says as it comes into the tree is in the message
// that brings it - which is what `Renders.settled` answers.

import XCTest
@_spi(Host) @testable import StateUI

/// A page with toolbar groups declared on its content and a menu written into
/// its session as it comes into the tree.
private struct BarredPage: ContentView {
    @Environment private var page: PageSession

    var content: any View {
        Label("one")
            .toolbar {
                ToolbarItem("Save")
                    .id("save")
                    .text("Save")
                    .icon("nav_media.png")
                    .showsText(true)
                    .isEnabled(true)
                    .onClicked {}

                ToolbarItem("Delete")
                    .id("delete")
                    .placement(.overflow)
                    .isDestructive(true)
            }
            .toolbar(.leading, id: "edit", order: 1) {
                ToolbarItem("Undo").id("undo")
            }
            .menuBar(order: 1) {
                Menu("File") {
                    MenuItem("New")
                        .id("new")
                        .text("New")
                        .icon("nav_media.png")
                        .isDestructive(false)
                        .isEnabled(true)
                        .onClicked {}
                    MenuSeparator().id("sep")
                    Menu("Recent") {
                        MenuItem("a.txt").id("a")
                    }
                    .id("recent")
                    .isEnabled(true)
                }
                .id("file")
                .isEnabled(true)
            }
            .onCreated { page.title = "Notes" }
    }
}

final class PageBarTests: XCTestCase {
    /// What the page's first message carries - its `.onCreated` run, and what
    /// it wrote walked in.
    private static func arrived() -> HostPatch {
        Renders().settled(Node.page(BarredPage()))
    }

    /// Each toolbar group and menu bar hangs on the element declaring it,
    /// after its own children, as a collection of its own - which is what lets
    /// the host keep the list in step rather than rebuilding it.
    func testADeclarationHangsOnTheElementDeclaringIt() throws {
        let page = Self.arrived()

        XCTAssertEqual(page.children.map { $0.type }, ["Label"])
        let label = page.children[0]
        XCTAssertEqual(label.children.map { $0.type }, ["ToolbarItems", "ToolbarItems", "MenuBar"])

        let toolbar = label.children[0]
        XCTAssertEqual(toolbar.props["side"], .enumeration(0))
        XCTAssertEqual(toolbar.props["order"], .number(0))
        let edit = label.children[1]
        XCTAssertEqual(edit.id, .manual("edit"), "the group's own id, which a group further in joins")
        XCTAssertEqual(edit.props["side"], .enumeration(1))
        XCTAssertEqual(edit.props["order"], .number(1))
        XCTAssertEqual(toolbar.children.map { $0.id }, [.manual("save"), .manual("delete")])
        XCTAssertEqual(toolbar.children[0].props["text"], .string("Save"))
        XCTAssertEqual(toolbar.children[1].props["placement"], .enumeration(2),
                       "ToolbarItemPlacement.Overflow")
        XCTAssertNotNil(toolbar.children[0].events?["clicked"])

        let menus = try XCTUnwrap(label.children.first { $0.type == "MenuBar" })
        XCTAssertEqual(menus.props["order"], .number(1))
        let file = menus.children[0]

        XCTAssertEqual(file.type, "Menu")
        XCTAssertEqual(file.children.map { $0.type },
                       ["MenuItem", "MenuSeparator", "Menu"])
        XCTAssertEqual(file.children[2].children[0].props["text"], .string("a.txt"))
    }

    /// The same guarantee `testEveryModifierIsExercised` gives a control, for
    /// the elements that belong to a page rather than to a view: a modifier no
    /// message carries is one the host can quietly not implement.
    func testEveryToolbarAndMenuModifierIsExercised() throws {
        let sent = Self.keys(in: Self.arrived())

        for source in ["ToolbarItem.swift", "Page+Toolbar.swift", "Menu.swift", "MenuItem.swift", "Page+MenuBar.swift"] {
            let declared = try SourceTree.propertyKeys(in: source)

            XCTAssertFalse(declared.isEmpty, "the scan found nothing \(source) writes")

            let missing = declared.subtracting(sent).sorted()

            XCTAssertTrue(missing.isEmpty, """
                \(source) declares \(missing.joined(separator: ", ")), which \
                BarredPage does not use.

                These hang off a PAGE rather than sitting in a view, so they \
                have no control case - this is where they are covered.
                """)
        }
    }

    /// Every property name a patch carries, however deep it sits.
    private static func keys(in patch: HostPatch) -> Set<String> {
        patch.children.reduce(into: Set(patch.props.keys.map(\.name))) { names, child in
            names.formUnion(keys(in: child))
        }
    }

    /// A group declared on an arrangement stands after its pages, and a title
    /// view holds the one view it was given.
    func testAnArrangementsGroupFollowsItsPagesAndATitleViewHoldsOneView() {
        struct Plain: ContentView {
            var content: any View { Label("one") }
        }

        let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Plain() } destination: { _ in Plain() }
            .toolbar { ToolbarItem("Share").id("share") }
            .titleView { Label("title") }
        let built = stack.body

        XCTAssertEqual(built.children.map { $0.type }.suffix(2), ["ToolbarItems", "TitleView"], "after the root page")
        XCTAssertEqual(built.children.count, 3)
        XCTAssertEqual(built.children[2].children.map { $0.type }, ["Label"])
    }

    /// A group keeps its element as the view it hangs on gains and loses
    /// children, and its items keep theirs; a group declared and then not is
    /// taken away, and one declared anew is a new element.
    func testAGroupKeepsItsElementAsTheViewItHangsOnChanges() throws {
        let view = { (more: Bool, grouped: Bool) -> Node in
            var stack = VStack {
                Label("one")
                if more { Label("two") }
            }
            if grouped { stack = stack.toolbar { ToolbarItem("Save").id("save") } }
            return stack.body
        }
        let differ = Differ()
        let group = { (patch: HostPatch) in patch.children.first { $0.type == "ToolbarItems" } }

        let first = differ.reconcile(nil, with: view(false, true))
        let before = try XCTUnwrap(group(first.patch)?.id)

        let grown = differ.reconcile(first.node, with: view(true, true))
        XCTAssertEqual(grown.node.children.last?.id, before, "the same group after a child came before it")
        XCTAssertEqual(grown.node.children.last?.children.first?.id, .manual("save"))

        let gone = differ.reconcile(grown.node, with: view(true, false))
        XCTAssertFalse(gone.node.children.contains { $0.type == "ToolbarItems" })

        let back = differ.reconcile(gone.node, with: view(true, true))
        XCTAssertNotEqual(back.node.children.last?.id, before, "a group declared anew is another element")
    }

    /// A page with neither says nothing about them, so a host that has none is
    /// not told to empty one.
    func testAPageWithNoToolbarSendsNoSlot() {
        struct Plain: ContentView {
            var content: any View { Label("one") }
        }

        XCTAssertEqual(Node.page(Plain()).built.children.map { $0.type }, ["Label"])
    }
}
