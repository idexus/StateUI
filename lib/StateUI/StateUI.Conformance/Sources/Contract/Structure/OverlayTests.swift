// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `OverlayContract` on a host: a view a page declares over the window stands over its page, a press beside it
/// reaches the page, nothing is left once the tree takes it away, it goes with the page declaring it, and one
/// declared further in stands over those declared around it.
@_spi(Host) public enum OverlayTests: ConformanceFamily {
    public static let name = "Overlay"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anOverlayStandsOverThePageAndLetsAPressBesideItThrough", proves: [
                Covered(OverlayContract.self),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let notice = State(wrappedValue: false)
                s.start { OverlaidPage(notice: notice) }
                let beneath = try s.element("beneath")

                try s.perform(.activate, on: s.element("show"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("notice")) == true }
                let over = try s.element("notice")
                // A view coming into a layer standing already fades in: pressed once it stands.
                try s.settle { try s.reaches(over, at: Point(40, 10)) }
                s.expect(try s.reaches(over, at: Point(40, 10)), true, "the overlay takes a press on it")
                s.expect(try s.reaches(beneath, at: Point(5, 200)), true, "a press beside it reaches the page")

                try s.perform(.activate, on: s.element("hide"))
                s.settle { (try? s.element("notice")) == nil }
                s.expect((try? s.element("notice")) == nil, true, "gone once the tree takes it away")
            },
            ConformanceCase("anOverlayGoesWithThePageDeclaringIt", proves: [Covered(OverlayContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        Text("Home").overlays { Text("Home's").width(80).height(20).id("home's") }
                    } destination: { _ in Text("Pushed") }
                }
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("home's")) == true }

                let shown = { (try? s.element("home's")).flatMap { try? s.held(VisualElementContract.isVisible, on: $0) } }
                path.wrappedValue = [1]
                s.settle { shown() != true }
                s.expect(shown() == true, false, "a page pushed over it took it away")

                path.wrappedValue = []
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("home's")) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("home's")), true, "back with its page")
            },
            ConformanceCase("anOverlayDeclaredFurtherInStandsOverThoseAround", proves: [
                Covered(OverlayContract.self),
            ]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        Text("Home").overlays {
                            Text("Inner").width(80).height(40).horizontalAlignment(.start).verticalAlignment(.start)
                                .id("inner")
                        }
                    } destination: { _ in Text("Pushed") }
                    .overlays {
                        Text("Outer").width(80).height(40).horizontalAlignment(.start).verticalAlignment(.start)
                            .id("outer")
                    }
                }
                let (inner, outer) = (try s.element("inner"), try s.element("outer"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: inner) == true }

                s.expect(try s.reaches(inner, at: Point(10, 10)), true, "the inner one takes the press")
                s.expect(try s.reaches(outer, at: Point(10, 10)), false, "the outer one stands under it")
            },
        ]
    }
}

/// A page that declares a notice over its window while a state says so.
struct OverlaidPage: View {
    let notice: State<Bool>

    var body: some View {
        let notice = notice
        return VStack {
            Button("Show").onClicked { notice.wrappedValue = true }.id("show")
            Button("Hide").onClicked { notice.wrappedValue = false }.id("hide")
            ColorBox(.red).height(300).id("beneath")
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
        .overlays {
            if notice.wrappedValue {
                Text("Offline").width(80).height(20).horizontalAlignment(.end).verticalAlignment(.start).id("notice")
            }
        }
    }
}
