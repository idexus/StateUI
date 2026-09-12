// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a PAGE puts on the wire, and the guards that keep the list complete.
//
// A page is not a control: it has no fixture in fixtures/controls/, it cannot
// be styled, and `Fixtures.controlSources()` skips the file it lives in. So
// the coverage a control gets for free - every modifier exercised, every
// property carried - has to be written here instead, and this is the file that
// writes it.
//
// Everything a page can be told is its session's, in Types/PageSession.swift,
// and everything a window can be told is its window session's, in
// Types/HostEnvironment.swift - so the guards below read both files and insist
// the two exhaustive values in this one carry every key: the page for a
// page's, the window for a window's. A page writes its session from its own
// `.onCreated`, and what that writes is in the message that brings the page -
// so what a page carries is read off `Renders.settled`, which runs it the way
// the renderer does.

import XCTest
@testable import StateUIWireProbe
@testable import StateUI

/// A page that writes EVERYTHING a page's session holds, as it comes into the
/// tree.
///
/// Deliberately nonsensical as an interface - it asks for a tab icon and a
/// navigation bar at once, which no real page would. What it is for is the
/// guards below: a property nobody writes here is a property the host may
/// quietly not apply.
private struct EveryPropertyPage: ContentPage {
    @Environment private var page: PageSession

