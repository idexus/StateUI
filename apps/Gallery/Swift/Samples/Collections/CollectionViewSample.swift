import StateUI

/// A thousand rows, of which the list describes the dozen that can be seen -
/// and one measured row is where all the arithmetic comes from.
private struct BigList: ContentView {
    @State private var chosen: Int?

    var content: Element {
        Grid {
            CollectionView(0..<1_000) { number in
                HStack {
                    Label("\(number)")
                        .fontSize(14)
                        .widthRequest(90)
                        .verticalOptions(.center)

                    Label("\(number * number)")
                        .fontSize(13)
                        .textColor(Palette.subtle)
                        .verticalOptions(.center)
                }
                .spacing(12)
                .padding(14, 10)
                .backgroundColor(chosen == number ? Palette.selected : .transparent)
            }
            .header(Label("N and N², a thousand times")
                .fontSize(11)
                .fontAttributes(.bold)
                .textColor(Palette.subtle)
                .padding(14, 8)
                .backgroundColor(Palette.raised))
            .footer(Label("That is all of them.")
                .fontSize(12)
                .textColor(Palette.subtle)
                .padding(14, 8))
            .selection($chosen)
            .gridRow(0)

            Label(chosen.map { "Row \($0) is chosen - tap it again to clear it." }
                ?? "Nothing chosen. Tap a row.")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(10)
    }

    /// The words under this half - the page places them, and on a held page
    /// they take a tab of their own. See `SampleContent.notes`.
    var notes: Element {
        Label("Every row is described in Swift, and only the ones in view are described "
            + "at all: a screenful and a few either side, whatever the screen - scroll "
            + "to the end and the thousandth row is the first time row 999 exists. What "
            + "makes that possible is the FIRST row, measured - the height it settles "
            + "at is every row's, so the scroller's own height is the count times that "
            + "number and nothing has to be built to work it out.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// The same list, told its row height rather than measuring one - which is
/// also what lets an act scroll to a row by number.
private struct PickList: ContentView {
    @State private var chosen: Set<Int> = []

    @State private var list = ControlState<ScrollView>()

    var content: Element {
        Grid {
            HStack {
                Button("Top")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await list.scrollTo(x: 0, y: 0) }

                Button("Row 500")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await list.scrollTo(x: 0, y: 500 * 44) }

                Button("Clear")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(!chosen.isEmpty)
                    .onClicked { chosen = [] }
            }
            .spacing(10)
            .horizontalOptions(.center)
            .gridRow(0)

            CollectionView(0..<1_000) { number in
                HStack {
                    Label(chosen.contains(number) ? "✓" : "")
                        .fontSize(14)
                        .textColor(Palette.accent)
                        .widthRequest(22)
                        .verticalOptions(.center)

                    Label("Row \(number)")
                        .fontSize(14)
                        .verticalOptions(.center)
                }
                .spacing(8)
                .padding(14, 10)
                .backgroundColor(chosen.contains(number) ? Palette.selected : .transparent)
            }
            .itemSize(44)
            .selection($chosen)
            .assign(list)
            .gridRow(1)

            Label("\(chosen.count) chosen")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(2)
        }
        .rowDefinitions(.auto, .star, .auto)
        .rowSpacing(10)
    }

    /// The words under this half. See `SampleContent.notes`.
    var notes: Element {
        Label("A Set is what says how many rows may be chosen - one binding of one type, "
            + "and no mode to disagree with it. The row draws itself from the same state, "
            + "which is why a chosen row can look like anything at all. And a stated "
            + "`.itemSize` is what makes a row's offset arithmetic: this list IS a "
            + "ScrollView from the outside, so the state it is assigned to takes a "
            + "ScrollView's own acts.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// The same list turned on its side, twice: one that comes to rest on an item
/// and one that stops wherever the throw ran out.
private struct AcrossList: ContentView {
    var content: Element {
        VStack {
            strip(snapping: true)

            Label("resting on an item - let go and a card lands at the edge")
                .fontSize(12)
                .textColor(Palette.subtle)

            strip(snapping: false)

            Label("the same strip without it - it stops wherever the throw ran out")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    /// One row of cards, told how long an item is and whether to rest on one.
    private func strip(snapping: Bool) -> Element {
        var list = CollectionView(1...200) { number in
            // The card FILLS its slot - the alignment is the text's, not the
            // view's - so what is on screen is the item's real size.
            Label("Card \(number)")
                .fontSize(14)
                .horizontalTextAlignment(.center)
                .verticalTextAlignment(.center)
                .backgroundColor(Palette.surface)
                .margin(0, 0, 8, 0)
        }
        .orientation(.horizontal)
        .itemSize(120)

        if snapping {
            list = list.snapToItem(true)
        }

        // A list running ACROSS needs a bounded height for the same reason one
        // running down needs a bounded height: a scroller with no size across
        // its axis is measured at nothing.
        return list.heightRequest(70)
    }

    var notes: Element {
        VStack {
            Label("The same arithmetic along the other axis: an item takes the whole HEIGHT "
                + "of a list that runs across, as it takes the whole width of one that runs "
                + "down, and `itemSize` is its width rather than its height. Two hundred "
                + "cards, of which the handful in view are described.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.snapToItem(true)` on the first one: where the platform's own braking "
                + "would have stopped is rounded to a multiple of 120 BEFORE it starts, so a "
                + "throw still travels as far as its speed deserves and it is one movement, "
                + "the platform's own - it simply ends with a card at the edge. Throw both "
                + "strips and watch where each stops.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A GROUPED list is left alone by it: a heading is not the size of a row, so "
                + "the rows under one stand off any fixed grid.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// This library's own list - what stands in for MAUI's CollectionView here.
struct CollectionViewSample: SampleContent {
    static let id = "collectionView"
    static let title = "CollectionView"
    static let summary = "The library's own list: a thousand rows, a dozen described - down or across."

    // The list scrolls itself, so the page holds still and scrolls the code -
    // and the example takes the window's height, since a list is worth as many
    // rows as there is room for.
    static let scrolls = false
    static let fills = true

    /// The big list, then selection and the acts - each with its own words,
    /// which is what lets a phone put them in a tab of their own.
    var parts: [SamplePart] {
        let big = BigList()
        let pick = PickList()
        let across = AcrossList()

        return [SamplePart(title: "EXAMPLE 1", view: big, notes: big.notes),
                SamplePart(title: "EXAMPLE 2", view: pick, notes: pick.notes),
                SamplePart(title: "EXAMPLE 3", view: across, notes: across.notes)]
    }

    var content: Element {
        VStack {
            BigList()
            PickList()
            AcrossList()
        }
        .spacing(16)
    }

    static let code = """
        // -- EXAMPLE 1 --

        struct BigList: ContentView {
            @State private var chosen: Int?

            var content: Element {
                // A list needs a bounded height, like any scroller - and a
                // STAR row is the way to bound it: the list is then as tall as
                // the window allows, where a height in points would show the
                // same few rows on every screen.
                Grid {
                    // The initializer is the row template, run here - what
                    // differs from a full list is how many of the
                    // thousand are described: the ones in view, and a few
                    // either side. The first row placed is measured, and its
                    // height is every row's.
                    CollectionView(0..<1_000) { number in
                        HStack {
                            Label("\\(number)").widthRequest(90)
                            Label("\\(number * number)")
                        }
                        .padding(14, 10)
                        // A chosen row draws itself: the template reads the
                        // same state the binding writes.
                        .backgroundColor(chosen == number ? Palette.selected : .transparent)
                    }
                    .header(Label("N and N², a thousand times"))
                    .footer(Label("That is all of them."))
                    .selection($chosen)
                    .gridRow(0)

                    Label(chosen.map { "Row \\($0) is chosen." } ?? "Nothing chosen.")
                        .gridRow(1)
                }
                .rowDefinitions(.star, .auto)
            }
        }

        // -- EXAMPLE 2 --

        struct PickList: ContentView {
            @State private var chosen: Set<Int> = []

            // The list IS a ScrollView from the outside, so this is what its
            // acts aim with.
            @State private var list = ControlState<ScrollView>()

            var content: Element {
                Grid {
                    HStack {
                        Button("Top").onClicked { try await list.scrollTo(x: 0, y: 0) }

                        // A stated row height is what makes a row's offset
                        // arithmetic rather than a guess.
                        Button("Row 500")
                            .onClicked { try await list.scrollTo(x: 0, y: 500 * 44) }

                        Button("Clear")
                            .isEnabled(!chosen.isEmpty)
                            .onClicked { chosen = [] }
                    }
                    .gridRow(0)

                    CollectionView(0..<1_000) { number in
                        HStack {
                            Label(chosen.contains(number) ? "✓" : "").widthRequest(22)
                            Label("Row \\(number)")
                        }
                        .padding(14, 10)
                        .backgroundColor(chosen.contains(number) ? Palette.selected : .transparent)
                    }
                    .itemSize(44)
                    // A Set rather than one value: the binding's TYPE is what
                    // says how many rows may be chosen.
                    .selection($chosen)
                    .assign(list)
                    .gridRow(1)

                    Label("\\(chosen.count) chosen")
                        .gridRow(2)
                }
                .rowDefinitions(.auto, .star, .auto)
            }
        }

        // -- EXAMPLE 3 --

        struct AcrossList: ContentView {
            var content: Element {
                VStack {
                    // The same arithmetic along the other axis: an item takes
                    // the whole height, and `itemSize` is its WIDTH.
                    CollectionView(1...200) { number in
                        Label("Card \\(number)")
                            .verticalTextAlignment(.center)
                            .backgroundColor(Palette.surface)
                    }
                    .orientation(.horizontal)
                    .itemSize(120)
                    // Let go and an item comes to rest at the edge: the
                    // platform's own braking is aimed at a multiple of 120
                    // before it starts.
                    .snapToItem(true)
                    .heightRequest(70)

                    // The same strip without it, for comparison.
                    CollectionView(1...200) { number in
                        Label("Card \\(number)")
                            .backgroundColor(Palette.surface)
                    }
                    .orientation(.horizontal)
                    .itemSize(120)
                    .heightRequest(70)
                }
            }
        }
        """
}
