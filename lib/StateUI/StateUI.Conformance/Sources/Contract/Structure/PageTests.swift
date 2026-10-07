// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PageContract` on a host: a page shows its content, hears each phase of its life in order as pages are pushed
/// and popped over it, and stands with the bar, the way back and the background its view says of it - as a value,
/// and from a state the host follows.
@_spi(Host) public enum PageTests: ConformanceFamily {
    public static let name = "Page"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aWindowsPageShowsItsContent", proves: [Covered(PageContract.self)]) { s in
                s.start { VStack { Text("On the page").id("label") } }

                _ = try s.element(ofType: PageContract.nodeType)
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("label")), true)
            },
            ConformanceCase("theRootAppearsAndIsNavigatedTo", proves: [
                Covered(PageContract.appearing), Covered(PageContract.navigatedTo),
            ]) { s in
                let log = Received<String>()
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        PhasePage(title: "Root", log: log)
                    } destination: { _ in PhasePage(title: "Pushed", log: log) }
                }

                s.settle { log.values == ["Root appearing", "Root navigatedTo"] }
                s.expect(log.values, ["Root appearing", "Root navigatedTo"])
            },
            ConformanceCase("aPushIsHeardByThePagesInOrder", proves: [
                Covered(PageContract.appearing), Covered(PageContract.disappearing), Covered(PageContract.navigatedTo),
                Covered(PageContract.navigatingFrom), Covered(PageContract.navigatedFrom),
            ]) { s in
                let path = State(wrappedValue: [Int]())
                let log = Received<String>()
                s.start {
                    NavigationStack(path.projectedValue) {
                        PhasePage(title: "Root", log: log)
                    } destination: { _ in PhasePage(title: "Pushed", log: log) }
                }
                s.settle { log.values.count == 2 }

                log.values = []
                path.wrappedValue = [1]
                s.settle { log.values.count == 5 }
                s.expect(log.values, [
                    "Root navigatingFrom", "Root disappearing", "Root navigatedFrom",
                    "Pushed appearing", "Pushed navigatedTo",
                ], "the root leaves before the pushed page comes")
            },
            ConformanceCase("aPopBringsThePageBeneathBack", proves: [
                Covered(PageContract.appearing), Covered(PageContract.navigatedTo),
            ]) { s in
                let path = State(wrappedValue: [1])
                let log = Received<String>()
                s.start {
                    NavigationStack(path.projectedValue) {
                        PhasePage(title: "Root", log: log)
                    } destination: { _ in PhasePage(title: "Pushed", log: log) }
                }
                s.settle { log.values.contains("Pushed navigatedTo") }

                log.values = []
                path.wrappedValue = []
                s.settle { log.values.suffix(2) == ["Root appearing", "Root navigatedTo"] }
                s.expect(Array(log.values.suffix(2)), ["Root appearing", "Root navigatedTo"], "the page beneath comes back")
            },
            pushedHolds(PageContract.showsBackButton, false, then: true) { $0.showsBackButton($1) },
            pushedHolds(PageContract.backButtonTitle, "Notes", then: "All notes") { $0.backButtonTitle($1) },
            pushedHolds(PageContract.showsNavigationBar, false, then: true) { $0.showsNavigationBar($1) },
            pushedHolds(PageContract.background, .color(.red), then: .color(.blue)) { $0.pageBackground($1) },
            pushedFollows(PageContract.showsBackButton, false, then: true) { $0.showsBackButton($1) },
            pushedFollows(PageContract.backButtonTitle, "Notes", then: "All notes") { $0.backButtonTitle($1) },
            pushedFollows(PageContract.showsNavigationBar, false, then: true) { $0.showsNavigationBar($1) },
            pushedFollowsColour(PageContract.background, .red, then: .blue) { $0.pageBackground($1) },
        ]
    }

    /// `member` of a page pushed over the root holds what its view says, and what it says once its body - and
    /// nothing around it - is built again.
    static func pushedHolds<Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<PageContract, Value>, _ first: Value, then second: Value,
        _ say: @escaping @Sendable (VStack, Value) -> VStack
    ) -> ConformanceCase {
        ConformanceCase("Page.\(member.name).holdsWhatItsViewSaysAndChanges", proves: [
            Covered(member),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: first)
            s.start {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    Text("Root")
                } destination: { _ in
                    Saying(value: value, second: second, say: say)
                }
            }
            try held(member, first, then: second, s)
        }
    }

    /// `member` of a page pushed over the root holds the state its view says it from, and follows the state as it
    /// is written, no view built again.
    static func pushedFollows<Value: HostRepresentable & StateValue & Sendable & Equatable>(
        _ member: ElementProperty<PageContract, Value>, _ first: Value, then second: Value,
        _ say: @escaping @Sendable (VStack, Binding<Value>) -> VStack
    ) -> ConformanceCase {
        ConformanceCase("Page.\(member.name).followsItsState", proves: [
            Covered(member),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: first)
            s.start {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    Text("Root")
                } destination: { _ in
                    say(changing(value, to: second), value.projectedValue)
                }
            }
            try held(member, first, then: second, s)
        }
    }

    /// `member` of a page pushed over the root holds the colour of the state its view says it from, and follows the
    /// state as it is written, no view built again - a colour's channel writing a material.
    static func pushedFollowsColour(
        _ member: ElementProperty<PageContract, Material>, _ first: Color, then second: Color,
        _ say: @escaping @Sendable (VStack, Binding<Color>) -> VStack
    ) -> ConformanceCase {
        ConformanceCase("Page.\(member.name).followsItsState", proves: [
            Covered(member),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: first)
            s.start {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    Text("Root")
                } destination: { _ in
                    say(changing(value, to: second), value.projectedValue)
                }
            }
            try held(member, .color(first), then: .color(second), s)
        }
    }

    /// Words and a button writing `second` into `value`.
    static func changing<Value>(_ value: State<Value>, to second: Value) -> VStack {
        VStack {
            Text("Page")
            Button("Change").onClicked { value.wrappedValue = second }.id("change")
        }
    }

    /// The pushed page holds `first`, then `second` once the button is clicked.
    @MainActor static func held<Value: HostRepresentable & Equatable>(
        _ member: ElementProperty<PageContract, Value>, _ first: Value, then second: Value, _ s: Session
    ) throws {
        let pushed = try pushedPage(s)
        try s.settle { try s.held(member, on: pushedPage(s)) == first }
        s.expect(try s.held(member, on: pushed), first, "what its view said")

        try s.perform(.activate, on: s.element("change"))
        try s.settle { try s.held(member, on: pushedPage(s)) == second }
        s.expect(try s.held(member, on: pushedPage(s)), second, "what it was changed to")
    }

    /// The page pushed over the root: the last page the tree holds.
    @MainActor static func pushedPage(_ s: Session) throws -> MountedElement {
        guard let page = s.elements(ofType: PageContract.nodeType).last else {
            throw DriverCannot("find a pushed page")
        }
        return page
    }
}

/// A page whose body says `value` of its page, and is built again - alone - when the button writes `second`.
struct Saying<Value: HostRepresentable & Sendable & Equatable>: View {
    let value: State<Value>
    let second: Value
    let say: @Sendable (VStack, Value) -> VStack

    var body: some View {
        say(PageTests.changing(value, to: second), value.wrappedValue)
    }
}

/// A page saying each phase of its life, as its title and the phase.
struct PhasePage: View {
    let title: String
    let log: Received<String>

    var body: some View {
        let (title, log) = (self.title, self.log)
        return Text(title).title(title).loggingPhases(log, as: title)
    }
}
