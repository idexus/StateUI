import StateUI

/// A strip of tiles a fixed distance apart - the shape both grid halves are cut
/// from. A tile is 140 wide with 20 between them, so one starts every 160,
/// which is the interval a snapping strip is told to rest on.
private func tileStrip() -> ScrollView {
    ScrollView {
        HStack {
            ForEach(1...40) { tile in
                Label("Tile \(tile)")
                    .fontSize(13)
                    .horizontalTextAlignment(.center)
                    .verticalOptions(.center)
                    .widthRequest(140)
                    .heightRequest(100)
                    .backgroundColor(Palette.surface)
            }
        }
        .spacing(20)
    }
    .orientation(.horizontal)
    .horizontalScrollBarVisibility(.never)
}

/// Where a scroller IS, reported one way, and an act that puts it somewhere.
private struct OffsetStrips: ContentView {
    @State private var scrolled = 0.0

    @State private var stepped = 0.0

    @State private var across = 0.0

    @State private var scroller = ControlState<ScrollView>()

    var content: Element {
        Grid {
            ScrollView {
                VStack {
                    ForEach(1...40) { line in
                        Label("Line \(line)")
                            .fontSize(15)
                            .padding(8, 6)
                    }
                }
            }
            .assign(scroller)
            .scrollY($scrolled)
            // The same offset at a STEP: one report each time it crosses a
            // multiple of 60, and nothing in between - drag slowly and watch
            // the second number move in jumps.
            .scrollY($stepped, every: 60)
            .gridRow(0)

            VStack {
                Label("Scrolled to \(Int(scrolled)) - every change")
                    .fontSize(14)
                    .horizontalTextAlignment(.center)

                Label("Scrolled to \(Int(stepped)) - every 60")
                    .fontSize(14)
                    .horizontalTextAlignment(.center)
            }
            .spacing(2)
            .gridRow(1)

            HStack {
                Button("Top")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await scroller.scrollTo(x: 0, y: 0) }

                Button("Line 9")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await scroller.scrollTo(x: 0, y: 240) }
            }
            .spacing(16)
            .horizontalOptions(.center)
            .gridRow(2)

            SectionTitle("SIDEWAYS")
                .gridRow(3)

