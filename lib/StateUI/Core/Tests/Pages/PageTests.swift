// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a PAGE puts in the patch, and the guards that keep the list complete.
//
// A page is not a control: it has no case in ControlTests, it cannot
// be styled, and `SourceTree.controlSources()` skips the file it lives in. So
// the coverage a control gets for free - every modifier exercised, every
// property carried - has to be written here instead, and this is the file that
// writes it.
//
// Everything a page can be told, the view it shows says by modifier, in
// View+PageValues.swift, and everything a window can be told is its window
// session's, in WindowSession.swift - so the guards below read both files and
// the page's contract, and insist the two exhaustive values in this one carry
// every key.

import XCTest
@_spi(Host) @testable import StateUI

/// A page whose view says EVERYTHING a view can say of its page.
///
/// Deliberately nonsensical as an interface - it asks for a tab icon and a
/// navigation bar at once, which no real page would. What it is for is the
/// guards below: a property nobody writes here is a property the host may
/// quietly not apply.
private struct EveryPropertyPage: View {
    var body: some View {
        Text("content")
            // What it declares for its bar, each saying everything ITS type can
            // say - a page is the only place a toolbar item is covered, there
            // being no control case for one.
            .titleView { Text("stack title") }
            .toolbar {
                ToolbarItem("Save")
                    .accessibilityIdentifier("bar.save")
                    .icon(ImageSource("mark.png"))
                    .placement(.overflow)
                    .showsText(true)
                    .isDestructive(true)
                    .isEnabled(false)
                    .onClicked {}
            }
            // Its menus, every entry saying all it can.
            .menuBar {
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

                    Divider()
                }
                .isEnabled(true)
            }
            // The page's own.
            .title("Everything")
            .icon(ImageSource("tab.png"))
            .pageBackground(.whiteSmoke)
            // What it asks of a NavigationStack.
            .showsNavigationBar(false)
            .showsBackButton(false)
            .backButtonTitle("Back")
            // And every phase it hears.
            .onAppearing {}
            .onDisappearing {}
            .onNavigatedTo {}
            .onNavigatingFrom {}
            .onNavigatedFrom {}
    }
}

/// A window whose session says everything a window can be told.
private func everyPropertyWindow() -> Node {
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
    session.background = .blur(.thin.tint(Color("#26512BD4")))

    return Node.window(showing: { Node.page(EveryPropertyPage()) }, kind: "EveryPropertyPage", session: session).built
}

/// A page whose view says every value of its page from a state of its own, each one of two values, and turns
/// them all on a press. So what the next message carries is what the view says now, nothing else having moved.
private struct KnobPage: View {
    @State private var on = false

    var body: some View {
        VStack { Button("dress").onClicked { on = true } }
            .title(on ? "On" : "Off")
            .icon(ImageSource(on ? "on.png" : "off.png"))
            .pageBackground(on ? .red : .whiteSmoke)
            .showsNavigationBar(on)
            .showsBackButton(on)
            .backButtonTitle(on ? "Back" : "Return")
    }
}

/// A view that says nothing about the page it is shown on.
private struct Plain: View {
    var body: some View { Text("plain") }
}

/// A view whose body is an arrangement.
private struct Stacked: View {
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack($path) { Plain() } destination: { _ in Plain() }
    }
}

/// A view whose body chooses between an arrangement and a view.
private struct Choosing: View {
    let stack: Bool
    @State private var path: [Int] = []

    var body: some View {
        if stack {
            NavigationStack($path) { Plain() } destination: { _ in Plain() }
        } else {
            Plain()
        }
    }
}

/// What a view is offered.
private final class Offered {}

/// A view that names the page it is shown on, from its body.
private struct Named: View {
    let name: String

    var body: some View {
        Text(name).title(name)
    }
}

/// How often what a view is made of was read.
private final class Builds {
    var count = 0
}

/// A view naming its page from a state it holds, renamed on a press - counting its builds.
private struct Renaming: View {
    @State private var name = "Home"
    let builds: Builds

    var body: some View {
        builds.count += 1
        return Button("rename").onClicked { name = "Renamed" }.title(name)
    }
}

