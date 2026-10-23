// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a page hangs on its bars: the toolbar and the desktop menu bar.
//
// Both are lists of things that are NOT views, so they have no case in
// ControlTests - this is where every modifier they declare is covered. A page
// declares its toolbar groups and its menus where their state lives; what its
// view says is in the message that brings it.

import XCTest
@_spi(Host) @testable import StateUI

/// A page with toolbar groups and a menu declared on its content.
private struct BarredPage: View {
    var body: some View {
        Text("one")
            .toolbar {
                ToolbarGroup {
                    ToolbarButton("Save")
                        .id("save")
                        .text("Save")
                        .icon("nav_media.png")
                        .showsText(true)
                        .isEnabled(true)
                        .onClicked {}

                    ToolbarButton("Delete")
                        .id("delete")
                        .role(.destructive)
                }
                .placement(at: .overflow)
                .hidesWithSidebar(true)
                .isEnabled(false)

                ToolbarButton("Undo")
                    .id("undo")
                    .placement(.sidebar, at: .start, order: 1)
                    .hidesWithSidebar(true)
            }
            .menuBar(order: 1) {
                Menu("File") {
                    MenuItem("New")
                        .id("new")
                        .text("New")
                        .icon("nav_media.png")
                        .role(.normal)
                        .isEnabled(true)
                        .isOn(false)
                        .onToggled { _ in }
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
            .title("Notes")
    }
}

@MainActor
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

        XCTAssertEqual(page.children.map { $0.type }, ["Text"])
        let label = page.children[0]
        XCTAssertEqual(label.children.map { $0.type }, ["ToolbarGroup", "ToolbarGroup", "MenuBar"])

        let toolbar = label.children[0]
        XCTAssertEqual(toolbar.props["position"], .enumeration(2), "ToolbarPosition.overflow")
        XCTAssertEqual(toolbar.props["hidesWithSidebar"], .bool(true))
        XCTAssertNil(toolbar.props["part"], "unsaid: its declarer's")
        XCTAssertEqual(toolbar.children.map { $0.id }, [.manual("save"), .manual("delete")])
        XCTAssertEqual(toolbar.children[0].props["text"], .string("Save"))
        XCTAssertEqual(toolbar.props["isEnabled"], .bool(false), "the group's, its items out of reach with it")
        XCTAssertNotNil(toolbar.children[0].events?["clicked"])

        let undo = label.children[1]
        XCTAssertEqual(undo.props["part"], .enumeration(0), "ToolbarPart.sidebar")
        XCTAssertEqual(undo.props["position"], .enumeration(1), "ToolbarPosition.start")
        XCTAssertEqual(undo.props["order"], .number(1))
        XCTAssertEqual(undo.props["hidesWithSidebar"], .bool(true))
        XCTAssertEqual(undo.children.map { $0.id }, [.manual("undo")])
        XCTAssertNil(undo.children[0].props["position"], "the item says nothing of where it stands")

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

        for source in [
            "ToolbarButton.swift", "ToolbarGroup.swift", "Menu.swift", "MenuItem.swift", "View+MenuBar.swift",
        ] {
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
        struct Plain: View {
            var body: some View { Text("one") }
        }

        let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Plain() } destination: { _ in Plain() }
            .toolbar { ToolbarButton("Share").id("share") }
            .titleView { Text("title") }
        let built = stack.node

        XCTAssertEqual(built.children.map { $0.type }.suffix(2), ["ToolbarGroup", "TitleView"], "after the root page")
        XCTAssertEqual(built.children.count, 3)
        XCTAssertEqual(built.children[2].children.map { $0.type }, ["Text"])
    }

    /// An item in a group stands where its group does: its own placement is
    /// left out, and said once.
    func testAnItemsPlacementInAGroupIsLeftOut() {
        let group = ToolbarGroup {
            ToolbarButton("Bold").placement(at: .start)
            ToolbarButton("Italic")
        }
        .placement(at: .end, order: 2)

        XCTAssertEqual(group.node.props.keys.map(\.name).sorted(), ["order", "position"])
        XCTAssertEqual(group.node.children.map { $0.props.keys.map(\.name).sorted() }, [["text"], ["text"]])
        XCTAssertTrue(hasComplained("A toolbar item in a ToolbarGroup stands where its group does"))
    }

    /// A split view's groups hang on the split view after its columns, each
    /// saying the part of its bar it names.
    func testASplitViewsGroupsFollowItsColumns() {
        let split = SplitView(State(wrappedValue: true).projectedValue) { Text("Folders") } detail: { Text("Notes") }
            .toolbar {
                ToolbarButton("Add").placement(.sidebar)
                ToolbarButton("Share")
            }
        let groups = split.node.children.suffix(2)

        XCTAssertEqual(split.node.children.count, 4)
        XCTAssertEqual(groups.map(\.type), ["ToolbarGroup", "ToolbarGroup"])
        XCTAssertEqual(groups.map { $0.props["part"] }, [.enumeration(0), nil], "the detail's unsaid")
    }

    /// A group keeps its element as the view it hangs on gains and loses
    /// children, and its items keep theirs; a group declared and then not is
    /// taken away, and one declared anew is a new element.
    func testAGroupKeepsItsElementAsTheViewItHangsOnChanges() throws {
        let view = { (more: Bool, grouped: Bool) -> Node in
            var stack = VStack {
                Text("one")
                if more { Text("two") }
            }
            if grouped { stack = stack.toolbar { ToolbarButton("Save").id("save") } }
            return stack.node
        }
        let differ = Differ()
        let group = { (patch: HostPatch) in patch.children.first { $0.type == "ToolbarGroup" } }

        let first = differ.reconcile(nil, with: view(false, true))
        let before = try XCTUnwrap(group(first.patch)?.id)

        let grown = differ.reconcile(first.node, with: view(true, true))
        XCTAssertEqual(grown.node.children.last?.id, before, "the same group after a child came before it")
        XCTAssertEqual(grown.node.children.last?.children.first?.id, .manual("save"))

        let gone = differ.reconcile(grown.node, with: view(true, false))
        XCTAssertFalse(gone.node.children.contains { $0.type == "ToolbarGroup" })

        let back = differ.reconcile(gone.node, with: view(true, true))
        XCTAssertNotEqual(back.node.children.last?.id, before, "a group declared anew is another element")
    }

    /// A page with neither says nothing about them, so a host that has none is
    /// not told to empty one.
    func testAPageWithNoToolbarSendsNoSlot() {
        struct Plain: View {
            var body: some View { Text("one") }
        }

        XCTAssertEqual(Node.page(Plain()).built.children.map { $0.type }, ["Text"])
    }
}
