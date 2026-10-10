import StateUI

/// A run of cards swiped through, in a shape one word chooses.
struct GalleryViewSample: SampleContent, ExampleContent {
    static let id = "galleryView"
    static let title = "GalleryView"
    static let summary = "A run of cards the user swipes through - a wheel, a fan or a row, chosen with .arrangement."

    // listing: GalleryViewSample
    /// The cards: what each picture is called and which file it is.
    static let cards: [Card] = [
        Card(name: "Mural", art: "art_mural.png"),
        Card(name: "Nebula", art: "art_nebula.png"),
        Card(name: "Ridge", art: "art_ridge.png"),
        Card(name: "Bloom", art: "art_bloom.png"),
        Card(name: "Tide", art: "art_tide.png"),
        Card(name: "Prism", art: "art_prism.png"),
        Card(name: "Grove", art: "art_grove.png"),
    ]

    /// One card's face.
    struct Card {
        let name: String
        let art: String
    }

    /// The three shapes, and what to call them on the button that cycles them.
    static let shapes: [(GalleryArrangement, String)] = [
        (.default, "Wheel"),
        (.fan, "Fan"),
        (.row, "Row"),
    ]

    @State private var shape = 0
    @State private var shown = 0
    @State private var swipes = true
    @State private var shaded = true
    @State private var opened = "tap one"
    @State private var moves = 0
    // listing: end

    // The cards are turned by a scroller of their own, so the example is not
    // put in a second one: the page's scroller would claim the swipe before it
    // heard about one.
    static let scrolls = false

    // And it takes the whole cell: a gallery wants the room, and the cards are
    // placed in whatever it is given.
    static let fills = true

