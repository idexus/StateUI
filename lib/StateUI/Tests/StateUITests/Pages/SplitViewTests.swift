// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The flyout, as Swift describes it.
//
// A SplitView puts two pages in the patch - the pane and the page under it,
// each wearing the identity of its half - and whether the pane is showing as
// one property. Coming back there is one report, and it says what is true now.

import XCTest
@_spi(Host) @testable import StateUI

/// The pane. A page like any other, which is the whole point - and it carries
/// a title, written as it comes into the tree, so the pane arrives with one.
private struct MenuPage: ContentView {
    @Environment private var page: PageSession
    @Binding var section: String
    @Binding var menu: Bool

    var content: any View {
        VStack {
            Button("Today").onClicked {
                section = "today"
                menu = false
            }
            Button("Archive").onClicked {
                section = "archive"
                menu = false
            }
        }
        .onCreated { page.title = "Sections" }
    }
}

/// The page under the pane, named for the section it shows - as it comes into
/// the tree, and again whenever it is handed another.
private struct DetailPage: ContentView {
    @Environment private var page: PageSession
    let section: String

    var content: any View {
        ModifiedContent(node: label(section))
            .onCreated { page.title = section }
            .onChanged(section) { page.title = section }
    }
}

/// The flyout under test, over whatever state is lent to it.
private func flyout(
    _ menu: Binding<Bool>,
    _ section: Binding<String>
) -> SplitView {
    SplitView(menu) {
        MenuPage(section: section, menu: menu)
    } detail: {
        DetailPage(section: section.wrappedValue)
    }
}

final class SplitViewTests: XCTestCase {
    // MARK: - What goes out

    /// Two children, each wearing the identity of its half - so a patch about
    /// one of them can never be taken for the other.
    func testTheTwoHalvesAreTheChildren() {
        let menu = State<Bool>(false)
        let section = State<String>("today")

        let patch = Renders().settled(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertEqual(patch.type, "SplitView")
        XCTAssertEqual(patch.children.map { $0.id }, [.manual("sidebar"), .manual("detail")])
        XCTAssertEqual(patch.children.map { $0.props["title"] },
                       [.string("Sections"), .string("today")])
    }

    /// Whether the pane is showing is a property, and it is the binding's
    /// value - nothing else says it, so there is nothing to disagree.
    func testWhetherItIsPresentedIsTheBindingsValue() {
        let menu = State<Bool>(true)
        let section = State<String>("today")

        let node = flyout(menu.projectedValue, section.projectedValue).body.built

        XCTAssertEqual(node.props["isSidebarVisible"], .bool(true))
    }

    /// Opening it from code is assigning the binding, and what goes out is one
    /// property - the pages themselves did not change.
    func testOpeningItIsAssigningTheBinding() {
        let menu = State<Bool>(false)
        let section = State<String>("today")
        let renders = Renders()

        renders.settled(flyout(menu.projectedValue, section.projectedValue).body)

        menu.wrappedValue = true
        let patch = renders.settled(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertEqual(patch.props["isSidebarVisible"], .bool(true))
        XCTAssertTrue(patch.children.isEmpty)
    }

    /// A row in the pane is a Button whose handler writes state - here two
    /// writes, "show this section" and "close the menu", which is why the
    /// library ships no flyout item type at all.
    func testARowIsAButtonThatWritesState() {
        let menu = State<Bool>(true)
        let section = State<String>("today")
        let renders = Renders()

        let patch = renders.settled(flyout(menu.projectedValue, section.projectedValue).body)

        let archive = patch.child("sidebar")?.children.first?.children.last
        XCTAssertTrue(renders.fire(archive?.events?["clicked"] ?? -1))

        XCTAssertEqual(section.wrappedValue, "archive")
        XCTAssertFalse(menu.wrappedValue, "and the pane closed itself on the way")

        // Which the next render says in one message: the detail page changed
        // and the pane is no longer showing.
        let next = renders.settled(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertEqual(next.props["isSidebarVisible"], .bool(false))
        XCTAssertEqual(next.child("detail")?.props["title"], .string("archive"))
    }

    // MARK: - The contract a host reads

    /// The whole thing: a pane with two rows, a detail page that is a whole
    /// navigation stack, and the pane showing.
    func testAPaneAndAStackArriveAsTheSplitsTwoPages() throws {
        let menu = State<Bool>(true)
        let section = State<String>("today")
        let path = State<[Int]>([1])

        let tree = SplitView(menu.projectedValue) {
            MenuPage(section: section.projectedValue, menu: menu.projectedValue)
        } detail: {
            NavigationStack(path.projectedValue) {
                DetailPage(section: "today")
            } destination: { depth in
                DetailPage(section: "level \(depth)")
            }
            .title("Diary")
            .barBackgroundColor(Color("#512BD4"))
        }
        .body

        // As the message that brings the pages carries them - with the title
        // each wrote into its session on the way in.
        let split = Renders().settled(tree)

        XCTAssertEqual(split.props, ["isSidebarVisible": .bool(true)])
        XCTAssertEqual(split.eventNames, ["isSidebarVisibleChanged"])
        XCTAssertEqual(split.arrangement, [.manual("sidebar"), .manual("detail")])

        let pane = try XCTUnwrap(split.child("sidebar"))
        XCTAssertEqual(pane.props["title"], .string("Sections"))
        XCTAssertEqual(pane.subtree.filter { $0.type == .button }.map { $0.props["text"] },
                       [.string("Today"), .string("Archive")])

        let detail = try XCTUnwrap(split.child("detail"))
        XCTAssertEqual(detail.type, .navigationStack)
        XCTAssertEqual(detail.props["title"], .string("Diary"))
        XCTAssertEqual(detail.arrangement, [.manual("root"), .manual("0/1")])
        XCTAssertEqual(detail.children.map { $0.props["title"] }, [.string("today"), .string("level 1")])
    }

    // MARK: - What comes back

    /// The one report: what is true now. A swipe, a tap outside the pane, the
    /// platform's own button - all of them arrive here.
    func testASwipeWritesTheBinding() {
        let menu = State<Bool>(false)
        let section = State<String>("today")
        let renders = Renders()

        let patch = renders.settled(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["isSidebarVisibleChanged"] ?? -1, with: [.bool(true)]))
        XCTAssertTrue(menu.wrappedValue)
    }

    /// And a report saying what the binding already holds writes nothing -
    /// the rule that keeps a flyout the AUTHOR opened to one render.
    func testAReportOfWhatIsAlreadyTrueWritesNothing() {
        let menu = State<Bool>(true)
        let section = State<String>("today")
        let renders = Renders()

        let patch = renders.settled(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["isSidebarVisibleChanged"] ?? -1, with: [.bool(true)]))

        XCTAssertTrue(menu.wrappedValue)
        XCTAssertTrue(renders.settled(flyout(menu.projectedValue, section.projectedValue).body).isEmpty,
                      "nothing to say after it")
    }

    /// A payload of the wrong shape leaves the binding alone.
    func testAValueOfTheWrongKindLeavesTheBindingAlone() {
        let menu = State<Bool>(false)
        let section = State<String>("today")
        let renders = Renders()

        let patch = renders.settled(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["isSidebarVisibleChanged"] ?? -1,
                                   with: [.string("true")]))
        XCTAssertFalse(menu.wrappedValue)
    }
}
