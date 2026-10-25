// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PageElementContract` on a host: a page and an arrangement stand under the title and with the icon the tree gives
/// them where another container presents them - a tabbed view's tab - and under the titles the tree changes them to,
/// each case made for every element wearing the tier; an arrangement's background is the ground of its pages that say
/// none; the visible page's title names its window, from a state too.
@_spi(Host) public enum PageElementTests: ConformanceFamily {
    public static let name = "PageElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(PageElementContract.self).flatMap { element in
            [
                inTab(PageElementContract.title, of: element, "Notes", then: "Drafts"),
                inTab(PageElementContract.icon, of: element, "test_dot.png", then: "test_wide.png"),
            ] + (element == PageContract.nodeType.name ? [] : [groundsItsPages(element)]) + [linked(element)]
        } + [titled, titledByState, groundHolds, groundFollowsColor, followsAMaterial]
    }

    /// A link the application is asked to open, given to the window `element` stands in as its page, is heard by it:
    /// its address, once - said on a view the page shows, or on the arrangement where the page stands.
    @MainActor
    static func linked(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).hearsALinkItsWindowIsGiven", proves: [
            Covered(PageElementContract.linkOpened, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start { Presented.hearing(element) { heard.values.append($0) } }
            let words = try s.element("words")
            let specimen = element == PageContract.nodeType.name
                ? words.enclosing(type: .page) : words.enclosing(type: NodeType(stringLiteral: element))
            guard let specimen else { throw DriverCannot("find the \(element) the words stand in") }

            try s.perform(.openLink("stateui-conformance://note/7"), on: specimen)
            s.settle { !heard.values.isEmpty }
            s.expect(heard.values, ["stateui-conformance://note/7"], "its address, once")
        }
    }

    /// The background `element` declares is the ground of its pages that say none: the page in it stands on what the
    /// tree gives it, and on what the tree changes it to.
    @MainActor
    static func groundsItsPages(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).background.groundsItsPagesThatSayNone", proves: [
            Covered(PageElementContract.background, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let (first, second) = (Material.color(.steelBlue), Material.color(.firebrick))
            let value = State(wrappedValue: first)
            s.start {
                Presented.page(element, PageElementContract.background, value.wrappedValue, beside: [
                    Button("Change").onClicked { value.wrappedValue = second }.id("change"),
                ])
            }
            let page = { () throws -> MountedElement in
                guard let page = try s.element("change").enclosing(type: .page) else {
                    throw DriverCannot("find the page in \(element)")
                }
                return page
            }
            try s.settle { try s.held(PageElementContract.background, on: page()) == first }
            s.expect(try s.held(PageElementContract.background, on: page()), first, "the ground the tree gave")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(PageElementContract.background, on: page()) == second }
            s.expect(try s.held(PageElementContract.background, on: page()), second, "the ground the tree changed it to")
        }
    }

    /// `member` of `element`, presented as a tabbed view's first tab, holds what the tree gives it and what the tree
    /// changes it to.
    @MainActor
    static func inTab<Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<PageElementContract, Value>, of element: String, _ first: Value, then second: Value
    ) -> ConformanceCase {
        ConformanceCase("\(element).\(member.name).standsOnItsTab", proves: [
            Covered(member, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: first)
            s.start {
                TabView([0, 1]) { tab in
                    if tab == 0 {
                        Presented.page(element, member, value.wrappedValue, beside: [
                            Button("Change").onClicked { value.wrappedValue = second }.id("change"),
                        ])
                    } else {
                        Text("Other")
                    }
                }
            }
            let kind = s.elements(ofType: NodeType(element))
            let presented = element == "TabView" ? kind.last : kind.first
            guard let specimen = element == "Page" ? try tabPage(s) : presented else {
                return s.fail("no \(element) presented")
            }
            try s.settle { try s.held(member, on: specimen) == first }
            s.expect(try s.held(member, on: specimen), first, "the value the tree gave")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(member, on: specimen) == second }
            s.expect(try s.held(member, on: specimen), second, "the value the tree changed it to")
        }
    }

    /// A pushed page's background holds what its view says, and what it says once its body is built again.
    @MainActor
    static var groundHolds: ConformanceCase {
        ConformanceCase("Page.background.holdsWhatItsViewSaysAndChanges", proves: [
            Covered(PageElementContract.background, on: PageContract.self),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: Material.color(.red))
            s.start {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    Text("Root")
                } destination: { _ in
                    Saying(value: value, second: .color(.blue)) { $0.pageBackground($1) }
                }
            }
            try PageTests.held(PageElementContract.background, .color(.red), then: .color(.blue), s)
        }
    }

    /// A pushed page's background holds the color of the state its view says it from, and follows the state as it is
    /// written, no view built again - a color's channel writing a material.
    @MainActor
    static var groundFollowsColor: ConformanceCase {
        ConformanceCase("Page.background.followsItsState", proves: [
            Covered(PageElementContract.background, on: PageContract.self),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: Color.red)
            s.start {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    Text("Root")
                } destination: { _ in
                    PageTests.changing(value, to: .blue).pageBackground(value.projectedValue)
                }
            }
            try PageTests.held(PageElementContract.background, .color(.red), then: .color(.blue), s)
        }
    }

    /// A pushed page's background follows the material state its view says it from - a material's channel.
    @MainActor
    static var followsAMaterial: ConformanceCase {
        ConformanceCase("Page.background.followsAMaterialState", proves: [
            Covered(PageElementContract.background, on: PageContract.self),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let (first, second) = (Material.color(Color(hex: 0x0F766E)), Material.color(Color(hex: 0x512BD4)))
            let value = State(wrappedValue: first)
            s.start {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    Text("Root")
                } destination: { _ in
                    PageTests.changing(value, to: second).pageBackground(value.projectedValue)
                }
            }
            try PageTests.held(PageElementContract.background, first, then: second, s)
        }
    }

    /// The page of the tabbed view's first tab.
    @MainActor static func tabPage(_ s: Session) throws -> MountedElement {
        guard let tabs = s.elements(ofType: TabViewContract.nodeType).first,
              let page = tabs.children.first(where: { $0.type == PageContract.nodeType })
        else { throw DriverCannot("find the tab's page") }
        return page
    }

    /// The visible page's title names its window.
    @MainActor
    static var titled: ConformanceCase {
        ConformanceCase("Page.theVisiblePagesTitleNamesItsWindow", proves: [
            Covered(PageElementContract.title, on: "Page"),
        ]) { s in
            s.start { VStack { Text("Page") }.title("Notes") }

            try s.settle { try s.held(WindowContract.title, on: s.element(ofType: WindowContract.nodeType)) == "Notes" }
            s.expect(try s.held(WindowContract.title, on: s.element(ofType: WindowContract.nodeType)), "Notes")
        }
    }

    /// The visible page's title said from a state names its window, and follows the state as it is written.
    @MainActor
    static var titledByState: ConformanceCase {
        ConformanceCase("Page.theTitleFromAStateFollowsIt", proves: [
            Covered(PageElementContract.title, on: "Page"),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let title = State(wrappedValue: "Notes")
            s.start {
                VStack {
                    Text("Page")
                    Button("Rename").onClicked { title.wrappedValue = "Drafts" }.id("rename")
                }
                .title(title.projectedValue)
            }
            let window = try s.element(ofType: WindowContract.nodeType)
            try s.settle { try s.held(WindowContract.title, on: window) == "Notes" }
            s.expect(try s.held(WindowContract.title, on: window), "Notes", "the title the state holds")

            try s.perform(.activate, on: s.element("rename"))
            try s.settle { try s.held(WindowContract.title, on: window) == "Drafts" }
            s.expect(try s.held(WindowContract.title, on: window), "Drafts", "and the one written into it")
        }
    }
}

