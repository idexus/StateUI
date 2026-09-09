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

/// Forty numbered lines - the same strip in all three columns below, so the
/// only difference on the screen is what the offset costs.
private func numberedLines() -> ScrollView {
    ScrollView {
        VStack {
            ForEach(1...40) { line in
                Label("Line \(line)")
                    .fontSize(14)
                    .padding(8, 6)
            }
        }
    }
}

/// The heading over one column.
///
/// - Parameter text: what this column is.
/// - Returns: the words, styled.
private func columnTitle(_ text: String) -> Label {
    Label(text)
        .fontSize(12)
        .fontAttributes(.bold)
        .textColor(Palette.subtle)
        .horizontalTextAlignment(.center)
}

/// The spelling that makes a column what it is, under its reading.
///
/// - Parameter text: the line of code this column is about.
/// - Returns: the words, in the code face.
private func spelling(_ text: String) -> Label {
    Label(text)
        .fontSize(11)
        .fontFamily("Menlo")
        .textColor(Palette.subtle)
        .horizontalTextAlignment(.center)
}

/// THE OFFSET DESCRIBED: the reading is a get in these braces, so this view is
/// the reader and is built again on every report the strip makes.
private struct DescribedOffset: ContentView {
    /// Where the strip is - the state declared beside the buttons that move
    /// all three strips, handed down: the scroller gets it, and the label
    /// below reads it.
    @Binding var offset: Journey<Point>

    var content: Element {
        Grid {
            columnTitle("DESCRIBED")

            numberedLines()
                .scroll($offset)
                .gridRow(1)

            // THE GET. Reading the offset here is what makes this Grid its
            // reader, and a render is what every single report then costs.
            Label("\(Int(offset.value.y)) down")
                .fontSize(14)
                .horizontalTextAlignment(.center)
                .gridRow(2)

            DebugInfoLabel()
                .horizontalOptions(.center)
                .horizontalTextAlignment(.center)
                .gridRow(3)

            spelling("a get in these braces")
                .gridRow(4)
        }
        .rowDefinitions(.auto, .star, .auto, .auto, .auto)
        .rowSpacing(6)
    }
}

/// THE SAME GET, ON A CADENCE: the state asks for a render at most ten times a
/// second, so the reading is the same and the count is a tenth of the reports.
private struct PacedOffset: ContentView {
    /// The same state as the column before - declared beside the buttons
    /// with `asks: .every(100)`, which is the one difference.
    @Binding var offset: Journey<Point>

    var content: Element {
        Grid {
            columnTitle("ON A CADENCE")

            numberedLines()
                .scroll($offset)
                .gridRow(1)

            // The same get as the column before, over a state that asks for
            // fewer renders. The number is right the moment it is read; what
            // the cadence holds back is how often it is read again.
            Label("\(Int(offset.value.y)) down")
                .fontSize(14)
                .horizontalTextAlignment(.center)
                .gridRow(2)

            DebugInfoLabel()
                .horizontalOptions(.center)
                .horizontalTextAlignment(.center)
                .gridRow(3)

            spelling("@State(asks: .every(100))")
                .gridRow(4)
        }
        .rowDefinitions(.auto, .star, .auto, .auto, .auto)
        .rowSpacing(6)
    }
}

/// THE OFFSET THROUGH A CHANNEL: nothing here reads it. The words are a
/// conversion the host works out on its own frames, so the number keeps up
/// with the finger and this view is never built again.
private struct DrivenOffset: ContentView {
    /// Handed to the scroller and to the conversion, and read by nobody.
    @Binding var offset: Journey<Point>

