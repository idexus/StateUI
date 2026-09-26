// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PageContract` on a host: a page shows its content, hears each phase of its life in order as pages are pushed
/// and popped over it, and stands with the bar, the way back, the background and the padding its session asks for.
@_spi(Host) public enum PageTests: ConformanceFamily {
    public static let name = "Page"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aWindowsPageShowsItsContent", covers: [Covered(PageContract.self)]) { s in
                s.start { VStack { Label("On the page").id("label") } }

                _ = try s.element(ofType: PageContract.nodeType)
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("label")), true)
            },
            ConformanceCase("theRootAppearsAndIsNavigatedTo", covers: [
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
            ConformanceCase("aPushIsHeardByThePagesInOrder", covers: [
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
            ConformanceCase("aPopBringsThePageBeneathBack", covers: [
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
            pushedHolds(PageContract.hasBackButton, false, then: true) { $0.hasBackButton = $1 },
            pushedHolds(PageContract.backButtonTitle, "Notes", then: "All notes") { $0.backButtonTitle = $1 },
            pushedHolds(PageContract.hasNavigationBar, false, then: true) { $0.hasNavigationBar = $1 },
            pushedHolds(PageContract.background, .red, then: .blue) { $0.background = $1 },
            ConformanceCase("aPagesPaddingKeepsItsContentIn", covers: [
                Covered(PageContract.padding), Covered(ButtonContract.clicked),
            ]) { s in
                let wide = State(wrappedValue: false)
                let frames = Received<[Double]>()
                s.start {
                    SessionPage(beside: [
                        ColorBox(.red).width(20).height(20).horizontalAlignment(.start)
                            .onEvent(ViewContract.frameChanged) { frames.values.append($0) },
                        Button("Wider").onClicked { wide.wrappedValue = true }.id("change"),
                    ], key: "\(wide.wrappedValue)") { page, _ in
                        page.padding = wide.wrappedValue ? Insets(30) : Insets(10)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { frames.values.last.map(FrameReport.inContent)?.first == 10 }
                s.expect(frames.values.last.map(FrameReport.inContent)?.first, 10, "in from the window by its padding")

                try s.perform(.activate, on: s.element("change"))
                s.settle { frames.values.last.map(FrameReport.inContent)?.first == 30 }
                s.expect(frames.values.last.map(FrameReport.inContent)?.first, 30, "and by the padding the tree changed it to")
            },
        ]
    }

    /// `member` of a page pushed over the root holds what its session writes, and what the tree changes it to.
    static func pushedHolds<Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<PageContract, Value>, _ first: Value, then second: Value,
        _ write: @escaping @Sendable (PageSession, Value) -> Void
    ) -> ConformanceCase {
        ConformanceCase("Page.\(member.name).holdsWhatItsSessionWritesAndChanges", covers: [
            Covered(member), Covered(ButtonContract.clicked),
        ]) { s in
            let value = State(wrappedValue: first)
            s.start {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    Label("Root")
                } destination: { _ in
                    SessionPage(beside: [Button("Change").onClicked { value.wrappedValue = second }.id("change")],
                                key: "\(value.wrappedValue)") { page, _ in write(page, value.wrappedValue) }
                }
            }
            let pushed = try pushedPage(s)
            try s.settle { try s.held(member, on: pushedPage(s)) == first }
            s.expect(try s.held(member, on: pushed), first, "what its session wrote")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(member, on: pushedPage(s)) == second }
            s.expect(try s.held(member, on: pushedPage(s)), second, "what the tree changed it to")
        }
    }

    /// The page pushed over the root: the last page the tree holds.
    @MainActor static func pushedPage(_ s: Session) throws -> MountedElement {
        guard let page = s.elements(ofType: PageContract.nodeType).last else {
            throw DriverCannot("find a pushed page")
        }
        return page
    }
}

/// A page saying each phase of its life, as its title and the phase.
struct PhasePage: ContentView {
    let title: String
    let log: Received<String>

    @Environment private var page: PageSession

    var content: any View {
        let (title, log, page) = (self.title, self.log, self.page)
        return Label(title)
            .onCreated { page.title = title }
            .onChanged(page.phase) { log.values.append("\(title) \(page.phase)") }
    }
}