/// A view naming its page from a state it is lent, as a channel.
private struct Following: View {
    let name: Binding<String>
    let builds: Builds

    var body: some View {
        builds.count += 1
        return Text("following").title(name).backButtonTitle(name)
    }
}

/// A view saying a title of its page deeper than the view the page shows.
private struct Deep: View {
    var body: some View {
        VStack { Text("deep").title("Deep") }
    }
}

final class PageTests: XCTestCase {
    /// A page position takes a branch as a page of its own: swapped for the other branch of the same view type,
    /// the page is made anew - created again - as two branches in a container are two elements.
    func testAPageSwappedForABranchOfTheSameTypeIsANewPage() {
        let first = State(wrappedValue: true)
        let log = State(wrappedValue: [String]())
        @ViewBuilder func shown() -> some View {
            if first.wrappedValue {
                Created(name: "one", log: log.projectedValue)
            } else {
                Created(name: "two", log: log.projectedValue)
            }
        }
        let renders = Renders()

        renders.settled(Node.page(shown()))
        first.wrappedValue = false
        let swapped = renders.settled(Node.page(shown()), changed: Renderer.shared.pendingChanges)

        XCTAssertTrue(swapped.replace, "the page went on as the other branch")
        XCTAssertEqual(log.wrappedValue, ["created one", "created two"])
    }

    // MARK: - What a view says of its page

    /// The page says what the view it shows says of it - from the view's body - and a parent building again with
    /// the same view says nothing new.
    func testThePageSaysWhatItsViewSays() {
        let renders = Renders()
        let first = renders.render(Node.page(Named(name: "Home")))
        let again = renders.render(Node.page(Named(name: "Home")))

        XCTAssertEqual(first.props[.title], .string("Home"))
        XCTAssertNil(first.children.first?.props[.title], "the view's own carries none of it")
        XCTAssertNil(again.props[.title], "the title stands, so nothing is said about it")
        XCTAssertEqual(again.cleared, [], "and nothing is taken off the page")
    }

    /// What is written ON a composed view stands over what its body says, the way every modifier on one does.
    func testWhatIsWrittenOnAViewStandsOverItsBody() {
        let page = Renders().render(Node.page(Named(name: "Home").title("Away").icon("away.png")))

        XCTAssertEqual(page.props[.title], .string("Away"))
        XCTAssertEqual(page.props[.icon], .string("away.png"))
    }

    /// Another view standing there is another page: the host makes it anew, nothing the view before said is on
    /// it, and what the view arriving says is.
    func testAnotherViewOnThePageIsAnotherPage() {
        let renders = Renders()
        renders.render(Node.page(Named(name: "Home")))
        let plain = renders.render(Node.page(Plain()))
        let named = renders.render(Node.page(Named(name: "Away")))

        XCTAssertTrue(plain.replace, "the host makes the page anew")
        XCTAssertNil(plain.props[.title], "the title was the view before's")
        XCTAssertTrue(named.replace)
        XCTAssertEqual(named.props[.title], .string("Away"))
    }

    /// The same kind of view under another explicit id is another view, and so another page.
    func testTheSameViewUnderAnotherIdIsAnotherPage() {
        let renders = Renders()
        renders.render(Node.page(Named(name: "Home").id("one")))
        let other = renders.render(Node.page(Named(name: "Away").id("two")))

        XCTAssertTrue(other.replace)
        XCTAssertEqual(other.props[.title], .string("Away"))
    }

    /// A write the view's page values read builds the view once and says them again on the page - on the walk
    /// that builds only what read the write, too.
    func testAWriteThePageValuesReadSaysThemAgain() throws {
        let builds = Builds()
        let renders = Renders()
        let first = renders.render(Node.page(Renaming(builds: builds)))
        let rename = try XCTUnwrap(first.children.first?.events?[.clicked])

        XCTAssertEqual(first.props[.title], .string("Home"))
        XCTAssertTrue(renders.fire(rename))

        let walked = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(walked.props[.title], .string("Renamed"), "the page said the new title")
        XCTAssertEqual(builds.count, 2, "the view built once for the write")
    }

