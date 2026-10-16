import StateUI

/// A deck that changes at the phase it stands at: cards join, leave, change
/// places and spread, and each travels from where it was shown.
struct ChangingDeckSample: SampleContent, ExampleContent {
    static let id = "changingDeck"
    static let title = "A deck that changes"
    static let summary = "Cards join, leave and change places - each travels from where it was; one pulled up flies out."

    // listing: ChangingDeckSample
    /// One card: its name, which is its identity, its colour and its icon.
    struct Card: Hashable {
        let name: String
        let colour: String
        let icon: Icon
    }

    /// Every card the deck can hold, dealt in this order.
    static let all = [
        Card(name: "Mural", colour: "#7C3AED", icon: .star), Card(name: "Nebula", colour: "#2563EB", icon: .heart),
        Card(name: "Ridge", colour: "#0D9488", icon: .home), Card(name: "Bloom", colour: "#D97706", icon: .calendar),
        Card(name: "Tide", colour: "#DB2777", icon: .mail), Card(name: "Prism", colour: "#4F46E5", icon: .settings),
        Card(name: "Grove", colour: "#16A34A", icon: .person), Card(name: "Ember", colour: "#DC2626", icon: .play),
    ]

    /// The cards in the deck, in order.
    @State private var cards = Array(Self.all.prefix(4))

    /// Which card is at the front - handed on with `$`, never read in the body.
    @State private var turn = 1.0

    /// Whether the cards fan out or stand in a pile: read in the body, so a
    /// change is a new description of the layout, and so is the hand's unit.
    @State private var spread = false
    // listing: end

    // The cards are turned by the hand of their own, so the example is not put
    // in a second scroller.
    static let scrolls = false

    // And it takes the whole cell: the fan wants the room.
    static let fills = true

    // listing: ChangingDeckSample
    var body: some View {
        Grid {
            Grid {
                Rectangle(Palette.raised)
                    .cornerRadius(14)

                deck
            }
            .gridRow(0)
            .clipsContent(true)

            HStack {
                // A CARD JOINS AT THE END: it fades in where the arithmetic
                // puts it, and the others make room.
                Button("Add").onClicked {
                    if let next { cards.append(next) }
                }

                // A CARD COMES IN AT THE FRONT: it fades in where the front
                // card stood, and the others move aside - the phase is where
                // it was, so the new card is the one at the front.
                Button("Insert").onClicked {
                    if let next { cards.insert(next, at: min(front, cards.count)) }
                }

                // THE FRONT CARD LEAVES: at once, the others closing up, and
                // the card behind it comes to the front.
                Button("Remove").onClicked { remove(cards[front]) }
            }
            .spacing(8)
            .horizontalAlignment(.center)
            .gridRow(1)

            HStack {
                // A NEW ORDER: each card slides from where it stood.
                Button("Reverse").onClicked { cards.reverse() }

                SwitchRow("Spread", $spread)
            }
            .spacing(16)
            .horizontalAlignment(.center)
            .gridRow(2)
        }
        .rows(.fill, .auto, .auto)
        .rowSpacing(10)
    }

    /// The next card not in the deck, if any is left.
    private var next: Card? {
        Self.all.first { !cards.contains($0) }
    }

    /// Where the card at the front stands among the cards.
    private var front: Int {
        min(max(Int(turn.rounded()), 0), cards.count - 1)
    }

    /// `card` leaves the deck, the others closing up: one before the front
    /// card keeps that card in front; the front card's place goes to the one
    /// behind it - where it was the last, the phase travels to the one before.
    private func remove(_ card: Card) {
        guard cards.count > 1, let leaving = cards.firstIndex(of: card) else { return }
        let shown = front
        cards.remove(at: leaving)
        if leaving < shown {
            $turn.journey.snap(to: Double(shown - 1))
        } else {
            $turn.journey.move(to: Double(min(shown, cards.count - 1)))
        }
    }

