import StateUI

/// This library's own: a run of cards swiped through, in a shape one word
/// chooses.
struct GalleryViewSample: SampleContent {
    static let id = "galleryView"
    static let title = "GalleryView"
    static let summary = "A run of cards the reader swipes through - a wheel, a fan or a row, chosen with .galleryStyle. Nothing is described while the cards move."

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
    static let shapes: [(GalleryStyle, String)] = [
        (.default, "Wheel"),
        (.fan, "Fan"),
        (.row, "Row"),
    ]

    @State private var shape = 0
    @State private var shown = 0
    @State private var stepped = false
    @State private var swipes = true
    @State private var opened = "swipe the cards, then tap one"

    // The cards are turned by a scroller of their own, so the example is not
    // put in a second one: the page's scroller would claim the swipe before it
    // heard about one.
    static let scrolls = false

    // And it takes the whole cell: a gallery wants the room, and the cards are
    // placed in whatever it is given.
    static let fills = true

    static let code = """
        @State private var shown = 0
        @State private var opened = ""

        private let cards = ["Mural", "Nebula", "Ridge", "Bloom", "Tide"]

        VStack {
            // THE WHOLE CONTROL. One card per item, the item its identity, and
            // one word for the shape they stand in.
            GalleryView(cards, id: \\.self) { card in
                CardFace(card)
            }
            .galleryStyle(.default)
            .position($shown)
            .onItemTapped { card in opened = card }

            // The binding is written as the reader swipes, so anything under
            // the run follows the hand - and assigning it moves the cards. The
            // dots are joined to the gallery by that one state and nothing
            // else.
            IndicatorView()
                .count(cards.count)
                .position(shown)

            Label(cards[shown])

            HStack {
                Button("Back").onClicked { shown -= 1 }
                Button("Next").onClicked { shown += 1 }
            }
        }
        """

    var content: Element {
        // A GRID rather than a stack: the board takes whatever room is left
        // over, which a stack cannot give a child - and a gallery wants it all.
        Grid {
            Grid {
                BoxView(Palette.raised)
                    .cornerRadius(14)

                GalleryView(Self.cards, id: \.name) { card in
                    face(card)
                }
                .galleryStyle(Self.shapes[shape].0)
                .position($shown)
                .isSwipeEnabled(swipes)
                .snapsAtMost(stepped ? 1 : 0)
                .onItemTapped { card in opened = "tapped \(card.name)" }
            }
            .gridRow(0)
            // The cards stay ON the board: one mid-flight between two shapes,
            // or turned far out in a small room, is cut at the board's edge
            // rather than painted over the page.
            .isClippedToBounds(true)

            // A LIVE READING, so it stays with the example rather than going to
            // the notes: the position binding is written as the run moves - and
            // the dots read the SAME state, which is the whole of how the two
            // controls are joined.
            VStack {
                IndicatorView()
                    .count(Self.cards.count)
                    .position(shown)
                    .indicatorColor(Palette.outline)
                    .selectedIndicatorColor(Palette.accent)

                Label("\(Self.cards[min(max(shown, 0), Self.cards.count - 1)].name) · "
                    + "card \(shown + 1) of \(Self.cards.count) · \(opened)")
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(6)
            .gridRow(1)

            // ONE ROW THAT WRAPS: a phone held upright folds it into two lines,
            // and a phone on its side - which has no height to spare - keeps it
            // on one.
            FlexLayout {
                // ONE WIDTH FOR EVERY CAPTION: a wrapping row re-measures a
                // child on its own schedule, and a caption that changed inside
                // one is drawn cut short until something else makes it measure
                // again.
                Button(Self.shapes[shape].1)
                    .widthRequest(88)
                    .margin(4, 0)
                    .onClicked { shape = (shape + 1) % Self.shapes.count }

                Button("Back")
                    .margin(4, 0)
                    .isEnabled(shown > 0)
                    .onClicked { shown -= 1 }

                Button("Next")
                    .margin(4, 0)
                    .isEnabled(shown < Self.cards.count - 1)
                    .onClicked { shown += 1 }

                SwitchRow("One card a swipe", $stepped)
                    .margin(4, 0)

                SwitchRow("Swipeable", $swipes)
                    .margin(4, 0)
            }
            .direction(.row)
            .wrap(.wrap)
            .justifyContent(.center)
            .alignItems(.center)
            .gridRow(2)
        }
        .rowDefinitions(.star, .auto, .auto)
        .rowSpacing(8)
    }

    /// One card's face - a picture and its name, and nothing at all about where
    /// the card is or which way it faces. That is the gallery's, and keeping
    /// the two apart is what lets one run of cards wear three shapes.
    private func face(_ card: Card) -> Element {
        Border {
            Grid {
                Image(ImageSource(card.art))
                    .aspect(.aspectFill)

                Label(card.name)
                    .fontSize(18)
                    .fontAttributes(.bold)
                    .textColor(Palette.onBrand)
                    .lineBreakMode(.tailTruncation)
                    .padding(12, 10)
                    .backgroundColor(Color("#B3000000"))
                    .verticalOptions(.end)
            }
            .isClippedToBounds(true)
        }
        .strokeThickness(0)
        .strokeShape(.roundRectangle(16))
    }

    var notes: Element? {
        VStack {
            Label("`GalleryView` is this library's own: a run of cards the "
                + "reader swipes through, with `.galleryStyle` choosing the "
                + "shape they stand in - `.default` is a wheel, `.fan` a hand "
                + "of cards, `.row` a strip. The cards TRAVEL between the "
                + "three, so the button above carries the whole run across.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Swipe, drag with a trackpad or turn a wheel: the run "
                + "settles on the card it is nearest. `.position($shown)` is "
                + "which one, written as the reader moves and glided to when "
                + "it is assigned - which is what Back and Next do, and what "
                + "the line under the cards is written from.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("`One card a swipe` is `.snapsAtMost(1)`: however hard the "
                + "run is thrown it crosses one card, which is what a deck "
                + "somebody is stepping through wants. `Swipeable` is "
                + "`.isSwipeEnabled(false)` - the reader's hand is stopped and "
                + "the buttons still move the run.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Tapping the run opens the card in the MIDDLE - a gallery is "
                + "swiped to choose and tapped to open, and the middle card is "
                + "the choice. `.onItemTapped` is handed it.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The dots under the cards are an `IndicatorView` reading the "
                + "same `@State` the gallery writes. Neither control names the "
                + "other; one number joins them.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Nothing is described while the cards move. The scroller's "
                + "offset rides a channel, which is read and written without "
                + "the interface being described again, and the host runs the "
                + "arithmetic on its own frames - so the one render is the "
                + "card CHANGING. `.itemSize(width:height:)` says how big a "
                + "card is, and the run scales down to fit a small window.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
