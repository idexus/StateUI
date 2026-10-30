// listing: PhaseLayoutSample
import StateUIFoundation
// listing: end
import StateUI

/// A layout of the author's own: a few lines of arithmetic say where each
/// card goes and how it is turned, and the host puts every card there on its
/// own frames.
struct PhaseLayoutSample: SampleContent, ExampleContent {
    static let id = "phaseLayout"
    static let title = "PhaseLayout"
    static let summary = "PhaseLayout puts each view where arithmetic of yours says - here, a ring seen from above."

    // listing: PhaseLayoutSample
    /// The cards: the gallery's groups, each its name and its picture as the
    /// home page shows it.
    static let cards: [Card] = [
        Card(name: "Layout", art: "cat_layout.png"),
        Card(name: "Phase Layout", art: "cat_phaselayout.png"),
        Card(name: "Styles", art: "cat_styles.png"),
        Card(name: "Shapes", art: "cat_shapes.png"),
        Card(name: "Media", art: "cat_media.png"),
        Card(name: "Navigation", art: "cat_navigation.png"),
        Card(name: "Date & time", art: "cat_datetime.png"),
        Card(name: "Fundamentals", art: "cat_fundamentals.png"),
        Card(name: "Animation", art: "cat_animation.png"),
        Card(name: "Gestures", art: "cat_gestures.png"),
    ]

    /// One card's face.
    struct Card {
        let name: String
        let art: String
    }

    /// What the ring places: every card, and a dot for each at the board's
    /// foot - one arithmetic for both, so the dots move with the cards.
    enum Piece: Hashable {
        case card(Int)
        case dot(Int)
    }

    static let pieces = cards.indices.map(Piece.card) + cards.indices.map(Piece.dot)

    /// How big the place a card stands in is - what the ring is worked out
    /// from - and how big the card is drawn in it.
    static let width = 176.0
    static let height = 248.0
    static let card = 0.8

    /// How far the eye stands from the ring's front, in radii: the nearer it
    /// stands, the smaller a card at the back is drawn.
    static let eye = 1.6

    /// How far below the horizon the front card stands, in card heights: the
    /// higher the eye above the ring, the more of the far cards it sees.
    static let above = 1.9

    /// How tall the whole ring stands, in card heights: the back card's top to
    /// the front card's foot.
    static var ringHeight: Double { above - back * (above - 1) }

    /// How big the card at the back is drawn, against the one at the front.
    static var back: Double { eye / (eye + 2) }

    /// HOW A THROW GOES ON - any motion: how far a throw carries, and the
    /// curve it slows on.
    enum Throwing: CaseIterable, Hashable {
        case easeOut, glide, spring, bounce, short

        var motion: Motion {
            switch self {
            case .easeOut: .eased(.milliseconds(400), .cubicOut)
            case .glide: .eased(.milliseconds(300), .sineOut)
            case .spring: .spring(response: .milliseconds(400), damping: 0.8)
            case .bounce: .eased(.milliseconds(600), .backOut)
            case .short: .eased(.milliseconds(200), .cubicOut)
            }
        }

        var title: String {
            switch self {
            case .easeOut: "Ease out"
            case .glide: "Glide"
            case .spring: "Spring"
            case .bounce: "Bounce"
            case .short: "Short"
            }
        }
    }

    /// Which of them the ring is thrown by.
    @State private var throwing = Throwing.easeOut

    /// Whether the board is laid out right to left, and whether the ring
    /// turns with it or keeps the shape its arithmetic writes.
    @State private var rightToLeft = false
    @State private var mirrored = true

    /// Whether each card follows its place as a body, lagging as the ring
    /// turns and swaying back onto it.
    @State private var swaying = false

    /// WHICH CARD IS AT THE FRONT - the phase, two-way: `Back` and `Next`
    /// write it and the ring travels there; the hand names the card it passes
    /// and the one it comes to rest on. It starts on the middle card, and it
    /// has no end: a turn on, it is the same card again.
    @State private var turn = Double(PhaseLayoutSample.cards.count / 2)

    /// The device - a phone's cards carry their names alone, smaller.
    @Environment(\.device) private var device
    // listing: end

    // The cards are turned by the hand over them, so the example is not put in
    // a scroller: the page's would claim the swipe before the ring heard it.
    // The words and the code scroll instead - see SampleContent.scrolls.
    static let scrolls = false

    // And it takes the whole cell: a ring wants the room, and the cards are
    // placed in whatever it is given.
    static let fills = true

