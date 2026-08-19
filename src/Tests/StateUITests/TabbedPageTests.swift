// The tabs, as Swift describes them.
//
// A TabbedPage puts its tabs on the wire as its ARRANGED children - one page
// per tab, in order - and which one is showing as an INDEX into that same list.
// That is the whole protocol going out. Coming back there is one report - which
// page became current - and it writes the bound selection.
//
// What the renderer does with it is next door, in the C# TabbedPageTests.

import StateUIWireProbe
import XCTest
@testable import StateUI

/// An application's own tabs: a typed enum, which is what replaces an index.
private enum Tab: Hashable, CaseIterable {
    case home
    case browse
    case settings
}

private struct TabPage: ContentPage {
    let tab: Tab

    var title: String? { "\(tab)" }
    var iconImageSource: ImageSource? { ImageSource("\(tab).png") }
    var content: Element { label("\(tab)") }
}

/// The tab bar under test, over whatever selection is lent to it.
private func tabs(
    _ selection: Binding<Tab>,
    _ offered: [Tab] = Tab.allCases
) -> TabbedPage {
    TabbedPage(offered) { tab in
        TabPage(tab: tab)
    }
    .selection(selection)
}

final class TabbedPageTests: XCTestCase {
    // MARK: - What goes out

    /// The tabs ARE the children, in order, each identified by its own value.
    func testTheTabsAreTheChildrenOfTheNode() {
        let selection = State<Tab>(.home)
        let node = tabs(selection.projectedValue).body.built

        XCTAssertEqual(node.type, "TabbedPage")
        XCTAssertEqual(node.children.map { $0.id }, ["home", "browse", "settings"])
        XCTAssertEqual(node.children.map { $0.built.props["title"] },
                       [.string("home"), .string("browse"), .string("settings")])
    }

    /// A tab's caption and its picture are the PAGE's, which is where MAUI
    /// reads them from too - so a page written for a tab says them itself.
    func testATabsCaptionAndIconAreThePages() {
        let selection = State<Tab>(.home)
        let node = tabs(selection.projectedValue).body.built

        XCTAssertEqual(node.children.first?.built.props["iconImageSource"],
                       ImageSource("home.png").propValue)
    }

    /// Which tab is showing is a POSITION in the arranged list beside it - the
    /// same list, so the two cannot mean different things.
    func testTheSelectionIsAnIndexIntoTheChildren() {
        let selection = State<Tab>(.settings)
        let node = tabs(selection.projectedValue).body.built

        XCTAssertEqual(node.props["currentPage"], .number(2))
    }

    /// A selection naming no tab at all says NOTHING, deliberately: the
    /// platform is showing something, it reports which, and the binding is
    /// written to match on the way back. That is how a tab being taken away
    /// while it is showing resolves itself, with no rule of its own.
    func testASelectionThatNamesNoTabSaysNothing() {
        let selection = State<Tab>(.settings)
        let node = tabs(selection.projectedValue, [.home, .browse]).body.built

        XCTAssertNil(node.props["currentPage"])
        XCTAssertEqual(node.children.count, 2)
    }

    /// Identity is the tab's VALUE and nothing else - not its position, which
    /// is what lets the tabs be reordered without their pages being rebuilt.
    /// (A navigation stack is the other way round, and for a reason: the same
    /// route twice is a legal stack, the same tab twice is a mistake.)
    func testATabIsIdentifiedByItsValueAlone() {
        let selection = State<Tab>(.home)
        let renders = Renders()

        renders.render(tabs(selection.projectedValue).body)

        let patch = renders.render(
            tabs(selection.projectedValue, [.settings, .home, .browse]).body)

        XCTAssertTrue(patch.arranged, "the tabs moved, so the arrangement is described")
        XCTAssertEqual(patch.children.map { $0.id },
                       [.manual("settings"), .manual("home"), .manual("browse")])
        XCTAssertTrue(patch.children.allSatisfy { $0.isEmpty },
                      "every page moved and none of them was built again")
    }

    /// Choosing a tab from code is assigning the binding, and what goes out is
    /// one property - no rearrangement, because nothing was rearranged.
    func testChoosingATabIsAssigningTheBinding() {
        let selection = State<Tab>(.home)
        let renders = Renders()

        renders.render(tabs(selection.projectedValue).body)

        selection.wrappedValue = .browse
        let patch = renders.render(tabs(selection.projectedValue).body)

        XCTAssertEqual(patch.props["currentPage"], .number(1))
        XCTAssertFalse(patch.arranged, "the tabs themselves did not move")
        XCTAssertTrue(patch.children.isEmpty, "and none of the pages changed")
    }

