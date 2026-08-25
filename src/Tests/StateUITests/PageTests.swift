// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a PAGE puts on the wire, and the guard that keeps the list complete.
//
// A page is not a control: it has no fixture in fixtures/controls/, it cannot
// be styled, and `Fixtures.controlSources()` skips the file it lives in. So
// the coverage a control gets for free - every modifier exercised, every
// property carried - has to be written here instead, and this is the file that
// writes it.
//
// Everything a page can say is declared in Views/Application.swift, beside the
// Window, so the guard below reads that file and insists the two exhaustive
// values in it carry every key: the page for a page's, the window for a
// window's.

import XCTest
@testable import StateUIWireProbe
@testable import StateUI

/// A page that says EVERYTHING a page can say.
///
/// Deliberately nonsensical as an interface - it asks for a tab icon and a
/// navigation bar at once, which no real page would. What it is for is the
/// guard below: a property nobody writes here is a property the host may
/// quietly not apply.
private struct EveryPropertyPage: ContentPage {
    var content: Element { Label("content") }

    // The page's own.
    var title: String? { "Everything" }
    var iconImageSource: ImageSource? { ImageSource("tab.png") }
    var padding: Thickness? { Thickness(4, 8, 12, 16) }
    var backgroundColor: Color? { .whiteSmoke }
    var hideSoftInputOnTapped: Bool? { true }
    var isBusy: Bool? { true }
    var backgroundImageSource: ImageSource? { ImageSource("backdrop.png") }
    var useSafeArea: Bool? { false }
    var modalPresentationStyle: UIModalPresentationStyle? { .pageSheet }

    // And its two events - the page is the only place either is covered, a
    // page having no control fixture.
    var onAppearing: EventHandler? { {} }
    var onDisappearing: EventHandler? { {} }
    var onNavigatedTo: EventHandler? { {} }
    var onNavigatingFrom: EventHandler? { {} }
    var onNavigatedFrom: EventHandler? { {} }

    // What it asks of a NavigationPage.
    var navigationPageHasNavigationBar: Bool? { false }
    var navigationPageHasBackButton: Bool? { false }
    var navigationPageBackButtonTitle: String? { "Back" }
    var navigationPageTitleIconImageSource: ImageSource? { ImageSource("mark.png") }
    var navigationPageIconColor: Color? { .red }
    var navigationPageTitleView: Element? { Label("stack title") }

    // What hangs off it either way, each saying everything ITS type can say -
    // a page is the only place a toolbar item or a menu entry is covered, there
    // being no control fixture for either.
    var toolbarItems: [ToolbarItem] {
        [
            ToolbarItem("Save")
                .iconImageSource(ImageSource("mark.png"))
                .order(.secondary)
                .priority(2)
                .isDestructive(true)
                .isEnabled(false)
                .onClicked {},
        ]
    }

    var menuBarItems: [MenuBarItem] {
        [
            MenuBarItem("File") {
                MenuFlyoutItem("Open")
                    .iconImageSource(ImageSource("mark.png"))
                    .isDestructive(true)
                    .isEnabled(false)
                    .onClicked {}

                MenuFlyoutSubItem("Recent") {
                    MenuFlyoutItem("Notes.txt")
                }
                .isEnabled(true)

                MenuFlyoutSeparator()
            }
            .isEnabled(true),
        ]
    }
}

/// A window that says everything a window can say.
private struct EveryPropertyWindow: Window {
    var title: String? { "Everything" }
    var x: Double? { 10 }
    var y: Double? { 20 }
    var width: Double? { 1200 }
    var height: Double? { 800 }
    var minimumWidth: Double? { 600 }
    var minimumHeight: Double? { 400 }
    var maximumWidth: Double? { 1600 }
    var maximumHeight: Double? { 1200 }
    var isMaximizable: Bool? { false }
    var isMinimizable: Bool? { true }

    var content: Page { EveryPropertyPage() }

    static var node: Node { EveryPropertyWindow().body.built }
}

final class PageTests: XCTestCase {
    // MARK: - The guard

