import Foundation
import StateUI

/// A layout of the author's own: one line of arithmetic says where each card
/// goes and how it is turned, and every card travels there.
struct PlacedSample: SampleContent {
    static let id = "placed"
    static let title = "A layout of your own"
    static let summary = "PlacedLayout hands you the index, the count and the room, and takes back where a view goes and how it is turned - a gallery, a fan, a ring or a row. Swipe or take hold of the cards to turn the run through it, with nothing described as it moves."

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

    /// How far the run has been SCROLLED, and how far it has been DRAGGED -
    /// neither of them state, so neither describes anything when it moves.
    /// The arithmetic below reads both and the host runs it on its own frames.
    @Channel private var scrolled = Double(PlacedSample.cards.count / 2)
        * PlacedSample.reach

    @Channel private var dragged = 0.0

    /// Whether the run is turned by DRAGGING it rather than by scrolling. Both
    /// move the same arithmetic; a scroller cannot be laid over a view that is
    /// to be taken hold of, so the two swap places.
    @State private var grabbing = false

    @State private var scroller = ControlState<ScrollView>()

    /// Whether the cards are TRAVELLING rather than following the scroller -
    /// true for as long as one flight between shapes lasts.
    @State private var flying = false

    /// Whether the run has been put on the card it opens on. A scroller
    /// cannot be moved before its content is laid out - asked earlier it
    /// clamps to the length it has so far - so the opening aim below keeps
    /// asking until the card it was aimed at is where it was sent, and this
    /// closes it.
    @State private var opened = false

    /// Where the aim sends a fresh scroller, in device units. The middle card
    /// at the first opening, and the card the run STOOD ON at a handover -
    /// held apart from the channel, whose value a scroller being built can
    /// briefly stomp with the clamps of its first layout.
    @State private var aim = Double(PlacedSample.cards.count / 2) * PlacedSample.reach

    /// How long the scroller's content was when it last reported - the aim
    /// runs when this changes, which is when a jump can finally land.
    @State private var length = 0.0

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
        // A DRAG COUNTS THE OTHER WAY: a scroller's offset grows as the run
        // moves left, and a finger going left reports a negative distance.
        let turned = (scrolled - dragged) / Self.reach

        // AND A DRAG HAS NO ENDS: a scroller cannot be pulled past its length,
        // but a hand can - so the arithmetic is what holds the run to its
        // cards.
        guard turned.isFinite else { return 0 }

