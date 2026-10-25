// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BarElementContract` on a host: the bar an arrangement declares holds the look the tree gives it, and the look the
/// tree changes it to - on every element wearing the tier - and the look crosses a sheet a view in it presents.
@_spi(Host) public enum BarElementTests: ConformanceFamily {
    public static let name = "BarElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(BarElementContract.self).flatMap { element in
            [
                holds(BarElementContract.barBackground, on: element, .color(.steelBlue), then: .color(.firebrick)),
                // A blur, or the color a host that blurs nothing behind its bars stands in for it.
                holds(
                    BarElementContract.barBackground, on: element, .blur(.thick), then: .blur(.ultraThin),
                    aspect: "showsABlurOrWhatStandsInForIt"),
                holds(
                    BarElementContract.barForegroundColor, on: element, .white, then: .black,
                    over: [Write(BarElementContract.barBackground, Material.color(.steelBlue))]),
                holds(BarElementContract.barButtonBackgroundColor, on: element, .steelBlue, then: .firebrick),
                holds(BarElementContract.toolbarStyle, on: element, .glass, then: .rounded),
                crossesASheet(on: element),
            ]
        }
    }

    /// The bar's color `element` declares crosses a sheet a view in it presents: the stack in the sheet wears it, as
    /// nothing nearer says another.
    @MainActor
    static func crossesASheet(on element: String) -> ConformanceCase {
        ConformanceCase("\(element).barBackground.crossesASheetItsViewPresents", proves: [
            Covered(BarElementContract.barBackground, on: element),
        ], needs: [Covered(SheetContract.isPresented)]) { s in
            s.start {
                declaring(element, [Write(BarElementContract.barBackground, Material.color(.steelBlue))], beside: [
                    Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) {
                        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                            Text("In the sheet").title("Sheet")
                        } destination: { _ in Text("Pushed") }
                    },
                ])
            }
            _ = try s.element(ofType: SheetContract.nodeType)
            let inSheet = { () throws -> MountedElement in
                guard let stack = s.elements(ofType: NavigationStackContract.nodeType)
                    .last(where: { $0.enclosing(type: .sheet) != nil })
                else { throw DriverCannot("find the stack in the sheet") }
                return stack
            }
            try s.settle { try s.held(BarElementContract.barBackground, on: inSheet()) == .color(.steelBlue) }
            s.expect(
                try s.held(BarElementContract.barBackground, on: inSheet()), Material.color(.steelBlue),
                "the look of the bar over the view presenting the sheet")
        }
    }

    /// `member`, declared by `element` `over` what else it declares, holds what the tree gives it and what the tree
    /// changes it to.
    @MainActor
    static func holds<Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<BarElementContract, Value>, on element: String, _ first: Value, then second: Value,
        over others: [any Worn] = [], aspect: String = "holdsWhatTheTreeGivesAndChanges"
    ) -> ConformanceCase {
        Aspects.holds(
            member, on: element, first, then: second, with: others, page: declaring(_:_:beside:), late: true,
            aspect: aspect)
    }

    /// A page where `element` wears `worn` around a bar every host draws - a split view's detail, a tabbed view's
    /// first tab are a stack of one page - `beside` the page's words, its title standing on
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
        default:
            return Specimens.page(element, worn, beside: beside)
        }
    }
}
