import Foundation
import StateUI

/// A layout of the author's own: one line of arithmetic says where each card
/// goes and how it is turned, and every card travels there.
struct PlacedSample: SampleContent {
    static let id = "placed"
    static let title = "A layout of your own"
    static let summary = "PlacedLayout hands you the index, the count and the room, and takes back where a view goes and how it is turned - a gallery, a fan, a ring or a row. Swipe to turn the cards through it."

    /// The four arrangements the same cards are put in.
    static let shapes = ["Gallery", "Fan", "Ring", "Row"]

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

    /// How far the hand travels to turn the cards by one, in device units.
    static let reach = 90.0

    /// How big a card is - the SAME in every shape, which is what lets a switch
    /// between them be one journey rather than two.
    static let width = 176.0
    static let height = 248.0

    @State private var shape = 0

    /// How far the run has been scrolled, and the scroller that moves it.
    @State private var offset = Double(PlacedSample.cards.count / 2) * PlacedSample.reach

    @State private var scroller = ControlState<ScrollView>()

    /// Whether the cards are TRAVELLING rather than following the scroller -
    /// true for as long as one flight between shapes lasts.
    @State private var flying = false

    /// Whether the run has been put where it opens. A scroller cannot be moved
    /// before it has been laid out - asked earlier it clamps to the length it
    /// has so far, which is the whole viewport short - so the first frame
    /// report is what says it is ready.
    @State private var opened = false

    // The cards are turned by a scroller of their own, so the example is not
    // put in a second one: the page's scroller would claim the swipe before it
    // heard about one. The words and the code scroll instead - see
    // SampleContent.scrolls.
    static let scrolls = false

    // And it takes the whole cell: a gallery wants the room, and the cards are
    // placed in whatever it is given.
    static let fills = true

    /// How far the run is turned, in CARDS - a whole number at rest and
    /// whatever the scroller says while it is moving.
    ///
    /// A READING FROM OUTSIDE IS NOT A NUMBER UNTIL IT IS CHECKED: a platform
    /// that reports through a transform can answer with no number at all, and
    /// `Int()` on one of those does not return.
    private var at: Double {
        let turned = offset / Self.reach

        return turned.isFinite ? turned : 0
    }

    static let code = """
        @State private var offset = 0.0
        @State private var scroller = ControlState<ScrollView>()

        // THE WHOLE LAYOUT IS THIS CLOSURE. Given which card this is, how many
        // there are and how much room there is, it answers a Placement - where
        // the card goes AND how it is turned, scaled, faded and stacked. How
        // far the run has been scrolled is in the arithmetic, so moving the
        // scroller swings the whole gallery round.
        Grid {
            FrameReader { room in
                PlacedLayout(cards, id: \\.name, at: { index, count, room in
                    let step = Double(index) - offset / 90
                    let near = max(-2.4, min(2.4, step))
                    let away = min(abs(near), 1.55) / 1.55

                    return Placement(
                        Rect(
                            room.width / 2 + near * 92 - 88,
                            room.height / 2 - 124,
                            176,
                            248),
                        opacity: 1 - min(max(abs(near) - 0.35, 0) / 3, 0.62),
                        zIndex: 1000 - Int(min(abs(step), 99) * 100)
                    ) {
                        // ONE TRANSFORM, about the card's own centre, and the
                        // same picture on every platform. `turn` is a turn
                        // about the vertical axis drawn FLAT; `.rotationY` is
                        // the other reading, which every platform projects
                        // through a camera of its own.
                        $0.turn(away * 64)
                            .scale(1.1 - min(abs(near), 1.6) * 0.2)
                            .rotate(near * 3)
                    }
                }) { card in
                    CardFace(card)
                }
                // A PLACEMENT WORKED OUT FROM A SCROLLER DOES NOT TRAVEL: the
                // arithmetic is re-answered on every report, and a card a fifth
                // of a second behind the hand is a card that lags.
                .motion(.none)
            }
            .inputTransparent(true)

            // WHAT MOVES IT, and it is a scroller rather than a pan on purpose:
            // a finger drag, a two-finger swipe and a wheel notch are one thing
            // to a scroller and three to everything else. Nothing to see in it
            // - the cards show through - one card per 90 points of its length,
            // and told to rest on that same grid, so the platform's own
            // snapping is what settles it on a card.
            FrameReader { room in
                ScrollView {
                    BoxView(Color("#00000000"))
                        .widthRequest(Double(cards.count - 1) * 90 + room.width)
                        .heightRequest(room.height)
                }
                .orientation(.horizontal)
                .horizontalScrollBarVisibility(.never)
                .snapInterval(90)
                .assign(scroller)
                .scrollX($offset)
            }
        }
        """