    // listing: PhaseLayoutSample
    var body: some View {
        // A GRID rather than a stack: the board takes whatever room is left
        // over, which a stack cannot give a child - and a ring wants it all.
        Grid {
            Grid {
                // THE CARDS, and what moves them - the whole of the example.
                ring
            }
            .layoutDirection(rightToLeft ? .rightToLeft : .inherited)
            .gridRow(0)
            // The cards stay ON the board: one turned far out in a small room
            // is cut at the board's edge rather than painted over the page.
            .clipsContent(true)

            HStack {
                // The ring turns for no build at all: the label says so.
                DebugInfoLabel()
                    .margin(horizontal: 4, vertical: 0)

                Button("Back")
                    .margin(horizontal: 4, vertical: 0)
                    .onClicked { move(-1) }

                Button("Next")
                    .margin(horizontal: 4, vertical: 0)
                    .onClicked { move(1) }

            }
            .spacing(8)
            .horizontalAlignment(.center)
            .gridRow(1)

            Picker(Throwing.allCases, selection: $throwing) { $0.title }
                .horizontalAlignment(.center)
                .gridRow(2)

            HStack {
                SwitchRow("Right to left", $rightToLeft)

                SwitchRow("Mirrored", $mirrored)

                SwitchRow("Cards sway", $swaying)
            }
            .spacing(16)
            .horizontalAlignment(.center)
            .gridRow(3)
        }
        .rows(.fill, .auto, .auto, .auto)
        .rowSpacing(10)
    }

    /// The ring of cards and its dots, placed by the arithmetic below.
    private var ring: some View {
        PhaseLayout(Self.pieces, phase: $turn) { piece in
            switch piece {
            case .card(let index):
                // A BODY FOLLOWING ITS PLACE: carried by the ring, the card lags
                // behind as it turns, swings past where the turn stops and
                // settles back onto its place.
                if swaying {
                    face(Self.cards[index])
                        .physicsBody(.followsLayout(.spring(response: .milliseconds(420), damping: 0.55)))
                } else {
                    face(Self.cards[index])
                }
            case .dot:
                Rectangle()
                    .fill(Palette.text)
                    .cornerRadius(3)
            }
        } placements: { room, phase in
            // THE WHOLE LAYOUT, run on the display's own frames whenever the
            // room or the phase has moved, with no view built.
            Self.cards.indices.map { place($0, phase, room) }
                + Self.cards.indices.map { dot($0, phase, room) }
        }
        // THE HAND OVER THE CARDS: a finger or a pointer dragged, a trackpad's
        // two fingers and a wheel all turn the ring, carrying the card in
        // front with them, and let go with speed it goes on to the card
        // nearest where the throw would end. It rests on a card, never
        // between two - and comes round, a turn of the range bringing every
        // card back.
        .axis(
            \.self, input: .scroll(.horizontal, throwing: throwing.motion),
            range: 0...Double(Self.cards.count), snaps: .every(1), circular: true)
        // WHAT `shade` IN THE ARITHMETIC BELOW IS WORN BY: one view, drawn
        // over every card, wearing the card's own corners - which is why it is
        // the application's to give and not the library's to draw.
        .shade(
            Rectangle()
                .fill(Color(hex: 0x000000))
                .cornerRadius(16))
        .motion(.eased(.milliseconds(300), .cubicOut))
        // RIGHT TO LEFT, MIRRORED: the ring turns about the board's middle,
        // the arithmetic above still written left to right, and the hand turns
        // it the mirror's way. Not mirrored, it keeps the shape it is written in.
        .mirrorsRightToLeft(mirrored)
    }

    /// A card either way, from a button: the ring travels there, and the
    /// arithmetic follows it frame by frame - past the last card to the first.
    private func move(_ by: Int) {
        turn += Double(by)
    }

    /// One card's face - a picture and its name, and nothing at all about where
    /// the card is or which way it faces. That is the placement's, and keeping
    /// the two apart is what lets one run of cards be turned into any shape.
    private func face(_ card: Card) -> some View {
        let phone = device.info.formFactor == .phone

        return ZStack {
            Grid {
                Image(ImageSource(card.art))
                    .contentMode(.fill)

                VStack {
                    // ONE LINE, whatever the card's width: a caption that
                    // wrapped would change the picture's height with it.
                    Text(card.name)
                        .fontSize(phone ? 14 : 18)
                        .fontWeight(.bold)
                        .textColor(Palette.onBrand)
                        .lineBreak(.tailTruncation)

                    // A phone's small card carries its name alone.
                    if !phone {
                        Text("Placed by arithmetic")
                            .fontSize(10)
                            .textColor(Palette.onBrand)
                            .opacity(0.8)
                            .lineBreak(.tailTruncation)
                    }
                }
                .padding(horizontal: phone ? 10 : 12, vertical: phone ? 8 : 10)
                .spacing(1)
                // A dark strip under the words, so a caption reads over a
                // picture of any color.
                .background(Color(hex: 0x000000, opacity: 0.7))
                .verticalAlignment(.end)
            }
            // THE PICTURE IS CUT AT THE CARD'S EDGE: a picture told to FILL
            // the card is cut at its own room - the Web's reaches two points
            // past it - so the grid holding it - a layout, with edges to cut
            // at - cuts it there.
            .clipsContent(true)
        }
        .style(.card)
        .lineWidth(0)
        .shape(.roundedRectangle(16))
    }