        return min(max(turned, 0), Double(Self.cards.count - 1))
    }

    static let code = """
        // NOT STATE. A scroller's offset moves many times a second, and a view
        // rebuilt for each of them is a view that lags. A channel is read and
        // written without the interface being described again - so nothing
        // here is rebuilt while the run moves.
        @Channel private var scrolled = 270.0
        @Channel private var dragged = 0.0

        // WHAT MOVES IT. A ScrollReader lays an empty scroller over the cards
        // and writes its offset into the value; `.panX` writes a drag into
        // one instead, for a run that is taken hold of rather than scrolled.
        ScrollReader(across: Double(cards.count - 1) * 90) {
            cards
        }
        .scrollX($scrolled)
        .snapInterval(90)

        // THE WHOLE LAYOUT IS THIS CLOSURE, and `following` says which values
        // moving asks for it again. It READS them by name - reading one
        // records nothing - so the host runs this same arithmetic on its own
        // frames and writes the answers straight onto the cards.
        var cards: Element {
            PlacedLayout(cards, id: \\.name, following: $scrolled, $dragged) {
                index, count, room in

                // THE CARD FITS THE ROOM - at most half its width, within its
                // height - and every distance scales with it.
                let fit = min(1, room.width * 0.5 / 176, room.height / 288)
                // A hand has no ends the way a scroller does, so the
                // arithmetic holds the run to its cards.
                let at = min(max((scrolled - dragged) / 90, 0), 6)
                let step = Double(index) - at
                let near = max(-2.4, min(2.4, step))
                let away = min(abs(near), 1.55) / 1.55

                // ONE TRANSFORM, about the card's own centre, and the same
                // picture on every platform. `turn` is a turn about the
                // vertical axis drawn FLAT; `.rotationY` is the other reading,
                // which every platform projects through a camera of its own.
                return Placement(
                    Rect(
                        room.width / 2 + near * 92 * fit - 88 * fit,
                        room.height / 2 - 124 * fit,
                        176 * fit,
                        248 * fit),
                    transform: .turn(away * 64)
                        .scale(1.1 - min(abs(near), 1.6) * 0.2)
                        .rotate(near * 3),
                    opacity: 1 - min(max(abs(near) - 0.35, 0) / 3, 0.62),
                    zIndex: 1000 - Int(min(abs(step), 99) * 100))
            } content: { card in
                CardFace(card)
            }
            // A PLACEMENT WORKED OUT FROM SOMETHING THE READER IS MOVING DOES
            // NOT TRAVEL: the arithmetic is re-answered on every report, and a
            // card a fifth of a second behind the hand is a card that lags.
            .motion(.none)
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

                // THE CARDS, and what moves them - the whole of the example.
                // Nothing here is described again while the run moves: the
                // arithmetic READS two continuous values, the host runs it on
                // its own frames, and the numbers land on the cards.
                if grabbing {
                    // TAKEN HOLD OF: the drag is written into a value, and a
                    // scroller is not laid over the cards at all - a scroller
                    // claims a drag before anything under it hears about one.
                    Grid {
                        cards
                    }
                    .panX($dragged)
                } else {
                    // SCROLLED: an empty scroller lies over the cards and its
                    // offset is the value. A finger drag, a two-finger
                    // trackpad swipe and a mouse wheel are ONE thing to a
                    // scroller and three different things to anything else.
                    ScrollReader(across: Double(Self.cards.count - 1) * Self.reach) {
                        cards
                    }
                    .scrollX($scrolled)
                    // ONE CARD PER `reach`, so the platform's own snapping
                    // settles the run on the card it is nearest.
                    .snapInterval(Self.reach)
                    .assign(scroller)
                    // THE OPENING AIM: a scroller cannot be moved before its
                    // content is laid out - asked earlier it clamps to the
                    // length it has so far - so this asks again until the
                    // middle card is where it was sent.
                    .onFrameChanged { frame in
                        guard !opened, frame.width != length else { return }

                        length = frame.width

                        let sendTo = aim
                        var asks = 0

                        repeat {
                            try await scroller.scrollTo(x: sendTo, y: 0, animated: false)
                            try await Task.sleep(for: .milliseconds(100))
                            asks += 1
                        } while abs(scrolled - sendTo) > 1 && asks < 10

                        opened = abs(scrolled - sendTo) <= 1
                    }
                }

                // WHICH CARD IS IN THE MIDDLE, said by a fade - a second
                // layout following the SAME two values, drawn over the board's
                // foot and taking no touches. Inside the board rather than in
                // a row of its own, because a phone on its side has no height
                // to spare for one.
                PlacedLayout(Self.cards, id: \.name, following: $scrolled, $dragged) {
                    index, count, room in

                    Placement(
                        Rect(
                            room.width / 2
                                + (Double(index) - Double(count - 1) / 2) * 13 - 3,
                            room.height - 16,
                            6,
                            6),
                        opacity: 0.25 + 0.75 * chosen(Double(index) - at))
                } content: { _ in
                    BoxView(Palette.text)
                        .cornerRadius(3)
                }
                .motion(.none)
                .inputTransparent(true)
            }
            .gridRow(0)
            // The cards stay ON the board: one mid-flight between two shapes,
            // or turned far out in a small room, is cut at the board's edge
            // rather than painted over the page.
            .isClippedToBounds(true)

            // ONE ROW THAT WRAPS: a phone held upright folds it into two
            // lines, and a phone on its side - which has no height to spare -
            // keeps it on one.
            FlexLayout {
                // ONE WIDTH FOR EVERY CAPTION: a wrapping row re-measures a
                // child on its own schedule, and a caption that changed inside
                // one was drawn cut short until something else made it measure
                // again. The widest caption's width holds still.
                Button(Self.shapes[shape])
                    .widthRequest(96)
                    .margin(4, 0)
                    .onClicked { try await reshape() }

                Button("Back")
                    .margin(4, 0)
                    .isEnabled(!grabbing)
                    .onClicked { try await move(-1) }

                Button("Next")
                    .margin(4, 0)
                    .isEnabled(!grabbing)
                    .onClicked { try await move(1) }

                SwitchRow(
                    "Turn by dragging",
                    Binding(
                        get: { grabbing },
                        set: { taking in
                            // ONE NUMBER AT EACH HANDOVER: the two values are
                            // folded into the scroll alone, so whichever input
                            // comes next starts from where the run stands -
                            // and the scroller, built afresh by the swap,
                            // is aimed at that card again by the opening aim.
                            let standing = at.rounded() * Self.reach

                            dragged = 0
                            scrolled = standing
                            aim = standing
                            opened = taking
                            grabbing = taking
                        }))
                    .margin(4, 0)
            }
            .direction(.row)
            .wrap(.wrap)
            .justifyContent(.center)
            .alignItems(.center)
            .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(10)
    }

    /// The run of cards, placed by the arithmetic below - the same views
    /// whichever way the reader moves them.
    private var cards: Element {
        PlacedLayout(Self.cards, id: \.name, following: $scrolled, $dragged, at: place) { card in
            face(card)
        }
        // A PLACEMENT WORKED OUT FROM SOMETHING THE READER IS MOVING DOES NOT
        // TRAVEL: the arithmetic is re-answered on every report, and a card a
        // fifth of a second behind the hand is a card that lags. A change of
        // SHAPE is the other case, and the only one where these do travel.
        .motion(flying ? .inherited : .none)
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

    /// How far this card stands from the middle, as the arithmetic counts it -
    /// what the dots and the scrim below are both written from.
    private func step(_ card: Card) -> Double {
        guard let index = Self.cards.firstIndex(where: { $0.name == card.name }) else {
            return 99
        }

        return Double(index) - at
    }

    /// How lit one card's dot is: full for the one in the middle, faint for the
    /// rest, and part way for either side of a run being turned.
    private func dot(_ card: Card) -> Double {
        0.25 + 0.75 * chosen(step(card))
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

    /// How much of the classic card this room can afford: all of it where
    /// there is space to spare, and less on a phone - the card takes at most
    /// half the room's width, and every distance in the shapes below scales
    /// with it, so a narrow window shows the same gallery smaller rather than
    /// three slivers of the full-size one. BOTH AXES: a phone on its side
    /// hands this board plenty of width and almost no height, and a card
    /// sized by width alone would paint far outside it.
    private func fit(in room: Rect) -> Double {
        min(
            1,
            room.width * 0.5 / Self.width,
            max(room.height, 1) / (Self.height + 40))
    }

    /// Where one card goes and how it is turned - the whole of the layout.
    ///
    /// A CARD IS ONE SIZE in every shape, and how big it LOOKS is the
    /// transform's. Sizing by the rectangle instead would put the run through a
    /// change of size as well as of place at every switch, which is two
    /// journeys where one will do.
    private func place(_ index: Int, _ count: Int, _ room: Rect) -> Placement {
        let step = Double(index) - at
        let fit = fit(in: room)

        switch shape {
        case 1:
            return fan(step, room, fit)

        case 2:
            return ring(index, count, room, fit)

        case 3:
            return row(step, count, room, fit)

        default:
            return gallery(step, room, fit)
        }
    }

    /// A GALLERY: the cards stand on a wheel, the one in the middle facing the
    /// reader and the rest turning away, shrinking and fading behind it.
    private func gallery(_ step: Double, _ room: Rect, _ fit: Double) -> Placement {
        let near = max(-2.4, min(2.4, step))
        let away = min(abs(near), 1.55) / 1.55

        // TURNED, SIZED AND TIPPED IN ONE PLACE. `turn` is a turn about the
        // card's vertical axis drawn FLAT, which is the same picture on every
        // platform - `.rotationY` is the other reading, and every platform
        // projects that one through a camera of its own.
        return Placement(
            card(room, up: 0, across: near * 92 * fit, fit: fit),
            transform: .turn(away * 64)
                .scale(1.1 - min(abs(near), 1.6) * 0.2)
                .rotate(near * 3),
            opacity: 1 - min(max(abs(near) - 0.35, 0) / 3, 0.62),
            zIndex: 1000 - Int(min(abs(step), 99) * 100))
    }

    /// A FAN: the card in the middle stands tallest and the ones beside it lean
    /// away and sink.
    private func fan(_ step: Double, _ room: Rect, _ fit: Double) -> Placement {
        let near = max(-2.6, min(2.6, step))

        return Placement(
            card(room, up: abs(near) * 16 * fit, across: near * 70 * fit, fit: fit),
            transform: .rotate(near * 6).scale(0.9 - min(abs(near), 2) * 0.1),
            opacity: 1 - min(max(abs(near) - 0.35, 0) / 3.4, 0.5),
            zIndex: 1000 - Int(min(abs(step), 99) * 100))
    }

    /// A RING, which the scroller rotates - each card lying along the circle.
    private func ring(_ index: Int, _ count: Int, _ room: Rect, _ fit: Double) -> Placement {
        let angle = (Double(index) - at) / Double(max(count, 1)) * 2 * .pi
        let radius = min(room.width, room.height) / 2 - 56 * fit
        let along = angle * 180 / .pi + 90

        return Placement(
            card(room, up: -sin(angle) * radius, across: cos(angle) * radius, fit: fit),
            transform: .rotate(along)
                .scale(0.52 + 0.16 * chosen(Double(index) - at)),
            zIndex: 1000 - Int(min(abs(Double(index) - at), 99) * 100))
    }

    /// A ROW, side by side.
    private func row(_ step: Double, _ count: Int, _ room: Rect, _ fit: Double) -> Placement {
        let across = min(112 * fit, room.width / Double(max(count, 1)))

        return Placement(
            card(room, up: 0, across: step * across, fit: fit),
            transform: .scale(0.58 + 0.16 * chosen(step)),
            zIndex: 1000 - Int(min(abs(step), 99) * 100))
    }

    /// How much of "the chosen one" a card is: 1 in the middle, nothing a card
    /// away, and part way between while the run is moving - which is what makes
    /// the emphasis cross over rather than jump.
    private func chosen(_ step: Double) -> Double {
        max(0, 1 - abs(step))
    }

    /// A card's rectangle: the same size in every shape, in the middle of the
    /// room and then moved by the arithmetic above.
    private func card(_ room: Rect, up: Double, across: Double, fit: Double) -> Rect {
        Rect(
            room.width / 2 + across - Self.width * fit / 2,
            room.height / 2 + up - Self.height * fit / 2,
            Self.width * fit,
            Self.height * fit)
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
                + "the same thing without the hand. Turn the switch on and the "
                + "cards are TAKEN HOLD OF instead: drag them and the run "
                + "follows the finger, with no scroller over them at all.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Neither of the two numbers is state. A `@Channel` is read "
                + "and written without the interface being described again, "
                + "and `following:` says which of them moving asks for the "
                + "arithmetic once more - so the whole run moves with no view "
                + "built, nothing compared and no message sent. The dots below "
                + "the board are a second layout following the same two "
                + "values.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("What lays the scroller over the cards is a `ScrollReader`: "
                + "an empty scroller as long as the room plus how far the run "
                + "goes beyond it, writing its offset into the value. A finger "
                + "drag, a two-finger trackpad swipe and a mouse wheel are one "
                + "thing to a scroller and three different things to anything "
                + "else, so all three move the run.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The run keeps its card through a change of geometry: turn "
                + "the phone, resize the window, and the same card is back in "
                + "the middle once the room settles.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("A view CANNOT show a channel, and that is the trade: "
                + "nothing tells the tree it moved, so a label written from it "
                + "would be built once and never again. What follows one is "
                + "the PLACEMENT - where a card goes, how it is turned, how "
                + "opaque it is - which is why the cards recede as they leave "
                + "the middle and no view here is rebuilt to do it.")
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
