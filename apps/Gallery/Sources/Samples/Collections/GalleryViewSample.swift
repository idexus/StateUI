import StateUI

/// A run of cards swiped through, in a shape one word chooses.
struct GalleryViewSample: SampleContent, ExampleContent {
    static let id = "galleryView"
    static let title = "GalleryView"
    static let summary = "A run of cards the user swipes through - a wheel, a fan, a row or a deck, chosen with .arrangement."

    // listing: GalleryViewSample
    /// Every card the gallery can hold - the gallery's groups, each its name
    /// and its picture as the home page shows it - dealt in this order.
    static let all: [Card] = [
        Card(name: "Fundamentals", art: "cat_fundamentals.png"),
        Card(name: "Driven values", art: "cat_driven.png"),
        Card(name: "Using state", art: "cat_state.png"),
        Card(name: "Animation", art: "cat_animation.png"),
        Card(name: "Controls", art: "cat_basicinput.png"),
        Card(name: "Text & typing", art: "cat_text.png"),
        Card(name: "Layout", art: "cat_layout.png"),
        Card(name: "Styles", art: "cat_styles.png"),
        Card(name: "Shapes", art: "cat_shapes.png"),
        Card(name: "Items and Cards", art: "cat_collections.png"),
        Card(name: "Gestures", art: "cat_gestures.png"),
        Card(name: "Media", art: "cat_media.png"),
    ]

    /// One card's face.
    struct Card: Hashable {
        let name: String
        let art: String
    }

    /// The four shapes, as the picker offers them.
    enum Shape: CaseIterable, Hashable {
        case wheel, fan, row, deck

        var arrangement: GalleryArrangement {
            switch self {
            case .wheel: .default
            case .fan: .fan
            case .row: .row
            case .deck: .deck
            }
        }

        var title: String {
            switch self {
            case .wheel: "Wheel"
            case .fan: "Fan"
            case .row: "Row"
            case .deck: "Deck"
            }
        }
    }

    @State private var cards = Array(Self.all.prefix(7))
    @State private var shape = Shape.wheel
    @State private var shown = 0
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
                Rectangle(Palette.raised)
                    .cornerRadius(14)

                // THE WHOLE CONTROL: the run made below - one card per item, each
                // named by its name - and one word for the shape they stand in.
                gallery
                    .arrangement(shape.arrangement)
                    .position($shown)
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
                    .count(cards.count)
                    .position(shown)
                    .indicatorColor(Palette.outline)
                    .currentIndicatorColor(Palette.accent)
                    .horizontalAlignment(.center)

                Text("\(cards[front].name) · card \(shown + 1) of \(cards.count) · \(opened) · moved \(moves)")
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(6)
            .gridRow(1)

            HStack {
                // A CARD JOINS AT THE END, or comes in at the front, fading in
                // where the shape puts it; the front card leaves at once and
                // the others close up.
                Button("Add").onClicked {
                    if let next { cards.append(next) }
                }

                Button("Insert").onClicked {
                    if let next { cards.insert(next, at: front) }
                }

                Button("Remove").onClicked {
                    guard cards.count > 1 else { return }
                    cards.remove(at: front)
                    // The last card gone, the one before it comes to the front.
                    shown = min(shown, cards.count - 1)
                }
            }
            .spacing(8)
            .horizontalAlignment(.center)
            .gridRow(2)

            HStack {
                Button("Back")
                    .isEnabled(shown > 0)
                    .onClicked { shown -= 1 }

                Button("Next")
                    .isEnabled(shown < cards.count - 1)
                    .onClicked { shown += 1 }
            }
            .spacing(8)
            .horizontalAlignment(.center)
            .gridRow(3)

            HStack {
                // THE SHAPE, one word: the cards travel to the new one.
                Picker(Shape.allCases, selection: $shape) { $0.title }

                SwitchRow("Shaded", $shaded)
            }
            .spacing(16)
            .horizontalAlignment(.center)
            .gridRow(4)
        }
        .rows(.fill, .auto, .auto, .auto, .auto)
        .rowSpacing(8)
    }

    /// The next card not in the gallery, if any is left.
    private var next: Card? {
        Self.all.first { !cards.contains($0) }
    }

    /// Where the card in front stands among the cards.
    private var front: Int {
        min(max(shown, 0), cards.count - 1)
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
        let run = GalleryView(cards, id: \.name) { card in
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
        return run.shade(Rectangle(Color(hex: 0x000000)).cornerRadius(16))
    }

    /// One card's face - a picture and its name, and nothing at all about where
    /// the card is or which way it faces. That is the gallery's, and keeping
    /// the two apart is what lets one run of cards wear four shapes.
    private func face(_ card: Card) -> some View {
        ZStack {
            Grid {
                Image(ImageSource(card.art))
                    .contentMode(.fill)

                Text(card.name)
                    .fontSize(18)
                    .fontWeight(.bold)
                    .textColor(Palette.onBrand)
                    .lineBreak(.tailTruncation)
                    .padding(horizontal: 12, vertical: 10)
                    .background(Color(hex: 0x000000, opacity: 0.7))
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
                + "wheel, `.fan` a hand of cards, `.row` a strip, `.deck` a pile swiped a "
                + "card at a time. The cards TRAVEL between the shapes, and a card added, "
                + "inserted or removed travels from where it was.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Swipe, drag with the mouse or turn a wheel: the run settles on the "
                + "card it is nearest - in the deck, the card in front goes out under your "
                + "finger and under the next. `.position($shown)` is which one, written "
                + "as the user moves and glided to when it is assigned - which is what "
                + "Back and Next do. The dots are a `PositionIndicator` reading the same "
                + "`@State`: one number joins the two controls.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`Shaded` is `.shade(Rectangle(Color(hex: 0x000000)).cornerRadius(16))`: "
                + "the cards away from the middle are DARKENED by a view drawn over them "
                + "rather than faded, so what is behind a far card stays hidden. "
                + "`.onItemTapped` is handed the card in the MIDDLE.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