    /// The cards, placed around the one at the front.
    private var deck: some View {
        // Read here, in the body: a change of it describes the layout anew,
        // and every card travels from where it was to its new place.
        let fanned = spread
        let count = cards.count

        return LayoutEngine(cards, id: \.name) { card in
            face(card, large: !fanned)
        } placements: { room, turn, from in
            (0..<count).map { fanned ? fan($0, turn, room) : pile($0, turn, from, room) }
        }
        .phase($turn)
        // The pile is swiped a card at a time, the fan scrolled through.
        .input(fanned ? .scroll(.horizontal) : .swipe(.horizontal))
        .snapTargets(cards.indices.map(Double.init))
        // A CARD PULLED UP is the hand's alone: let go far enough, it flies
        // out of the deck and leaves it; short of that, it goes back.
        .itemDrag(begins: .across)
        .onItemDismissed(.up, beyond: 120) { card in remove(card) }
        // ONE MOTION for the turn and for every change at the phase.
        .motion(.spring(response: .milliseconds(380), damping: 0.82))
    }

    /// Where one card stands in the fan: along an arc and turned with it, the
    /// front card in the middle.
    private func fan(_ index: Int, _ turn: Double, _ room: Rect) -> Placement {
        let step = Double(index) - turn
        let width = min(room.width * 0.3, room.height * 0.55, 140)
        let height = width * 1.4

        return Placement(
            Rect(room.width / 2 - width / 2 + step * width * 0.62,
                 room.height / 2 - height / 2 + abs(step) * width * 0.1, width, height),
            transform: .rotate(step * 8).scale(1 - min(abs(step), 3) * 0.05),
            zIndex: 100 - Int(min(abs(step), 9) * 10))
    }

    /// Where one card stands in the pile: the front card large and straight in
    /// the middle, the others peeking out either side - those passed on the
    /// left, those to come on the right - tilted and smaller the farther they
    /// are. The card the run set out from goes out the way it goes, under the
    /// finger, until it stands beside the pile, then tucks under the new front
    /// card.
    private func pile(_ index: Int, _ turn: Double, _ from: Double, _ room: Rect) -> Placement {
        let step = Double(index) - turn
        let width = min(room.width * 0.62, room.height * 0.75 / 1.33, 320)
        let height = width * 1.33
        let side: Double = step < 0 ? -1 : 1
        let behind = min(abs(step), 4)

        // Out over most of a card - nought to one - then back under at once.
        let leaving = Double(index) == from && abs(step) < 1
        let outward = abs(step) < 0.8
        let out = leaving ? (outward ? abs(step) / 0.8 : (1 - abs(step)) / 0.2) : 0

        return Placement(
            Rect(room.width / 2 - width / 2 + side * (behind * 14 + out * width * 1.05),
                 room.height / 2 - height / 2 + behind * 3, width, height),
            transform: .rotate(side * (behind * 2.5 + out * 12)).scale(1 - behind * 0.03),
            opacity: min(max(5 - abs(step), 0), 1),
            zIndex: leaving && outward ? 200 : Int(100 - behind * 10))
    }

    /// One card's face: its colour, its icon on a light disc and its name -
    /// the icon in the platform's own colour, which shows on the disc in a
    /// light theme and a dark one alike - larger on the pile's larger cards.
    private func face(_ card: Card, large: Bool) -> some View {
        let disc = large ? 88.0 : 56.0
        return ZStack {
            Rectangle(Color(card.colour))
                .cornerRadius(20)

            VStack {
                ZStack {
                    Rectangle(.white)
                        .cornerRadius(disc / 2)
                        .opacity(0.3)

                    Image(.icon(card.icon))
                        .width(disc * 0.55)
                        .height(disc * 0.55)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                }
                .width(disc)
                .height(disc)
                .horizontalAlignment(.center)

                Text(card.name)
                    .fontSize(large ? 21 : 18)
                    .fontWeight(.bold)
                    .textColor(Palette.onBrand)
                    .horizontalAlignment(.center)
            }
            .spacing(10)
            .verticalAlignment(.center)
        }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Add, insert, remove, reverse or spread the cards while the deck stands - or while it "
                + "still turns. Nothing here animates a card: a change of the layout's description "
                + "at the phase it stands at travels under its `.motion`, each card from where it "
                + "was shown to where the new arithmetic puts it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("In the pile, swipe the front card either way - one card a swipe: it goes out under "
                + "your finger and under the next. The arithmetic is handed `from`, the card the "
                + "swipe set out from, and the way it goes is the phase's side of it. Pull a card up "
                + "and let go to send it out of the deck.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