    /// A page value from a state, `$x`, is the host's to follow: the page carries the channel, and a write
    /// builds nothing.
    func testAPageValueFromAStateIsAChannel() {
        let name = State(wrappedValue: "Home")
        let builds = Builds()
        let page = Renders().render(Node.page(Following(name: name.projectedValue, builds: builds)))

        XCTAssertEqual(Self.channels(of: page), ["backButtonTitle", "title"], "the page carries their channels")
        XCTAssertEqual(Self.kinds(of: page), [.text, .text], "each as words, which a host writes as they change")
        XCTAssertNil(page.props[.title], "and no value of it")
        XCTAssertEqual(Self.channels(of: page.children[0]), [], "the view's own carries none of it")

        name.wrappedValue = "Away"
        XCTAssertEqual(builds.count, 1)
    }

    /// Said deeper than the view a page shows, a page value says nothing - and is complained about.
    func testAPageValueSaidDeeperSaysNothing() {
        let page = Renders().render(Node.page(Deep()))

        XCTAssertNil(page.props[.title])
        XCTAssertFalse(page.subtree.contains { $0.props[.title] != nil }, "nowhere in the tree")
    }

    /// A view with no element of its own - a control, a stack - is shown the same way, and follows its parent:
    /// what the parent builds it with is on the page in the next message.
    func testAPlainViewOnAPageFollowsItsParent() {
        let renders = Renders()
        renders.render(Node.page(Text("one").title("one")))
        let second = renders.render(Node.page(Text("two").title("two")))

        XCTAssertEqual(second.children.first?.props[.text], .string("two"))
        XCTAssertEqual(second.props[.title], .string("two"))
    }

    /// What is written ON a view shown as a page as its own stays the view's: a view's `background` is the view's,
    /// and the page's is `pageBackground`.
    func testAViewsOwnValuesStayOnTheView() {
        let written: [any View] = [
            Plain().background(.red).pageBackground(.blue),
            Text("plain").background(.red).pageBackground(.blue),
        ]

        for view in written {
            let page = Renders().render(Node.page(ModifiedContent(node: view.node)))

            XCTAssertEqual(page.type, .page)
            XCTAssertEqual(page.props[.background], Color.blue.propValue, "the page's own")
            XCTAssertEqual(page.children.first?.props[.background], Color.red.propValue, "the view's own")
        }
    }

    /// Every arrangement is a page already, and is shown as it is; the pages it arranges stand inside it.
    func testEveryArrangementIsShownAsItIs() {
        let path = State<[Int]>([])
        let sidebar = State(false)
        let stack = NavigationStack(path.projectedValue) { Plain() } destination: { _ in Plain() }
        let arrangements: [(view: any View, type: NodeType)] = [
            (stack, .navigationStack),
            (TabView([0, 1]) { _ in Plain() }, .tabView),
            (SplitView(sidebar.projectedValue) { Plain() } detail: { Plain() }, .splitView),
            (ModalStack(path.projectedValue) { Plain() } destination: { _ in Plain() }, .modalStack),
        ]

        XCTAssertEqual(Set(arrangements.map(\.type)), NodeType.arrangements, "every arrangement is shown")
        for (view, type) in arrangements {
            XCTAssertEqual(Node.page(ModifiedContent(node: view.node)).built.type, type)
        }
        XCTAssertEqual(Node.page(stack).built.children.first?.type, .page)
    }

    /// An arrangement standing where a page stands takes the title and the icon a page would - a tab's caption
    /// and picture - and nothing else a page alone says.
    func testAnArrangementTakesItsTitleAndIcon() {
        let path = State<[Int]>([])
        let stack = NavigationStack(path.projectedValue) { Plain() } destination: { _ in Plain() }
            .title("Home")
            .icon("house.png")
            .showsNavigationBar(false)

        let patch = Renders().render(Node.page(stack))

        XCTAssertEqual(patch.type, .navigationStack)
        XCTAssertEqual(patch.props[.title], .string("Home"))
        XCTAssertEqual(patch.props[.icon], .string("house.png"))
        XCTAssertNil(patch.props[.showsNavigationBar], "a page's alone")
    }

