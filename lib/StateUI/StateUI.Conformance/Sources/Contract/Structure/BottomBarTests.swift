// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BottomBarContract` on a host: the view a page declares at its foot stands there as tall as it lays out, the page's
/// content clear above it and growing smaller as it grows; a scroller let under it at its end stays at its end, one
/// elsewhere where it is - a list's as a ScrollView's, its last item brought to rest clear above it; the edge it shows
/// over what scrolls under it is the one its view says.
@_spi(Host) public enum BottomBarTests: ConformanceFamily {
    public static let name = "BottomBar"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPagesContentStandsClearAboveItsBottomBar", proves: [Covered(BottomBarContract.self)]) { s in
                let tall = State(wrappedValue: 40.0)
                s.start {
                    Rectangle()
                        .fill(.red)
                        .id("content")
                        .title("Foot")
                        .bottomBar {
                            Rectangle()
                                .fill(.blue)
                                .height(tall.wrappedValue)
                                .id("bar")
                        }
                }
                try s.settle { try s.place(of: s.element("bar")).height == 40 }
                let (content, bar) = (try s.place(of: s.element("content")), try s.place(of: s.element("bar")))
                s.expect(content.y + content.height <= bar.y + 0.5, true, "the content above the bar: \(content), \(bar)")

                tall.wrappedValue = 100
                try s.settle { try s.place(of: s.element("bar")).height == 100 }
                let (grown, taller) = (try s.place(of: s.element("content")), try s.place(of: s.element("bar")))
                s.expect(grown.y + grown.height <= taller.y + 0.5, true, "above it still: \(grown), \(taller)")
                s.expect(abs(content.height - grown.height - 60) < 1, true,
                         "smaller by what the bar grew: \(content.height) to \(grown.height)")
            },
            ConformanceCase("aScrollerAtItsEndStaysThereAsTheBarGrows", proves: [
                Covered(BottomBarContract.self),
            ], needs: [Covered(ScrollViewContract.scrollOffset)]) { s in
                let tall = State(wrappedValue: 40.0)
                let offset = State(wrappedValue: Point(0, 0))
                s.start(reducesMotion: true) {
                    Grid {
                        ScrollView {
                            Rectangle()
                                .fill(.red)
                                .height(3000)
                        }
                        .scrollOffset(offset.projectedValue)
                        .id("scroller")
                    }
                    .ignoresSafeArea(.all)
                    .title("Foot")
                    .bottomBar {
                        Rectangle()
                            .fill(.blue)
                            .height(tall.wrappedValue)
                            .id("bar")
                    }
                }
                let scroller = try s.element("scroller")
                let standing = { try s.held(ScrollViewContract.scrollOffset, on: scroller)?.y ?? -1 }

                offset.wrappedValue = Point(0, 100)
                try s.settle { try standing() == 100 }
                tall.wrappedValue = 70
                try s.settle { try s.place(of: s.element("bar")).height == 70 }
                s.expect(try standing(), 100, "one short of its end where it was")

                offset.wrappedValue = Point(0, 10_000)
                try s.settle { try standing() > 100 }
                let end = try standing()
                tall.wrappedValue = 130
                try s.settle { try abs(standing() - (end + 60)) < 1 }
                s.expect(abs(try standing() - (end + 60)) < 1, true, "at its end still: \(end) to \(try standing())")
            },
            ConformanceCase("aListUnderItsBottomBarBringsItsLastItemClearAboveIt", proves: [
                Covered(BottomBarContract.self),
            ], needs: [Covered(ItemsViewContract.scrollTo), Covered(ButtonContract.clicked)]) { s in
                let aim = Aim(ItemsView<Int>.self)
                s.start(reducesMotion: true) {
                    Grid {
                        ItemsView(0..<60) { Text("Item \($0)").padding(12) }
                            .aim(aim)
                            .id("list")
                    }
                    .ignoresSafeArea(.all)
                    .title("Foot")
                    .bottomBar {
                        Button("To the end").onClicked(.ignoreWhileRunning) { try await aim.scrollTo(59, anchor: .end) }
                            .id("go")
                    }
                }
                s.settle { (try? s.item("0", of: s.element("list"))) != nil }
                let (list, bar) = (try s.place(of: s.element("list")), try s.place(of: s.element("go")))
                s.expect(list.y + list.height >= bar.y - 0.5, true, "the list reaches its bar: \(list), \(bar)")

                try s.perform(.activate, on: s.element("go"))
                let foot = { (try? s.place(of: s.item("59", of: s.element("list")))).map { $0.y + $0.height } }
                s.settle { foot().map { abs($0 - bar.y) < 1 } ?? false }
                s.expect(foot().map { abs($0 - bar.y) < 1 }, true, "the last item at rest on the bar: \(String(describing: foot())), \(bar)")
            },
            ConformanceCase("aStacksBottomBarStandsOnThePageItShows", proves: [Covered(BottomBarContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        Rectangle().fill(.red).id("root").title("Root")
                    } destination: { _ in
                        Rectangle().fill(.green).id("pushed").title("Pushed")
                    }
                    .bottomBar {
                        Rectangle()
                            .fill(.blue)
                            .height(40)
                            .id("bar")
                    }
                }
                try s.settle { try s.place(of: s.element("bar")).height == 40 }
                s.expect(try s.place(of: s.element("bar")).height, 40, "under the root")

                path.wrappedValue = [1]
                try s.settle { try s.isShown("pushed") && s.place(of: s.element("bar")).height == 40 }
                s.expect(try s.place(of: s.element("bar")).height, 40, "under the page pushed")

                path.wrappedValue = []
                try s.settle { try !s.isShown("pushed") && s.place(of: s.element("bar")).height == 40 }
                s.expect(try s.place(of: s.element("bar")).height, 40, "under the root again")
            },
            ConformanceCase("aBottomBarsEdgeHoldsWhatItsViewSays", proves: [Covered(BottomBarContract.edge)]) { s in
                let edge = State(wrappedValue: ScrollEdge.hard)
                s.start {
                    Grid {
                        ScrollView {
                            Rectangle()
                                .fill(.red)
                                .height(3000)
                        }
                    }
                    .ignoresSafeArea(.all)
                    .title("Foot")
                    .bottomBar(edge: edge.wrappedValue) {
                        Rectangle()
                            .fill(.blue)
                            .height(40)
                            .id("bar")
                    }
                }
                let bar = try s.element("bar")
                try s.settle { try s.held(BottomBarContract.edge, on: bar) == .hard }
                s.expect(try s.held(BottomBarContract.edge, on: bar), .hard, "the edge the view gave")

                edge.wrappedValue = .none
                try s.settle { try s.held(BottomBarContract.edge, on: bar) == ScrollEdge.none }
                s.expect(try s.held(BottomBarContract.edge, on: bar), ScrollEdge.none, "the edge it changed to")
            },
        ]
    }
}
