// listing: LayoutEngineSample
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#elseif canImport(WASILibc)
import WASILibc
#endif
// listing: end
import StateUI

/// A layout of the author's own: a few lines of arithmetic say where each
/// card goes and how it is turned, and the host puts every card there on its
/// own frames.
struct LayoutEngineSample: SampleContent, ExampleContent {
    static let id = "layoutEngine"
    static let title = "LayoutEngine"
    static let summary = "LayoutEngine puts each view where arithmetic of yours says - here, cards on a ring."

    // listing: LayoutEngineSample
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

    /// What the ring places: every card, and a dot for each at the board's
    /// foot - one arithmetic for both, so the dots move with the cards.
    enum Piece: Hashable {
        case card(Int)
        case dot(Int)
    }

    static let pieces = cards.indices.map(Piece.card) + cards.indices.map(Piece.dot)

    /// How far the hand travels to turn the ring by one card, in device units.
    static let reach = 90.0

    /// How big a card is.
    static let width = 176.0
    static let height = 248.0

    /// Whether the ring is turned by DRAGGING it rather than by scrolling. Both
    /// move the same arithmetic; a scroller cannot be laid over a view that is
    /// to be taken hold of, so the two swap places.
    @State private var grabbing = false

    /// WHICH CARD IS AT THE FRONT - the phase, two-way: `Back` and `Next`
    /// write it and the ring travels there; a swipe names the card it passes
    /// and the one it comes to rest on. It starts on the middle card.
    @State private var turn = Double(LayoutEngineSample.cards.count / 2)

    /// How far the cards have been DRAGGED, handed on with `$`, so it describes
    /// nothing when it moves: the arithmetic follows it on the host's frames.
    @State private var dragged = 0.0
    // listing: end

    // The cards are turned by a scroller of their own, so the example is not
    // put in a second one: the page's scroller would claim the swipe before it
    // heard about one. The words and the code scroll instead - see
    // SampleContent.scrolls.
    static let scrolls = false

    // And it takes the whole cell: a ring wants the room, and the cards are
    // placed in whatever it is given.
    static let fills = true

