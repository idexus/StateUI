import Foundation
import StateUI

/// A layout of the author's own: one line of arithmetic says where each card
/// goes and how it is turned, and every card travels there.
struct PlacedSample: SampleContent {
    static let id = "placed"
    static let title = "A layout of your own"
    static let summary = "PlacedLayout hands you the index, the count and the room, and takes back where a view goes and how it is turned - here a RING the cards stand on. Swipe or take hold of them to turn it, with nothing described as it moves."

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

    /// How far the hand travels to turn the ring by one card, in device units.
    static let reach = 90.0

    /// How big a card is.
    static let width = 176.0
    static let height = 248.0

    /// How far the run has been SCROLLED, and how far it has been DRAGGED -
    /// neither of them state, so neither describes anything when it moves.
    /// The arithmetic below reads both and the host runs it on its own frames.
    @Channel private var scrolled = Double(PlacedSample.cards.count / 2)
        * PlacedSample.reach

    @Channel private var dragged = 0.0

    /// Whether the ring is turned by DRAGGING it rather than by scrolling. Both
    /// move the same arithmetic; a scroller cannot be laid over a view that is
    /// to be taken hold of, so the two swap places.
    @State private var grabbing = false

    @State private var scroller = ControlState<ScrollView>()

    /// Whether the run has been put on the card it opens on. A scroller
    /// cannot be moved before its content is laid out - asked earlier it
    /// clamps to the length it has so far - so the opening aim below keeps
    /// asking until the card it was aimed at is where it was sent, and this
    /// closes it.
    @State private var opened = false

    /// Where the aim sends a fresh scroller, in device units. The middle card
    /// at the first opening, and the card the ring STOOD ON at a handover -
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

    // And it takes the whole cell: a ring wants the room, and the cards are
    // placed in whatever it is given.
    static let fills = true

    /// How far the ring is turned, in CARDS - a whole number at rest and
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
        // but a hand can - so the arithmetic is what holds the ring to its
        // cards.
        guard turned.isFinite else { return 0 }