    /// The same promise `testEveryModifierIsExercised` makes a control: a
    /// property the sources can write and no test carries is a property the
    /// renderer can quietly not implement.
    ///
    /// Application.swift declares the Application, the Window and the Page, so
    /// the two exhaustive values above are read TOGETHER - a window property is
    /// no less covered for not being a page's.
    func testEveryPropertyApplicationSwiftDeclaresIsCarried() throws {
        let sent = Self.keys(in: EveryPropertyPage().body.built)
            .union(Self.keys(in: EveryPropertyWindow.node))

        let declared = try Fixtures.propertyKeys(in: "Application.swift")
        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            Application.swift declares \(missing.joined(separator: ", ")), which \
            neither EveryPropertyPage nor EveryPropertyWindow writes.

            A page and a window have no control fixture - this is where their \
            properties are covered. Add it to the value above, and check the \
            renderer reads it on the C# side.
            """)
    }

    /// The same promise for what HANGS OFF a page - its toolbar items and its
    /// menus.
    ///
    /// They have no control fixture: a `ToolbarItem` is not a view and never
    /// appears in `fixtures/controls/`, so the guard in ControlTests cannot see
    /// one, and this page is the only place either is built with everything it
    /// can do. Measured when the tier guard was written: `order` and `priority`
    /// were carried by NOTHING - two arms of `ApplyToolbarItem` that no test had
    /// ever run.
    func testEveryPropertyAPagesItemsDeclareIsCarried() throws {
        let sent = Self.keys(in: EveryPropertyPage().body.built)

        for source in ["ToolbarItem.swift", "MenuBar.swift", "MenuItemElement.swift"] {
            let missing = try Fixtures.propertyKeys(in: source).subtracting(sent).sorted()

            XCTAssertTrue(missing.isEmpty, """
                \(source) declares \(missing.joined(separator: ", ")), which \
                EveryPropertyPage does not write.

                Add it to the items above - they are where a toolbar item and a \
                menu entry are covered - and check the renderer reads it.
                """)
        }
    }

    /// The guard above reads what the sources WRITE; this one reads what the
    /// protocol DECLARES, and they catch opposite mistakes.
    ///
    /// A property added to `ContentPage` and never written into `pageProps`
    /// reaches nothing and is invisible to a scan of the writes - it is exactly
    /// the mistake somebody makes while adding the seventh one, so it is the
    /// one worth failing on.
    func testEveryPagePropertyDeclaredIsAlsoSent() throws {
        // The requirements that ride as CHILDREN rather than as properties -
        // each becomes a node of its own. `content` is the page's own view and
        // the three below are checked by the test after this one.
        let slots: Set<String> = [
            "content", "navigationPageTitleView", "toolbarItems", "menuBarItems",
        ]

        // A page's EVENTS are declared beside its properties and travel
        // as handler ids rather than as props, so the scan reads both - the
        // requirement is the same one either way: declared and never sent is a
        // promise nothing keeps.
        let carried = Self.keys(in: EveryPropertyPage().body.built)
            .union(Self.handlers(in: EveryPropertyPage().body.built))

        let missing = try Self.declaredOnPage().subtracting(carried).subtracting(slots).sorted()

        XCTAssertTrue(missing.isEmpty, """
            The ContentPage protocol declares \(missing.joined(separator: ", ")), \
            which never reaches the wire.

            Every property a page can declare is written into `pageProps` in \
            Views/Application.swift, or hangs off it as a slot in `pageSlots`. \
            One that is declared and written nowhere is a property an author \
            can set and nothing will read.
            """)
    }

    /// Every requirement the `ContentPage` protocol declares, read out of the
    /// source.
    ///
    /// `ContentPage` rather than `Page`, and that is the point of the split:
    /// `Page` is the marker a CONSTRUCTED page wears too, and it declares
    /// nothing - a property declared there would be one a `NavigationPage`
    /// carries and can never answer. What a page can be told is what the page
    /// an author WRITES declares.
    ///
    /// Comment lines go first: the doc above each requirement shows how to
    /// write it, and a scan that read those examples would think the property
    /// was declared twice under a name from a sentence.
    private static func declaredOnPage() throws -> Set<String> {
        let source = try Fixtures.text(in: "Application.swift")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.drop(while: { $0 == " " }) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")

        guard let opening = source.range(of: "public protocol ContentPage: Page {"),
              let closing = source.range(of: "\n}", range: opening.upperBound..<source.endIndex)
        else {
            XCTFail("Views/Application.swift no longer declares `public protocol ContentPage: Page`")
            return []
        }

        return Set(
            String(source[opening.upperBound..<closing.lowerBound])
                .occurrences(between: "var ", and: ":")
                .map { $0.trimmingCharacters(in: .whitespaces) })
    }

    /// The other half of the same surface: what a page the library CONSTRUCTS
    /// is told by modifier, since a constructor's result has no properties to
    /// override. `PageElement.swift` has no fixture of its own for the reason a
    /// bar tier has none - there is no control to build one on.
    func testEveryPageElementModifierIsExercised() throws {
        let path = State<[Int]>([])

        let sent = Set(
            NavigationPage(path.projectedValue) { EveryPropertyPage() } destination: { _ in
                EveryPropertyPage()
            }
            .title("Home")
            .iconImageSource("house.png")
            .modalPresentationStyle(.formSheet)
            .body
            .built
            .props
            .keys
            .map(\.name))

        let declared = try Fixtures.propertyKeys(in: "PageElement.swift")
        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            PageElement.swift declares \(missing.joined(separator: ", ")), which \
            this test does not write.
            """)
    }

    /// And the two spellings are ONE property - the same key on the wire, so
    /// the host reads a page's name in one place whichever way it was said.
    func testTheTwoWaysOfNamingAPageAreOneProperty() {
        let path = State<[Int]>([])

        let written = EveryPropertyPage().body.built.props[.title]
        let constructed = NavigationPage(path.projectedValue) { EveryPropertyPage() }
            destination: { _ in EveryPropertyPage() }
            .title("Everything")
            .body
            .built
            .props[.title]

        XCTAssertEqual(written, constructed)
    }

    /// And the slots, which are children rather than properties: each rides as
    /// a wrapper node of its own, in a fixed order after the content, so a
    /// patch that carries one slot cannot be mistaken for the content.
    func testEveryPageSlotRidesAsItsOwnNode() {
        let page = EveryPropertyPage().body.built
        let slots = page.children.map { $0.type.name }

        XCTAssertEqual(
            slots,
            ["Label", "NavigationPageTitleView", "ToolbarItems", "MenuBarItems"],
            "the content first, then one node per slot, in a fixed order")
    }

    // MARK: - What the values look like

    /// A page's own properties are its own: `backgroundColor` is the PAGE's,
    /// where the bar above it takes `barBackgroundColor` on the arrangement -
    /// two different things, and one name if either were shortened.
    func testAPageCarriesItsOwnPropertiesUnderMauisNames() {
        let page = EveryPropertyPage().body.built

        XCTAssertEqual(page.props["title"], .string("Everything"))
        XCTAssertEqual(page.props["padding"], .numbers([4, 8, 12, 16]))
        XCTAssertEqual(page.props["backgroundColor"], Color("#F5F5F5").propValue)
        XCTAssertEqual(page.props["hideSoftInputOnTapped"], .bool(true))
    }

    /// The stack's attached properties are spelled with the class that
    /// declares them, which is what keeps them apart from the page's own: a
    /// page under no stack simply has them never read.
    func testAPageCarriesTheStacksAttachedPropertiesUnderItsName() {
        let page = EveryPropertyPage().body.built

        XCTAssertEqual(page.props["navigationPageHasNavigationBar"], .bool(false))

        XCTAssertEqual(page.props["navigationPageHasBackButton"], .bool(false))
        XCTAssertEqual(page.props["navigationPageBackButtonTitle"], .string("Back"))
        XCTAssertEqual(page.props["navigationPageTitleIconImageSource"], .string("mark.png"))
        XCTAssertEqual(page.props["navigationPageIconColor"], Color("#FF0000").propValue)
    }

    /// A page that says nothing sends nothing, so MAUI's own defaults stand -
    /// the rule that lets a page write only what it wants different.
    func testAPageThatSaysNothingCarriesNothing() {
        struct Plain: ContentPage {
            var content: Element { Label("plain") }
        }

        let page = Plain().body.built

        XCTAssertEqual(page.props.count, 0)
        XCTAssertEqual(page.children.count, 1, "the content, and no slot it did not ask for")
    }

    /// Every property name in one place, however deep it sits.
    private static func keys(in node: Node) -> Set<String> {
        node.children.reduce(into: Set(node.props.keys.map(\.name))) { names, child in
            names.formUnion(keys(in: child))
        }
    }

    /// The same for what the node HANDLES, under the name the protocol
    /// requirement carries: an `onAppearing` is the `appearing` event, the way
    /// a window's six are.
    private static func handlers(in node: Node) -> Set<String> {
        let mine = node.events.keys.map { "on" + $0.name.prefix(1).uppercased() + $0.name.dropFirst() }

        return node.children.reduce(into: Set(mine)) { names, child in
            names.formUnion(handlers(in: child))
        }
    }

    /// MAUI's own tap-to-dismiss, which is why this library adds no
    /// tap-catching view of its own - one laid over the content would have to
    /// let scrolls, buttons and gestures through, and MAUI's recognizer already
    /// runs alongside them.
    func testAPageCanGiveTheKeyboardBackOnATapBesideTheField() {
        struct FormPage: ContentPage {
            var content: Element { Label("form") }

            var hideSoftInputOnTapped: Bool? { true }
        }

        struct Plain: ContentPage {
            var content: Element { Label("plain") }
        }

        XCTAssertEqual(FormPage().body.built.props["hideSoftInputOnTapped"], .bool(true))

        XCTAssertNil(
            Plain().body.built.props["hideSoftInputOnTapped"],
            "a page that says nothing leaves the platform's own behaviour alone")
    }

    /// A page whose TOP is a picture says so, and the inset the platform would
    /// have taken is the difference between a banner and a banner with a strip
    /// of the page's own colour above it.
    func testAPageCanRunUnderTheBars() {
        struct Banner: ContentPage {
            var content: Element { Label("banner") }

            var useSafeArea: Bool? { false }
        }

        struct Bare: ContentPage {
            var content: Element { Label("plain") }
        }

        XCTAssertEqual(Banner().body.built.props["useSafeArea"], .bool(false))

        XCTAssertNil(
            Bare().body.built.props["useSafeArea"],
            "a page that says nothing keeps the platform's own inset")
    }

    // MARK: - The page's own events

    /// A page's arrival and departure ride as HANDLERS on the page node, the
    /// way a window's six lifecycle events ride on its own - a page is not a
    /// view, and the differ has never cared.
    ///
    /// Five of them: the two that answer the page being on screen at all, and
    /// the three that answer a MOVE - which are not the same question, since a
    /// page appears again when the application wakes and nothing navigated.
    func testAPagesArrivalAndDepartureRideAsItsEvents() {
        let node = EveryPropertyPage().body.built

        XCTAssertEqual(
            node.events.keys.map(\.name).sorted(),
            ["appearing", "disappearing", "navigatedFrom", "navigatedTo", "navigatingFrom"])
    }

    /// A page that listens to neither says neither - an absent event costs a
    /// handler id and a name on the wire, and a page usually wants no such
    /// thing.
    func testAPageThatListensToNothingSendsNoHandlers() {
        struct Plain: ContentPage {
            var content: Element { Label("plain") }
        }

        XCTAssertTrue(Plain().body.built.events.isEmpty)
    }

    /// The handler RUNS, which is the half a node's shape cannot show: the
    /// differ registers it under an id, and firing that id is what the host
    /// does when the platform raises Appearing.
    func testAPagesArrivalHandlerRuns() throws {
        let arrivals = State(0)

        struct Watched: ContentPage {
            let arrivals: Binding<Int>

            var content: Element { Label("watched") }

            var onAppearing: EventHandler? {
                { arrivals.wrappedValue += 1 }
            }
        }

        let renders = Renders()
        let patch = renders.render(Watched(arrivals: arrivals.projectedValue).body)
        let appearing = try XCTUnwrap(Self.appearing(in: patch))

        XCTAssertTrue(renders.fire(appearing))
        XCTAssertEqual(arrivals.wrappedValue, 1)

        // And again on the next arrival: MAUI raises it on every one, which is
        // what makes it the place to refresh what may have changed while the
        // page was covered.
        XCTAssertTrue(renders.fire(appearing))
        XCTAssertEqual(arrivals.wrappedValue, 2)
    }

    /// The id the `appearing` handler was registered under, at any depth.
    private static func appearing(in patch: Patch) -> Int? {
        if let id = patch.events?["appearing"] { return id }

        for child in patch.children {
            if let hit = appearing(in: child) { return hit }
        }

        return nil
    }

    /// The page is written down whole, so the C# side applies the same bytes -
    /// its properties, its two handlers and everything hanging off it.
    ///
    /// Under `pages/` rather than `controls/`, the NavigationPage rule: a
    /// fixture in `controls/` is walked by the C# StyleTests, which would then
    /// insist every property in it can be set by a Style, and a page's cannot.
    func testThePageIsWrittenDown() throws {
        let differ = Differ()
        let result = differ.reconcile(nil, with: EveryPropertyPage().body)
        let bytes = Wire.encode(result.patch, generation: 1, dictionary: WireDictionary())

        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: WireNames()),
            against: "pages/ContentPage")
    }
}