    var content: Element {
        Grid {
            columnTitle("A CHANNEL")

            numberedLines()
                .scroll($offset)
                .gridRow(1)

            // NO GET. The conversion is a second state the host writes from
            // the first, so the reading moves without a view being built -
            // and it reads `value`, where the offset IS, so it follows a
            // glide frame by frame rather than jumping to where it is going.
            Label($offset.convert { "\(Int($0.value.y)) down" })
                .fontSize(14)
                .horizontalTextAlignment(.center)
                .gridRow(2)

            DebugInfoLabel()
                .horizontalOptions(.center)
                .horizontalTextAlignment(.center)
                .gridRow(3)

            spelling("$offset.convert { … }")
                .gridRow(4)
        }
        .rowDefinitions(.auto, .star, .auto, .auto, .auto)
        .rowSpacing(6)
    }
}

/// What an offset costs, three ways over one scroller - and the write that
/// moves all three.
private struct OffsetStrips: ContentView {
    /// One state per strip, and the three declarations the columns are about:
    /// plain, on a cadence, and one nothing reads. Each strip is handed its
    /// own, and the buttons below write all three.
    @State private var described = Journey(Point.zero)

    @State(asks: .every(100)) private var paced = Journey(Point.zero)

    @State private var driven = Journey(Point.zero)

