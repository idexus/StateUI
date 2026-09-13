// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a page hangs on its bars: the toolbar and the desktop menu bar.
//
// Both are lists of things that are NOT views and hang beside the content, so
// they have no control fixture - this is where every modifier they declare is
// covered. A page writes both into its session, and what it writes as it comes
// into the tree is in the message that brings it - which is what
// `Renders.settled` answers.

import XCTest
@_spi(Host) @testable import StateUI

/// A page with a toolbar and a menu, which are lists of things that are not
/// views and hang BESIDE the content - written into the page's session as it
/// comes into the tree.
private struct BarredPage: ContentPage {
    @Environment private var page: PageSession

    var content: any View {
        Label("one").onCreated {
            page.title = "Notes"

            page.toolbarItems = [
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

            page.menuBarItems = [
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
    }
}

final class PageBarTests: XCTestCase {
    /// What the page's first message carries - its `.onCreated` run, and what
    /// it wrote walked in.
    private static func arrived() -> HostPatch {
        Renders().settled(BarredPage().body)
    }

    /// The slots travel beside the content, each as a collection of its own -
    /// which is what lets the host keep the list in step rather than rebuilding
    /// it.
    func testAPagePutsItsToolbarAndMenusBesideItsContent() throws {
        let page = Self.arrived()

        XCTAssertEqual(page.children.map { $0.type }, ["Label", "ToolbarItems", "MenuBarItems"])

        let toolbar = try XCTUnwrap(page.children.first { $0.type == "ToolbarItems" })
        XCTAssertEqual(toolbar.children.map { $0.id }, [.manual("save"), .manual("delete")])
        XCTAssertEqual(toolbar.children[0].props["text"], .string("Save"))
        XCTAssertEqual(toolbar.children[1].props["order"], .enumeration(2),
                       "ToolbarItemOrder.Secondary")
        XCTAssertNotNil(toolbar.children[0].events?["clicked"])

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
        let sent = Self.keys(in: Self.arrived())

        for source in ["ToolbarItem.swift", "MenuBar.swift"] {
            let declared = try Fixtures.propertyKeys(in: source)

            XCTAssertFalse(declared.isEmpty, "the scan found nothing \(source) writes")

            let missing = declared.subtracting(sent).sorted()

            XCTAssertTrue(missing.isEmpty, """
                \(source) declares \(missing.joined(separator: ", ")), which \
                BarredPage does not use.

                These hang off a PAGE rather than sitting in a view, so they \
                have no control fixture - this is where they are covered.
                """)
        }
    }

    /// Every property name a patch carries, however deep it sits.
    private static func keys(in patch: HostPatch) -> Set<String> {
        patch.children.reduce(into: Set(patch.props.keys.map(\.name))) { names, child in
            names.formUnion(keys(in: child))
        }
    }

    /// A page with neither says nothing about them, so a host that has none is
    /// not told to empty one.
    func testAPageWithNoToolbarSendsNoSlot() {
        struct Plain: ContentPage {
            var content: any View { Label("one") }
        }

        XCTAssertEqual(Plain().body.built.children.map { $0.type }, ["Label"])
    }
}
