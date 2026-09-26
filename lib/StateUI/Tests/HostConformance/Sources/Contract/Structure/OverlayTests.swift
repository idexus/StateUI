// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `OverlayContract` on a host: a view laid over the window stands over its page and over a sheet presented after
/// it, a press beside it reaches the page, and nothing is left once the tree takes it away.
@_spi(Host) public enum OverlayTests: ConformanceFamily {
    public static let name = "Overlay"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anOverlayStandsOverThePageAndLetsAPressBesideItThrough", covers: [
                Covered(OverlayContract.self), Covered(ButtonContract.clicked),
            ]) { s in
                let notice = State(wrappedValue: false)
                s.start { OverlaidPage(notice: notice) }
                let beneath = try s.element("beneath")

                try s.perform(.activate, on: s.element("show"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("notice")) == true }
                let over = try s.element("notice")
                s.expect(try s.reaches(over, at: Point(40, 10)), true, "the overlay takes a press on it")
                s.expect(try s.reaches(beneath, at: Point(5, 200)), true, "a press beside it reaches the page")

                try s.perform(.activate, on: s.element("hide"))
                s.settle { (try? s.element("notice")) == nil }
                s.expect((try? s.element("notice")) == nil, true, "gone once the tree takes it away")
            },
        ]
    }
}

extension OverlayKey {
    /// The notice a case lays over its window.
    fileprivate static let notice = OverlayKey("conformance.notice")
}

/// A page that lays a notice over its window while a state says so.
struct OverlaidPage: ContentView {
    let notice: State<Bool>

    @Environment private var window: WindowSession

    var content: any View {
        let (notice, window) = (self.notice, self.window)
        return VStack {
            Button("Show").onClicked { notice.wrappedValue = true }.id("show")
            Button("Hide").onClicked { notice.wrappedValue = false }.id("hide")
            ColorBox(.red).height(300).id("beneath")
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
        .onChanged(notice.wrappedValue) {
            window.overlays[.notice] = notice.wrappedValue
                ? Label("Offline").width(80).height(20).horizontalAlignment(.end).verticalAlignment(.start).id("notice")
                : nil
        }
    }
}