    var content: Element {
        Grid {
            // THREE IDENTICAL STRIPS over three states. What differs is where
            // each column's reading comes from, and the count under it is
            // what that costs - drag them and watch.
            Grid {
                DescribedOffset(offset: $described)

                PacedOffset(offset: $paced)
                    .gridColumn(1)

                DrivenOffset(offset: $driven)
                    .gridColumn(2)
            }
            .columnDefinitions(.star, .star, .star)
            .columnSpacing(12)
            .gridRow(0)

            HStack {
                Button("Top")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await move(to: 0) }

                Button("Line 9")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await move(to: 240) }
            }
            .spacing(16)
            .horizontalOptions(.center)
            .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(10)
    }

    /// Puts all three strips at the same offset, one after another.
    ///
    /// A journey is awaited and answers when the glide has FINISHED, so the
    /// three strips move in turn rather than together - which is what `await`
    /// on a write to `scroll($:)` means, said on the screen.
    ///
    /// - Parameter y: how far down each strip is sent.
    private func move(to y: Double) async throws {
        for strip in [$described, $paced, $driven] {
            try await strip.animateTo(Point(0, y), .eased(300, .cubicOut))
        }
    }

    /// The words under this half - the page places them, and on a held page
    /// they take a tab of their own. See `SampleContent.notes`.
    var notes: Element {
        VStack {
            Label("Three strips, three states, one report each. `.scroll($offset)` hands "
                + "the state over, so the scroller is no reader of it and the offset "
                + "itself costs nothing wherever it moves. What it costs is decided by "
                + "who reads it, and each column reads it a different way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("DESCRIBED reads the offset in the column's own braces, so that column "
                + "is rebuilt on every report - a render for every few points of a drag. "
                + "ON A CADENCE is the same get over `@State(asks: .every(100))`, which "
                + "asks for a render at most ten times a second: the number is as right "
                + "as the other one whenever it is read, and the count is a tenth of it. "
                + "A CHANNEL reads nothing - the words are `$offset.convert { … }`, a "
                + "second state the host works out on its own frames - so the number "
                + "keeps up with the finger and the count stays at one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("So the ladder is: hand the value on and show it through a channel where "
                + "it moves with a finger; read it where something has to DECIDE by it, "
                + "and put a cadence on it where a reader could not see the difference "
                + "anyway. The cadence itself has a sample of its own, `A state on a "
                + "cadence`, under Using state.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.scroll($offset)` goes BOTH WAYS. The reader's scrolling is the host's "
                + "own write into the state, and a write to the state moves the scroller: "
                + "`try await $offset.animateTo(Point(0, y), …)` is suspended until the "
                + "glide finishes, which is why Top sends the three strips one after "
                + "another rather than all at once, and `$offset.snap(to:)` puts one "
                + "there at once. The offset is one point - MAUI's ScrollX and ScrollY "
                + "together - so a move on both axes arrives on both together.")
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
    static let summary = "A scrollable container - what its offset costs read three ways, and a write that moves it."

    // Every half of this sample IS a scroller, so the page must not put one
    // inside another: the wrong one moves under the reader's finger, and a
    // scroller inside a scroller cannot be given a height worth having.
    static let scrolls = false

    /// Each half is given the WINDOW's height, which is what a scroller needs
    /// to be worth dragging.
    static let fills = true

    static let code = """
        // -- OFFSET --

        // The same strip in all three columns, so the only difference on the
        // screen is what the offset costs.
        func numberedLines() -> ScrollView {
            ScrollView {
                VStack {
                    ForEach(1...40) { line in
                        Label("Line \\(line)")
                            .padding(8, 6)
                    }
                }
            }
        }

        // THE OFFSET DESCRIBED: the reading is a get in these braces, so this
        // view is the reader and is built again on every report.
        struct DescribedOffset: ContentView {
            // The strips' own state, declared beside the buttons that move
            // all three and handed down.
            @Binding var offset: Journey<Point>

            var content: Element {
                Grid {
                    columnTitle("DESCRIBED")

                    numberedLines()
                        .scroll($offset)
                        .gridRow(1)

                    // THE GET. Reading the offset here is what makes this Grid
                    // its reader, and a render is what every report costs.
                    Label("\\(Int(offset.value.y)) down")
                        .gridRow(2)

                    DebugInfoLabel()
                        .gridRow(3)
                }
                .rowDefinitions(.auto, .star, .auto, .auto)
            }
        }

        // THE SAME GET, ON A CADENCE: at most ten renders a second, so the
        // reading is the same and the count is a tenth of the reports.
        struct PacedOffset: ContentView {
            @Binding var offset: Journey<Point>

            var content: Element {
                Grid {
                    columnTitle("ON A CADENCE")

                    numberedLines()
                        .scroll($offset)
                        .gridRow(1)

                    Label("\\(Int(offset.value.y)) down")
                        .gridRow(2)

                    DebugInfoLabel()
                        .gridRow(3)
                }
                .rowDefinitions(.auto, .star, .auto, .auto)
            }
        }

        // THROUGH A CHANNEL: nothing here reads the offset. The words are a
        // conversion the host works out on its own frames.
        struct DrivenOffset: ContentView {
            @Binding var offset: Journey<Point>

            var content: Element {
                Grid {
                    columnTitle("A CHANNEL")

                    numberedLines()
                        .scroll($offset)
                        .gridRow(1)

                    // NO GET: a second state the host writes from the first,
                    // so the reading moves without a view being built - and
                    // `value` is where the offset IS, frame by frame.
                    Label($offset.convert { "\\(Int($0.value.y)) down" })
                        .gridRow(2)

                    DebugInfoLabel()
                        .gridRow(3)
                }
                .rowDefinitions(.auto, .star, .auto, .auto)
            }
        }

        struct OffsetStrips: ContentView {
            // One state per strip, and the three declarations the columns
            // are about: plain, on a cadence, and one nothing reads.
            @State private var described = Journey(Point.zero)
            @State(asks: .every(100)) private var paced = Journey(Point.zero)
            @State private var driven = Journey(Point.zero)

            var content: Element {
                Grid {
                    Grid {
                        DescribedOffset(offset: $described)
                        PacedOffset(offset: $paced).gridColumn(1)
                        DrivenOffset(offset: $driven).gridColumn(2)
                    }
                    .columnDefinitions(.star, .star, .star)
                    .gridRow(0)

                    HStack {
                        Button("Top").onClicked { try await move(to: 0) }
                        Button("Line 9").onClicked { try await move(to: 240) }
                    }
                    .gridRow(1)
                }
                .rowDefinitions(.star, .auto)
            }

            // A journey is awaited and answers when the glide has FINISHED,
            // so the three strips move in turn rather than together.
            private func move(to y: Double) async throws {
                for strip in [$described, $paced, $driven] {
                    try await strip.animateTo(Point(0, y), .eased(300, .cubicOut))
                }
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
