// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Every element that is drawn, shown on a page and taken away again a click each way - bare, then dressed: taken
/// away the second time, it leaves its host holding as many views alive as the first time, or a view of it
/// outlived it. Every host's own suite runs it with its driver; it marks nothing.
/// Design: docs/design/host/conformance.md#nothing-left-behind
@MainActor
@_spi(Host) public enum Leaving {
    /// Each of `elements` whose views `driver`'s host held on to after it left, with how many; none where the host
    /// let go of every view, or counts none.
    public static func outlived(
        on driver: any HostDriver, _ elements: [String] = Specimens.wearing(VisualElementContract.self)
    ) throws -> [String] {
        var outlived: [String] = []
        for element in elements {
            for (worn, said) in [([], element), (dressing(element), "\(element) dressed")] {
                let tree = driver.start(clock: nil, reducesMotion: false) { ComingAndGoing(element: element, worn: worn) }
                let once = try toggle(tree, on: driver)
                _ = try toggle(tree, on: driver)
                if let once, let twice = try toggle(tree, on: driver), twice > once {
                    let left = settled(above: once, on: driver)
                    if left > once { outlived.append("\(said): \(left - once) views") }
                }
            }
        }
        return outlived
    }

    /// What `element` wears the second time: a look from each tier it wears, and an ear for each gesture - what a
    /// host answers with a closure of its own.
    static func dressing(_ element: String) -> [any Worn] {
        func on(_ tier: any Contract.Type, _ worn: [any Worn]) -> [any Worn] {
            Specimens.wearing(tier).contains(element) ? worn : []
        }
        let visual: [any Worn] = [
            Write(VisualElementContract.background, Background.color(.red)), Write(VisualElementContract.opacity, 0.9),
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
            + on(TextStyleElementContract.self, [Write(TextStyleElementContract.textColor, .red)])
            + on(TintElementContract.self, [Write(TintElementContract.tint, .red)])
            + on(PaddingElementContract.self, [Write(PaddingElementContract.padding, Insets(4))])
            + on(BorderElementContract.self, border)
    }

    /// The views alive once the host let go of what it may keep a while after it left - MapKit on the Mac keeps a
    /// map five seconds: stepping the host until no more than `once` are, at most ten seconds.
    /// Design: docs/design/host/conformance.md#nothing-left-behind
    private static func settled(above once: Int, on driver: any HostDriver) -> Int {
        let end = ContinuousClock.now + .seconds(10)
        var alive = driver.liveViews ?? once
        while alive > once, ContinuousClock.now < end {
            driver.step()
            alive = driver.liveViews ?? once
        }
        return alive
    }

    /// Clicks the page's toggle and steps the host until the specimen came or went: the views it then holds alive.
    private static func toggle(_ tree: MountedTree, on driver: any HostDriver) throws -> Int? {
        func shown() -> Bool { tree.root?.first(id: .manual("specimen")) != nil }
        guard let toggle = tree.root?.first(id: .manual("toggle")) else { throw Session.Missing(id: "toggle") }
        let was = shown()
        try driver.perform(.activate, on: toggle)
        for _ in 0..<150 where shown() == was { driver.step() }
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
