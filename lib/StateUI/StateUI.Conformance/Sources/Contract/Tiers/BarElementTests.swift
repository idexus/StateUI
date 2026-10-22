// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BarElementContract` on a host: the bar an arrangement declares holds the colors, the application's name, line
/// and mark the tree gives it, and those the tree changes them to - on every element wearing the tier; a modal
/// stack's colors paint the sheets it shows too.
@_spi(Host) public enum BarElementTests: ConformanceFamily {
    public static let name = "BarElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(BarElementContract.self).flatMap { element in
            [
                holds(BarElementContract.barBackgroundColor, on: element, .steelBlue, then: .firebrick),
                holds(
                    BarElementContract.barForegroundColor, on: element, .white, then: .black,
                    over: [Write(BarElementContract.barBackgroundColor, Color.steelBlue)]),
                holds(BarElementContract.barTitle, on: element, "Notes", then: "Drafts"),
                holds(BarElementContract.barSubtitle, on: element, "Inbox", then: "Sent"),
                holds(BarElementContract.barIcon, on: element, "test_dot.png", then: "test_wide.png"),
                holds(BarElementContract.barButtonBackgroundColor, on: element, .steelBlue, then: .firebrick),
                holds(BarElementContract.toolbarStyle, on: element, .glass, then: .rounded),
            ] + (element == "ModalStack" ? [colorsPaintTheSheets()] : [])
        }
    }

    /// A modal stack's bar colors paint the bar of the sheet it shows, and those the tree changes them to.
    @MainActor
    static func colorsPaintTheSheets() -> ConformanceCase {
        ConformanceCase("ModalStack.barColors.paintTheSheetsItShows", proves: [
            Covered(BarElementContract.barBackgroundColor, on: "ModalStack"),
            Covered(BarElementContract.barForegroundColor, on: "ModalStack"),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let painted = State(wrappedValue: false)
            s.start {
                ModalStack(State(wrappedValue: [1]).projectedValue) {
                    VStack { Text("Page") }.title("Page")
                } destination: { _ in
                    VStack { Button("Change").onClicked { painted.wrappedValue = true }.id("change") }
                        .title("Sheet")
                        .id("sheet")
                }
                .barBackgroundColor(painted.wrappedValue ? .firebrick : .steelBlue)
                .barForegroundColor(painted.wrappedValue ? .black : .white)
            }
            try s.settle { try s.isShown("sheet") }
            var sheet = try s.element("sheet")
            while sheet.type != .page, let parent = sheet.parent { sheet = parent }
            let bar = { (member: ElementProperty<BarElementContract, Color>) in try s.held(member, on: sheet) }
            // A color changing travels to the new one: both are waited for.
            try s.settle {
                try bar(BarElementContract.barBackgroundColor) == .steelBlue && bar(BarElementContract.barForegroundColor) == .white
            }
            s.expect(try bar(BarElementContract.barBackgroundColor), .steelBlue, "the stack's color on its sheet's bar")
            s.expect(try bar(BarElementContract.barForegroundColor), .white, "and what stands on it in the stack's")

            try s.perform(.activate, on: s.element("change"))
            try s.settle {
                try bar(BarElementContract.barBackgroundColor) == .firebrick && bar(BarElementContract.barForegroundColor) == .black
            }
            s.expect(try bar(BarElementContract.barBackgroundColor), .firebrick, "the color the tree changed it to")
            s.expect(try bar(BarElementContract.barForegroundColor), .black, "and the words'")
        }
    }

    /// `member`, declared by `element` `over` what else it declares, holds what the tree gives it and what the tree
    /// changes it to.
    @MainActor
    static func holds<Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<BarElementContract, Value>, on element: String, _ first: Value, then second: Value,
        over others: [any Worn] = []
    ) -> ConformanceCase {
        Aspects.holds(member, on: element, first, then: second, with: others, page: declaring(_:_:beside:), late: true)
    }

    /// A page where `element` wears `worn` around a bar every host draws - a split view's detail, a tabbed view's
    /// first tab and a modal stack's root are a stack of one page - `beside` the page's words, its title standing on
    /// the bar in the bar's colors.
    @MainActor
    static func declaring(_ element: String, _ worn: [any Worn], beside: [any View]) -> AnyView {
        // Chosen by name, so held as `any View` and handed on as its node.
        AnyView(chosen(element, worn, beside: beside))
    }

    /// The page `declaring(_:_:beside:)` shows, chosen by name.
    @MainActor
    private static func chosen(_ element: String, _ worn: [any Worn], beside: [any View]) -> any View {
        let dressing = Dressing(worn)
        let others: [any View] = beside
        let stack = {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                VStack { Beside([Text("Page")] + others) }.title("Page")
            } destination: { _ in Text("Pushed") }
        }
        switch element {
        case "NavigationStack":
            return dressing.wear(stack())
        case "SplitView":
            return dressing.wear(SplitView(State(wrappedValue: true).projectedValue) {
                Text("Sidebar")
            } detail: { stack() })
        case "TabView":
            return dressing.wear(TabView([0, 1]) { tab in
                if tab == 0 {
                    stack()
                } else {
                    Text("Other")
                }
            })
        case "ModalStack":
            return dressing.wear(ModalStack(State(wrappedValue: [Int]()).projectedValue) {
                stack()
            } destination: { _ in Text("Sheet") })
        default:
            return Specimens.page(element, worn, beside: beside)
        }
    }
}
