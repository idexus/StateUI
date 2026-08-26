// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The flyout, as Swift describes it.
//
// A FlyoutPage puts two pages on the wire - the pane and the page under it,
// each wearing the identity of its half - and whether the pane is showing as
// one property. Coming back there is one report, and it says what is true now.
//
// What the renderer does with it is next door, in the C# FlyoutPageTests.

import StateUIWireProbe
import XCTest
@testable import StateUI

/// The pane. A page like any other, which is the whole point - and it needs a
/// title, which is MAUI's rule rather than this library's.
private struct MenuPage: ContentPage {
    @Binding var section: String
    @Binding var menu: Bool

    var title: String? { "Sections" }

    var content: Element {
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
    }
}

private struct DetailPage: ContentPage {
    let section: String

    var title: String? { section }
    var content: Element { label(section) }
}

/// The flyout under test, over whatever state is lent to it.
private func flyout(
    _ menu: Binding<Bool>,
    _ section: Binding<String>
) -> FlyoutPage {
    FlyoutPage(menu) {
        MenuPage(section: section, menu: menu)
    } detail: {
        DetailPage(section: section.wrappedValue)
    }
}

final class FlyoutPageTests: XCTestCase {
    // MARK: - What goes out

    /// Two children, each wearing the identity of its half - so a patch about
    /// one of them can never be taken for the other.
    func testTheTwoHalvesAreTheChildren() {
        let menu = State<Bool>(false)
        let section = State<String>("today")

        let node = flyout(menu.projectedValue, section.projectedValue).body.built

        XCTAssertEqual(node.type, "FlyoutPage")
        XCTAssertEqual(node.children.map { $0.id }, ["flyout", "detail"])
        XCTAssertEqual(node.children.map { $0.built.props["title"] },
                       [.string("Sections"), .string("today")])
    }

    /// Whether the pane is showing is a property, and it is the binding's
    /// value - nothing else says it, so there is nothing to disagree.
    func testWhetherItIsPresentedIsTheBindingsValue() {
        let menu = State<Bool>(true)
        let section = State<String>("today")

        let node = flyout(menu.projectedValue, section.projectedValue).body.built

        XCTAssertEqual(node.props["isPresented"], .bool(true))
    }

    /// Opening it from code is assigning the binding, and what goes out is one
    /// property - the pages themselves did not change.
    func testOpeningItIsAssigningTheBinding() {
        let menu = State<Bool>(false)
        let section = State<String>("today")
        let renders = Renders()

        renders.render(flyout(menu.projectedValue, section.projectedValue).body)

        menu.wrappedValue = true
        let patch = renders.render(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertEqual(patch.props["isPresented"], .bool(true))
        XCTAssertTrue(patch.children.isEmpty)
    }

    /// A row in the pane is a Button whose handler writes state - here two
    /// writes, "show this section" and "close the menu", which is why the
    /// library ships no flyout item type at all.
    func testARowIsAButtonThatWritesState() {
        let menu = State<Bool>(true)
        let section = State<String>("today")
        let renders = Renders()

        let patch = renders.render(flyout(menu.projectedValue, section.projectedValue).body)

        let archive = patch.child("flyout")?.children.first?.children.last
        XCTAssertTrue(renders.fire(archive?.events?["clicked"] ?? -1))

        XCTAssertEqual(section.wrappedValue, "archive")
        XCTAssertFalse(menu.wrappedValue, "and the pane closed itself on the way")

        // Which the next render says in one message: the detail page changed
        // and the pane is no longer showing.
        let next = renders.render(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertEqual(next.props["isPresented"], .bool(false))
        XCTAssertEqual(next.child("detail")?.props["title"], .string("archive"))
    }

    /// The two properties that say how the halves are laid out.
    func testTheLayoutIsTheFlyoutPagesOwnProperty() {
        let menu = State<Bool>(false)
        let section = State<String>("today")

        let node = flyout(menu.projectedValue, section.projectedValue)
            .flyoutLayoutBehavior(.split)
            .isGestureEnabled(false)
            .body
            .built

        XCTAssertEqual(node.props["flyoutLayoutBehavior"], .enumeration(2),
                       "FlyoutLayoutBehavior.Split")
        XCTAssertEqual(node.props["isGestureEnabled"], .bool(false))
    }

    /// The promise `testEveryModifierIsExercised` makes a control, kept here
    /// for a page: a modifier no message carries is one the host can leave out
    /// with nothing failing.
    func testEveryFlyoutPageModifierIsExercised() throws {
        let menu = State<Bool>(false)
        let section = State<String>("today")

        let sent = Set(
            flyout(menu.projectedValue, section.projectedValue)
                .flyoutLayoutBehavior(.popover)
                .isGestureEnabled(true)
                .body
                .built
                .props
                .keys
                .map(\.name))

        let declared = try Fixtures.propertyKeys(in: "FlyoutPage.swift")
        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            FlyoutPage.swift declares \(missing.joined(separator: ", ")), which \
            this test does not write.
            """)
    }

    // MARK: - The contract the C# side reads

    /// The whole thing, written down: a pane with two rows, a detail page that
    /// is a whole navigation stack, and the pane showing.
    func testTheFlyoutIsWrittenDown() throws {
        let menu = State<Bool>(true)
        let section = State<String>("today")
        let path = State<[Int]>([1])
        let differ = Differ()

        let tree = FlyoutPage(menu.projectedValue) {
            MenuPage(section: section.projectedValue, menu: menu.projectedValue)
        } detail: {
            NavigationPage(path.projectedValue) {
                DetailPage(section: "today")
            } destination: { depth in
                DetailPage(section: "level \(depth)")
            }
            .title("Diary")
            .barBackgroundColor(Color.fromArgb("#512BD4"))
        }
        .flyoutLayoutBehavior(.popover)
        .isGestureEnabled(false)
        .body

        let result = differ.reconcile(nil, with: tree)
        let bytes = Wire.encode(result.patch, generation: 1, dictionary: WireDictionary())

        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: WireNames()),
            against: "pages/FlyoutPage")
    }

    // MARK: - What comes back

    /// The one report: what is true now. A swipe, a tap outside the pane, the
    /// platform's own button - all of them arrive here.
    func testASwipeWritesTheBinding() {
        let menu = State<Bool>(false)
        let section = State<String>("today")
        let renders = Renders()

        let patch = renders.render(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["isPresentedChanged"] ?? -1, with: [.bool(true)]))
        XCTAssertTrue(menu.wrappedValue)
    }

    /// And a report saying what the binding already holds writes nothing -
    /// the rule that keeps a flyout the AUTHOR opened to one render.
    func testAReportOfWhatIsAlreadyTrueWritesNothing() {
        let menu = State<Bool>(true)
        let section = State<String>("today")
        let renders = Renders()

        let patch = renders.render(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["isPresentedChanged"] ?? -1, with: [.bool(true)]))

        XCTAssertTrue(menu.wrappedValue)
        XCTAssertTrue(renders.render(flyout(menu.projectedValue, section.projectedValue).body).isEmpty,
                      "nothing to say after it")
    }

    /// A payload of the wrong shape leaves the binding alone.
    func testAValueOfTheWrongKindLeavesTheBindingAlone() {
        let menu = State<Bool>(false)
        let section = State<String>("today")
        let renders = Renders()

        let patch = renders.render(flyout(menu.projectedValue, section.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["isPresentedChanged"] ?? -1,
                                   with: [.string("true")]))
        XCTAssertFalse(menu.wrappedValue)
    }
}
