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
                // The notice's middle, and a point below it, on the rectangle filling the page - wherever the host
                // lays its overlays, over the page or over the whole window.
                let (stands, page) = (try s.place(of: over), try s.place(of: beneath))
                let underNotice = Point(stands.x + stands.width / 2 - page.x, stands.y + stands.height / 2 - page.y)
                let beside = Point(underNotice.x, underNotice.y + 60)
                s.expect(try s.reaches(beneath, at: beside), true, "a press beside it reaches the page")
                s.expect(try s.reaches(beneath, at: underNotice), false, "a press on it reaches nothing beneath")

                try s.perform(.activate, on: s.element("hide"))
                try s.settle { try s.reaches(beneath, at: underNotice) }
                s.expect(try s.reaches(beneath, at: underNotice), true, "gone, a press where it stood reaches the page")
            },
            ConformanceCase("anOverlayGoesWithThePageDeclaringIt", proves: [Covered(OverlayContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        Text("Home").overlays { Text("Home's").width(80).height(20).id("home's") }
                    } destination: { _ in Text("Pushed") }
                }
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("home's")) == true }
                path.wrappedValue = [1]
                try s.settle { try !s.isShown("home's") }
                s.expect(try s.isShown("home's"), false, "a page pushed over it took it away")

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
        return ZStack {
            Rectangle()
                .fill(.red)
                .id("beneath")
            VStack {
                Button("Show").onClicked { notice.wrappedValue = true }.id("show")
                Button("Hide").onClicked { notice.wrappedValue = false }.id("hide")
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        .overlays {
            if notice.wrappedValue {
                Text("Offline").width(80).height(20).horizontalAlignment(.center).verticalAlignment(.center).id("notice")
            }
        }
    }
}