    var content: Element {
        // A GRID rather than a stack: the board takes whatever room is left
        // over, which a stack cannot give a child - and a gallery wants it all.
        Grid {
            Grid {
                // THE BOARD, under everything.
                BoxView(Palette.raised)
                    .cornerRadius(14)

                // THE CARDS AND WHAT MOVES THEM, in one measured room: the
                // scroller is laid OVER the cards and is last, so it is what a
                // touch lands on, and the cards under it take no input at all.
                FrameReader { room in
                    Grid {
                        PlacedLayout(Self.cards, id: \.name, at: place) { card in
                            face(card)
                        }
                        // A PLACEMENT WORKED OUT FROM A SCROLLER DOES NOT
                        // TRAVEL: the arithmetic is re-answered on every
                        // report, and a card a fifth of a second behind the
                        // hand is a card that lags. A change of SHAPE is the
                        // other case, and the only one where these do travel.
                        .motion(flying ? .inherited : .none)
                        .inputTransparent(true)

                        // A SCROLLER RATHER THAN A PAN, on purpose: a finger
                        // drag, a two-finger trackpad swipe and a mouse wheel
                        // are ONE thing to a scroller and three different
                        // things to everything else. Measured on iOS: a pan
                        // written on the board under these layers is never told
                        // about a touch at all, and one written on a card is
                        // told in that card's own turned coordinates, which is
                        // not a number.
                        ScrollView {
                            // Nothing to see: what shows through is the layout
                            // underneath, and the length is what says how many
                            // cards there are to reach.
                            // NO HEIGHT OF ITS OWN: a height taken from the
                            // room this scroller is IN is a size that feeds
                            // itself, and a measure that feeds itself does not
                            // have to settle. The scroller fills its cell and
                            // takes the whole board's touches either way.
                            BoxView(Color("#00000000"))
                                .widthRequest(
                                    Double(Self.cards.count - 1) * Self.reach
                                        + max(room.width, 1))
                                .heightRequest(1)
                        }
                        .orientation(.horizontal)
                        .horizontalScrollBarVisibility(.never)
                        // ONE CARD PER `reach`, and the platform's own snapping
                        // is then what settles the run on the card it is
                        // nearest.
                        .snapInterval(Self.reach)
                        .assign(scroller)
                        .scrollX($offset)
                        // Opened on the middle card, so there is a run of them
                        // either side from the first moment - at the first
                        // frame report, which is when the length above is real.
                        .onFrameChanged { frame in
                            guard !opened, frame.width > 0 else { return }

                            opened = true

                            try await scroller.scrollTo(
                                x: Double(Self.cards.count / 2) * Self.reach,
                                y: 0,
                                animated: false)
                        }
                    }
                }
            }
            .gridRow(0)

            HStack {
                ForEach(Self.cards, id: \.name) { card in
                    // The THEME's ink, not the white that reads on a card: the
                    // dots sit on the page, which is light in one theme and
                    // dark in the other.
                    BoxView(Palette.text)
                        .cornerRadius(3)
                        .widthRequest(6)
                        .heightRequest(6)
                        .verticalOptions(.center)
                        // WHICH CARD IS IN THE MIDDLE, said by a fade: the run
                        // is turned by a fraction while it is moving, so the
                        // dots cross over as the cards do.
                        .opacity(dot(card))
                }
            }
            .spacing(7)
            .horizontalOptions(.center)
            .gridRow(1)

            HStack {
                Button(Self.shapes[shape]).onClicked { try await reshape() }

                Button("Back").onClicked { try await move(-1) }

                Button("Next").onClicked { try await move(1) }
            }
            .spacing(8)
            .horizontalOptions(.center)
            .gridRow(2)
        }
        .rowDefinitions(.star, .auto, .auto)
        .rowSpacing(10)
    }

