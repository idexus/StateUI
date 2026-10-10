// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PageElementContract` on a host: a page and an arrangement stand under the title and with the icon the tree gives
/// them where another container presents them - a tabbed view's tab - and under the titles the tree changes them to,
/// each case made for every element wearing the tier; the visible page's title names its window, from a state too.
@_spi(Host) public enum PageElementTests: ConformanceFamily {
    public static let name = "PageElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(PageElementContract.self).flatMap { element in
            [
                inTab(PageElementContract.title, of: element, "Notes", then: "Drafts"),
                inTab(PageElementContract.icon, of: element, "test_dot.png", then: "test_wide.png"),
            ]
        } + [titled, titledByState]
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
    /// A page of `element`'s kind whose `member` is `value`, `beside` its words.
    static func page<Value: HostRepresentable & Sendable & Equatable>(
        _ element: String, _ member: ElementProperty<PageElementContract, Value>, _ value: Value, beside: [any View]
    ) -> ModifiedContent {
        // Chosen by name, so held as `any View` and handed on as its node.
        ModifiedContent(node: chosen(element, member, value, beside: beside).node)
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
                VStack { [Text("Root")] + others }
            } destination: { _ in Text("Pushed") })
        case "SplitView":
            return written.worn(by: SplitView(State(wrappedValue: true).projectedValue) {
                Text("Sidebar")
            } detail: { VStack { [Text("Detail")] + others } })
        case "TabView":
            return written.worn(by: TabView([0]) { _ in VStack { [Text("Inner")] + others } })
        default:
            let words = VStack { [Text("Page")] + others }
            if let title = value as? String, member.name == PageElementContract.title.name { return words.title(title) }
            if let icon = value as? ImageSource, member.name == PageElementContract.icon.name { return words.icon(icon) }
            return words
        }
    }
}
