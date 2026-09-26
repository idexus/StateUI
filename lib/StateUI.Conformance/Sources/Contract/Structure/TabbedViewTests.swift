// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TabbedViewContract` on a host: the tab the binding names shows; the user's choice lands on the binding, the
/// program's is shown.
@_spi(Host) public enum TabbedViewTests: ConformanceFamily {
    public static let name = "TabbedView"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("theTabTheBindingNamesShows", covers: [
                Covered(TabbedViewContract.self), Covered(TabbedViewContract.currentPage),
            ]) { s in
                s.start {
                    TabbedView([0, 1]) { tab in Label("Tab \(tab)").id("tab\(tab)") }
                        .selection(State(wrappedValue: 1).projectedValue)
                }
                let tabs = try s.element(ofType: TabbedViewContract.nodeType)

                try s.settle { try s.held(TabbedViewContract.currentPage, on: tabs) == 1 }
                s.expect(try s.held(TabbedViewContract.currentPage, on: tabs), 1)
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("tab1")), true, "its page shown")
            },
            ConformanceCase("theUsersChoiceLandsOnTheBinding", covers: [
                Covered(TabbedViewContract.currentPage), Covered(TabbedViewContract.currentPageChanged),
            ]) { s in
                let tab = State(wrappedValue: 0)
                s.start { TabbedView([0, 1]) { tab in Label("Tab \(tab)") }.selection(tab.projectedValue) }
                let tabs = try s.element(ofType: TabbedViewContract.nodeType)

                try s.perform(.choose(1), on: tabs)
                s.settle { tab.wrappedValue == 1 }
                s.expect(tab.wrappedValue, 1)
                s.expect(try s.held(TabbedViewContract.currentPage, on: tabs), 1)
            },
            ConformanceCase("theProgramsChoiceIsShown", covers: [
                Covered(TabbedViewContract.currentPage), Covered(ButtonContract.clicked),
            ]) { s in
                let tab = State(wrappedValue: 0)
                s.start {
                    TabbedView([0, 1]) { number in
                        VStack { Button("Next").onClicked { tab.wrappedValue = 1 }.id("next\(number)") }
                    }
                    .selection(tab.projectedValue)
                }
                let tabs = try s.element(ofType: TabbedViewContract.nodeType)

                try s.perform(.activate, on: s.element("next0"))
                try s.settle { try s.held(TabbedViewContract.currentPage, on: tabs) == 1 }
                s.expect(try s.held(TabbedViewContract.currentPage, on: tabs), 1)
            },
        ]
    }
}