    /// Tabs are data like anything else here, so a tab bar can grow.
    func testATabBarCanGrow() {
        let selection = State<Tab>(.home)
        let renders = Renders()

        renders.render(tabs(selection.projectedValue, [.home]).body)

        let patch = renders.render(tabs(selection.projectedValue, [.home, .settings]).body)

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.count, 2)
        XCTAssertTrue(patch.children[0].isEmpty, "the tab that was already there")
    }

    /// And a tab bar with nothing in it is describable - an application whose
    /// tabs are loaded starts there, and MAUI's own TabbedPage is empty until
    /// something is put in it.
    func testATabBarCanBeEmpty() {
        let selection = State<Tab>(.home)
        let node = tabs(selection.projectedValue, []).body.built

        XCTAssertEqual(node.children.count, 0)
        XCTAssertNil(node.props["currentPage"])
    }

    /// The ordinary shape of a tabbed application: every tab holds a stack of
    /// its own, and the tab's caption is the STACK's, given by modifier since a
    /// constructed page has no properties to answer with.
    func testATabCanHoldAWholeStack() {
        let selection = State<Tab>(.home)
        let path = State<[Int]>([1])

        let node = TabbedPage([Tab.home]) { _ in
            NavigationPage(path.projectedValue) {
                TabPage(tab: .home)
            } destination: { _ in
                TabPage(tab: .browse)
            }
            .title("Home")
            .iconImageSource("house.png")
        }
        .selection(selection.projectedValue)
        .body
        .built

        let stack = node.children[0].built

        XCTAssertEqual(stack.type, "NavigationPage")
        XCTAssertEqual(stack.id, "home", "the tab names the page in it")
        XCTAssertEqual(stack.props["title"], .string("Home"))
        XCTAssertEqual(stack.props["iconImageSource"], ImageSource("house.png").propValue)
        XCTAssertEqual(stack.children.count, 2, "the root and the one route")
    }

    // MARK: - The bar

    /// The tab bar's own colours - the three every bar has, and the two only a
    /// tab bar has.
    func testTheBarIsTheTabsOwnProperty() {
        let selection = State<Tab>(.home)

        let node = tabs(selection.projectedValue)
            .barBackgroundColor(Color.fromArgb("#512BD4"))
            .selectedTabColor(.white)
            .unselectedTabColor(Color.fromArgb("#B0A6E0"))
            .body
            .built

        XCTAssertEqual(node.props["barBackgroundColor"], Color("#512BD4").propValue)
        XCTAssertEqual(node.props["selectedTabColor"], Color("#FFFFFF").propValue)
        XCTAssertEqual(node.props["unselectedTabColor"], Color("#B0A6E0").propValue)
        XCTAssertNil(node.children.first?.built.props["selectedTabColor"],
                     "and not on the page under it")
    }

    /// The same promise `testEveryModifierIsExercised` makes a control. A page
    /// has no control fixture, so this is where a modifier of its own is
    /// covered - and it reads the SOURCE, so a property added tomorrow and
    /// written nowhere names itself here.
    func testEveryTabbedPageModifierIsExercised() throws {
        let selection = State<Tab>(.home)

        let sent = Set(
            tabs(selection.projectedValue)
                .barBackgroundColor(.black)
                .barBackground(.solidColor(.white))
                .barTextColor(.white)
                .selectedTabColor(.white)
                .unselectedTabColor(.black)
                .body
                .built
                .props
                .keys
                .map(\.name))

        let declared = try Fixtures.propertyKeys(in: "TabbedPage.swift")
        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            TabbedPage.swift declares \(missing.joined(separator: ", ")), which \
            this test does not write.

            A page has no control fixture - add the modifier here and read it \
            on the C# side.
            """)
    }

    // MARK: - The contract the C# side reads

    /// The whole thing, written down: a tab bar with its colours, a tab holding
    /// a navigation stack that carries its own caption, and a tab that is a
    /// plain page - with the second one showing.
    func testTheTabsAreWrittenDown() throws {
        let selection = State<Tab>(.settings)
        let path = State<[Int]>([])
        let differ = Differ()

        let tree = TabbedPage([Tab.home, .settings]) { tab in
            switch tab {
            case .home:
                return NavigationPage(path.projectedValue) {
                    TabPage(tab: .home)
                } destination: { _ in
                    TabPage(tab: .browse)
                }
                .title("Home")
                .iconImageSource("house.png")

            default:
                return TabPage(tab: tab)
            }
        }
        .selection(selection.projectedValue)
        .barBackgroundColor(Color.fromArgb("#512BD4"))
        .barTextColor(.white)
        .selectedTabColor(.white)
        .unselectedTabColor(Color.fromArgb("#B0A6E0"))
        .body

        let result = differ.reconcile(nil, with: tree)
        let bytes = Wire.encode(result.patch, generation: 1, dictionary: WireDictionary())

        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: WireNames()),
            against: "pages/TabbedPage")
    }

    // MARK: - What comes back

    /// The one report: which page is showing now. It writes the binding, and
    /// the render that follows finds the platform already right.
    func testAChosenTabIsWrittenToTheBinding() {
        let selection = State<Tab>(.home)
        let renders = Renders()

        let patch = renders.render(tabs(selection.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["currentPageChanged"] ?? -1, with: [.number(2)]))
        XCTAssertEqual(selection.wrappedValue, .settings)
    }

    /// A report about the tab already showing writes nothing. Both sides guard
    /// it - the host does not send one, and this does not act on one - because
    /// a binding written with the value it holds is a render nobody asked for.
    func testAReportForTheTabAlreadyShowingWritesNothing() {
        let selection = State<Tab>(.browse)
        let renders = Renders()

        let patch = renders.render(tabs(selection.projectedValue).body)
        let before = renders.render(tabs(selection.projectedValue).body)

        XCTAssertTrue(before.isEmpty, "nothing to say before the report either")
        XCTAssertTrue(renders.fire(patch.events?["currentPageChanged"] ?? -1, with: [.number(1)]))

        XCTAssertEqual(selection.wrappedValue, .browse)
        XCTAssertTrue(renders.render(tabs(selection.projectedValue).body).isEmpty,
                      "and nothing to say after it")
    }

    /// An index naming no tab leaves the selection alone - the rule every typed
    /// report in this library follows, and the one that makes a report arriving
    /// after the tabs changed harmless.
    func testAnIndexOutsideTheTabsLeavesTheSelectionAlone() {
        let selection = State<Tab>(.home)
        let renders = Renders()

        let patch = renders.render(tabs(selection.projectedValue, [.home, .browse]).body)
        let reported = patch.events?["currentPageChanged"] ?? -1

        XCTAssertTrue(renders.fire(reported, with: [.number(7)]))
        XCTAssertEqual(selection.wrappedValue, .home)

        XCTAssertTrue(renders.fire(reported, with: [.number(-1)]))
        XCTAssertEqual(selection.wrappedValue, .home)
    }

    /// A payload of the wrong shape leaves it alone too.
    func testAValueOfTheWrongKindLeavesTheSelectionAlone() {
        let selection = State<Tab>(.home)
        let renders = Renders()

        let patch = renders.render(tabs(selection.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["currentPageChanged"] ?? -1,
                                   with: [.string("settings")]))
        XCTAssertEqual(selection.wrappedValue, .home)
    }

    // MARK: - The selection is a modifier

    /// A tab bar with no selection at all: the tabs are still described, and
    /// nothing says which is current or listens for one.
    ///
    /// Which is what `Picker` without `selectedIndex` and `LazyList` without
    /// `selection` already do - the reason the binding moved out of the
    /// initializer is that it is the same kind of thing they take.
    func testTabsWithoutASelectionDescribeThemselvesAndReportNothing() {
        let node = TabbedPage(Tab.allCases) { TabPage(tab: $0) }.body.built

        XCTAssertEqual(node.children.map { $0.id }, ["home", "browse", "settings"])
        XCTAssertNil(node.props["currentPage"], "nothing says which tab is showing")
        XCTAssertTrue(node.events.isEmpty, "and nothing is listening for one")
    }

    /// A binding of a type the TABS are not - the one mistake erasing them to
    /// `AnyHashable` makes possible - names no tab and writes nothing.
    ///
    /// It cannot be caught at compile time: `selection` is generic over any
    /// `Hashable` because the page it sits on is not generic at all. So it
    /// behaves as a selection naming a tab that is not offered does, which is
    /// the neighbouring test above - no index out, no trap, and the host's
    /// report simply finds nothing to write.
    func testASelectionOfAnotherTypeEntirelyNamesNoTab() {
        let selection = State<String>("home")
        let renders = Renders()

        let page = TabbedPage(Tab.allCases) { TabPage(tab: $0) }
            .selection(selection.projectedValue)

        let patch = renders.render(page.body)

        XCTAssertNil(page.body.built.props["currentPage"],
                     "a String is not one of these tabs, whatever it spells")

        XCTAssertTrue(renders.fire(patch.events?["currentPageChanged"] ?? -1, with: [.number(2)]))
        XCTAssertEqual(selection.wrappedValue, "home", "and the report writes nothing")
    }
}
