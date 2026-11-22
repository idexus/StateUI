import StateUI

/// The whole motion model on one board: cards thrown and held, moved, closed and brought back, laid out
/// another way, opened into their detail and pulled back - beside a field and a scroller of the platform's own.
struct CommonBoardSample: SampleContent, ExampleContent {
    static let id = "commonBoard"
    static let title = "A board of cards"
    static let summary = "Throw and move the cards, close and bring one back, show them as a grid, open one and "
        + "pull it down."

    // listing: CommonBoardSample
    /// One card: its name, which is its identity, and its color.
    struct Card: Hashable {
        let name: String
        let color: Color
    }

    static let all = [
        Card(name: "Mural", color: Color(hex: 0x7C3AED)),
        Card(name: "Nebula", color: Color(hex: 0x2563EB)),
        Card(name: "Ridge", color: Color(hex: 0x0D9488)),
        Card(name: "Bloom", color: Color(hex: 0xD97706)),
        Card(name: "Tide", color: Color(hex: 0xDB2777)),
        Card(name: "Grove", color: Color(hex: 0x16A34A)),
    ]

    /// The cards on the board, in order, and those closed, the last closed last.
    @State private var cards = Self.all
    @State private var closed: [Card] = []

    /// Which card is in front - its law is the state's own, and the hand's.
    @State(motion: .spring(response: .milliseconds(420), damping: 0.82)) private var turn = 0.0

    /// Whether the cards stand as a grid, the card the hand holds, the card
    /// opened, and the board's name, an ordinary field beside it all.
    @State private var asGrid = false
    @State private var held: String?
    @State private var opened: Card?
    @State private var name = "My board"

    /// What was done last, and how what it started ended.
    @State private var said = "Throw the cards"

    /// THE BOARD the changes are aimed at: what holds the card and its
    /// detail.
    @Aim(VStack.self) private var board
    // listing: end

    // The cards are moved by a hand of their own, so the example is not put in
    // a second scroller.
    static let scrolls = false

    // And it takes the whole cell: the cards want the room.
    static let fills = true

