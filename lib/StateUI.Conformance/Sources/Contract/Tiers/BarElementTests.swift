// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BarElementContract` on a host: the bar an arrangement declares holds the colours, the application's name, line
/// and mark the tree gives it, and those the tree changes them to - on every element wearing the tier.
@_spi(Host) public enum BarElementTests: ConformanceFamily {
    public static let name = "BarElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(BarElementContract.self).flatMap { element in
            [
                holds(BarElementContract.barBackgroundColor, on: element, .steelBlue, then: .firebrick),
                holds(BarElementContract.barForegroundColor, on: element, .white, then: .black),
                holds(BarElementContract.barTitle, on: element, "Notes", then: "Drafts"),
                holds(BarElementContract.barSubtitle, on: element, "Inbox", then: "Sent"),
                holds(BarElementContract.barIcon, on: element, "test_dot.png", then: "test_wide.png"),
            ]
        }
    }

    /// `member`, declared by `element`, holds what the tree gives it and what the tree changes it to.
    static func holds<Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<BarElementContract, Value>, on element: String, _ first: Value, then second: Value
    ) -> ConformanceCase {
        ConformanceCase("\(element).\(member.name).holdsWhatTheTreeGivesAndChanges", proves: [
            Covered(member, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: first)
            s.start {
                declaring(element, [Write(member, value.wrappedValue)], beside: [
                    Button("Change").onClicked { value.wrappedValue = second }.id("change"),
                ])
            }
            let specimen = try s.specimen(element)
            try s.settle { try s.held(member, on: specimen) == first }
            s.expect(try s.held(member, on: specimen), first, "the value the tree gave")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(member, on: specimen) == second }
            s.expect(try s.held(member, on: specimen), second, "the value the tree changed it to")
        }
    }

    /// A page where `element` wears `worn` around a bar every host draws - a split view's detail, a tabbed view's
    /// first tab and a modal stack's root are a stack of one page - `beside` the page's words.
    static func declaring(_ element: String, _ worn: [any Worn], beside: [any View]) -> any Page {
        let dressing = Dressing(worn)
        let others: [any View] = beside
        let stack = {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                VStack { [Label("Page")] + others }
            } destination: { _ in Label("Pushed") }
        }
        switch element {
        case "SplitView":
            return dressing.wear(SplitView(State(wrappedValue: true).projectedValue) {
                Label("Sidebar")
            } detail: { stack() })
        case "TabbedView":
            return dressing.wear(TabbedView([0, 1]) { tab -> any Page in tab == 0 ? stack() : Label("Other") })
        case "ModalStack":
            return dressing.wear(ModalStack(State(wrappedValue: [Int]()).projectedValue) {
                stack()
            } destination: { _ in Label("Sheet") })
        default:
            return Specimens.page(element, worn, beside: beside)
        }
    }
}