            // ScrollX is the same report along the other axis, so what it takes
            // is a scroller that runs that way - drag the row and watch it.
            ScrollView {
                HStack {
                    ForEach(1...40) { column in
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
            .gridRow(4)

            Label("Scrolled across \(Int(across))")
                .fontSize(14)
                .horizontalTextAlignment(.center)
                .gridRow(5)
        }
        // The tall scroller takes the STAR row; everything under it keeps its
        // own height.
        .rowDefinitions(.star, .auto, .auto, .auto, .auto, .auto)
        .rowSpacing(10)
    }

    /// The words under this half - the page places them, and on a held page
    /// they take a tab of their own. See `SampleContent.notes`.
    var notes: Element {
        VStack {
            Label("`scrollTo` is an act on the view's id, the WebView pattern - MAUI's "
                + "ScrollToAsync, the `Async` dropped - and the handler is suspended "
                + "until the glide finishes. The offset comes back the other way: "
                + "ScrollX and ScrollY have no setter worth writing to, so each is "
                + "reported into a binding.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`every:` is the step: the host reports the offset once each time it "
                + "crosses a multiple of it, and nothing crosses the boundary in "
                + "between. A list of 44-point rows asks for 44 and hears one report per "
                + "row; a gallery asks for a card. Left out, every change is a report "
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
}

/// The offsets a scroller may come to rest on, and which of them it is nearest.
private struct GridStrips: ContentView {
    @State private var tile = 0

    @State private var rests = 0

    var content: Element {
        Grid {
            tileStrip()
                // The offsets it may rest on, and which of them it is nearest -
                // reported as that changes, which is halfway between two tiles.
                .snapInterval(160)
                .snapItem($tile)
                // And the moment nothing is moving any more - once per drag,
                // however many tiles it crossed on the way.
                .onScrollStopped { rests += 1 }
                .gridRow(0)

            Label("nearest tile: \(tile + 1)   ·   came to rest \(rests) times")
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
                .horizontalTextAlignment(.center)
                .gridRow(1)

            Label("`.snapInterval(160)`")
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .gridRow(2)

            // The same strip with nothing said about where it may rest, so the
            // difference on screen is the interval and nothing else.
            tileStrip()
                .gridRow(3)

            Label("nothing said - it stops where the throw ran out")
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .gridRow(4)
        }
        .rowDefinitions(.auto, .auto, .auto, .auto, .auto)
        .rowSpacing(10)
        // The bands are as tall as they need to be, so the pair sits in the
        // middle of whatever height the window gave the cell.
        .verticalOptions(.center)
    }

    /// See `OffsetStrips.notes`.
    var notes: Element {
        VStack {
            Label("`.snapInterval(160)` - drag the first strip and let go: wherever the "
                + "platform's own braking would have stopped is rounded to a multiple of "
                + "160 BEFORE it starts, so it brakes once, its own way, onto a tile. The "
                + "strip under it is the same one with nothing said, and stops half a tile "
                + "off as often as not.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.snapItem($tile)` is the other half: the number above changes as the "
                + "strip passes the halfway mark, which is the same rounding, so it names "
                + "the tile it is going to stop at while it is still moving.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.onScrollStopped` is the third: it runs once the strip has stopped "
                + "moving - once per drag, whether that drag crossed one tile or six, and "
                + "after the correction where one was needed. That is the moment work "
                + "costs nothing to do, so it is where a list builds the rows "
                + "the next swipe will need.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ON WINDOWS THE STRIP FOLLOWS A TOUCHPAD and meets the grid once, when "
                + "the fingers stop; a mouse wheel steps it a tile a click. Both land on a "
                + "tile, so the number above and `.onScrollStopped` say the same there as "
                + "anywhere.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// How much of the platform's own throw a release keeps.
private struct ThrowStrips: ContentView {
    var content: Element {
        Grid {
            tileStrip()
                .snapInterval(160)
                .gridRow(0)

            Label("the whole of the platform's throw")
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .gridRow(1)

            // The same grid keeping a THIRD of the platform's own throw, so the
            // pair differs by that and nothing else.
            tileStrip()
                .snapInterval(160)
                .momentum(0.35)
                .gridRow(2)

            Label("`.momentum(0.35)`")
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .gridRow(3)
        }
        .rowDefinitions(.auto, .auto, .auto, .auto)
        .rowSpacing(10)
        .verticalOptions(.center)
    }

    /// See `OffsetStrips.notes`.
    var notes: Element {
        VStack {
            Label("Flick both strips the same way. The lower one keeps a THIRD of what the "
                + "platform would have thrown it, so the same flick means a tile or two "
                + "rather than five.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("It scales the platform's own prediction rather than replacing it, so a "
                + "hard throw still goes further than a gentle one and the braking stays "
                + "the platform's. A GalleryView keeps half, which is what makes an "
                + "ordinary swipe mean the next card.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// The bar down the side, asked for and taken away.
private struct BarStrips: ContentView {
    var content: Element {
        Grid {
            barCase(.always, "verticalScrollBarVisibility(.always)")
                .gridColumn(0)

            barCase(.never, "verticalScrollBarVisibility(.never)")
                .gridColumn(1)
        }
        .columnDefinitions(.star, .star)
        .columnSpacing(12)
    }

    /// One scroller with the setting that made it named underneath, so the pair
    /// reads as one difference rather than as two scrollers.
    ///
    /// - Parameter visibility: what this half asks for.
    /// - Parameter caption: the words under it.
    private func barCase(_ visibility: ScrollBarVisibility, _ caption: String) -> Grid {
        Grid {
            ScrollView {
                VStack {
                    ForEach(1...40) { line in
                        Label("Line \(line)")
                            .fontSize(13)
                            .padding(6, 4)
                    }
                }
            }
            .verticalScrollBarVisibility(visibility)
            .gridRow(0)

            Label(caption)
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(6)
    }

    /// See `OffsetStrips.notes`.
    var notes: Element {
        Label("`.never` takes the bar away and nothing brings it back; `.always` asks "
            + "for one that stands there whether or not a drag is under way. Where the "
            + "platform draws an OVERLAY bar that fades on its own - macOS, Android - "
            + "the two look alike until the scroller is dragged.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// MAUI: ScrollView.
struct ScrollViewSample: SampleContent {
    static let id = "scrollView"
    static let title = "ScrollView"
    static let summary = "A scrollable container - its offset reported one way, and set by an act."

    // Every half of this sample IS a scroller, so the page must not put one
    // inside another: the wrong one moves under the reader's finger, and a
    // scroller inside a scroller cannot be given a height worth having.
    static let scrolls = false

    /// Each half is given the WINDOW's height, which is what a scroller needs
    /// to be worth dragging.
    static let fills = true

    static let code = """
        // -- OFFSET --

        struct OffsetStrips: ContentView {
            @State private var scrolled = 0.0
            @State private var stepped = 0.0
            @State private var across = 0.0

            @State private var scroller = ControlState<ScrollView>()

            var content: Element {
                Grid {
                    ScrollView {
                        VStack {
                            ForEach(1...40) { line in
                                Label("Line \\(line)")
                                    .padding(8, 6)
                            }
                        }
                    }
                    .assign(scroller)
                    .scrollY($scrolled)
                    // The same offset at a STEP: one report each time it
                    // crosses a multiple of 60, and nothing in between.
                    .scrollY($stepped, every: 60)
                    .gridRow(0)

                    VStack {
                        Label("Scrolled to \\(Int(scrolled)) - every change")
                        Label("Scrolled to \\(Int(stepped)) - every 60")
                    }
                    .gridRow(1)

                    HStack {
                        Button("Top")
                            .onClicked { try await scroller.scrollTo(x: 0, y: 0) }

                        Button("Line 9")
                            .onClicked { try await scroller.scrollTo(x: 0, y: 240) }
                    }
                    .gridRow(2)

                    SectionTitle("SIDEWAYS")
                        .gridRow(3)

                    // The same report along the other axis, from a scroller
                    // that runs that way.
                    ScrollView {
                        HStack {
                            ForEach(1...40) { column in
                                Label("Column \\(column)")
                                    .padding(12, 8)
                            }
                        }
                    }
                    .orientation(.horizontal)
                    .scrollX($across)
                    .gridRow(4)

                    Label("Scrolled across \\(Int(across))")
                        .gridRow(5)
                }
                // The tall scroller takes the STAR row; everything under it
                // keeps its own height.
                .rowDefinitions(.star, .auto, .auto, .auto, .auto, .auto)
                .rowSpacing(10)
            }
        }

        // -- GRID --

        // The strip both halves are cut from - and THROW below reuses it. A
        // tile is 140 wide with 20 between them, so one starts every 160,
        // which is the interval a snapping strip is told to rest on.
        func tileStrip() -> ScrollView {
            ScrollView {
                HStack {
                    ForEach(1...40) { tile in
                        Label("Tile \\(tile)")
                            .widthRequest(140)
                            .heightRequest(100)
                    }
                }
                .spacing(20)
            }
            .orientation(.horizontal)
        }

        struct GridStrips: ContentView {
            @State private var tile = 0
            @State private var rests = 0

            var content: Element {
                Grid {
                    tileStrip()
                        // The offsets it may rest on, and which of them it is
                        // nearest - reported as that changes, which is halfway
                        // between two tiles.
                        .snapInterval(160)
                        .snapItem($tile)
                        // And the moment nothing is moving any more - once per
                        // drag, however many tiles it crossed on the way.
                        .onScrollStopped { rests += 1 }
                        .gridRow(0)

                    Label("nearest tile: \\(tile + 1)   ·   came to rest \\(rests) times")
                        .gridRow(1)

                    // The same strip with nothing said about where it may rest.
                    tileStrip()
                        .gridRow(3)
                }
                .rowDefinitions(.auto, .auto, .auto, .auto, .auto)
                .rowSpacing(10)
                .verticalOptions(.center)
            }
        }

        // -- THROW --

        // Made of the tileStrip() the GRID section defines.
        struct ThrowStrips: ContentView {
            var content: Element {
                Grid {
                    tileStrip()
                        .snapInterval(160)
                        .gridRow(0)

                    // The same grid keeping a THIRD of the platform's own
                    // throw, so the pair differs by that and nothing else.
                    tileStrip()
                        .snapInterval(160)
                        .momentum(0.35)
                        .gridRow(2)
                }
                .rowDefinitions(.auto, .auto, .auto, .auto)
                .rowSpacing(10)
                .verticalOptions(.center)
            }
        }

        // -- BAR --

        struct BarStrips: ContentView {
            var content: Element {
                Grid {
                    barCase(.always).gridColumn(0)
                    barCase(.never).gridColumn(1)
                }
                .columnDefinitions(.star, .star)
                .columnSpacing(12)
            }

            private func barCase(_ visibility: ScrollBarVisibility) -> ScrollView {
                ScrollView {
                    VStack {
                        ForEach(1...40) { line in
                            Label("Line \\(line)")
                                .padding(6, 4)
                        }
                    }
                }
                .verticalScrollBarVisibility(visibility)
            }
        }
        """

    var parts: [SamplePart] {
        let offset = OffsetStrips()
        let grid = GridStrips()
        let carried = ThrowStrips()
        let bars = BarStrips()

        return [SamplePart(title: "OFFSET", view: offset, notes: offset.notes),
                SamplePart(title: "GRID", view: grid, notes: grid.notes),
                SamplePart(title: "THROW", view: carried, notes: carried.notes),
                SamplePart(title: "BAR", view: bars, notes: bars.notes)]
    }

    var content: Element {
        VStack {
            OffsetStrips()
            GridStrips()
            ThrowStrips()
            BarStrips()
        }
        .spacing(16)
    }
}
