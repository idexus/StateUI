// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ToolbarGroupContract` on a host: a page's groups stand on its own bar while it is shown - a pushed page's
/// alone - a group's items together, by their order and at their position, out of reach with a disabled group; a
/// split view's stand in the part of its bar they name over the page shown there, move to the other part as their
/// part changes, and while the sidebar is not shown stand at the detail's start or hide with it.
@_spi(Host) public enum ToolbarGroupTests: ConformanceFamily {
    public static let name = "ToolbarGroup"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("theVisiblePagesItemsStandOnItsBar", proves: [
                Covered(ToolbarGroupContract.self),
            ], needs: [Covered(ActionElementContract.clicked, on: "ToolbarButton")]) { s in
                let path = State(wrappedValue: [Int]())
                let heard = Received<String>()
                s.start {
                    NavigationStack(path.projectedValue) {
                        DeclaringPage { [ToolbarButton("Save").onClicked { heard.values.append("save") }.id("save")] }
                    } destination: { _ in
                        DeclaringPage { [ToolbarButton("Share").onClicked { heard.values.append("share") }.id("share")] }
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
            ConformanceCase("aPushedPageShowsItsOwnAlone", proves: [Covered(ToolbarGroupContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        DeclaringPage { [ToolbarButton("Save").id("save")] }
                    } destination: { _ in
                        DeclaringPage { [ToolbarButton("Share").id("share")] }
                    }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[save]|" }
                s.expect(try bar(), "|[save]|")

                path.wrappedValue = [1]
                try s.settle { try bar() == "|[share]|" }
                s.expect(try bar(), "|[share]|", "the pushed page's own, none of the page under it")

                path.wrappedValue = []
                try s.settle { try bar() == "|[save]|" }
                s.expect(try bar(), "|[save]|", "back, as it stood")
            },
            ConformanceCase("aGroupsItemsStandTogether", proves: [Covered(ToolbarGroupContract.self)]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        Text("Page").toolbar {
                            ToolbarGroup {
                                ToolbarButton("Bold").id("bold")
                                ToolbarButton("Italic").id("italic")
                            }
                            ToolbarButton("Share").id("share")
                        }
                    } destination: { _ in Text("Pushed") }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[bold italic] [share]|" }
                s.expect(try bar(), "|[bold italic] [share]|", "one group, then an item standing alone")
            },
            ConformanceCase("groupsStandByTheirOrder", proves: [Covered(ToolbarGroupContract.order)]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        DeclaringPage {
                            [
                                ToolbarButton("Save").id("save"),
                                ToolbarButton("Later").id("later").placement(order: 1),
                                ToolbarButton("Home").id("home"),
                            ]
                        }
                    } destination: { _ in Text("Pushed") }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[save] [home] [later]|" }
                s.expect(try bar(), "|[save] [home] [later]|", "the group of order 1 after those of 0")
            },
            ConformanceCase("aGroupStandsAtItsPosition", proves: [Covered(ToolbarGroupContract.position)]) { s in
                let away = State(wrappedValue: false)
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        DeclaringPage(beside: [Button("Away").onClicked { away.wrappedValue = true }.id("change")],
                                      key: "\(away.wrappedValue)") {
                            [
                                ToolbarButton("Filter").id("filter").placement(at: .start),
                                ToolbarButton("Home").id("home"),
                                ToolbarButton("Save").id("save").placement(at: away.wrappedValue ? .overflow : .end),
                            ]
                        }
                    } destination: { _ in Text("Pushed") }
                }
                let bar = { reading(try s.bar(of: try shownPage(s))) }

                try s.settle { try bar() == "[filter] [home] [save]|" }
                s.expect(try bar(), "[filter] [home] [save]|", "the start's first in reading order, then the end's")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try bar() == "[filter] [home]|save" }
                s.expect(try bar(), "[filter] [home]|save", "behind the overflow")
            },
            ConformanceCase("aDisabledGroupsItemsAreOutOfReach", proves: [
                Covered(ToolbarGroupContract.isEnabled),
            ]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        Text("Page").toolbar {
                            ToolbarGroup {
                                ToolbarButton("Bold").id("bold")
                                ToolbarButton("Italic").id("italic")
                            }
                            .isEnabled(false)
                        }
                    } destination: { _ in Text("Pushed") }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[!bold !italic]|" }
                s.expect(try bar(), "|[!bold !italic]|")
            },
            ConformanceCase("aSplitViewsDetailItemsStandBesideTheDetailsOwn", proves: [
                Covered(ToolbarGroupContract.part),
            ]) { s in
                s.start {
                    SplitView(State(wrappedValue: true).projectedValue) {
                        DeclaringPage { [ToolbarButton("Folder").id("folder")] }
                    } detail: {
                        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                            DeclaringPage { [ToolbarButton("Save").id("save")] }
                        } destination: { _ in Text("Pushed") }
                    }
                    .toolbar {
                        ToolbarButton("Add").id("add").placement(.sidebar)
                        ToolbarButton("Home").id("home")
                    }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[save] [home]|" }
                s.expect(try bar(), "|[save] [home]|", "the detail's own nearer the title, its part's at the edge")
            },
            ConformanceCase("aSplitViewsSidebarItemsStandBesideTheSidebarsOwn", proves: [
                Covered(ToolbarGroupContract.part),
            ]) { s in
                s.start {
                    SplitView(State(wrappedValue: true).projectedValue) {
                        DeclaringPage { [ToolbarButton("Folder").id("folder")] }
                    } detail: {
                        DeclaringPage { [ToolbarButton("Save").id("save")] }
                    }
                    .toolbar {
                        ToolbarButton("Add").id("add").placement(.sidebar)
                        ToolbarButton("Home").id("home")
                    }
                }
                let bar = { try s.bar(of: try sidebarPage(s)) }

                try s.settle { try bar() == "|[folder] [add]|" }
                s.expect(try bar(), "|[folder] [add]|", "the sidebar's own nearer the title, its part's at the edge")
            },
            ConformanceCase("anItemWhosePartChangesMovesToTheOther", proves: [
                Covered(ToolbarGroupContract.part),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let inDetail = State(wrappedValue: false)
                s.start {
                    SplitView(State(wrappedValue: true).projectedValue) {
                        DeclaringPage()
                    } detail: {
                        DeclaringPage(beside: [Button("Move").onClicked { inDetail.wrappedValue = true }.id("change")]) {
                            [ToolbarButton("Save").id("save")]
                        }
                    }
                    .toolbar { ToolbarButton("Pin").id("pin").placement(inDetail.wrappedValue ? .detail : .sidebar) }
                }
                let detail = { try s.bar(of: try detailPage(s)) }

                try s.settle { try detail() == "|[save]|" }
                s.expect(try detail(), "|[save]|", "in the sidebar's part")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try detail() == "|[save] [pin]|" }
                s.expect(try detail(), "|[save] [pin]|", "moved to the detail's part")
            },
            ConformanceCase("aHiddenSidebarsItemsStandAtTheDetailsStartOrHide", proves: [
                Covered(ToolbarGroupContract.hidesWithSidebar),
            ], needs: [Covered(SplitViewContract.showsSidebar)]) { s in
                // Hidden once shown: a split view first given a wide room shows its sidebar.
                let open = State(wrappedValue: true)
                s.start {
                    SplitView(open.projectedValue) {
                        DeclaringPage()
                    } detail: {
                        DeclaringPage { [ToolbarButton("Save").id("save")] }
                    }
                    .toolbar {
                        ToolbarButton("Add").id("add").placement(.sidebar)
                        ToolbarButton("Filter").id("filter").placement(.sidebar).hidesWithSidebar(true)
                    }
                }
                let detail = { reading(try s.bar(of: try detailPage(s))) }
                let split = try s.element(ofType: SplitViewContract.nodeType)
                try s.settle { try s.held(SplitViewContract.showsSidebar, on: split) == true }

                open.wrappedValue = false
                try s.settle { try detail() == "[add] [save]|" }
                s.expect(try detail(), "[add] [save]|", "the sidebar's moved to the detail's start, the hiding one gone")
            },
        ]
    }
}

