import StateUI

/// A deck that changes at the phase it stands at: cards join, leave, change
/// places and spread, and each travels from where it was shown.
struct ChangingDeckSample: SampleContent, ExampleContent {
    static let id = "changingDeck"
    static let title = "A deck that changes"
    static let summary = "Cards join, leave and change places where the deck stands - each travels from where it was."

    // listing: ChangingDeckSample
    /// One card: its name, which is its identity, and its colour.
    struct Card: Hashable {
        let name: String
        let colour: String
    }

    /// Every card the deck can hold, dealt in this order.
    static let all = [
        Card(name: "Mural", colour: "#7C3AED"), Card(name: "Nebula", colour: "#2563EB"),
        Card(name: "Ridge", colour: "#0D9488"), Card(name: "Bloom", colour: "#D97706"),
        Card(name: "Tide", colour: "#DB2777"), Card(name: "Prism", colour: "#4F46E5"),
        Card(name: "Grove", colour: "#16A34A"), Card(name: "Ember", colour: "#DC2626"),
    ]

    /// The cards in the deck, in order.
    @State private var cards = Array(Self.all.prefix(4))

    /// Which card is at the front - handed on with `$`, never read in the body.
    @State private var turn = 1.0

    /// Whether the cards fan out or stand in a pile: read in the body, so a
    /// change is a new description of the layout.
    @State private var spread = true
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
                // the card behind it comes to the front. Where the front card
                // was the last, the phase itself travels to the one behind.
                Button("Remove").onClicked {
                    guard cards.count > 1 else { return }
                    let leaving = front
                    cards.remove(at: leaving)
                    $turn.journey.move(to: Double(min(leaving, cards.count - 1)))
                }
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

    /// The cards, placed around the one at the front.
    private var deck: some View {
        // Read here, in the body: a change of it describes the layout anew,
        // and every card travels from where it was to its new place.
        let fanned = spread
        let count = cards.count

        return LayoutEngine(cards, id: \.name) { card in
            face(card)
        } placements: { room, turn in
            (0..<count).map { place($0, turn, room, fanned: fanned) }
        }
        .phase($turn)
        .input(.scroll(.horizontal, pointsPerUnit: 90))
        .snapTargets(cards.indices.map(Double.init))
        // ONE MOTION for the turn and for every change at the phase.
        .motion(.spring(response: .milliseconds(380), damping: 0.82))
    }

    /// Where one card stands: in a fan, along an arc and turned with it; in a
    /// pile, a few points behind the one in front - the front card in the
    /// middle either way.
    private func place(_ index: Int, _ turn: Double, _ room: Rect, fanned: Bool) -> Placement {
        let step = Double(index) - turn
        let width = min(room.width * 0.3, room.height * 0.55, 140)
        let height = width * 1.4
        let across = fanned ? step * width * 0.62 : step * 12
        let down = fanned ? abs(step) * width * 0.1 : -abs(step) * 6

        return Placement(
            Rect(room.width / 2 - width / 2 + across, room.height / 2 - height / 2 + down, width, height),
            transform: .rotate(fanned ? step * 8 : 0).scale(1 - min(abs(step), 3) * 0.05),
            zIndex: 100 - Int(min(abs(step), 9) * 10))
    }

    /// One card's face: its colour and its name.
    private func face(_ card: Card) -> some View {
        ZStack {
            Rectangle(Color(card.colour))
                .cornerRadius(16)

            Text(card.name)
                .fontSize(18)
                .fontWeight(.bold)
                .textColor(Palette.onBrand)
                .horizontalAlignment(.center)
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

            Text("A card joining fades in - at the end, or at the front where it is inserted; one "
                + "leaving goes at once, and the others close up. "
                + "`spread` is read in the body, so the switch describes the layout anew. When the "
                + "last card leaves, `$turn.journey.move(to:)` brings the one behind it to the front.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