    /// A view whose body is an arrangement stands as that arrangement, told by the view's type - which a modifier
    /// written on the view keeps - and any other view stands on a page of its own.
    func testAViewWhoseBodyIsAnArrangementStandsAsIt() {
        XCTAssertEqual(Node.page(Stacked()).built.type, .navigationStack)
        XCTAssertEqual(Node.page(Stacked().environment(Offered())).built.type, .navigationStack)
        XCTAssertEqual(Node.page(Plain()).built.type, .page)
    }

    /// A body choosing between an arrangement and a view stands as a view, as its type cannot tell which it builds;
    /// the arrangement it chose, standing inside a page, is left out.
    func testABodyChoosingAnArrangementStandsAsAView() {
        let patch = Renders().render(Node.page(Choosing(stack: true)))

        XCTAssertEqual(patch.type, .page)
        XCTAssertFalse(patch.subtree.contains { $0.type == .navigationStack })
    }

    /// An arrangement stands where a page stands: written inside a layout it is left out, and what is beside it
    /// stands.
    func testAnArrangementWhereNoPageStandsIsLeftOut() {
        let path = State<[Int]>([])
        let patch = Renders().render(VStack {
            Text("beside")
            NavigationStack(path.projectedValue) { Plain() } destination: { _ in Plain() }
        }.node)

        XCTAssertEqual(patch.subtree.map(\.type), [.vStack, .text])
    }

    /// An arrangement fills where a page stands: what its contract does not declare - a width, a tap - is left
    /// out, and what it declares stays.
    func testAnArrangementKeepsWhatItsContractDeclares() {
        let path = State<[Int]>([])
        let stack = NavigationStack(path.projectedValue) { Plain() } destination: { _ in Plain() }
            .width(120)
            .onTapped {}
            .barBackgroundColor(.red)

        let patch = Renders().render(Node.page(stack))

        XCTAssertNil(patch.props["width"])
        XCTAssertFalse(patch.eventNames.contains("tapped"))
        XCTAssertNotNil(patch.props["barBackgroundColor"])
    }

    // MARK: - The guards

    /// Every member a page's contracts declare - its own and its item tier's, values and events - is carried by
    /// a page whose view says everything, and every value the page modifiers and the window's session write is
    /// carried too: a member nobody exercises is one the renderer can quietly not implement.
    func testEveryPageAndWindowValueIsCarried() throws {
        let page = Self.arrived(EveryPropertyPage())
        let members = (PageContract.members + PageElementContract.members).map(\.name)
        let carried = Set(page.props.keys.map(\.name)).union(page.eventNames)

        XCTAssertEqual(Set(members).subtracting(carried).sorted(), [], "a member the page never carries")

        let sent = Self.keys(in: page).union(Self.keys(in: everyPropertyWindow()))
        let declared = try SourceTree.propertyKeys(in: "View+PageValues.swift")
            .union(SourceTree.propertyKeys(in: "WindowSession.swift"))

        XCTAssertTrue(declared.contains("title"), "the scan found nothing View+PageValues.swift writes")
        XCTAssertEqual(declared.subtracting(sent).sorted(), [], "a value written and never carried")
        XCTAssertEqual(
            try SourceTree.handlerKeys(in: "View+PageValues.swift").subtracting(page.eventNames).sorted(), [],
            "a phase heard and never carried")
    }

    /// Every value a page carries has a host default, so the page never needs making anew for one it no longer
    /// says - which describing the view it shows before the page itself relies on.
    func testEveryPageValueHasAHostDefault() {
        for member in PageContract.members + PageElementContract.members {
            XCTAssertTrue(Prop(member.name).facts.cleared, "\(member.name) has no host default")
        }
    }

