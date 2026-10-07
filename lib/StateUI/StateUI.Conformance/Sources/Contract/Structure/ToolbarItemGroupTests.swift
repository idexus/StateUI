// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ToolbarItemGroupContract` on a host: a group a page declares stands on its bar while the page is shown; a group its
/// stack declares stands on every page's bar, in place at the edge, and a page's own come and go with it; a group
/// stands by its order and at its side; a group of an id joins the one around it, and an item of an outer item's id
/// stands in its place.
@_spi(Host) public enum ToolbarItemGroupTests: ConformanceFamily {
    public static let name = "ToolbarItemGroup"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("theVisiblePagesItemsStandOnItsBar", proves: [
                Covered(ToolbarItemGroupContract.self), Covered(MenuItemElementContract.clicked, on: "ToolbarItem"),
            ]) { s in
                let path = State(wrappedValue: [Int]())
                let heard = Received<String>()
                s.start {
                    NavigationStack(path.projectedValue) {
                        DeclaringPage { [ToolbarItem("Save").onClicked { heard.values.append("save") }.id("save")] }
                    } destination: { _ in
                        DeclaringPage { [ToolbarItem("Share").onClicked { heard.values.append("share") }.id("share")] }
                    }
                }

                try s.perform(.activate, on: s.element("save"))
                s.settle { heard.values == ["save"] }

                path.wrappedValue = [1]
                s.settle { (try? s.element("share")) != nil }
                try s.perform(.activate, on: s.element("share"))
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["save", "share"], "each page's own, while it is the visible one")
            },
            ConformanceCase("aStacksGroupStandsOnEveryPageInPlace", proves: [Covered(ToolbarItemGroupContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        DeclaringPage { [ToolbarItem("Save").id("save")] }
                    } destination: { _ in
                        DeclaringPage { [ToolbarItem("Share").id("share")] }
                    }
                    .toolbar { ToolbarItem("Home").id("home") }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[save] [home]|" }
                s.expect(try bar(), "|[save] [home]|", "the page's own nearer the title, the stack's at the edge")

                path.wrappedValue = [1]
                try s.settle { try bar() == "|[share] [home]|" }
                s.expect(try bar(), "|[share] [home]|", "the pushed page's own in the place of the first's")

                path.wrappedValue = []
                try s.settle { try bar() == "|[save] [home]|" }
                s.expect(try bar(), "|[save] [home]|", "back, as it stood: nothing restored, nothing left")
            },
            ConformanceCase("groupsStandByTheirOrder", proves: [Covered(ToolbarItemGroupContract.order)]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        DeclaringPage { [ToolbarItem("Save").id("save")] }
                    } destination: { _ in Text("Pushed") }
                    .toolbar(order: 1) { ToolbarItem("Later").id("later") }
                    .toolbar { ToolbarItem("Home").id("home") }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[save] [home] [later]|" }
                s.expect(try bar(), "|[save] [home] [later]|", "the group of order 1 after those of 0")
            },
            ConformanceCase("aLeadingGroupStandsAtTheLeadingEdge", proves: [Covered(ToolbarItemGroupContract.side)]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        DeclaringPage(side: .leading) { [ToolbarItem("Filter").id("filter")] }
                    } destination: { _ in Text("Pushed") }
                    .toolbar { ToolbarItem("Home").id("home") }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "[filter]|[home]|" }
                s.expect(try bar(), "[filter]|[home]|")
            },
            ConformanceCase("aGroupJoinsTheOneOfItsIdAndAnItemStandsInPlace", proves: [
                Covered(ToolbarItemGroupContract.self),
            ]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        DeclaringPage(group: "window") {
                            [ToolbarItem("Help").id("help"), ToolbarItem("Save").isEnabled(false).id("save")]
                        }
                    } destination: { _ in Text("Pushed") }
                    .toolbar(id: "window") {
                        ToolbarItem("Home").id("home")
                        ToolbarItem("Save").id("save")
                    }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[help home !save]|" }
                s.expect(try bar(), "|[help home !save]|", "one group; the page's Save in the place of the stack's")
            },
        ]
    }
}

/// The page the case's stack shows.
@MainActor func shownPage(_ s: Session) throws -> MountedElement {
    guard let page = try s.element(ofType: .navigationStack).visiblePage else { throw NoShownPage() }
    return page
}

/// What a case finds where its stack shows no page.
struct NoShownPage: Error {}
