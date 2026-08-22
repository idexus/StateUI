import StateUI

/// MAUI: ScrollView.
struct ScrollViewSample: SampleContent {
    @State private var scrolled = 0.0

    @State private var stepped = 0.0

    @State private var across = 0.0

    @State private var tile = 0

    @State private var scroller = ControlState<ScrollView>()

    static let id = "scrollView"
    static let title = "ScrollView"
    static let summary = "A scrollable container - its offset reported one way, and set by an act."

    static let code = """
        @State private var scrolled = 0.0
        @State private var stepped = 0.0
        @State private var across = 0.0
        @State private var tile = 0

        @State private var scroller = ControlState<ScrollView>()

        VStack {
            ScrollView {
                VStack {
                    ForEach(1...12) { line in
                        Label("Line \\(line)")
                            .padding(8, 6)
                    }
                }
            }
            .assign(scroller)
            .heightRequest(160)
            .scrollY($scrolled)
            // The same offset at a STEP: one report each time it crosses a
            // multiple of 60, and nothing in between.
            .scrollY($stepped, every: 60)

            Label("Scrolled to \\(Int(scrolled)) - every change")
            Label("Scrolled to \\(Int(stepped)) - every 60")

            HStack {
                Button("Top")
                    .onClicked { try await scroller.scrollTo(x: 0, y: 0) }

                Button("Line 9")
                    .onClicked { try await scroller.scrollTo(x: 0, y: 240) }
            }

            // The same report, sideways, from a scroller that runs that way.
            ScrollView {
                HStack {
                    ForEach(1...12) { column in
                        Label("Column \\(column)")
                            .padding(12, 8)
                    }
                }
            }
            .orientation(.horizontal)
            .scrollX($across)

            Label("Scrolled across \\(Int(across))")

            // The same strip twice: one that rests on a multiple of the tile,
            // one that rests wherever the platform leaves it.
            ScrollView {
                HStack {
                    ForEach(1...12) { tile in
                        Label("Tile \\(tile)")
                            .widthRequest(140)
                    }
                }
                .spacing(20)
            }
            .orientation(.horizontal)
            // The offsets it may rest on, and which of them it is nearest -
            // reported as that changes, which is halfway between two tiles.
            .snapInterval(160)
            .snapItem($tile)

            Label("nearest tile: \\(tile + 1)")

            ScrollView {
                HStack {
                    ForEach(1...12) { tile in
                        Label("Tile \\(tile)")
                            .widthRequest(140)
                    }
                }
                .spacing(20)
            }
            .orientation(.horizontal)

            // The same twelve rows twice, so the bar is the only difference.
            Grid {
                ScrollView {
                    VStack {
                        ForEach(1...12) { line in
                            Label("Line \\(line)")
                        }
                    }
                }
                .verticalScrollBarVisibility(.always)
                .heightRequest(110)

                ScrollView {
                    VStack {
                        ForEach(1...12) { line in
                            Label("Line \\(line)")
                        }
                    }
                }
                .verticalScrollBarVisibility(.never)
                .heightRequest(110)
                .gridColumn(1)
            }
            .columnDefinitions(.star, .star)
            .columnSpacing(12)
        }
        """