    /// A page's values follow the state the view reads: a write builds the view again, and the message carries
    /// each value that moved - every one the page's contracts declare.
    func testEveryPageValueFollowsTheStateItReads() throws {
        let renders = Renders()
        let first = renders.render(Node.page(KnobPage()))
        let dress = try XCTUnwrap(first.children.first?.children.first?.events?[.clicked])

        XCTAssertTrue(renders.fire(dress))

        let patch = renders.render(Node.page(KnobPage()), changed: Renderer.shared.pendingChanges)
        let values = (PageContract.members + PageElementContract.members)
            .filter { $0 is any PropertyMember }.map(\.name)

        XCTAssertEqual(Set(values).subtracting(patch.props.keys.map(\.name)).sorted(), [])
    }

    /// The same promise for what HANGS OFF a page - its toolbar items and its menus, which have no control case.
    func testEveryPropertyAPagesItemsDeclareIsCarried() throws {
        let sent = Self.keys(in: Self.arrived(EveryPropertyPage()))

        for source in ["ToolbarItem.swift", "Menu.swift", "MenuItem.swift", "MenuItemElement.swift"] {
            let declared = try SourceTree.propertyKeys(in: source)

            XCTAssertFalse(declared.isEmpty, "the scan found nothing \(source) writes")
            XCTAssertEqual(declared.subtracting(sent).sorted(), [], "\(source) declares what EveryPropertyPage does not write")
        }
    }

    /// The two that name a page are ONE property whoever stands there - the same key in the patch, so the host
    /// reads a page's name in one place.
    func testAPageAndAnArrangementNameThemselvesAlike() {
        let path = State<[Int]>([])

        let page = Self.arrived(EveryPropertyPage()).props[.title]
        let arrangement = Renders().render(Node.page(
            NavigationStack(path.projectedValue) { Plain() } destination: { _ in Plain() }.title("Everything")))
            .props[.title]

        XCTAssertEqual(page, .string("Everything"))
        XCTAssertEqual(page, arrangement)
    }

    /// And the slots, which are children rather than properties: each rides as a wrapper node of its own after the
    /// element declaring it - the title view, the toolbar group and the menus after the content's own children.
    func testEveryPageSlotRidesAsItsOwnNode() {
        let page = Self.arrived(EveryPropertyPage())

        XCTAssertEqual(page.children.map { $0.type.name }, ["Text"], "the content alone")
        XCTAssertEqual(page.children[0].children.map { $0.type.name }, ["TitleView", "ToolbarItemGroup", "MenuBar"])
    }

    // MARK: - What the values look like

    /// A page's own values are its own: `background` is the PAGE's, where the bar above it takes
    /// `barBackgroundColor` on the arrangement.
    func testAPageCarriesItsOwnValues() {
        let page = Self.arrived(EveryPropertyPage())

        XCTAssertEqual(page.props["title"], .string("Everything"))
        XCTAssertEqual(page.props["background"], Color("#F5F5F5").propValue)
        XCTAssertNil(page.props["padding"], "a page keeps no room of its own: its view does")
    }

    /// What a page asks of the stack it is on travels with the page: a page under no stack has them never read.
    func testAPageCarriesWhatItAsksOfTheStack() {
        let page = Self.arrived(EveryPropertyPage())

        XCTAssertEqual(page.props["showsNavigationBar"], .bool(false))
        XCTAssertEqual(page.props["showsBackButton"], .bool(false))
        XCTAssertEqual(page.props["backButtonTitle"], .string("Back"))
    }

    /// A page whose view says nothing sends nothing - no value, no event - leaving the native defaults intact.
    func testAPageThatSaysNothingCarriesNothing() {
        let page = Self.arrived(Plain())

        XCTAssertEqual(page.props.count, 0)
        XCTAssertNil(page.events)
        XCTAssertEqual(page.children.count, 1, "the content, and no slot it did not ask for")
    }

    /// The properties a patch ties to states.
    private static func channels(of patch: HostPatch) -> [String] {
        guard case .replace(let ties)? = patch.driven else { return [] }
        return ties.keys.map(\.name).sorted()
    }

    /// The kind of each channel a patch carries, in the order of their names.
    private static func kinds(of patch: HostPatch) -> [HostStateKind] {
        guard case .replace(let ties)? = patch.driven else { return [] }
        return ties.sorted { $0.key.name < $1.key.name }.map(\.value.kind)
    }