/// A bar as its reader meets it, in reading order: the groups on it - the start's, then the end's - "|", then what
/// stands behind its overflow. Whether the start stands at an edge of its own is a host's look, which its own tests
/// prove: a bar with no leading edge stands the start's first among its actions.
func reading(_ bar: String) -> String {
    let parts = bar.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 3 else { return bar }
    let onBar = [parts[0], parts[1]].filter { !$0.isEmpty }.joined(separator: " ")
    return onBar + "|" + parts[2]
}

/// The page a case's split view shows in its sidebar.
@MainActor func sidebarPage(_ s: Session) throws -> MountedElement {
    guard let page = try s.element(ofType: .splitView).arrangedChildren.first?.visiblePage else { throw NoShownPage() }
    return page
}

/// The page a case's split view shows in its detail.
@MainActor func detailPage(_ s: Session) throws -> MountedElement {
    guard let page = try s.element(ofType: .splitView).arrangedChildren.dropFirst().first?.visiblePage else {
        throw NoShownPage()
    }
    return page
}

/// The page the case's stack shows.
@MainActor func shownPage(_ s: Session) throws -> MountedElement {
    guard let page = try s.element(ofType: .navigationStack).visiblePage else { throw NoShownPage() }
    return page
}

/// What a case finds where its stack shows no page.
struct NoShownPage: Error {}