    var content: any View {
        Label("content").onCreated {
            // The page's own.
            page.title = "Everything"
            page.iconImageSource = ImageSource("tab.png")
            page.padding = Thickness(4, 8, 12, 16)
            page.backgroundColor = .whiteSmoke
            page.hideSoftInputOnTapped = true
            page.backgroundImageSource = ImageSource("backdrop.png")
            page.useSafeArea = false
            page.modalPresentationStyle = .pageSheet

            // What it asks of a NavigationPage.
            page.navigationPageHasNavigationBar = false
            page.navigationPageHasBackButton = false
            page.navigationPageBackButtonTitle = "Back"
            page.navigationPageTitleIconImageSource = ImageSource("mark.png")
            page.navigationPageIconColor = .red
            page.navigationPageTitleView = Label("stack title")

            // What hangs off it either way, each saying everything ITS type
            // can say - a page is the only place a toolbar item or a menu entry
            // is covered, there being no control fixture for either.
            page.toolbarItems = [
                ToolbarItem("Save")
                    .automationId("bar.save")
                    .iconImageSource(ImageSource("mark.png"))
                    .order(.secondary)
                    .priority(2)
                    .isDestructive(true)
                    .isEnabled(false)
                    .onClicked {},
            ]

            page.menuBarItems = [
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
}

/// A window whose session says everything a window can be told.
private struct EveryPropertyWindow: Window {
    var page: any Page { EveryPropertyPage() }

    static var node: Node {
        let session = WindowSession()
        session.title = "Everything"
        session.x = 10
        session.y = 20
        session.width = 1200
        session.height = 800
        session.minimumWidth = 600
        session.minimumHeight = 400
        session.maximumWidth = 1600
        session.maximumHeight = 1200
        session.isMaximizable = false
        session.isMinimizable = true

        return EveryPropertyWindow().body(panel: nil, session: session).built
    }
}

/// A page that dresses its whole session as it arrives, and again - every
/// property to another value - on a press. So the write that matters is made
/// once the page is standing, and what the next message carries is what the
/// page READ of its session, nothing else having moved.
private struct KnobPage: ContentPage {
    @Environment private var page: PageSession

    var content: any View {
        Button("dress")
            .onCreated { dress(false) }
            .onClicked { dress(true) }
    }

    /// Writes every property of the page's session, each to one of two values.
    private func dress(_ on: Bool) {
        page.title = on ? "On" : "Off"
        page.iconImageSource = ImageSource(on ? "on.png" : "off.png")
        page.padding = Thickness(on ? 8 : 4)
        page.backgroundColor = on ? .red : .whiteSmoke
        page.hideSoftInputOnTapped = on
        page.backgroundImageSource = ImageSource(on ? "a.png" : "b.png")
        page.useSafeArea = on
        page.modalPresentationStyle = on ? .pageSheet : .fullScreen

        page.navigationPageHasNavigationBar = on
        page.navigationPageHasBackButton = on
        page.navigationPageBackButtonTitle = on ? "Back" : "Return"
        page.navigationPageTitleIconImageSource = ImageSource(on ? "x.png" : "y.png")
        page.navigationPageIconColor = on ? .red : .whiteSmoke
        page.navigationPageTitleView = Label(on ? "on" : "off")

        page.toolbarItems = [ToolbarItem(on ? "On" : "Off")]
        page.menuBarItems = [MenuBarItem(on ? "On" : "Off") { MenuFlyoutItem("Open") }]
    }
}

final class PageTests: XCTestCase {
    // MARK: - The guards

    /// The same promise `testEveryModifierIsExercised` makes a control: a
    /// property the sources can write and no test carries is a property the
    /// renderer can quietly not implement.
    ///
    /// A page's properties are written onto its node by its session, in
    /// PageSession.swift, and a window's by its own, in HostEnvironment.swift,
    /// both nodes being built in Application.swift - so the two exhaustive
    /// values above are read against all three files, a window property being
    /// no less covered for not being a page's.
    func testEveryPropertyAPageOrAWindowCanBeToldIsCarried() throws {
        let sent = Self.keys(in: Self.arrived(EveryPropertyPage()))
            .union(Self.keys(in: EveryPropertyWindow.node))

        let page = try Fixtures.propertyKeys(in: "PageSession.swift")
        let window = try Fixtures.propertyKeys(in: "HostEnvironment.swift")

        XCTAssertTrue(page.contains("title"), "the scan found nothing PageSession.swift writes")
        XCTAssertTrue(window.contains("width"), "the scan found nothing HostEnvironment.swift writes")

        let declared = try page.union(window).union(Fixtures.propertyKeys(in: "Application.swift"))
        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            A page's or a window's session writes \
            \(missing.joined(separator: ", ")), which neither EveryPropertyPage \
            nor EveryPropertyWindow carries.

            A page and a window have no control fixture - this is where their \
            properties are covered. Write it in the value above, and check the \
            renderer reads it on the C# side.
            """)
    }

    /// A page's properties are read off its session as the page builds, so
    /// the page is a reader of every one of them: a write made once the page
    /// is standing builds it again, and the message carries each property that
    /// moved - EVERY property the session declares, read off the declarations,
    /// its three slots included.
    func testEveryPagePropertyFollowsTheStateItReads() throws {
        let renders = Renders()
        let first = renders.settled(KnobPage().body)
        let dress = try XCTUnwrap(first.children.first?.events?[.clicked])

        XCTAssertTrue(renders.fire(dress))
        XCTAssertTrue(Renderer.shared.needsRender, "the page read its session, so a write asks")

        // Nothing the page was built with changed, so it is built again only
        // because it READ what the press wrote.
        let patch = renders.settled(KnobPage().body, changed: Renderer.shared.pendingChanges)
        let missing = try Self.declaredOnPage().subtracting(Self.carried(by: patch)).sorted()

        XCTAssertTrue(
            missing.isEmpty,
            "a state the page's properties read moved, and the message left out: "
                + missing.joined(separator: ", "))
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
        let sent = Self.keys(in: Self.arrived(EveryPropertyPage()))

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
    /// session DECLARES, and they catch opposite mistakes.
    ///
    /// A property added to `PageSession` and never written into its `props` or
    /// its `slots` reaches nothing and is invisible to a scan of the writes -
    /// it is exactly the mistake somebody makes while adding the seventeenth
    /// one, so it is the one worth failing on.
    func testEveryPagePropertyDeclaredIsAlsoSent() throws {
        let carried = Self.carried(by: Self.arrived(EveryPropertyPage()))
        let missing = try Self.declaredOnPage().subtracting(carried).sorted()

        XCTAssertTrue(missing.isEmpty, """
            PageSession declares \(missing.joined(separator: ", ")), which never \
            reaches the wire.

            Every property a page's session holds is written into its `props` \
            in Types/PageSession.swift, or hangs off the page as a node in its \
            `slots`. One that is declared and written nowhere is a property an \
            author can set and nothing will read.
            """)
    }

    /// Every property `PageSession` declares for an author to write, read out
    /// of the source - its `@State public var`s. The phase is the page's to
    /// report and nobody's to write, `public internal(set)`, so the scan passes
    /// over it.
    ///
    /// `PageSession` rather than the `ContentPage` protocol, and that is the
    /// point of the split: a page DECLARES only its content, and what it can be
    /// told is its session's state. `Page` is the marker a CONSTRUCTED page
    /// wears too, and declares nothing - a constructed page is told what it is
    /// by modifier.
    ///
    /// Comment lines go first: the doc above each property shows how to write
    /// it, and a scan that read those examples would think the property was
    /// declared twice under a name from a sentence.
    private static func declaredOnPage() throws -> Set<String> {
        let source = try Fixtures.text(in: "PageSession.swift")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.drop(while: { $0 == " " }) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")

        let declared = Set(
            source.occurrences(between: "@State public var ", and: ":")
                .map { $0.trimmingCharacters(in: .whitespaces) })

        XCTAssertTrue(
            declared.contains("title") && declared.contains("toolbarItems"),
            "Types/PageSession.swift no longer declares `@State public var title` - the scan read nothing")

        return declared
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

        let written = Self.arrived(EveryPropertyPage()).props[.title]
        let constructed = NavigationPage(path.projectedValue) { EveryPropertyPage() }
            destination: { _ in EveryPropertyPage() }
            .title("Everything")
            .body
            .built
            .props[.title]

        XCTAssertEqual(written, .string("Everything"), "the title the page wrote never arrived")
        XCTAssertEqual(written, constructed)
    }

    /// And the slots, which are children rather than properties: each rides as
    /// a wrapper node of its own, in a fixed order after the content, so a
    /// patch that carries one slot cannot be mistaken for the content.
    func testEveryPageSlotRidesAsItsOwnNode() {
        let slots = Self.arrived(EveryPropertyPage()).children.map { $0.type.name }

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
        let page = Self.arrived(EveryPropertyPage())

        XCTAssertEqual(page.props["title"], .string("Everything"))
        XCTAssertEqual(page.props["padding"], .numbers([4, 8, 12, 16]))
        XCTAssertEqual(page.props["backgroundColor"], Color("#F5F5F5").propValue)
        XCTAssertEqual(page.props["hideSoftInputOnTapped"], .bool(true))
    }

    /// The stack's attached properties are spelled with the class that
    /// declares them, which is what keeps them apart from the page's own: a
    /// page under no stack simply has them never read.
    func testAPageCarriesTheStacksAttachedPropertiesUnderItsName() {
        let page = Self.arrived(EveryPropertyPage())

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
            var content: any View { Label("plain") }
        }

        let page = Plain().body.built

        XCTAssertEqual(page.props.count, 0)
        XCTAssertEqual(page.children.count, 1, "the content, and no slot it did not ask for")
    }

    /// What a page's first message carries - its `.onCreated` run, and what it
    /// wrote walked in, the way the renderer sends it.
    private static func arrived(_ page: some ContentPage) -> Patch {
        Renders().settled(page.body)
    }

    /// Every property name in one place, however deep it sits.
    private static func keys(in node: Node) -> Set<String> {
        node.children.reduce(into: Set(node.props.keys.map(\.name))) { names, child in
            names.formUnion(keys(in: child))
        }
    }

    /// The same, in a patch.
    private static func keys(in patch: Patch) -> Set<String> {
        patch.children.reduce(into: Set(patch.props.keys.map(\.name))) { names, child in
            names.formUnion(keys(in: child))
        }
    }

    /// What a page's patch carries of its session, under the name each is
    /// declared by: its own properties, and each slot hanging off it as a node
    /// named for the property it rides - `NavigationPageTitleView` for
    /// `navigationPageTitleView`.
    private static func carried(by patch: Patch) -> Set<String> {
        let slots = patch.children.map { child -> String in
            let name = child.type.name
            return name.prefix(1).lowercased() + name.dropFirst()
        }

        return Set(patch.props.keys.map(\.name)).union(slots)
    }

    /// MAUI's own tap-to-dismiss, which is why this library adds no
    /// tap-catching view of its own - one laid over the content would have to
    /// let scrolls, buttons and gestures through, and MAUI's recognizer already
    /// runs alongside them.
    func testAPageCanGiveTheKeyboardBackOnATapBesideTheField() {
        struct FormPage: ContentPage {
            @Environment private var page: PageSession

            var content: any View {
                Label("form").onCreated { page.hideSoftInputOnTapped = true }
            }
        }

        struct Plain: ContentPage {
            var content: any View { Label("plain") }
        }

        XCTAssertEqual(Self.arrived(FormPage()).props["hideSoftInputOnTapped"], .bool(true))

        XCTAssertNil(
            Self.arrived(Plain()).props["hideSoftInputOnTapped"],
            "a page that says nothing leaves the platform's own behaviour alone")
    }

    /// A page whose TOP is a picture says so, and the inset the platform would
    /// have taken is the difference between a banner and a banner with a strip
    /// of the page's own colour above it.
    func testAPageCanRunUnderTheBars() {
        struct Banner: ContentPage {
            @Environment private var page: PageSession

            var content: any View {
                Label("banner").onCreated { page.useSafeArea = false }
            }
        }

        struct Bare: ContentPage {
            var content: any View { Label("plain") }
        }

        XCTAssertEqual(Self.arrived(Banner()).props["useSafeArea"], .bool(false))

        XCTAssertNil(
            Self.arrived(Bare()).props["useSafeArea"],
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

    /// EVERY content page carries the five, whatever it writes: they are what
    /// move its session's `phase`, which anything in the page may watch - so a
    /// page is heard arriving whether it says one word about itself or all of
    /// them.
    func testEveryContentPageCarriesItsFiveEventsWhateverItWrites() {
        struct Plain: ContentPage {
            var content: any View { Label("plain") }
        }

        let five = ["appearing", "disappearing", "navigatedFrom", "navigatedTo", "navigatingFrom"]

        XCTAssertEqual(
            Self.arrived(Plain()).events?.keys.map(\.name).sorted(), five,
            "a page that writes nothing")

        XCTAssertEqual(
            Self.arrived(EveryPropertyPage()).events?.keys.map(\.name).sorted(), five,
            "a page that writes everything")
    }

    /// The handler RUNS, which is the half a node's shape cannot show: the
    /// differ registers it under an id, firing that id is what the host does
    /// when the platform raises Appearing, and what it does is move the page
    /// session's `phase` - which a view in the page watching it sees on the
    /// render that follows.
    func testAPagesArrivalHandlerRuns() throws {
        let arrivals = State(0)

        struct Watched: ContentPage {
            @Environment private var page: PageSession
            let arrivals: Binding<Int>

            var content: any View {
                Label("\(page.phase)")
                    .onChanged(page.phase) {
                        if page.phase == .appearing { arrivals.wrappedValue += 1 }
                    }
            }
        }

        let renders = Renders()
        let first = renders.settled(Watched(arrivals: arrivals.projectedValue).body)
        let events = try XCTUnwrap(first.events)

        XCTAssertEqual(first.children.first?.props[.text], .string("created"))

        /// Fires one of the page's reports, and answers the render that follows.
        func report(_ event: Event) throws -> Patch {
            XCTAssertTrue(renders.fire(try XCTUnwrap(events[event])))

            return renders.settled(
                Watched(arrivals: arrivals.projectedValue).body,
                changed: Renderer.shared.pendingChanges)
        }

        let arrived = try report(.appearing)

        XCTAssertEqual(
            arrived.children.first?.props[.text], .string("appearing"),
            "the report moved the phase, and the page read it")
        XCTAssertEqual(arrivals.wrappedValue, 1)

        // And again on the next arrival: MAUI raises it on every one, which is
        // what makes it the place to refresh what may have changed while the
        // page was covered.
        _ = try report(.disappearing)
        XCTAssertEqual(arrivals.wrappedValue, 1, "a departure is no arrival")

        _ = try report(.appearing)
        XCTAssertEqual(arrivals.wrappedValue, 2)
    }

    /// The page is written down whole, so the C# side applies the same bytes -
    /// its properties, its five handlers and everything hanging off it, as
    /// the message that brings it carries them.
    ///
    /// Under `pages/` rather than `controls/`, the NavigationPage rule: a
    /// fixture in `controls/` is walked by the C# StyleTests, which would then
    /// insist every property in it can be set by a Style, and a page's cannot.
    func testThePageIsWrittenDown() throws {
        let bytes = Wire.encode(
            Self.arrived(EveryPropertyPage()), generation: 1, dictionary: WireDictionary())

        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: WireNames()),
            against: "pages/ContentPage")
    }
}
