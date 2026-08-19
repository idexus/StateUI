// What a page hangs on its bars: the toolbar and the desktop menu bar.
//
// Both are lists of things that are NOT views and hang beside the content, so
// they have no control fixture - this is where every modifier they declare is
// covered.

import XCTest
@testable import StateUI

/// A page with a toolbar and a menu, which are lists of things that are not
/// views and hang BESIDE the content.
private struct BarredPage: ContentPage {
    var title: String? { "Notes" }

    var toolbarItems: [ToolbarItem] {
        [
            ToolbarItem("Save")
                .id("save")
                .text("Save")
                .iconImageSource("nav_media.png")
                .priority(1)
                .isEnabled(true)
                .onClicked {},

            ToolbarItem("Delete")
                .id("delete")
                .order(.secondary)
                .isDestructive(true),
        ]
    }

    var menuBarItems: [MenuBarItem] {
        [
            MenuBarItem("File") {
                MenuFlyoutItem("New")
                    .id("new")
                    .text("New")
                    .iconImageSource("nav_media.png")
                    .isDestructive(false)
                    .isEnabled(true)
                    .onClicked {}
                MenuFlyoutSeparator().id("sep")
                MenuFlyoutSubItem("Recent") {
                    MenuFlyoutItem("a.txt").id("a")
                }
                .id("recent")
                .isEnabled(true)
            }
            .id("file")
            .isEnabled(true),
        ]
    }

    var content: Element { Label("one") }
}

final class PageBarTests: XCTestCase {
    /// The slots travel beside the content, each as a collection of its own -
    /// which is what lets the host keep the list in step rather than rebuilding
    /// it.
    func testAPagePutsItsToolbarAndMenusBesideItsContent() throws {
        let page = BarredPage().body.built

        XCTAssertEqual(page.children.map { $0.type }, ["Label", "ToolbarItems", "MenuBarItems"])

        let toolbar = try XCTUnwrap(page.children.first { $0.type == "ToolbarItems" })
        XCTAssertEqual(toolbar.children.map { $0.id }, ["save", "delete"])
        XCTAssertEqual(toolbar.children[0].props["text"], .string("Save"))
        XCTAssertEqual(toolbar.children[1].props["order"], .enumeration(2),
                       "ToolbarItemOrder.Secondary")
        XCTAssertNotNil(toolbar.children[0].events["clicked"])

        let menus = try XCTUnwrap(page.children.first { $0.type == "MenuBarItems" })
        let file = menus.children[0]

        XCTAssertEqual(file.type, "MenuBarItem")
        XCTAssertEqual(file.children.map { $0.type },
                       ["MenuFlyoutItem", "MenuFlyoutSeparator", "MenuFlyoutSubItem"])
        XCTAssertEqual(file.children[2].children[0].props["text"], .string("a.txt"))
    }

    /// The same guarantee `testEveryModifierIsExercised` gives a control, for
    /// the elements that belong to a page rather than to a view: a modifier no
    /// message carries is one the host can quietly not implement.
    func testEveryToolbarAndMenuModifierIsExercised() throws {
        let sent = Self.keys(in: BarredPage().body.built)

        for source in ["ToolbarItem.swift", "MenuBar.swift"] {
            let declared = try Fixtures.propertyKeys(in: source)
            let missing = declared.subtracting(sent).sorted()

            XCTAssertTrue(missing.isEmpty, """
                \(source) declares \(missing.joined(separator: ", ")), which \
                BarredPage does not use.

                These hang off a PAGE rather than sitting in a view, so they \
                have no control fixture - this is where they are covered.
                """)
        }
    }

    private static func keys(in node: Node) -> Set<String> {
        node.children.reduce(into: Set(node.props.keys.map(\.name))) { names, child in
            names.formUnion(keys(in: child))
        }
    }

    /// A page with neither says nothing about them, so a host that has none is
    /// not told to empty one.
    func testAPageWithNoToolbarSendsNoSlot() {
        struct Plain: ContentPage {
            var content: Element { Label("one") }
        }

        XCTAssertEqual(Plain().body.built.children.map { $0.type }, ["Label"])
    }
}