    /// How big the cards are in THIS room, as a multiple of the size above -
    /// what every distance below scales with.
    ///
    /// BOTH AXES: the ring spread to either side takes the room's width, and
    /// the ring seen from above - the back card's top to the front card's foot
    /// - its height above the dots; the smaller of the two answers, so a
    /// window grown taller draws a bigger ring and a phone on its side -
    /// plenty of width, almost no height - is answered by the height.
    private func fit(in room: Rect) -> Double {
        max(
            min(
                1.375,
                (room.width * 0.4 - 6) / Self.width,
                (room.height - 46) / (Self.height * Self.ringHeight)),
            0.1)
    }

    /// A RING IN SPACE, turned to `at` - the cards standing upright on a
    /// circle that lies flat, seen from in front and above, the chosen card
    /// nearest the eye. The whole of the layout.
    private func place(_ index: Int, _ at: Double, _ room: Rect) -> Placement {
        let count = Self.cards.count
        let fit = fit(in: room)
        let step = Double(index) - at
        let angle = step / Double(max(count, 1)) * 2 * .pi
        let wide = Self.width * fit
        let tall = Self.height * fit

        // PERSPECTIVE: how big a card is drawn - 1 at the front, under half at
        // the back - which also says how near the middle it stands and how far
        // below the horizon its foot is.
        let drawn = Self.eye / (Self.eye + 1 - cos(angle))

        // The circle as wide as the room lets the cards spread, and the horizon
        // where the whole ring - the back card's top to the front card's foot -
        // stands in the middle of the room above the dots.
        let radius = min(wide * 1.75, (room.width / 2 - 8 - wide * 0.33) / 0.65)
        let horizon = (room.height - 30 - tall * Self.ringHeight) / 2 - tall * Self.back * (Self.above - 1)
        let across = room.width / 2 + sin(angle) * radius * drawn
        let foot = horizon + tall * Self.above * drawn

        // THE CARD AT ITS OWN SIZE, a little smaller than its place, standing
        // on the ring where its place does.
        let (cardWide, cardTall) = (wide * Self.card, tall * Self.card)

        return Placement(
            // Scaled about its middle to how big it is drawn - its words scale
            // with it rather than wrapping anew.
            Rect(across - cardWide / 2, foot - cardTall * drawn / 2 - cardTall / 2, cardWide, cardTall),
            transform: .scale(drawn),
            // THE FAR CARDS DARKEN. `shade` is the opacity of the view the
            // layout was given by `.shade(_:)` - nothing at all without one -
            // and here it is how far back the card stands. A FADE would show
            // the card behind it, which on a ring is every other card.
            shade: min((1 - drawn) * 1.1, 0.55),
            // The nearer card is drawn over the farther one.
            zIndex: Int(cos(angle) * 1000))
    }

    /// One dot at the board's foot, saying which card is at the front by a
    /// fade - over every card.
    private func dot(_ index: Int, _ at: Double, _ room: Rect) -> Placement {
        let count = Self.cards.count

        return Placement(
            Rect(
                room.width / 2 + (Double(index) - Double(count - 1) / 2) * 13 - 3,
                room.height - 16,
                6,
                6),
            // THE RING COMES ROUND: how far a card is from the front is taken
            // the short way, a turn on or back.
            opacity: 0.25 + 0.75 * chosen((Double(index) - at).remainder(dividingBy: Double(count))),
            zIndex: 2000)
    }

    /// How much of "the chosen one" a card is: 1 at the front, nothing a card
    /// away, and part way between while the ring is moving - which is what
    /// makes the emphasis cross over rather than jump.
    private func chosen(_ step: Double) -> Double {
        max(0, 1 - abs(step))
    }

    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`PhaseLayout` builds one view per item from its closure, and its "
                + "arithmetic answers a `Placement` for each - where it goes, and how it is "
                + "turned, scaled, faded, shaded and stacked - from the room it was given and "
                + "its phase. That is the whole layout: the ring standing in space, seen from "
                + "above - a card farther round drawn smaller, higher and darker, the chosen one "
                + "nearest - and its dots are a few lines of arithmetic. `GalleryView`, under "
                + "Items and Cards, is the same "
                + "layout with the arithmetic for a wheel, a fan, a row and a deck already written.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Swipe, drag or scroll left or right to turn the ring - a finger, the "
                + "pointer, a trackpad's two fingers and a wheel are one hand to it, carrying "
                + "the card in front with them however big the window makes the ring. Let go "
                + "still, it rests on the card it is nearest; let go with speed, it goes on to "
                + "the card nearest where the throw would end, in one movement. It has no "
                + "end: past the last card is the first again. `Back` and `Next` send it "
                + "there without the hand - the phase itself travels, under the layout's "
                + "`.motion`. The phase, `phase: $turn`, is the card at the front; "
                + "`.axis(\\.self, input: .scroll(…), range:, snaps: .every(1), circular: true)` gives "
                + "it to the hand, resting on a card and coming round. The picker changes how a throw goes "
                + "on - `.scroll(…, throwing:)` takes any motion: eased, its length says how far a "
                + "throw carries and its curve how it slows; a spring settles as springs do.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Nothing that turns the ring is read in the body. The arithmetic runs on "
                + "the display's own frames whenever the room or the phase has moved, and the "
                + "host wears the placements straight onto the cards, so the ring turns with "
                + "no view built.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
