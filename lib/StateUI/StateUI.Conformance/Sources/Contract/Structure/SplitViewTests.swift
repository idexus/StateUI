// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SplitViewContract` on a host: the sidebar beside the detail shows as the binding says; the user hiding or showing
/// it is heard on the binding, the program's is shown; the sidebar stands on the material of its place.
@_spi(Host) public enum SplitViewTests: ConformanceFamily {
    public static let name = "SplitView"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("standsAloneShowingItsDetail", proves: [
                Covered(SplitViewContract.self), Covered(ViewContract.frameChanged, on: "Text"),
            ]) { s in
                let frames = Received<[Double]>()
                s.start {
                    SplitView(State(wrappedValue: true).projectedValue) {
                        Text("Sidebar")
                    } detail: { WideDetail(Text("Detail").onEvent(ViewContract.frameChanged) { frames.values.append($0) }) }
                }
                s.settle { Aspects.laidOut(frames) }
                s.expect(Aspects.laidOut(frames), true, "its detail laid out in the window")
            },
            ConformanceCase("theSidebarStandsBesideTheDetail", proves: [
                Covered(SplitViewContract.showsSidebar),
            ]) { s in
                s.start {
                    SplitView(State(wrappedValue: true).projectedValue) {
                        Text("Sidebar").id("sidebar")
                    } detail: { WideDetail(Text("Detail").id("detail")) }
                }
                let split = try s.element(ofType: SplitViewContract.nodeType)

                try s.settle { try s.held(SplitViewContract.showsSidebar, on: split) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("detail")), true)
                s.expect(try s.held(SplitViewContract.showsSidebar, on: split), true)
            },
            ConformanceCase("theUsersHidingIsHeardOnTheBinding", proves: [
                Covered(SplitViewContract.showsSidebar), Covered(SplitViewContract.showsSidebarChanged),
            ]) { s in
                let open = State(wrappedValue: true)
                s.start {
                    SplitView(open.projectedValue) { Text("Sidebar") } detail: { WideDetail(Text("Detail")) }
                }
                let split = try s.element(ofType: SplitViewContract.nodeType)
                try s.settle { try s.held(SplitViewContract.showsSidebar, on: split) == true }

                try s.perform(.toggle, on: split)
                s.settle { !open.wrappedValue }
                s.expect(open.wrappedValue, false, "the user hid it")
                s.expect(try s.held(SplitViewContract.showsSidebar, on: split), false)

                try s.perform(.toggle, on: split)
                s.settle { open.wrappedValue }
                s.expect(open.wrappedValue, true, "and showed it again")
            },
            ConformanceCase("theProgramsHidingIsShown", proves: [
                Covered(SplitViewContract.showsSidebar),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let open = State(wrappedValue: true)
                s.start {
                    SplitView(open.projectedValue) {
                        Text("Sidebar")
                    } detail: {
                        WideDetail(VStack { Button("Hide").onClicked { open.wrappedValue = false }.id("hide") })
                    }
                }
                let split = try s.element(ofType: SplitViewContract.nodeType)
                try s.settle { try s.held(SplitViewContract.showsSidebar, on: split) == true }

                try s.perform(.activate, on: s.element("hide"))
                try s.settle { try s.held(SplitViewContract.showsSidebar, on: split) == false }
                s.expect(try s.held(SplitViewContract.showsSidebar, on: split), false)
            },
            standsOn(SplitViewContract.sidebarBackground, "theSidebarStandsOnItsMaterialBesideTheDetail") {
                $0.sidebarBackground($1)
            },
            standsOn(SplitViewContract.flyoutBackground, "theSidebarStandsOnItsFlyoutsMaterialOverTheDetail") {
                $0.flyoutBackground($1)
            },
            follows(SplitViewContract.sidebarBackground, "theSidebarFollowsAMaterialStateBesideTheDetail") {
                $0.sidebarBackground($1)
            },
            follows(SplitViewContract.flyoutBackground, "theSidebarFollowsAMaterialStateOverTheDetail") {
                $0.flyoutBackground($1)
            },
        ]
    }

    /// The sidebar stands on the material `member` says from a state handed on as `$x` - the colour the state holds,
    /// then the one written into it: a material's channel.
    @MainActor
    private static func follows(
        _ member: ElementProperty<SplitViewContract, Material>, _ name: String,
        _ write: @escaping @MainActor (SplitView, Binding<Material>) -> SplitView.Modified
    ) -> ConformanceCase {
        ConformanceCase(name, proves: [Covered(member)], needs: [Covered(ButtonContract.clicked)]) { s in
            let (first, changed) = (Material.color(Color("#0F766E")), Material.color(Color("#512BD4")))
            let value = State(wrappedValue: first)
            s.start {
                write(SplitView(State(wrappedValue: true).projectedValue) {
                    Text("Sidebar")
                } detail: {
                    WideDetail(VStack { Button("Change").onClicked { value.wrappedValue = changed }.id("change") })
                }, value.projectedValue)
            }
            let split = try s.element(ofType: SplitViewContract.nodeType)
            try s.settle { try s.held(member, on: split) == first }
            s.expect(try s.held(member, on: split), first, "the material the state holds")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(member, on: split) == changed }
            s.expect(try s.held(member, on: split), changed, "the material written into it")
        }
    }

    /// The sidebar stands on the material `member` says - the colour it starts with, then the one the tree changes
    /// it to.
    @MainActor
    private static func standsOn(
        _ member: ElementProperty<SplitViewContract, Material>, _ name: String,
        _ write: @escaping @MainActor (SplitView, Material) -> SplitView.Modified
    ) -> ConformanceCase {
        ConformanceCase(name, proves: [Covered(member)], needs: [Covered(ButtonContract.clicked)]) { s in
            let (first, changed) = (Material.color(Color("#0F766E")), Material.color(Color("#512BD4")))
            let value = State(wrappedValue: first)
            s.start {
                write(SplitView(State(wrappedValue: true).projectedValue) {
                    Text("Sidebar")
                } detail: {
                    WideDetail(VStack { Button("Change").onClicked { value.wrappedValue = changed }.id("change") })
                }, value.wrappedValue)
            }
            let split = try s.element(ofType: SplitViewContract.nodeType)
            try s.settle { try s.held(member, on: split) == first }
            s.expect(try s.held(member, on: split), first, "the material it starts with")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(member, on: split) == changed }
            s.expect(try s.held(member, on: split), changed, "the material the tree changed it to")
        }
    }
}

/// A split view's detail in a window wide enough for every desktop host to stand the sidebar beside it: in a
/// narrower one a host may lay the sidebar over the detail, and closed.
private struct WideDetail: View {
    let detail: any View

    @Environment(\.window) private var window

    init(_ detail: any View) {
        self.detail = detail
    }

    var body: some View {
        let window = self.window
        return VStack { ModifiedContent(node: detail.node) }
            .onCreated {
                window.width = 1016
                window.height = 700
            }
    }
}
