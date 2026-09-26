// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `NavigationStackContract` on a host: the top page of the path shows, named on the window; the user's way back
/// takes it off the path, which is heard; the bar's words stand in the colour the tree gives them.
@_spi(Host) public enum NavigationStackTests: ConformanceFamily {
    public static let name = "NavigationStack"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("theTopPageOfThePathShows", covers: [
                Covered(NavigationStackContract.self), Covered(PageElementContract.title, on: "Page"),
            ]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        PhasePage(title: "Root", log: Received())
                    } destination: { number in PhasePage(title: "Detail \(number)", log: Received()) }
                }
                let window = try s.element(ofType: WindowContract.nodeType)
                try s.settle { try s.held(WindowContract.title, on: window) == "Root" }
                s.expect(try s.held(WindowContract.title, on: window), "Root", "the root names the window")

                path.wrappedValue = [7]
                try s.settle { try s.held(WindowContract.title, on: window) == "Detail 7" }
                s.expect(try s.held(WindowContract.title, on: window), "Detail 7", "the pushed page names it")
            },
            ConformanceCase("theUsersWayBackIsHeardAndShortensThePath", covers: [
                Covered(NavigationStackContract.popped),
            ]) { s in
                let path = State(wrappedValue: [1, 2])
                s.start {
                    NavigationStack(path.projectedValue) {
                        Label("Root")
                    } destination: { number in Label("Page \(number)") }
                }
                let stack = try s.element(ofType: NavigationStackContract.nodeType)

                try s.perform(.goBack, on: stack)
                s.settle { path.wrappedValue == [1] }
                s.expect(path.wrappedValue, [1], "one page back")
                try s.perform(.goBack, on: stack)
                s.settle { path.wrappedValue.isEmpty }
                s.expect(path.wrappedValue, [], "and back to the root")
            },
            Aspects.holds(NavigationStackContract.barForegroundColor, on: "NavigationStack", .white, then: .black),
        ]
    }
}
