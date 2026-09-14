import StateUI

/// A strip of tiles a fixed distance apart - the shape the grid and throw
/// examples are cut from. A tile is 140 wide with 20 between them, so one
/// starts every 160, which is the interval a snapping strip is told to rest on.
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
    @Binding var offset: Point

    var content: any View {
        Grid {
            columnTitle("DESCRIBED")

            numberedLines()
                .scroll($offset)
                .gridRow(1)

            // THE GET. Reading the offset here is what makes this Grid its
            // reader, and a render is what every single report then costs.
            Label("\(Int($offset.journey.value.y)) down")
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

/// THE SAME GET, OFF A SAMPLE: the scroller writes a state of its own, as the
/// column before does, and this column shows a READING of it taken ten times a
/// second - so the number is as right whenever it is read, and the count is a
/// tenth.
private struct PacedOffset: ContentView {
    /// Handed to the scroller, as the column before.
    @Binding var offset: Point

    /// Where the value had got to when the reading was taken. An ordinary
    /// state, so the get below is a get like any other.
    let shown: Point

    var content: any View {
        Grid {
            columnTitle("ON A CADENCE")

            numberedLines()
                .scroll($offset)
                .gridRow(1)

            // The same get as the column before, over the SAMPLE rather than
            // over the scroller's own state. The number is right the moment
            // the reading was taken; what the window holds back is how often
            // one is taken.
            Label("\(Int(shown.y)) down")
                .fontSize(14)
                .horizontalTextAlignment(.center)
                .gridRow(2)

            DebugInfoLabel()
                .horizontalOptions(.center)
                .horizontalTextAlignment(.center)
                .gridRow(3)

            spelling(".samples($offset, into: $shown, .every(100))")
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
    @Binding var offset: Point

    var content: any View {
        Grid {
            columnTitle("A CHANNEL")

            numberedLines()
                .scroll($offset)
                .gridRow(1)

            // NO GET. The conversion is a second state the host writes from
            // the first, so the reading moves without a view being built -
            // and it reads `value`, where the offset IS, so it follows a
            // glide frame by frame rather than jumping to where it is going.
            Label($offset.journey.convert { "\(Int($0.value.y)) down" })
                .fontSize(14)
                .horizontalTextAlignment(.center)
                .gridRow(2)

            DebugInfoLabel()
                .horizontalOptions(.center)
                .horizontalTextAlignment(.center)
                .gridRow(3)

            spelling("$offset.journey.convert { … }")
                .gridRow(4)
        }
        .rowDefinitions(.auto, .star, .auto, .auto, .auto)
        .rowSpacing(6)
    }
}

/// What an offset costs, three ways over three identical strips - and the
/// write that moves all three.
private struct OffsetStrips: ExampleContent {
    /// One state per strip, and the three roads the columns are about: a get,
    /// a get on a cadence, and a value nothing reads. THE DECLARATIONS ARE
    /// IDENTICAL - what differs is what each column asks for and how it reads
    /// - and the buttons below write all three.
    @State private var described = Point.zero

    @State private var paced = Point.zero

    /// What the middle column shows: a reading of `paced`, taken ten times a
    /// second. An ordinary state, rebuilt from by an ordinary get.
    @State private var pacedShown = Point.zero

    @State private var driven = Point.zero

    static let code = """
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

        // The heading over one column.
        func columnTitle(_ text: String) -> Label {
            Label(text)
        }

        // THE OFFSET DESCRIBED: the reading is a get in these braces, so this
        // view is the reader and is built again on every report.
        struct DescribedOffset: ContentView {
            // This strip's own state, declared beside the buttons that move
            // all three and handed down.
            @Binding var offset: Point

            var content: any View {
                Grid {
                    columnTitle("DESCRIBED")

                    numberedLines()
                        .scroll($offset)
                        .gridRow(1)

                    // THE GET. Reading the journey here is what makes this Grid
                    // its reader, and a render is what every frame costs.
                    Label("\\(Int($offset.journey.value.y)) down")
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
            @Binding var offset: Point

            // Where the value had got to when the reading was taken - an
            // ordinary state, so this is an ordinary get.
            let shown: Point

            var content: any View {
                Grid {
                    columnTitle("ON A CADENCE")

                    numberedLines()
                        .scroll($offset)
                        .gridRow(1)

                    Label("\\(Int(shown.y)) down")
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
            @Binding var offset: Point

            var content: any View {
                Grid {
                    columnTitle("A CHANNEL")

                    numberedLines()
                        .scroll($offset)
                        .gridRow(1)

                    // NO GET: a second state the host writes from the first,
                    // so the reading moves without a view being built - and
                    // `value` is where the offset IS, frame by frame.
                    Label($offset.journey.convert { "\\(Int($0.value.y)) down" })
                        .gridRow(2)

                    DebugInfoLabel()
                        .gridRow(3)
                }
                .rowDefinitions(.auto, .star, .auto, .auto)
            }
        }

        struct OffsetStrips: ContentView {
            // One state per strip. THE DECLARATIONS ARE IDENTICAL: what the
            // three columns are about is what each ASKS for and how it reads.
            @State private var described = Point.zero
            @State private var paced = Point.zero
            @State private var pacedShown = Point.zero
            @State private var driven = Point.zero

            var content: any View {
                Grid {
                    Grid {
                        DescribedOffset(offset: $described)
                        PacedOffset(offset: $paced, shown: pacedShown)
                            .samples($paced, into: $pacedShown, .every(100))
                            .gridColumn(1)
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
                    try await strip.journey.move(to: Point(0, y), .eased(300, .cubicOut))
                }
            }
        }
        """

    var content: any View {
        Grid {
            // THREE IDENTICAL STRIPS over three states. What differs is where
            // each column's reading comes from, and the count under it is
            // what that costs - drag them and watch.
            Grid {
                DescribedOffset(offset: $described)

                // THE READING IS ASKED FOR WHERE IT IS SHOWN, and it is a
                // reading of where the value HAS GOT TO - which the state
                // itself never says, standing at its destination.
                PacedOffset(offset: $paced, shown: pacedShown)
                    .samples($paced, into: $pacedShown, .every(100))
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
            try await strip.journey.move(to: Point(0, y), .eased(300, .cubicOut))
        }
    }

    var notes: Element? {
        VStack {
            Label("Three strips, three states. `.scroll($offset)` hands the state over, "
                + "so the scroller is no reader of it: what the offset costs is decided "
                + "by who reads it, and each column reads it differently.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Described reads the offset in its own braces, so the column is built "
                + "again on every report. On a cadence reads a sample of it - "
                + "`.samples($offset, into: $shown, .every(100))` - at most ten times a "
                + "second, so its count is a tenth. A channel reads nothing: "
                + "`$offset.journey.convert { … }` is a second state the host works out "
                + "on its own frames, and the count stays at one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Hand the value on where it moves with a finger, read it where "
                + "something decides by it, and put a cadence on the read where the "
                + "difference cannot be seen. `A state on a cadence`, under Using state, "
                + "shows the cadence on its own.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.scroll($offset)` goes both ways: scrolling writes the state, and a "
                + "write moves the scroller. `try await $offset.journey.move(to:)` returns "
                + "when the glide finishes, which is why Top moves the strips one after "
                + "another; `$offset.journey.snap(to:)` puts one there at once.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A ScrollView holds one view; several children are wrapped in a stack.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// The offsets a scroller may come to rest on, and which of them it is nearest.
private struct GridStrips: ExampleContent {
    @State private var tile = 0

    @State private var rests = 0

    static let code = """
        // The strip both strips here are cut from, and the next example's too.
        // A tile is 140 wide with 20 between them, so one starts every 160,
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

            var content: any View {
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
        """

    var content: any View {
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

            Label("no interval")
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

    var notes: Element? {
        VStack {
            Label("`.snapInterval(160)`: drag the first strip and let go, and it comes to "
                + "rest on a tile however it was thrown. The strip under it says nothing "
                + "and stops wherever the throw ends.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.snapItem($tile)` names the tile the strip will stop at while it is "
                + "still moving: the number changes as the strip passes the halfway mark "
                + "between two tiles.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.onScrollStopped` runs once the strip has stopped - once per drag, "
                + "however many tiles it crossed, and after the correction where one was "
                + "needed. That is the moment work costs nothing, so it is where a list "
                + "builds the rows the next swipe needs.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// How much of the platform's own throw a release keeps.
private struct ThrowStrips: ExampleContent {
    static let code = """
        // Made of the tileStrip() the previous example defines.
        struct ThrowStrips: ContentView {
            var content: any View {
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
        """

    var content: any View {
        Grid {
            tileStrip()
                .snapInterval(160)
                .gridRow(0)

            Label("the platform's whole throw")
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

    var notes: Element? {
        VStack {
            Label("Flick both strips the same way. The lower one keeps a third of what the "
                + "platform would have thrown it, so the same flick means a tile or two "
                + "rather than five.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.momentum` scales the platform's own prediction rather than replacing "
                + "it, so a hard throw still goes further than a gentle one. A GalleryView "
                + "keeps half, which is what makes an ordinary swipe mean the next card.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// The bar down the side, asked for and taken away.
private struct BarStrips: ExampleContent {
    static let code = """
        struct BarStrips: ContentView {
            var content: any View {
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

    var content: any View {
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

    var notes: Element? {
        Label("`.never` takes the bar away and nothing brings it back; `.always` asks for "
            + "one that stays whether or not a drag is under way. Where the platform draws "
            + "an overlay bar that fades on its own, the two look alike until the scroller "
            + "is dragged.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A scroller: what reading its offset costs, where it may come to rest, how
/// far a throw carries it, and its bar.
struct ScrollViewSample: SampleContent {
    static let id = "scrollView"
    static let title = "ScrollView"
    static let summary = "A scrollable container - what its offset costs read three ways, and a write that moves it."

    // Every example here IS a scroller, so the page must not put one inside
    // another: the wrong one moves under the reader's finger, and a scroller
    // inside a scroller cannot be given a height worth having.
    static let scrolls = false

    /// Each example is given the WINDOW's height, which is what a scroller
    /// needs to be worth dragging.
    static let fills = true

    var examples: [Example] {
        [Example(OffsetStrips()), Example(GridStrips()), Example(ThrowStrips()), Example(BarStrips())]
    }
}