    // listing: GalleryViewSample
    var body: some View {
        // A GRID rather than a stack: the board takes whatever room is left
        // over, which a stack cannot give a child - and a gallery wants it all.
        Grid {
            Grid {
                ColorBox(Palette.raised)
                    .cornerRadius(14)

                // THE WHOLE CONTROL: the run made below - one card per item, each
                // named by its name - and one word for the shape they stand in.
                gallery
                    .arrangement(Self.shapes[shape].0)
                    .position($shown)
                    .isSwipeEnabled(swipes)
                    .onItemTapped { card in opened = "tapped \(card.name)" }
                    // Another card in the middle, swiped or assigned.
                    .onPositionChanged { _ in moves += 1 }
            }
            .gridRow(0)
            // The cards stay ON the board: one mid-crossing between two shapes,
            // or turned far out in a small room, is cut at the board's edge
            // rather than painted over the page.
            .clipsContent(true)

            // A LIVE READING: the position binding is written as the run
            // moves - and the dots read the SAME state, which is the whole of
            // how the two controls are joined.
            VStack {
                // INSIDE these braces, because that is where `shown`, `opened`
                // and `moves` are read - the dots and the caption are written
                // from them - so a swipe builds this closure as each card comes
                // to the middle, not on every frame of the movement.
                DebugInfoLabel()

                PositionIndicator()
                    .count(Self.cards.count)
                    .position(shown)
                    .indicatorColor(Palette.outline)
                    .currentIndicatorColor(Palette.accent)
                    .horizontalAlignment(.center)

                Text("\(Self.cards[min(max(shown, 0), Self.cards.count - 1)].name) · "
                    + "card \(shown + 1) of \(Self.cards.count) · \(opened) · moved \(moves)")
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(6)
            .gridRow(1)

            HStack {
                // ONE WIDTH FOR EVERY CAPTION: the button keeps its size as
                // Wheel, Fan and Row take turns, so the row does not shift.
                Button(Self.shapes[shape].1)
                    .width(88)
                    .margin(horizontal: 4, vertical: 0)
                    .onClicked { shape = (shape + 1) % Self.shapes.count }

                Button("Back")
                    .margin(horizontal: 4, vertical: 0)
                    .isEnabled(shown > 0)
                    .onClicked { shown -= 1 }

                Button("Next")
                    .margin(horizontal: 4, vertical: 0)
                    .isEnabled(shown < Self.cards.count - 1)
                    .onClicked { shown += 1 }

                SwitchRow("Swipeable", $swipes)
                    .margin(horizontal: 4, vertical: 0)

                SwitchRow("Shaded", $shaded)
                    .margin(horizontal: 4, vertical: 0)
            }
            .spacing(8)
            .horizontalAlignment(.center)
            .gridRow(2)
        }
        .rows(.fill, .auto, .auto)
        .rowSpacing(8)
    }

    /// The run, either way the switch is set - and the two are worth watching
    /// side by side. SHADED, a card going away is darkened by a view drawn
    /// over it and keeps a quarter of its fade, so what is under it stays
    /// mostly hidden; FADED, the same card goes transparent and the card
    /// behind it shows through, which on a wheel is the next card rather than
    /// the board.
    ///
    /// The shade wears the card's own corners, and that is why it is the
    /// application's to give: nothing in the library knows what shape a card
    /// has.
    private var gallery: GalleryView<[Card], String> {
        let run = GalleryView(Self.cards, id: \.name) { card in
            // A picture and its name. Where the card stands and which way
            // it faces is the SHAPE's, and this knows nothing about it.
            face(card)
        }

        guard shaded else { return run }

        // THE FAR CARDS DARKEN RATHER THAN FADE. A faded card shows
        // whatever is behind it, which on a wheel is the next card - so
        // depth is a shade drawn OVER the card. It wears the card's own
        // corners, which is why the view is the application's to give.
        // A quarter of the fade is left beside it, unless `.fade(_:)` says
        // otherwise.
        return run.shade(ColorBox(Color("#000000")).cornerRadius(16))
    }

    /// One card's face - a picture and its name, and nothing at all about where
    /// the card is or which way it faces. That is the gallery's, and keeping
    /// the two apart is what lets one run of cards wear three shapes.
    private func face(_ card: Card) -> some View {
        ZStack {
            Grid {
                Image(ImageSource(card.art))
                    .contentMode(.fill)

                Text(card.name)
                    .fontSize(18)
                    .fontAttributes(.bold)
                    .textColor(Palette.onBrand)
                    .lineBreak(.tailTruncation)
                    .padding(horizontal: 12, vertical: 10)
                    .background(Color("#B3000000"))
                    .verticalAlignment(.end)
            }
            .clipsContent(true)
        }
        .style(.card)
        .lineWidth(0)
        .shape(.roundedRectangle(16))
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`GalleryView` is a run of cards the user swipes through, with "
                + "`.arrangement` choosing the shape they stand in - `.default` is a "
                + "wheel, `.fan` a hand of cards, `.row` a strip. The cards TRAVEL "
                + "between the three, so the shape button carries the whole run across.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Swipe, drag with the mouse or turn a wheel: the run settles on the "
                + "card it is nearest. WHICH of those the run answers is the platform's: "
                + "a finger drags the run itself, so on a phone and a tablet that is the "
                + "whole of it, while on a desktop - where a mouse drag scrolls nothing - "
                + "the cards take a drag of their own. `.position($shown)` is which "
                + "one, written as the user moves and glided to when it is assigned - "
                + "which is what Back and Next do. The dots under the cards are a "
                + "`PositionIndicator` reading the same `@State`: neither control names the "
                + "other, and one number joins them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`Swipeable` is `.isSwipeEnabled(false)` - the user's "
                + "hand is stopped and the buttons still move the run. A gallery is "
                + "swiped to choose and tapped to open: `.onItemTapped` is handed the "
                + "card in the MIDDLE, and a tap beside it answers nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`Shaded` is `.shade(ColorBox(Color(\"#000000\")).cornerRadius(16))`: "
                + "the cards away from the middle are DARKENED by a view drawn over them "
                + "rather than faded. Turn it off and watch a far card go transparent - "
                + "what shows through is the card behind it. The shade is a view because "
                + "it has to wear the card's own corners, and `.fade(_:)` says how much "
                + "fade is left beside it, from 0 to 1 - a quarter unless said.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Nothing is described while the cards move: the one render is the "
                + "card CHANGING. `.itemSize(width:height:)` gives a card's proportions, "
                + "and the run is fitted to its room - smaller in a small window, larger "
                + "in a big one.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