    /// The next shape, and the cards FLY to it.
    ///
    /// The placement is held still while the scroller is moving it, so the one
    /// change that should be seen travelling asks for it - for as long as a
    /// flight lasts, and no longer.
    private func reshape() async throws {
        flying = true
        shape = (shape + 1) % Self.shapes.count

        try await Task.sleep(for: .milliseconds(500))

        flying = false
    }

    /// A card either way, from a button: the scroller is what moves, so this
    /// asks it to glide and the arithmetic follows it frame by frame.
    private func move(_ by: Int) async throws {
        let slot = max(0, min(Double(Self.cards.count - 1), (at + Double(by)).rounded()))

        try await scroller.scrollTo(x: slot * Self.reach, y: 0)
    }

    /// How lit one card's dot is: full for the one in the middle, faint for the
    /// rest, and part way for either side of a run being turned.
    private func dot(_ card: Card) -> Double {
        guard let index = Self.cards.firstIndex(where: { $0.name == card.name }) else {
            return 0.25
        }

        return 0.25 + 0.75 * max(0, 1 - abs(Double(index) - at))
    }

    /// One card's face - a picture and its name, and nothing at all about where
    /// the card is or which way it faces. That is the placement's, and keeping
    /// the two apart is what lets one run of cards wear four layouts.
    private func face(_ card: Card) -> Element {
        Border {
            Grid {
                Image(ImageSource(card.art))
                    .aspect(.aspectFill)

                VStack {
                    // ONE LINE, whatever the card's width: the same face wears
                    // four layouts here, and a caption that wrapped in the
                    // small ones would change the picture's height with it.
                    Label(card.name)
                        .fontSize(18)
                        .fontAttributes(.bold)
                        .textColor(Palette.onBrand)
                        .lineBreakMode(.tailTruncation)

                    Label("Placed by arithmetic")
                        .fontSize(10)
                        .textColor(Palette.onBrand)
                        .opacity(0.8)
                        .lineBreakMode(.tailTruncation)
                }
                .padding(12, 10)
                .spacing(1)
                // A dark strip under the words, so a caption reads over a
                // picture of any colour.
                .backgroundColor(Color("#B3000000"))
                .verticalOptions(.end)
            }
            // THE PICTURE IS CUT AT THE CARD'S EDGE, and this is a platform
            // difference rather than a nicety: a Border clips what it holds on
            // Apple and does not on Android, so a picture told to FILL the card
            // was painted at its own size all over the layout - measured on a
            // phone, cards the size of the board with the caption still in the
            // right place. The clip belongs on the grid, which is a layout and
            // therefore the thing that has edges to cut at.
            .isClippedToBounds(true)
        }
        .strokeThickness(0)
        .strokeShape(.roundRectangle(16))
    }

    /// Where one card goes and how it is turned - the whole of the layout.
    ///
    /// A CARD IS ONE SIZE in every shape, and how big it LOOKS is the
    /// transform's. Sizing by the rectangle instead would put the run through a
    /// change of size as well as of place at every switch, which is two
    /// journeys where one will do.
    private func place(_ index: Int, _ count: Int, _ room: Rect) -> Placement {
        let step = Double(index) - at

        switch shape {
        case 1:
            return fan(step, room)

        case 2:
            return ring(index, count, room)

        case 3:
            return row(step, count, room)

        default:
            return gallery(step, room)
        }
    }