    var content: Element {
        VStack {
            ScrollView {
                VStack {
                    ForEach(1...12) { line in
                        Label("Line \(line)")
                            .fontSize(15)
                            .padding(8, 6)
                    }
                }
            }
            .assign(scroller)
            .heightRequest(160)
            .scrollY($scrolled)
            // The same offset at a STEP: one report each time it crosses a
            // multiple of 60, and nothing in between - drag slowly and watch
            // the second number move in jumps.
            .scrollY($stepped, every: 60)

            Label("Scrolled to \(Int(scrolled)) - every change")
                .fontSize(14)
                .horizontalTextAlignment(.center)

            Label("Scrolled to \(Int(stepped)) - every 60")
                .fontSize(14)
                .horizontalTextAlignment(.center)

            HStack {
                Button("Top")
                    .onClicked { try await scroller.scrollTo(x: 0, y: 0) }

                Button("Line 9")
                    .onClicked { try await scroller.scrollTo(x: 0, y: 240) }
            }
            .spacing(12)
            .horizontalOptions(.center)

            SectionTitle("SIDEWAYS")

            // ScrollX is the same report along the other axis, so what it takes
            // is a scroller that runs that way - drag the row and watch it.
            ScrollView {
                HStack {
                    ForEach(1...12) { column in
                        Label("Column \(column)")
                            .fontSize(13)
                            .textColor(Palette.onAccent)
                            .backgroundColor(Palette.accent)
                            .padding(12, 8)
                    }
                }
                .spacing(8)
            }
            .orientation(.horizontal)
            .scrollX($across)

            Label("Scrolled across \(Int(across))")
                .fontSize(14)
                .horizontalTextAlignment(.center)

            SectionTitle("RESTING ON A GRID")

            // The tile is 140 and the gap 20, so a tile starts every 160 -
            // which is the interval this scroller is told to rest on.
            tiles(snapping: true)

            Label("nearest tile: \(tile + 1)")
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
                .horizontalTextAlignment(.center)

            Label("`.snapInterval(160)` - drag it and let go: wherever the platform's "
                + "own braking would have stopped is rounded to a multiple of 160 BEFORE "
                + "it starts, so it brakes once, its own way, onto a tile. `.snapItem($tile)` "
                + "is the other half: the number above changes as the strip passes the "
                + "halfway mark, which is the same rounding, so it names the tile it is "
                + "going to stop at while it is still moving.")
                .fontSize(12)
                .textColor(Palette.subtle)

            // The same strip with nothing said about where it may rest, so the
            // difference on screen is the interval and nothing else.
            tiles(snapping: false)

            Label("The same strip without it, for comparison: it stops wherever the "
                + "throw ran out, half a tile off as often as not.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("THE BAR DOWN THE SIDE")

            // The same twelve rows twice, so the bar is the only thing that
            // differs between them.
            Grid {
                barCase(.always, "verticalScrollBarVisibility(.always)")

                barCase(.never, "verticalScrollBarVisibility(.never)")
                    .gridColumn(1)
            }
            .columnDefinitions(.star, .star)
            .columnSpacing(12)

            Label("`.never` takes the bar away and nothing brings it back; `.always` asks "
                + "for one that stands there whether or not a drag is under way. Where the "
                + "platform draws an OVERLAY bar that fades on its own - macOS, Android - "
                + "the two look alike until the scroller is dragged.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`scrollTo` is an act on the view's id, the WebView pattern - MAUI's "
                + "ScrollToAsync, the `Async` dropped - and the handler is suspended "
                + "until the glide finishes. The offset comes back the other way: "
                + "ScrollX and ScrollY have no setter worth writing to, so each is "
                + "reported into a binding.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Neither offset has an event of its own, so both are watched through "
                + "PropertyChanged - and only because the tree asked for it. Width and "
                + "Height raise it at every measure, so a standing subscription per "
                + "control would cost real work for an answer nobody wanted.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`every:` is the step: the host reports the offset once each time it "
                + "crosses a multiple of it, and nothing crosses the boundary in "
                + "between. A list of 44-point rows asks for 44 and hears one report per "
                + "row; a carousel asks for a card. Left out, every change is a report "
                + "and a render.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A ScrollView holds ONE view; several children are wrapped in a stack "
                + "by the renderer rather than all but the first being dropped.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// A strip of tiles a fixed distance apart - once told where it may rest,
    /// once not. The snapping one also says which tile it is nearest, the
    /// report that comes with a grid.
    private func tiles(snapping: Bool) -> ScrollView {
        let strip = ScrollView {
            HStack {
                ForEach(1...12) { tile in
                    Label("Tile \(tile)")
                        .fontSize(13)
                        .horizontalTextAlignment(.center)
                        .verticalOptions(.center)
                        .widthRequest(140)
                        .heightRequest(60)
                        .backgroundColor(Palette.surface)
                }
            }
            .spacing(20)
        }
        .orientation(.horizontal)
        .horizontalScrollBarVisibility(.never)

        guard snapping else { return strip }

        return strip.snapInterval(160).snapItem($tile)
    }

    /// One short scroller with the setting that made it named underneath, so
    /// the pair reads as one difference rather than two scrollers. A stack
    /// rather than an Element, so the caller can say which column it goes in.
    private func barCase(_ visibility: ScrollBarVisibility, _ caption: String) -> VStack {
        VStack {
            ScrollView {
                VStack {
                    ForEach(1...12) { line in
                        Label("Line \(line)")
                            .fontSize(13)
                            .padding(6, 4)
                    }
                }
            }
            .verticalScrollBarVisibility(visibility)
            .heightRequest(110)

            Label(caption)
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(6)
    }
}
