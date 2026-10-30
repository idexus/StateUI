// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Every element that is drawn, and every item of a page's bar, shown and taken away again a click each way - bare,
/// then dressed: taken away the second time, it leaves its host holding as many views and elements alive as the
/// first time, or one of them outlived it. Every host's own suite runs it with its driver; it marks nothing.
/// Design: docs/design/host/conformance.md#nothing-left-behind
@MainActor
@_spi(Host) public enum Leaving {
    /// What `outlived` walks unless told otherwise: every element that is drawn, then a page's bar's items.
    public static var walked: [String] {
        Specimens.wearing(VisualElementContract.self) + onTheBar
    }

    /// The items that come and go on a page's bar.
    static let onTheBar = ["ToolbarButton", "ToolbarToggle", "ToolbarLabel"]

    /// Each of `elements` whose views or elements `driver`'s host held on to after it left, with how many; none where
    /// the host let go of everything.
    public static func outlived(on driver: any HostDriver, _ elements: [String] = walked) throws -> [String] {
        var outlived: [String] = []
        for element in elements {
            for (dressed, said) in [(false, element), (true, "\(element) dressed")] {
                let tree = driver.start(clock: nil, reducesMotion: false) { page(element, dressed: dressed) }
                let once = try toggle(tree, on: driver)
                let (kinds, held) = (driver.liveViewKinds, MountedElement.liveCount)
                _ = try toggle(tree, on: driver)
                let twice = try toggle(tree, on: driver)
                if let once, let twice, twice > once {
                    let left = settled(above: once, on: driver) { driver.liveViews ?? once }
                    if left > once { outlived.append("\(said): \(left - once) views" + grown(from: kinds, on: driver)) }
                }
                let kept = settled(above: held, on: driver) { MountedElement.liveCount }
                if kept > held { outlived.append("\(said): \(kept - held) elements") }
            }
        }
        return outlived
    }

    /// The page `element` comes and goes on, bare or dressed.
    private static func page(_ element: String, dressed: Bool) -> AnyView {
        onTheBar.contains(element)
            ? AnyView(ComingAndGoingOnTheBar(element: element, dressed: dressed))
            : AnyView(ComingAndGoing(element: element, worn: dressed ? dressing(element) : []))
    }

    /// What `element` wears the second time: a look from each tier it wears, and an ear for each gesture - what a
    /// host answers with a closure of its own.
    static func dressing(_ element: String) -> [any Worn] {
        func on(_ tier: any Contract.Type, _ worn: [any Worn]) -> [any Worn] {
            Specimens.wearing(tier).contains(element) ? worn : []
        }
        let visual: [any Worn] = [
            Write(VisualElementContract.background, Material.color(.red)), Write(VisualElementContract.opacity, 0.9),
        ]
        let gestures: [any Worn] = [
            HearDone(ViewContract.tapped) {}, HearDone(ViewContract.pointerEntered) {},
            Hear(ViewContract.pointerPressed) { _ in }, Hear(ViewContract.swiped) { _ in },
            HearThree(ViewContract.panUpdated) { _, _, _ in },
        ]
        let border: [any Worn] = [
            Write(BorderElementContract.stroke, Brush.solidColor(.red)), Write(BorderElementContract.lineWidth, 2),
            Write(BorderElementContract.shape, .roundedRectangle(12)),
        ]
        return on(VisualElementContract.self, visual) + on(ViewContract.self, gestures)
            + on(FontElementContract.self, [Write(FontElementContract.fontSize, 17)])
            + on(TextColorElementContract.self, [Write(TextColorElementContract.textColor, .red)])
            + on(TintElementContract.self, [Write(TintElementContract.tint, .red)])
            + on(PaddingElementContract.self, [Write(PaddingElementContract.padding, Insets(4))])
            + on(BorderElementContract.self, border)
    }

    /// The kinds of view more of are alive now than in `before`, as the driver names them - " (span +1)" - so a view
    /// that outlived its element says what it is; nothing where the driver names none.
    private static func grown(from before: [String: Int]?, on driver: any HostDriver) -> String {
        guard let before, let now = driver.liveViewKinds else { return "" }
        let grown = now.filter { $0.value > before[$0.key] ?? 0 }.map { "\($0.key) +\($0.value - (before[$0.key] ?? 0))" }
        return grown.isEmpty ? "" : " (" + grown.sorted().joined(separator: ", ") + ")"
    }

    /// What `alive` counts once the host let go of what a toolkit keeps a while after it left: stepping the host until
    /// no more than `once` are, at most ten seconds.
    /// Design: docs/design/host/conformance.md#nothing-left-behind
    private static func settled(above once: Int, on driver: any HostDriver, _ alive: () -> Int) -> Int {
        let end = ContinuousClock.now + .seconds(10)
        var count = alive()
        while count > once, ContinuousClock.now < end {
            driver.step()
            count = alive()
        }
        return count
    }

    /// Clicks the page's toggle and steps the host until the specimen came or went: the views it then holds alive.
    private static func toggle(_ tree: MountedTree, on driver: any HostDriver) throws -> Int? {
        func shown() -> Bool { tree.root?.first(id: .manual("specimen")) != nil }
        guard let toggle = tree.root?.first(id: .manual("toggle")) else { throw Session.Missing(id: "toggle") }
        let was = shown()
        try driver.perform(.activate, on: toggle)
        for _ in 0..<150 {
            guard shown() == was else { break }
            driver.step()
        }
        driver.step()
        return driver.liveViews
    }
}

/// A page that shows `element`'s specimen wearing `worn` and takes it away again, a click on its toggle each way.
struct ComingAndGoing: View {
    let element: String
    let worn: [any Worn]
    @State private var shown = true

    var body: some View {
        VStack {
            if shown {
                Specimens.view(element, worn)
            }
            Button("Toggle")
                .id("toggle")
                .onClicked { shown.toggle() }
        }
    }
}

/// A page whose bar shows `element`'s specimen and takes it away again, a click on its toggle each way - dressed, with
/// an ear for it and, a button, a menu: what a host answers with an action of its own.
struct ComingAndGoingOnTheBar: View {
    let element: String
    let dressed: Bool
    @State private var shown = true

    var body: some View {
        let (element, dressed, shown) = (element, dressed, shown)
        let toggle = Button("Toggle").id("toggle").onClicked { self.shown.toggle() }
        return NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            DeclaringPage(beside: [toggle], key: "\(shown)") {
                guard shown, element == "ToolbarButton" else { return [] }
                let button = ToolbarButton("Save").id("specimen")
                return [dressed ? button.onClicked {}.menu(.split) { MenuItem("Save as") } : button]
            } toggles: {
                guard shown, element == "ToolbarToggle" else { return [] }
                let setting = ToolbarToggle("Ruler", isOn: false).id("specimen")
                return [dressed ? setting.onToggled { _ in } : setting]
            } labels: {
                guard shown, element == "ToolbarLabel" else { return [] }
                let label = ToolbarLabel("Saved").id("specimen")
                return [dressed ? label.icon("test_dot.png") : label]
            }
        } destination: { _ in Text("Pushed") }
    }
}