        return min(max(turned, 0), Double(Self.cards.count - 1))
    }

    static let code = """
        // NOT STATE. A scroller's offset moves many times a second, and a view
        // rebuilt for each of them is a view that lags. A channel is read and
        // written without the interface being described again - so nothing
        // here is rebuilt while the ring turns.
        @Channel private var scrolled = 270.0
        @Channel private var dragged = 0.0

        // WHAT MOVES IT. A ScrollReader lays an empty scroller over the cards
        // and writes its offset into the value; `.panX` writes a drag into
        // one instead, for a ring that is taken hold of rather than scrolled.
        ScrollReader(across: Double(cards.count - 1) * 90) {
            ring
        }
        .scrollX($scrolled)
        .snapInterval(90)

        // THE WHOLE LAYOUT IS THIS CLOSURE, and `following` says which values
        // moving asks for it again. It READS them by name - reading one
        // records nothing - so the host runs this same arithmetic on its own
        // frames and writes the answers straight onto the cards.
        var ring: Element {
            PlacedLayout(cards, id: \\.name, following: $scrolled, $dragged) {
                index, count, room in

                // THE CARD FITS THE ROOM - at most half its width, within its
                // height - and every distance scales with it.
                let fit = min(1, room.width * 0.5 / 176, room.height / 288)
                // A hand has no ends the way a scroller does, so the
                // arithmetic holds the ring to its cards.
                let at = min(max((scrolled - dragged) / 90, 0), 6)

                // A RING: each card stands at its own angle on the circle and
                // lies ALONG it, and the one at the front is the largest.
                let angle = (Double(index) - at) / Double(count) * 2 * .pi
                let radius = min(room.width, room.height) / 2 - 56 * fit
                let near = max(0, 1 - abs(Double(index) - at))

                return Placement(
                    Rect(
                        room.width / 2 + cos(angle) * radius - 88 * fit,
                        room.height / 2 - sin(angle) * radius - 124 * fit,
                        176 * fit,
                        248 * fit),
                    transform: .rotate(angle * 180 / .pi + 90)
                        .scale(0.52 + 0.16 * near),
                    // THE FAR CARDS DARKEN rather than fade: a fade would show
                    // the card behind, which on a ring is every other card.
                    // `shade` is the opacity of the view given below.
                    shade: min(abs(Double(index) - at) / 3, 0.55),
                    zIndex: 1000 - Int(min(abs(Double(index) - at), 99) * 100))
            } content: { card in
                // A picture and its name, and nothing at all about where the
                // card is or which way it faces. That is the placement's.
                face(card)
            }
            // One view, drawn over every card and wearing the card's own
            // corners - which is why it is the application's to give.
            .shade(BoxView(Color("#000000")).cornerRadius(16))
            // A PLACEMENT WORKED OUT FROM SOMETHING THE READER IS MOVING DOES
            // NOT TRAVEL: the arithmetic is re-answered on every report, and a
            // card a fifth of a second behind the hand is a card that lags.
            .motion(.none)
        }
        """

    var content: Element {
        // A GRID rather than a stack: the board takes whatever room is left
        // over, which a stack cannot give a child - and a ring wants it all.
        Grid {
            Grid {
                // THE BOARD, under everything.
                BoxView(Palette.raised)
                    .cornerRadius(14)

                // THE CARDS, and what moves them - the whole of the example.
                // Nothing here is described again while the ring turns: the
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
                    // settles the ring on the card it is nearest.
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

                // WHICH CARD IS AT THE FRONT, said by a fade - a second layout
                // following the SAME two values, drawn over the board's foot
                // and taking no touches. Inside the board rather than in a row
                // of its own, because a phone on its side has no height to
                // spare for one.
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
            // The cards stay ON the board: one turned far out in a small room
            // is cut at the board's edge rather than painted over the page.
            .isClippedToBounds(true)

            // ONE ROW THAT WRAPS: a phone held upright folds it into two
            // lines, and a phone on its side - which has no height to spare -
            // keeps it on one.
            FlexLayout {
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
                            // comes next starts from where the ring stands -
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

    /// The ring of cards, placed by the arithmetic below - the same views
    /// whichever way the reader turns them.
    private var cards: Element {
        PlacedLayout(Self.cards, id: \.name, following: $scrolled, $dragged, at: ring) { card in
            face(card)
        }
        // WHAT `shade` IN THE ARITHMETIC ABOVE IS WORN BY: one view, drawn over
        // every card, wearing the card's own corners - which is why it is the
        // application's to give and not the library's to draw.
        .shade(BoxView(Color("#000000")).cornerRadius(16))
        // A PLACEMENT WORKED OUT FROM SOMETHING THE READER IS MOVING DOES NOT
        // TRAVEL: the arithmetic is re-answered on every report, and a card a
        // fifth of a second behind the hand is a card that lags.
        .motion(.none)
    }

    /// A card either way, from a button: the scroller is what moves, so this
    /// asks it to glide and the arithmetic follows it frame by frame.
    private func move(_ by: Int) async throws {
        let slot = max(0, min(Double(Self.cards.count - 1), (at + Double(by)).rounded()))

        try await scroller.scrollTo(x: slot * Self.reach, y: 0)
    }

    /// One card's face - a picture and its name, and nothing at all about where
    /// the card is or which way it faces. That is the placement's, and keeping
    /// the two apart is what lets one run of cards be turned into any shape.
    private func face(_ card: Card) -> Element {
        Border {
            Grid {
                Image(ImageSource(card.art))
                    .aspect(.aspectFill)

                VStack {
                    // ONE LINE, whatever the card's width: a caption that
                    // wrapped would change the picture's height with it.
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

    /// How big the cards are in THIS room, as a multiple of the size above -
    /// what every distance below scales with.
    ///
    /// BOTH AXES: a card takes at most half the room's width and stands within
    /// its height, and the smaller of the two answers, so a window grown
    /// taller draws a bigger ring and a phone on its side - plenty of width,
    /// almost no height - is answered by the height.
    private func fit(in room: Rect) -> Double {
        min(
            1.375,
            max(room.width, 1) * 0.5 / Self.width,
            max(room.height, 1) / (Self.height * 1.16))
    }

    /// A RING, which the scroller rotates - each card lying along the circle,
    /// the one at the front largest. The whole of the layout.
    private func ring(_ index: Int, _ count: Int, _ room: Rect) -> Placement {
        let fit = fit(in: room)
        let step = Double(index) - at
        let angle = step / Double(max(count, 1)) * 2 * .pi
        let radius = min(room.width, room.height) / 2 - 56 * fit
        let along = angle * 180 / .pi + 90

        return Placement(
            card(room, up: -sin(angle) * radius, across: cos(angle) * radius, fit: fit),
            transform: .rotate(along).scale(0.52 + 0.16 * chosen(step)),
            // THE FAR CARDS DARKEN. `shade` is the opacity of the view the
            // layout was given by `.shade(_:)` - nothing at all without one -
            // and here it is how far round the ring the card has gone. A FADE
            // would show the card behind it, which on a ring is every other
            // card.
            shade: min(abs(step) / 3, 0.55),
            zIndex: 1000 - Int(min(abs(step), 99) * 100))
    }

    /// How much of "the chosen one" a card is: 1 at the front, nothing a card
    /// away, and part way between while the ring is moving - which is what
    /// makes the emphasis cross over rather than jump.
    private func chosen(_ step: Double) -> Double {
        max(0, 1 - abs(step))
    }

    /// A card's rectangle: the same size wherever it stands, in the middle of
    /// the room and then moved onto the circle by the arithmetic above.
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
                + "stacked. That is the whole layout - this one is a ring, in "
                + "six lines of arithmetic.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Swipe left or right to turn the ring. It settles on the "
                + "card it is nearest, and `Back` and `Next` do the same thing "
                + "without the hand. Turn the switch on and the cards are "
                + "TAKEN HOLD OF instead: drag them and the ring follows the "
                + "finger, with no scroller over them at all.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Neither of the two numbers is state. A `@Channel` is read "
                + "and written without the interface being described again, "
                + "and `following:` says which of them moving asks for the "
                + "arithmetic once more - so the whole ring turns with no view "
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
                + "else, so all three turn the ring.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The ring keeps its card through a change of geometry: turn "
                + "the phone, resize the window, and the same card is back at "
                + "the front once the room settles.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("A view CANNOT show a channel, and that is the trade: "
                + "nothing tells the tree it moved, so a label written from it "
                + "would be built once and never again. What follows one is "
                + "the PLACEMENT - where a card goes, how it is turned, how "
                + "opaque it is - which is why the cards shrink as they go "
                + "round the back and no view here is rebuilt to do it.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("A run of cards in the shapes a reader expects - a wheel, a "
                + "fan, a row - is `GalleryView` under Collections, which is "
                + "this same layout with the arithmetic already written.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
