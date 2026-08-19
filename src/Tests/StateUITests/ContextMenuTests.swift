// A menu on the view itself.
//
// `.contextFlyout` is the first View-tier modifier that writes a CHILD rather
// than a property, and that is what these tests are mostly about: where the slot
// lands, that it survives a composed view being expanded, and that a patch about
// one entry carries that entry alone.

import XCTest
@testable import StateUI

/// A composed view with a menu written ON it - the case a slot is easiest to
/// lose, because a ContentView has no node of its own to keep one in.
private struct Card: ContentView {
    var content: Element {
        VStack {
            Label("card")
        }
    }
}

final class ContextMenuTests: XCTestCase {
    private func menu(_ view: some View) -> Node? {
        view.body.built.children.first { $0.type == "ContextFlyout" }
    }

    func testAMenuTravelsAsASlotAfterTheViewsOwnChildren() throws {
        let node = VStack {
            Label("one")
            Label("two")
        }
        .contextFlyout {
            MenuFlyoutItem("Rename")
            MenuFlyoutSeparator()
            MenuFlyoutSubItem("Move") { MenuFlyoutItem("Up") }
        }
        .body.built

        // The view's own children keep the positions the differ gave them, and
        // the slot is appended - the rule a group's header and footer follow.
        XCTAssertEqual(node.children.map { $0.type },
                       ["Label", "Label", "ContextFlyout"])

        let flyout = try XCTUnwrap(node.children.last)

        XCTAssertEqual(flyout.children.map { $0.type },
                       ["MenuFlyoutItem", "MenuFlyoutSeparator", "MenuFlyoutSubItem"])
        XCTAssertEqual(flyout.children.first?.props["text"], .string("Rename"))
        XCTAssertEqual(flyout.children.last?.children.first?.props["text"], .string("Up"))
    }

    /// A menu written on a COMPOSED view reaches what the view is made of.
    ///
    /// A ContentView has no node of its own, so everything written on it lands
    /// on the built content - props, handlers, watches, and now the slot. Before
    /// `Stateful.expand` carried children, this modifier compiled, rendered
    /// nothing and said nothing.
    func testAMenuOnAComposedViewReachesWhatItIsMadeOf() throws {
        let node = Card()
            .contextFlyout { MenuFlyoutItem("Rename") }
            .body.built

        XCTAssertEqual(node.type, "VerticalStackLayout")
        XCTAssertEqual(node.children.map { $0.type }, ["Label", "ContextFlyout"])
    }

    /// A memoized view keeps its menu: the skip stands for the whole subtree,
    /// slot included.
    func testAMemoizedViewKeepsTheMenuWrittenInsideIt() throws {
        let node = Label("row")
            .contextFlyout { MenuFlyoutItem("Rename") }
            .memoized(by: "row")
            .body.built

        XCTAssertEqual(node.type, "Label")
        XCTAssertEqual(node.children.map { $0.type }, ["ContextFlyout"])
    }

    /// A leaf takes one too: MAUI puts ContextFlyout on any view.
    func testALeafViewTakesAMenu() throws {
        let flyout = try XCTUnwrap(menu(Label("row").contextFlyout { MenuFlyoutItem("Copy") }))

        XCTAssertEqual(flyout.children.count, 1)
    }

    /// A patch about one entry carries that entry and nothing else - the rule
    /// every kept list follows, and the reason the host matches by identity.
    func testAChangedEntryCarriesThatEntryAlone() throws {
        let renders = Renders()

        func tree(_ caption: String) -> Node {
            VStack {
                Label("row")
            }
            .contextFlyout {
                MenuFlyoutItem("Rename")
                MenuFlyoutItem(caption)
            }
            .body
        }

        renders.render(tree("Delete"))
        let patch = renders.render(tree("Remove"))

        let flyout = try XCTUnwrap(patch.children.first { $0.type == "ContextFlyout" })

        XCTAssertFalse(flyout.arranged, "the arrangement did not change")
        XCTAssertEqual(flyout.children.count, 1, "the entry that did not change was sent too")
        XCTAssertEqual(flyout.children.first?.props, ["text": .string("Remove")])
    }

    /// An entry that leaves is NAMED - position cannot say which one went.
    func testAnEntryThatLeavesIsNamed() throws {
        let renders = Renders()

        func tree(_ deletable: Bool) -> Node {
            Label("row")
                .contextFlyout {
                    MenuFlyoutItem("Rename")

                    if deletable {
                        MenuFlyoutItem("Delete")
                    }
                }
                .body
        }

        renders.render(tree(true))
        let patch = renders.render(tree(false))

        let flyout = try XCTUnwrap(patch.children.first { $0.type == "ContextFlyout" })

        XCTAssertTrue(flyout.arranged, "an entry left, so the whole list is said")
        XCTAssertEqual(flyout.children.count, 1, "the one entry left is all it lists")
        XCTAssertEqual(flyout.children.first?.isEmpty, true,
                       "the entry that stayed rides as a stub")
    }

    /// The slot is counted like any other child on the wire; what leaves it out
    /// of the arrangement is the host - see StateUIRenderer.IsSlot.
    func testTheSlotIsCountedAmongTheChildrenOnTheWire() throws {
        let renders = Renders()

        let patch = renders.render(
            VStack {
                Label("one")
            }
            .contextFlyout { MenuFlyoutItem("Copy") }
            .body)

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.count, 2)
    }
}
