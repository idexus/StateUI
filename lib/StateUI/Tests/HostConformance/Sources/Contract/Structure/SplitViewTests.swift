// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `SplitViewContract` on a host: the sidebar beside the detail shows as the binding says; the user hiding or showing
/// it is heard on the binding, the program's is shown.
@_spi(Host) public enum SplitViewTests: ConformanceFamily {
    public static let name = "SplitView"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("theSidebarStandsBesideTheDetail", covers: [
                Covered(SplitViewContract.self), Covered(SplitViewContract.isSidebarVisible),
            ]) { s in
                s.start {
                    SplitView(State(wrappedValue: true).projectedValue) {
                        Label("Sidebar").id("sidebar")
                    } detail: { Label("Detail").id("detail") }
                }
                let split = try s.element(ofType: SplitViewContract.nodeType)

                try s.settle { try s.held(SplitViewContract.isSidebarVisible, on: split) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("detail")), true)
                s.expect(try s.held(SplitViewContract.isSidebarVisible, on: split), true)
            },
            ConformanceCase("theUsersHidingIsHeardOnTheBinding", covers: [
                Covered(SplitViewContract.isSidebarVisible), Covered(SplitViewContract.isSidebarVisibleChanged),
            ]) { s in
                let open = State(wrappedValue: true)
                s.start {
                    SplitView(open.projectedValue) { Label("Sidebar") } detail: { Label("Detail") }
                }
                let split = try s.element(ofType: SplitViewContract.nodeType)
                try s.settle { try s.held(SplitViewContract.isSidebarVisible, on: split) == true }

                try s.perform(.toggle, on: split)
                s.settle { !open.wrappedValue }
                s.expect(open.wrappedValue, false, "the user hid it")
                s.expect(try s.held(SplitViewContract.isSidebarVisible, on: split), false)

                try s.perform(.toggle, on: split)
                s.settle { open.wrappedValue }
                s.expect(open.wrappedValue, true, "and showed it again")
            },
            ConformanceCase("theProgramsHidingIsShown", covers: [
                Covered(SplitViewContract.isSidebarVisible), Covered(ButtonContract.clicked),
            ]) { s in
                let open = State(wrappedValue: true)
                s.start {
                    SplitView(open.projectedValue) {
                        Label("Sidebar")
                    } detail: {
                        VStack { Button("Hide").onClicked { open.wrappedValue = false }.id("hide") }
                    }
                }
                let split = try s.element(ofType: SplitViewContract.nodeType)
                try s.settle { try s.held(SplitViewContract.isSidebarVisible, on: split) == true }

                try s.perform(.activate, on: s.element("hide"))
                try s.settle { try s.held(SplitViewContract.isSidebarVisible, on: split) == false }
                s.expect(try s.held(SplitViewContract.isSidebarVisible, on: split), false)
            },
        ]
    }
}