    // listing: LayoutEngineSample
    var body: some View {
        // A GRID rather than a stack: the board takes whatever room is left
        // over, which a stack cannot give a child - and a ring wants it all.
        Grid {
            Grid {
                // THE BOARD, under everything.
                Rectangle(Palette.raised)
                    .cornerRadius(14)

                // THE CARDS, and what moves them - the whole of the example.
                ring
            }
            .gridRow(0)
            // The cards stay ON the board: one turned far out in a small room
            // is cut at the board's edge rather than painted over the page.
            .clipsContent(true)

            HStack {
                // INSIDE these braces, because that is where `grabbing` is
                // read: the switch below is the only thing here a build
                // depends on, and the ring itself turns for no build at all.
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

            SwitchRow(
                "Turn by panning",
                Binding(
                    get: { grabbing },
                    set: { taking in
                        // ONE NUMBER AT EACH HANDOVER: the drag is folded
                        // into the phase, so whichever input comes next
                        // starts from the card the ring stands nearest - the
                        // scroller, built afresh by the swap, included.
                        turn = turned(turn).rounded()
                        dragged = 0
                        grabbing = taking
                    }))
            .horizontalAlignment(.center)
            .gridRow(2)
        }
        .rows(.fill, .auto, .auto)
        .rowSpacing(10)
    }

    /// The ring of cards and its dots, placed by the arithmetic below - the
    /// same views whichever way the user turns them.
    @ViewBuilder
    private var ring: some View {
        let layout = LayoutEngine(Self.pieces) { piece in
            switch piece {
            case .card(let index):
                face(Self.cards[index])
            case .dot:
                Rectangle(Palette.text)
                    .cornerRadius(3)
            }
        } placements: { room, phase in
            // THE WHOLE LAYOUT, run on the display's own frames whenever the
            // room, the phase or the drag has moved, with no view built.
            let at = turned(phase)

            return Self.cards.indices.map { place($0, at, room) }
                + Self.cards.indices.map { dot($0, at, room) }
        }
        .phase($turn)
        // WHERE THE RING MAY COME TO REST: on a card, never between two.
        .snapTargets(Self.cards.indices.map(Double.init))
        .following($dragged)
        // WHAT `shade` IN THE ARITHMETIC BELOW IS WORN BY: one view, drawn
        // over every card, wearing the card's own corners - which is why it is
        // the application's to give and not the library's to draw.
        .shade(Rectangle(Color("#000000")).cornerRadius(16))
        .motion(.eased(.milliseconds(300), .cubicOut))

        if grabbing {
            // TAKEN HOLD OF: the drag is written into a value, and no scroller
            // is laid over the cards - a scroller claims a drag before
            // anything under it hears about one.
            layout.panX($dragged)
        } else {
            // SCROLLED: an empty scroller lies over the cards. A finger drag,
            // a two-finger trackpad swipe and a mouse wheel are ONE thing to a
            // scroller and three different things to anything else.
            layout.input(.scroll(.horizontal, pointsPerUnit: Self.reach))
        }
    }

    /// A card either way, from a button: the ring travels there, and the
    /// arithmetic follows it frame by frame.
    private func move(_ by: Int) {
        turn = max(0, min(Double(Self.cards.count - 1), turn + Double(by)))
    }

    /// How far the ring is turned, in CARDS, from the phase as it stands - a
    /// whole number at rest and whatever the hand says while it moves.
    ///
    /// A READING FROM OUTSIDE IS NOT A NUMBER UNTIL IT IS CHECKED: a platform
    /// that reports through a transform can answer with no number at all, and
    /// `Int()` on one of those does not return.
    private func turned(_ phase: Double) -> Double {
        // A DRAG COUNTS THE OTHER WAY: the phase grows as the ring moves left,
        // and a finger going left reports a negative distance.
        let turned = phase - dragged / Self.reach

        guard turned.isFinite else { return 0 }

        // AND A DRAG HAS NO ENDS: a scroller cannot be pulled past its length,
        // but a hand can - so the arithmetic is what holds the ring to its
        // cards.
        return min(max(turned, 0), Double(Self.cards.count - 1))
    }

    /// One card's face - a picture and its name, and nothing at all about where
    /// the card is or which way it faces. That is the placement's, and keeping
    /// the two apart is what lets one run of cards be turned into any shape.
    private func face(_ card: Card) -> some View {
        ZStack {
            Grid {
                Image(ImageSource(card.art))
                    .contentMode(.fill)

                VStack {
                    // ONE LINE, whatever the card's width: a caption that
                    // wrapped would change the picture's height with it.
                    Text(card.name)
                        .fontSize(18)
                        .fontWeight(.bold)
                        .textColor(Palette.onBrand)
                        .lineBreak(.tailTruncation)

                    Text("Placed by arithmetic")
                        .fontSize(10)
                        .textColor(Palette.onBrand)
                        .opacity(0.8)
                        .lineBreak(.tailTruncation)
                }
                .padding(horizontal: 12, vertical: 10)
                .spacing(1)
                // A dark strip under the words, so a caption reads over a
                // picture of any colour.
                .background(Color("#B3000000"))
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

    /// A RING, turned to `at` - each card lying along the circle, the one at
    /// the front largest. The whole of the layout.
    private func place(_ index: Int, _ at: Double, _ room: Rect) -> Placement {
        let count = Self.cards.count
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
            opacity: 0.25 + 0.75 * chosen(Double(index) - at),
            zIndex: 2000)
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
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`LayoutEngine` builds one view per item from its closure, and its "
                + "arithmetic answers a `Placement` for each - where it goes, and how it is "
                + "turned, scaled, faded, shaded and stacked - from the room it was given and "
                + "its phase. That is the whole layout: the ring and its dots are a few "
                + "lines of arithmetic. `GalleryView`, under Items and Cards, is the same "
                + "layout with the arithmetic for a wheel, a fan and a row already written.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Swipe left or right to turn the ring; it comes to rest on the card it is "
                + "nearest, and `Back` and `Next` send it there without the hand - the phase "
                + "itself travels, under the layout's `.motion`, a scroller over the cards or "
                + "none. The phase, "
                + "`.phase($turn)`, is the card at the front: the buttons write it, and a swipe "
                + "names the card it passes. `.input(.scroll(…))` lays an empty scroller over "
                + "the cards, so a finger drag, a two-finger trackpad swipe and a mouse wheel "
                + "all turn the ring, resting on its `.snapTargets`. With `Turn by panning` on, "
                + "the cards are taken hold of instead and follow the finger, with no scroller "
                + "over them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Nothing that turns the ring is read in the body. The arithmetic runs on "
                + "the display's own frames whenever the room, the phase or a state named in "
                + "`.following(_:)` - the drag - has moved, and the host wears the placements "
                + "straight onto the cards, so the ring turns with no view built.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The trap is a value read in the body: the layout is built again every "
                + "time it moves. Handed on with `$` and named in `.following(_:)`, the drag "
                + "moves the cards with no view rebuilt.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