    /// A GALLERY: the cards stand on a wheel, the one in the middle facing the
    /// reader and the rest turning away, shrinking and fading behind it.
    private func gallery(_ step: Double, _ room: Rect) -> Placement {
        let near = max(-2.4, min(2.4, step))
        let away = min(abs(near), 1.55) / 1.55

        return Placement(
            card(room, up: 0, across: near * 92),
            opacity: 1 - min(max(abs(near) - 0.35, 0) / 3, 0.62),
            zIndex: 1000 - Int(min(abs(step), 99) * 100)
        ) {
            // TURNED, SIZED AND TIPPED IN ONE PLACE. `turn` is a turn about the
            // card's vertical axis drawn FLAT, which is the same picture on
            // every platform - `.rotationY` is the other reading, and every
            // platform projects that one through a camera of its own.
            $0.turn(away * 64)
                .scale(1.1 - min(abs(near), 1.6) * 0.2)
                .rotate(near * 3)
        }
    }

    /// A FAN: the card in the middle stands tallest and the ones beside it lean
    /// away and sink.
    private func fan(_ step: Double, _ room: Rect) -> Placement {
        let near = max(-2.6, min(2.6, step))

        return Placement(
            card(room, up: abs(near) * 16, across: near * 70),
            opacity: 1 - min(max(abs(near) - 0.35, 0) / 3.4, 0.5),
            zIndex: 1000 - Int(min(abs(step), 99) * 100)
        ) {
            $0.rotate(near * 6).scale(0.9 - min(abs(near), 2) * 0.1)
        }
    }

    /// A RING, which the scroller rotates - each card lying along the circle.
    private func ring(_ index: Int, _ count: Int, _ room: Rect) -> Placement {
        let angle = (Double(index) - at) / Double(max(count, 1)) * 2 * .pi
        let radius = min(room.width, room.height) / 2 - 56
        let along = angle * 180 / .pi + 90

        return Placement(
            card(room, up: -sin(angle) * radius, across: cos(angle) * radius)
        ) {
            $0.rotate(along).scale(0.52 + 0.16 * chosen(Double(index) - at))
        }
    }

    /// A ROW, side by side.
    private func row(_ step: Double, _ count: Int, _ room: Rect) -> Placement {
        let across = min(112, room.width / Double(max(count, 1)))

        return Placement(card(room, up: 0, across: step * across)) {
            $0.scale(0.58 + 0.16 * chosen(step))
        }
    }

    /// How much of "the chosen one" a card is: 1 in the middle, nothing a card
    /// away, and part way between while the run is moving - which is what makes
    /// the emphasis cross over rather than jump.
    private func chosen(_ step: Double) -> Double {
        max(0, 1 - abs(step))
    }

    /// A card's rectangle: always the same size, in the middle of the room and
    /// then moved by the arithmetic above.
    private func card(_ room: Rect, up: Double, across: Double) -> Rect {
        Rect(
            room.width / 2 + across - Self.width / 2,
            room.height / 2 + up - Self.height / 2,
            Self.width,
            Self.height)
    }

    var notes: Element? {
        VStack {
            Label("`PlacedLayout` hands the closure which card it is, how many "
                + "there are and the room it has, and takes back a `Placement`: "
                + "where the card goes, and how it is turned, scaled, faded and "
                + "stacked. That is the whole layout - a gallery, a fan, a ring "
                + "and a row here, all of them a few lines of arithmetic.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Swipe left or right to turn the run through the shape. It "
                + "settles on the card it is nearest, and `Back` and `Next` do "
                + "the same thing without the hand.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("What moves it is a SCROLLER laid over the cards with nothing "
                + "in it to see - one card per turn of its length. A finger "
                + "drag, a two-finger trackpad swipe and a mouse wheel are one "
                + "thing to a scroller and three different things to anything "
                + "else, so all three work and the platform's own snapping "
                + "settles the run on a card.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The cards are held still WHILE it moves - `.motion(.none)` - "
                + "because the arithmetic is re-answered on every report and a "
                + "card a fifth of a second behind the hand is a card that "
                + "lags. Changing the SHAPE is the other case: there the cards "
                + "fly to their new place, turn and size, because a placement "
                + "is a value like any other.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
