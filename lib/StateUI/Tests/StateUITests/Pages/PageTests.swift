// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a PAGE puts in the patch, and the guards that keep the list complete.
//
// A page is not a control: it has no case in ControlTests, it cannot
// be styled, and `Fixtures.controlSources()` skips the file it lives in. So
// the coverage a control gets for free - every modifier exercised, every
// property carried - has to be written here instead, and this is the file that
// writes it.
//
// Everything a page can be told is its session's, in
// PageSession.swift, and everything a window can be told is its
// window session's, in WindowSession.swift - so the guards
// below read both files and insist the two exhaustive values in this one
// carry every key: the page for a page's, the window for a window's. A page
// writes its session from its own `.onCreated`, and what that writes is in
// the message that brings the page - so what a page carries is read off
// `Renders.settled`, which runs it the way the renderer does.

import XCTest
@_spi(Host) @testable import StateUI

/// A page that writes EVERYTHING a page's session holds, as it comes into the
/// tree.
///
/// Deliberately nonsensical as an interface - it asks for a tab icon and a
/// navigation bar at once, which no real page would. What it is for is the
/// guards below: a property nobody writes here is a property the host may
/// quietly not apply.
private struct EveryPropertyPage: ContentView {
    @Environment private var page: PageSession

    var content: any View {
        Label("content").onCreated {
            // The page's own.
            page.title = "Everything"
            page.icon = ImageSource("tab.png")
            page.padding = Insets(4, 8, 12, 16)
            page.background = .whiteSmoke

            // What it asks of a NavigationStack.
            page.hasNavigationBar = false
            page.hasBackButton = false
            page.backButtonTitle = "Back"
            page.titleView = Label("stack title")

            // What hangs off it either way, each saying everything ITS type
            // can say - a page is the only place a toolbar item or a menu entry
            // is covered, there being no control case for either.
            page.toolbarItems = [
                ToolbarItem("Save")
                    .accessibilityIdentifier("bar.save")
                    .icon(ImageSource("mark.png"))
                    .placement(.overflow)
                    .priority(2)
                    .isDestructive(true)
                    .isEnabled(false)
                    .onClicked {},
            ]

            page.menuBar = [
                Menu("File") {
                    MenuItem("Open")
                        .icon(ImageSource("mark.png"))
                        .isDestructive(true)
                        .isEnabled(false)
                        .onClicked {}

                    Menu("Recent") {
                        MenuItem("Notes.txt")
                    }
                    .isEnabled(true)

                    MenuSeparator()
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
        session.isTranslucent = true

        return EveryPropertyWindow().body(panel: nil, session: session).built
    }
}

/// A page that dresses its whole session as it arrives, and again - every
/// property to another value - on a press. So the write that matters is made
/// once the page is standing, and what the next message carries is what the
/// page READ of its session, nothing else having moved.
private struct KnobPage: ContentView {
    @Environment private var page: PageSession

    var content: any View {
        Button("dress")
            .onCreated { dress(false) }
            .onClicked { dress(true) }
    }

    /// Writes every property of the page's session, each to one of two values.
    private func dress(_ on: Bool) {
        page.title = on ? "On" : "Off"
        page.icon = ImageSource(on ? "on.png" : "off.png")
        page.padding = Insets(on ? 8 : 4)
        page.background = on ? .red : .whiteSmoke

        page.hasNavigationBar = on
        page.hasBackButton = on
        page.backButtonTitle = on ? "Back" : "Return"
        page.titleView = Label(on ? "on" : "off")

        page.toolbarItems = [ToolbarItem(on ? "On" : "Off")]
        page.menuBar = [Menu(on ? "On" : "Off") { MenuItem("Open") }]
    }
}

/// A view that says nothing about the page it is shown on.
private struct Plain: ContentView {
    var content: any View { Label("plain") }
}

/// A view that names the page it is shown on, as it arrives.
private struct Named: ContentView {
    @Environment private var page: PageSession
    let name: String

    var content: any View {
        Label(name).onCreated { page.title = name }
    }
}

/// How often what a view is made of was read.
private final class Builds {
    var count = 0
}

/// A view that renames its page on a press, counting its builds.
private struct Renaming: ContentView {
    @Environment private var page: PageSession
    let builds: Builds

    var content: any View {
        builds.count += 1
        return Button("rename").onClicked { page.title = "Renamed" }
    }
}

final class PageTests: XCTestCase {
    // MARK: - A view shown as a page

    /// The page holds its session while the same view stands on it: the parent
    /// building again hands the page a fresh value of the view, and the page
    /// keeps what the first one wrote.
    func testAPageKeepsItsSessionWhileTheSameViewStandsOnIt() {
        let renders = Renders()
        let first = renders.settled(Node.page(Named(name: "Home")))
        let again = renders.settled(Node.page(Named(name: "Home")))

        XCTAssertEqual(first.props[.title], .string("Home"))
        XCTAssertNil(again.props[.title], "the title stands, so nothing is said about it")
        XCTAssertEqual(again.cleared, [], "and nothing is taken off the page")
    }

    /// Another view standing there is another page: it starts with a session
    /// of its own, and nothing the view before it wrote is left on it.
    func testAnotherViewOnThePageStartsASessionOfItsOwn() {
        let renders = Renders()
        renders.settled(Node.page(Named(name: "Home")))
        let other = renders.settled(Node.page(Plain()))

        XCTAssertEqual(other.cleared, ["title"], "the title was the view before's")
    }

    /// The same kind of view under another explicit id is another view, and
    /// so another page.
    func testTheSameViewUnderAnotherIdStartsASessionOfItsOwn() {
        let renders = Renders()
        renders.settled(Node.page(Named(name: "Home").id("one")))
        let other = renders.settled(Node.page(Named(name: "Away").id("two")))

        XCTAssertEqual(other.props[.title], .string("Away"), "the page the second view arrived on")
    }

    /// A write to the page's session builds the page again and carries the
    /// view on it whole: the view read nothing the write moved.
    func testAWriteToThePageCarriesTheViewWhole() throws {
        let builds = Builds()
        let renders = Renders()
        let first = renders.settled(Node.page(Renaming(builds: builds)))
        let rename = try XCTUnwrap(first.children.first?.events?[.clicked])

        XCTAssertEqual(builds.count, 1)
        XCTAssertTrue(renders.fire(rename))

        let second = renders.settled(
            Node.page(Renaming(builds: builds)), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(second.props[.title], .string("Renamed"))
        XCTAssertEqual(builds.count, 1, "the view was built again for a write it never read")
    }

    /// A view with no element of its own - a control, a stack - is shown the
    /// same way, and follows its parent: what the parent builds it with is on
    /// the page in the next message.
    func testAPlainViewOnAPageFollowsItsParent() {
        let renders = Renders()
        renders.settled(Node.page(Label("one")))
        let second = renders.settled(Node.page(Label("two")))

        XCTAssertEqual(second.children.first?.props[.text], .string("two"))
    }

    /// What is written ON a view shown as a page is the view's, whichever kind
    /// of view it is: the page carries its session's properties, and the view
    /// on it its own.
    func testWhatIsWrittenOnAViewStaysOnTheView() {
        let written: [any View] = [
            Plain().background(.red),
            Label("plain").background(.red),
        ]

        for view in written {
            let page = Node.page(view).built

            XCTAssertEqual(page.type, .page)
            XCTAssertNil(page.props[.background], "the page's colour is its session's")
            XCTAssertEqual(page.children.first?.props[.background], Color.red.propValue)
        }
    }

    /// An arrangement is a page already, and is shown as it is.
    func testAnArrangementIsShownAsItIs() {
        let path = State<[Int]>([])
        let stack = NavigationStack(path.projectedValue) { Plain() } destination: { _ in Plain() }

        XCTAssertEqual(Node.page(stack).built.type, .navigationStack)
        XCTAssertEqual(Node.page(stack).built.children.first?.type, .page)
    }

    // MARK: - The guards

    /// The same promise `testEveryModifierIsExercised` makes a control: a
    /// property the sources can write and no test carries is a property the
    /// renderer can quietly not implement.
    ///
    /// A page's properties are written onto its node by its session, in
    /// PageSession.swift, and a window's by its own, in WindowSession.swift,
    /// both nodes being built in Application.swift - so the two exhaustive
    /// values above are read against all three files, a window property being
    /// no less covered for not being a page's.
    func testEveryPropertyAPageOrAWindowCanBeToldIsCarried() throws {
        let sent = Self.keys(in: Self.arrived(EveryPropertyPage()))
            .union(Self.keys(in: EveryPropertyWindow.node))

        let page = try Fixtures.propertyKeys(in: "PageSession.swift")
        let window = try Fixtures.propertyKeys(in: "WindowSession.swift")

        XCTAssertTrue(page.contains("title"), "the scan found nothing PageSession.swift writes")
        XCTAssertTrue(window.contains("width"), "the scan found nothing WindowSession.swift writes")

        let declared = try page.union(window).union(Fixtures.propertyKeys(in: "Application.swift"))
        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            A page's or a window's session writes \
            \(missing.joined(separator: ", ")), which neither EveryPropertyPage \
            nor EveryPropertyWindow carries.

            A page and a window have no control case - this is where their \
            properties are covered. Write it in the value above, and check the \
            host contract reads it.
            """)
    }

    /// A page's properties are read off its session as the page builds, so
    /// the page is a reader of every one of them: a write made once the page
    /// is standing builds it again, and the message carries each property that
    /// moved - EVERY property the session declares, read off the declarations,
    /// its three slots included.
    func testEveryPagePropertyFollowsTheStateItReads() throws {
        let renders = Renders()
        let first = renders.settled(Node.page(KnobPage()))
        let dress = try XCTUnwrap(first.children.first?.events?[.clicked])

        XCTAssertTrue(renders.fire(dress))
        XCTAssertTrue(Renderer.shared.needsRender, "the page read its session, so a write asks")

        // Nothing the page was built with changed, so it is built again only
        // because it READ what the press wrote.
        let patch = renders.settled(Node.page(KnobPage()), changed: Renderer.shared.pendingChanges)
        let missing = try Self.declaredOnPage().subtracting(Self.carried(by: patch)).sorted()

        XCTAssertTrue(
            missing.isEmpty,
            "a state the page's properties read moved, and the message left out: "
                + missing.joined(separator: ", "))
    }

    /// The same promise for what HANGS OFF a page - its toolbar items and its
    /// menus.
    ///
    /// They have no control case: a `ToolbarItem` is not a view and never
    /// appears among ControlTests' cases, so the guard there cannot see
    /// one, and this page is the only place either is built with everything it
    /// can do. Measured when the tier guard was written: `order` and `priority`
    /// were carried by NOTHING - two arms of `ApplyToolbarItem` that no test had
    /// ever run.
    func testEveryPropertyAPagesItemsDeclareIsCarried() throws {
        let sent = Self.keys(in: Self.arrived(EveryPropertyPage()))

        for source in ["ToolbarItem.swift", "MenuBar.swift", "MenuItemElement.swift"] {
            let declared = try Fixtures.propertyKeys(in: source)

            XCTAssertFalse(declared.isEmpty, "the scan found nothing \(source) writes")

            let missing = declared.subtracting(sent).sorted()

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
            reaches the patch.

            Every property a page's session holds is written into its `props` \
            in PageSession.swift, or hangs off the page as a node in its \
            `slots`. One that is declared and written nowhere is a property an \
            author can set and nothing will read.
            """)
    }

    /// Every property `PageSession` declares for an author to write, read out
    /// of the source - its `@State public var`s. The phase is the page's to
    /// report and nobody's to write, `public internal(set)`, so the scan passes
    /// over it.
    ///
    /// `PageSession`, because a page is a role rather than a type: the view it
    /// shows declares only what it is made of, and what the page can be told
    /// is its session's state. An arrangement, a page already, is told what it
    /// is by modifier.
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
            "PageSession.swift no longer declares `@State public var title` - the scan read nothing")

        return declared
    }

    /// The other half of the same surface: what a page the library CONSTRUCTS
    /// is told by modifier, since a constructor's result has no properties to
    /// override. `PageElement.swift` has no case of its own for the reason a
    /// bar tier has none - there is no control to build one on.
    func testEveryPageElementModifierIsExercised() throws {
        let path = State<[Int]>([])

        let sent = Set(
            NavigationStack(path.projectedValue) { EveryPropertyPage() } destination: { _ in
                EveryPropertyPage()
            }
            .title("Home")
            .icon("house.png")
            .body
            .built
            .props
            .keys
            .map(\.name))

        let declared = try Fixtures.propertyKeys(in: "PageElement.swift")

        XCTAssertFalse(declared.isEmpty, "the scan found nothing PageElement.swift writes")

        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            PageElement.swift declares \(missing.joined(separator: ", ")), which \
            this test does not write.
            """)
    }

    /// And the two spellings are ONE property - the same key in the patch, so
    /// the host reads a page's name in one place whichever way it was said.
    func testTheTwoWaysOfNamingAPageAreOneProperty() {
        let path = State<[Int]>([])

        let written = Self.arrived(EveryPropertyPage()).props[.title]
        let constructed = NavigationStack(path.projectedValue) { EveryPropertyPage() }
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
            ["Label", "TitleView", "ToolbarItems", "MenuBar"],
            "the content first, then one node per slot, in a fixed order")
    }

    // MARK: - What the values look like

    /// A page's own properties are its own: `background` is the PAGE's,
    /// where the bar above it takes `barBackgroundColor` on the arrangement -
    /// two different things, and one name if either were shortened.
    func testAPageCarriesItsOwnProperties() {
        let page = Self.arrived(EveryPropertyPage())

        XCTAssertEqual(page.props["title"], .string("Everything"))
        XCTAssertEqual(page.props["padding"], .numbers([4, 8, 12, 16]))
        XCTAssertEqual(page.props["background"], Color("#F5F5F5").propValue)
    }

    /// What a page asks of the stack it is on travels with the page, apart
    /// from the page's own properties: a page under no stack simply has them
    /// never read.
    func testAPageCarriesWhatItAsksOfTheStack() {
        let page = Self.arrived(EveryPropertyPage())

        XCTAssertEqual(page.props["hasNavigationBar"], .bool(false))

        XCTAssertEqual(page.props["hasBackButton"], .bool(false))
        XCTAssertEqual(page.props["backButtonTitle"], .string("Back"))
    }

    /// A page that says nothing sends nothing, leaving native defaults intact.
    func testAPageThatSaysNothingCarriesNothing() {
        let page = Node.page(Plain()).built

        XCTAssertEqual(page.props.count, 0)
        XCTAssertEqual(page.children.count, 1, "the content, and no slot it did not ask for")
    }

    /// What a page's first message carries - its `.onCreated` run, and what it
    /// wrote walked in, the way the renderer sends it.
    private static func arrived(_ view: some View) -> HostPatch {
        Renders().settled(Node.page(view))
    }

    /// Every property name in one place, however deep it sits.
    private static func keys(in node: Node) -> Set<String> {
        node.children.reduce(into: Set(node.props.keys.map(\.name))) { names, child in
            names.formUnion(keys(in: child))
        }
    }

    /// The same, in a patch.
    private static func keys(in patch: HostPatch) -> Set<String> {
        patch.children.reduce(into: Set(patch.props.keys.map(\.name))) { names, child in
            names.formUnion(keys(in: child))
        }
    }

    /// What a page's patch carries of its session, under the name each is
    /// declared by: its own properties, and each slot hanging off it as a node
    /// named for the property it rides - `TitleView` for
    /// `titleView`.
    private static func carried(by patch: HostPatch) -> Set<String> {
        let slots = patch.children.map { child -> String in
            let name = child.type.name
            return name.prefix(1).lowercased() + name.dropFirst()
        }

        return Set(patch.props.keys.map(\.name)).union(slots)
    }

    // MARK: - The page's own events

    /// A page's arrival and departure ride as HANDLERS on the page node, the
    /// way a window's six lifecycle events ride on its own.
    ///
    /// Five of them: the two that answer the page being on screen at all, and
    /// the three that answer a MOVE - which are not the same question, since a
    /// page appears again when the application wakes and nothing navigated.
    func testAPagesArrivalAndDepartureRideAsItsEvents() {
        let node = Node.page(EveryPropertyPage()).built

        XCTAssertEqual(
            node.events.keys.map(\.name).sorted(),
            ["appearing", "disappearing", "navigatedFrom", "navigatedTo", "navigatingFrom"])
    }

    /// EVERY page carries the five, whatever its view writes: they are what
    /// move its session's `phase`, which anything in the page may watch - so a
    /// page is heard arriving whether it says one word about itself or all of
    /// them.
    func testEveryPageCarriesItsFiveEventsWhateverItsViewWrites() {
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

        struct Watched: ContentView {
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
        let first = renders.settled(Node.page(Watched(arrivals: arrivals.projectedValue)))
        let events = try XCTUnwrap(first.events)

        XCTAssertEqual(first.children.first?.props[.text], .string("created"))

        /// Fires one of the page's reports, and answers the render that follows.
        func report(_ event: Event) throws -> HostPatch {
            XCTAssertTrue(renders.fire(try XCTUnwrap(events[event])))

            return renders.settled(
                Node.page(Watched(arrivals: arrivals.projectedValue)),
                changed: Renderer.shared.pendingChanges)
        }

        let arrived = try report(.appearing)

        XCTAssertEqual(
            arrived.children.first?.props[.text], .string("appearing"),
            "the report moved the phase, and the page read it")
        XCTAssertEqual(arrivals.wrappedValue, 1)

        // And again on the next arrival, which makes it the place to refresh
        // what may have changed while the page was covered.
        _ = try report(.disappearing)
        XCTAssertEqual(arrivals.wrappedValue, 1, "a departure is no arrival")

        _ = try report(.appearing)
        XCTAssertEqual(arrivals.wrappedValue, 2)
    }

    /// The page arrives whole: its properties, five handlers and every slot are
    /// in the message that brings it - the content, then the title view, the
    /// toolbar and the menus.
    func testThePageArrivesWhole() throws {
        let page = Self.arrived(EveryPropertyPage())

        XCTAssertEqual(page.props, [
            "backButtonTitle": .string("Back"), "background": Color("#F5F5F5").propValue,
            "hasBackButton": .bool(false), "hasNavigationBar": .bool(false), "icon": .string("tab.png"),
            "padding": .numbers([4, 8, 12, 16]), "title": .string("Everything"),
        ])
        XCTAssertEqual(page.eventNames, HostPatch.pageEvents)
        XCTAssertEqual(page.children.map(\.type), [.label, .titleView, .toolbarItems, .menuBar])

        let item = try XCTUnwrap(page.at(.auto(5), .auto(6)))
        XCTAssertEqual(item.props, [
            "accessibilityIdentifier": .string("bar.save"), "icon": .string("mark.png"),
            "isDestructive": .bool(true), "isEnabled": .bool(false),
            "placement": ToolbarItemPlacement.overflow.propValue, "priority": .number(2),
            "text": .string("Save"),
        ])
        XCTAssertEqual(item.eventNames, ["clicked"])

        // A menu at any depth: the bar's File holds an entry, a menu of its
        // own and a line.
        let file = try XCTUnwrap(page.at(.auto(7), .auto(8)))
        XCTAssertEqual(file.children.map(\.type), [.menuItem, .menu, .menuSeparator])
        XCTAssertEqual(file.at(.auto(10), .auto(11))?.props, ["text": .string("Notes.txt")])
    }

    /// The window arrives whole too: every property its session can say, its
    /// handlers and the page it holds.
    func testTheWindowArrivesWhole() throws {
        let window = Renders().settled(EveryPropertyWindow.node)

        XCTAssertEqual(window.props, [
            "height": .number(800), "isMaximizable": .bool(false), "isMinimizable": .bool(true),
            "isTranslucent": .bool(true), "maximumHeight": .number(1200), "maximumWidth": .number(1600),
            "minimumHeight": .number(400), "minimumWidth": .number(600), "title": .string("Everything"),
            "width": .number(1200), "x": .number(10), "y": .number(20),
        ])
        XCTAssertEqual(window.eventNames, HostPatch.windowEvents)
        XCTAssertEqual(window.children.map(\.type), [.page])
    }
}