    // listing: CommonBoardSample
    var body: some View {
        VStack {
            // AN ORDINARY FIELD beside the board: what is typed, and the
            // cursor, stay through every change below.
            TextField($name)
                .accessibilityIdentifier("board.name")

            VStack {
                if let opened {
                    // Pulled down, it goes back as Back takes it.
                    BoardDetail(card: opened) {
                        self.opened = nil
                        said = "Back from \(opened.name)"
                    }
                } else {
                    deck
                }
            }
            .aim(board)
            .height(300)

            // WHAT WAITS FOR A CHANGE STANDS OUTSIDE IT: a view the change
            // takes away - a card opened, the detail closed - takes with it
            // every run it began, and a wait in it would never be answered.
            HStack {
                Button("Open").onClicked(policy: .runConcurrently) {
                    guard opened == nil, let front = front else { return }
                    try await change("Opened \(front.name)") { opened = front }
                }
                .accessibilityIdentifier("board.open")

                Button("Back").onClicked(policy: .runConcurrently) {
                    guard let card = opened else { return }
                    try await change("Back from \(card.name)") { opened = nil }
                }
                .accessibilityIdentifier("board.back")

                Button("Close").onClicked(policy: .runConcurrently) {
                    guard opened == nil, let front = front else { return }
                    try await change("Closed \(front.name)") { close(front) }
                }
                .accessibilityIdentifier("board.close")

                // UNDO: the card last closed joins the board again where it stood.
                Button("Undo").onClicked(policy: .runConcurrently) {
                    guard let card = closed.last else { return }
                    try await change("Brought back \(card.name)") { bringBack(card) }
                }
                .accessibilityIdentifier("board.undo")
            }
            .spacing(8)
            .wraps(true)
            .horizontalAlignment(.center)

            // THE LAYOUT CHANGES: the same cards, another arithmetic - each
            // travels from where it stood.
            SwitchRow("As a grid", $asGrid)
                .accessibilityIdentifier("board.grid")

            // A SCROLLER OF THE PLATFORM'S OWN beside the hand: the cards
            // closed, any of them brought back by a press.
            ScrollView {
                HStack {
                    ForEach(closed, id: \.name) { card in
                        // The button leaves with its card: it waits for nothing.
                        Button(card.name).onClicked {
                            bringBack(card)
                            said = "Brought back \(card.name)"
                        }
                        .accessibilityIdentifier("board.closed.\(card.name)")
                    }
                }
                .spacing(8)
            }
            .axes(.horizontal)
            .height(44)
            .accessibilityIdentifier("board.closed")

            // Where a throw or the hand settles: the card the turn is bound for.
            Text("In front · \(front?.name ?? "none")")
                .accessibilityIdentifier("board.front")
                .horizontalTextAlignment(.center)

            Text(said)
                .accessibilityIdentifier("board.said")
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    /// The cards, placed as a deck around the one in front or as a grid.
    private var deck: some View {
        let (count, grid) = (cards.count, asGrid)
        return MotionLayout(cards, id: \.name, parameters: $turn) { card in
            BoardCard(card: card, held: held == card.name) {
                opened = card
                said = "Opened \(card.name)"
            }
        } placements: { context, turn in
            (0..<count).map { grid ? Self.cell($0, context.bounds) : Self.place($0, turn, context.bounds) }
        }
        // GRAB, THROW, GRAB AGAIN: the hand turns the deck, and a throw is
        // carried on and settles on a card. As a grid, the hand has nothing to turn.
        .interaction(grid ? nil :
            .value($turn, input: .translation(.horizontal, unit: .frontItem))
                .reversed(true)
                .range(0...Double(max(count - 1, 0)))
                .snaps(.every(1))
                .release(.projected(.spring(response: .milliseconds(420), damping: 0.82))))
        // HELD STILL, A CARD IS THE HAND'S: the card under it gives it its place.
        .onItemDragged { drag in
            switch drag.phase {
            case .began:
                held = drag.id
            case .ended, .cancelled:
                held = nil
                said = "Moved \(drag.id)"
            default:
                if let over = drag.over, let place = cards.firstIndex(where: { $0.name == over }) {
                    move(drag.id, to: place)
                }
            }
        }
        // The cards reaching new places - a move, a card closed or come back,
        // the grid - travel on a spring of their own.
        .layoutBodies(.onChange(response: .milliseconds(360), damping: 0.8))
        .height(300)
        .accessibilityIdentifier("board.deck")
    }

    /// The card opened, large: it grows from the card it was. Pulled down, it
    /// follows the hand, smaller the farther; let go far enough, or thrown
    /// down, it goes back into its card from where the hand left it; let go
    /// sooner, it stands again.
    struct BoardDetail: View {
        let card: Card
        let close: @MainActor @Sendable () -> Void

        /// Where the hand draws the detail: moved down, and smaller.
        @State(motion: .spring(response: .milliseconds(320), damping: 0.88)) private var down = 0.0
        @State(motion: .spring(response: .milliseconds(320), damping: 0.88)) private var size = 1.0

        var body: some View {
            VStack {
                Rectangle()
                    .fill(card.color)
                    .cornerRadius(16)
                    .height(200)
                    // THE CARD'S OWN ID: the detail and its card are drawn as one.
                    .id(card.name)
                    // Slow enough to see the way.
                    .motion(.eased(.milliseconds(600), curve: .sineInOut))
                    .onPanUpdated { pan in pulled(pan) }
                    .accessibilityIdentifier("board.detail")

                // ITS NAME comes in as the card grows; going back, it stays
                // where it stands and fades as the card leaves.
                Text(card.name)
                    .fontSize(20)
                    .fontWeight(.semibold)
                    .horizontalAlignment(.center)
                    .transition(Transition(enter: .opacity, exit: .identity).initialAppearance(true))
                    .motion(.eased(.milliseconds(600), curve: .sineInOut))
            }
            .spacing(10)
            // THE DETAIL AS THE HAND DRAWS IT: gone back, it goes on from
            // there into its card at the speed it had.
            .translationY($down)
            .scaleX($size)
            .scaleY($size)
        }

        /// The hand on the detail: a short spring a step behind it, still
        /// moving at the hand's speed as the hand lets go.
        private func pulled(_ pan: PanUpdate) {
            let following = Motion.spring(response: .milliseconds(80), damping: 1)
            switch pan.phase {
            case .began:
                break
            case .changed:
                let pull = max(pan.total.y, 0)
                $down.journey.move(to: pull, following)
                $size.journey.move(to: max(0.5, 1 - pull / 600), following)
            case .ended where pan.total.y > 120 || pan.velocity.y > 800:
                close()
            default:
                (down, size) = (0, 1)
            }
        }
    }

    /// Makes `update` a change of the board and says how what it started ended.
    private func change(_ words: String, _ update: () -> Void) async throws {
        let change = try board.presentationChange(update)
        said = "\(words) · under way"
        said = switch try await change.settled() {
        case .settled: "\(words) · settled"
        case .interrupted(let why): "\(words) · interrupted: \(why.map { "\($0)" }.joined(separator: ", "))"
        case .notPresented: "\(words) · not presented"
        }
    }

    /// The card in front, as the turn stands.
    private var front: Card? {
        cards.isEmpty ? nil : cards[min(max(Int(turn.rounded()), 0), cards.count - 1)]
    }

    /// The card `card` closed: the others close up, the one in front staying in front.
    private func close(_ card: Card) {
        guard cards.count > 1, let leaving = cards.firstIndex(of: card) else { return }
        let shown = min(max(Int(turn.rounded()), 0), cards.count - 1)
        cards.remove(at: leaving)
        closed.append(card)
        $turn.journey.move(to: Double(min(leaving < shown ? shown - 1 : shown, cards.count - 1)))
    }

    /// The card `card` back on the board, where it stood among the cards still on it.
    private func bringBack(_ card: Card) {
        closed.removeAll { $0 == card }
        let order = Self.all.filter { $0 == card || cards.contains($0) }
        cards = order
    }


    /// The card `name` taken to `place`, the others making room.
    private func move(_ name: String, to place: Int) {
        guard let from = cards.firstIndex(where: { $0.name == name }), from != place else { return }
        let card = cards.remove(at: from)
        cards.insert(card, at: place)
    }

    /// A deck: the card in front in the middle, those after it under it to
    /// the right, smaller the farther they go.
    private static func place(_ index: Int, _ turn: Double, _ room: Rect) -> Placement {
        let step = Double(index) - turn
        let width = min(room.width * 0.42, 170)
        let height = min(width * 1.35, room.height)
        let far = min(abs(step), 3)
        return Placement(
            Rect(x: room.width / 2 - width / 2 + step * width * 0.62, y: (room.height - height) / 2,
                 width: width, height: height),
            transform: .scale(1 - far * 0.08),
            opacity: min(max(3.4 - abs(step), 0), 1),
            zIndex: 100 - Int((abs(step) * 10).rounded()))
    }

    /// A grid of three columns, the cards in their order.
    private static func cell(_ index: Int, _ room: Rect) -> Placement {
        let gap = 10.0
        let width = (room.width - gap * 2) / 3
        let height = min(width * 1.2, (room.height - gap) / 2)
        return Placement(Rect(
            x: Double(index % 3) * (width + gap), y: Double(index / 3) * (height + gap),
            width: width, height: height))
    }

    /// One card: its color and name, lifted while the hand holds it, opened by a press.
    struct BoardCard: View {
        let card: Card
        let held: Bool
        let open: @MainActor @Sendable () throws -> Void

        var body: some View {
            ZStack {
                Rectangle()
                    .fill(card.color)
                    .cornerRadius(14)
                Text(card.name)
                    .fontSize(17)
                    .fontWeight(.semibold)
                    .textColor(.white)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
            // ONE ID WITH ITS DETAIL, its name: opened, the detail grows from
            // it; back, the detail shrinks into it as its deck comes.
            .id(card.name)
            .motion(.eased(.milliseconds(600), curve: .sineInOut))
            .scale(held ? 1.1 : 1)
            // THE HAND TAKES THE CARD ITSELF once a press has stood still on it.
            .interaction(.drag(.both, begins: .longPress))
            .onTapped { try open() }
            .accessibilityIdentifier("board.card.\(card.name)")
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("Throw the cards sideways and catch them on the way. Hold one still until it lifts, then move it over "
            + "another. Close the card in front and bring it back. Turn the grid on, open a card, and pull it down "
            + "to go back - type in the field first: what you typed stays.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