    /// What a page's first message carries, the way the renderer sends it.
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

    // MARK: - The page's phases

    /// A page carries the phases its view hears, as handlers on the page node - and only those.
    func testAPageCarriesThePhasesItsViewHears() {
        XCTAssertEqual(Self.arrived(EveryPropertyPage()).eventNames, HostPatch.pageEvents)
        XCTAssertEqual(Self.arrived(Text("x").onAppearing {}).eventNames, ["appearing"])
        XCTAssertEqual(Self.arrived(Text("x").onNavigatedFrom {}).eventNames, ["navigatedFrom"])
        XCTAssertEqual(Self.arrived(Text("x")).eventNames, [])
    }

    /// The handler RUNS: firing the id the page carries - what the host does when the platform raises the phase -
    /// runs what the view gave, on every arrival.
    func testAPhaseHandlerRuns() throws {
        let arrivals = State(0)
        let page = Self.arrived(Text("arriving").onAppearing { arrivals.wrappedValue += 1 })
        let renders = Renders()
        let first = renders.render(Node.page(Text("arriving").onAppearing { arrivals.wrappedValue += 1 }))
        let appearing = try XCTUnwrap(first.events?[.appearing])

        XCTAssertNotNil(page.events?[.appearing])
        XCTAssertTrue(renders.fire(appearing))
        XCTAssertTrue(renders.fire(appearing))
        XCTAssertEqual(arrivals.wrappedValue, 2)
    }

    /// The page arrives whole: its values, its handlers and everything hanging off it are in the message that
    /// brings it - the content with the title view, the toolbar group and the menus it declares.
    func testThePageArrivesWhole() throws {
        let page = Self.arrived(EveryPropertyPage())

        XCTAssertEqual(page.props, [
            "backButtonTitle": .string("Back"), "background": Color("#F5F5F5").propValue,
            "showsBackButton": .bool(false), "showsNavigationBar": .bool(false), "icon": .string("tab.png"),
            "title": .string("Everything"),
        ])
        XCTAssertEqual(page.eventNames, HostPatch.pageEvents)
        XCTAssertEqual(page.children.map(\.type), [.text])
        let content = page.children[0]
        XCTAssertEqual(content.children.map(\.type), [.titleView, .toolbarItemGroup, .menuBar])

        let item = try XCTUnwrap(content.children[1].children.first)
        XCTAssertEqual(item.props, [
            "accessibilityIdentifier": .string("bar.save"), "icon": .string("mark.png"),
            "isDestructive": .bool(true), "isEnabled": .bool(false),
            "placement": ToolbarItemPlacement.overflow.propValue,
            "showsText": .bool(true), "text": .string("Save"),
        ])
        XCTAssertEqual(item.eventNames, ["clicked"])

        // A menu at any depth: the bar's File holds an entry, a menu of its own and a line.
        let file = try XCTUnwrap(content.children.last?.children.first)
        XCTAssertEqual(file.children.map(\.type), [.menuItem, .menu, .divider])
        XCTAssertEqual(file.children[1].children.first?.props, ["text": .string("Notes.txt")])
    }

    /// The window arrives whole too: every property its session can say, its handlers and the page it holds.
    func testTheWindowArrivesWhole() throws {
        let window = Renders().settled(everyPropertyWindow())

        XCTAssertEqual(window.props, [
            "background": Material.blur(.thin.tint(Color("#26512BD4"))).propValue.resolvingTheme(),
            "height": .number(800), "isMaximizable": .bool(false), "isMinimizable": .bool(true),
            "maximumHeight": .number(1200), "maximumWidth": .number(1600),
            "minimumHeight": .number(400), "minimumWidth": .number(600), "title": .string("Everything"),
            "width": .number(1200), "x": .number(10), "y": .number(20),
        ])
        XCTAssertEqual(window.eventNames, HostPatch.windowEvents)
        XCTAssertEqual(window.children.map(\.type), [.page])
    }
}

/// A page saying when it is made, by its name.
private struct Created: View {
    let name: String
    @Binding var log: [String]

    var body: some View {
        Text(name).onCreated { log.append("created \(name)") }
    }
}