/// A page of each kind wearing the tier - a page of its own, or an arrangement - carrying one of the tier's members.
@MainActor
enum Presented {
    /// A page of `element`'s kind, standing as its window's page, that hears the links its window is given - said on
    /// its words where it is a page of its own, on itself where it is an arrangement.
    static func hearing(_ element: String, _ handler: @escaping @MainActor (String) -> Void) -> AnyView {
        let words = Text("Words").id("words")
        switch element {
        case "NavigationStack":
            return AnyView(NavigationStack(State(wrappedValue: [Int]()).projectedValue) { words }
                destination: { _ in Text("Pushed") }.onLinkOpened(handler))
        case "SplitView":
            return AnyView(SplitView(State(wrappedValue: true).projectedValue) { Text("Sidebar") }
                detail: { words }.onLinkOpened(handler))
        case "TabView":
            return AnyView(TabView([0]) { _ in words }.onLinkOpened(handler))
        default:
            return AnyView(VStack { words }.onLinkOpened(handler))
        }
    }

    /// A page of `element`'s kind whose `member` is `value`, `beside` its words.
    static func page<Value: HostRepresentable & Sendable & Equatable>(
        _ element: String, _ member: ElementProperty<PageElementContract, Value>, _ value: Value, beside: [any View]
    ) -> AnyView {
        // Chosen by name, so held as `any View` and handed on as its node.
        AnyView(chosen(element, member, value, beside: beside))
    }

    /// The page `page(_:_:_:beside:)` shows, chosen by name.
    private static func chosen<Value: HostRepresentable & Sendable & Equatable>(
        _ element: String, _ member: ElementProperty<PageElementContract, Value>, _ value: Value, beside: [any View]
    ) -> any View {
        let others: [any View] = beside
        let written = Write(member, value)
        switch element {
        case "NavigationStack":
            return written.worn(by: NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                VStack { Beside([Text("Root")] + others) }
            } destination: { _ in Text("Pushed") })
        case "SplitView":
            return written.worn(by: SplitView(State(wrappedValue: true).projectedValue) {
                Text("Sidebar")
            } detail: { VStack { Beside([Text("Detail")] + others) } })
        case "TabView":
            return written.worn(by: TabView([0]) { _ in VStack { Beside([Text("Inner")] + others) } })
        default:
            let words = VStack { Beside([Text("Page")] + others) }
            if let title = value as? String, member.name == PageElementContract.title.name { return words.title(title) }
            if let icon = value as? ImageSource, member.name == PageElementContract.icon.name { return words.icon(icon) }
            return words
        }
    }
}
