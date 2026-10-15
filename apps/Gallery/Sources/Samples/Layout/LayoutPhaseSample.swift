import StateUI

/// A phase of two axes: the hand turns a run of cards while a switch fans
/// them out, and each axis travels on its own.
struct LayoutPhaseSample: SampleContent, ExampleContent {
    static let id = "layoutPhase"
    static let title = "LayoutPhase"
    static let summary = "A phase of two axes - the hand turns the cards while a switch fans them out."

    // listing: LayoutPhaseSample
    /// THE PHASE: two numbers, each moved on its own - the turn by the hand,
    /// the spread by the switch.
    struct Deal: LayoutPhase {
        /// Which card is at the front.
        var turn = 2.0

        /// How far the cards are fanned out: 0 a pile, 1 an arc.
        var spread = 0.0

        static var axes: [WritableKeyPath<Deal, Double>] { [\.turn, \.spread] }
    }

    /// The cards: a name and a colour each.
    static let names = ["Mural", "Nebula", "Ridge", "Bloom", "Tide"]
    static let colours = ["#7C3AED", "#2563EB", "#0D9488", "#D97706", "#DB2777"]

    /// Where the run stands on both axes - handed on with `$`, never read in
    /// the body.
    @State private var deal = Deal()

    /// The switch's own value: what the body reads.
    @State private var fanned = false
    // listing: end

    // The cards are turned by a scroller of their own, so the example is not
    // put in a second one.
    static let scrolls = false

    // And it takes the whole cell: the arc wants the room.
    static let fills = true

    // listing: LayoutPhaseSample
    var body: some View {
        Grid {
            Grid {
                Rectangle(Palette.raised)
                    .cornerRadius(14)

                cards
            }
            .gridRow(0)
            .clipsContent(true)

            SwitchRow(
                "Fan out",
                Binding(
                    get: { fanned },
                    set: { fanning in
                        fanned = fanning
                        // ONE AXIS WRITTEN: the spread travels there, and a
                        // turn under way goes on as it was.
                        deal.spread = fanning ? 1 : 0
                    }))
            .horizontalAlignment(.center)
            .gridRow(1)
        }
        .rows(.fill, .auto)
        .rowSpacing(10)
    }

    /// The cards, placed from both axes of the phase.
    private var cards: some View {
        LayoutEngine(Array(Self.names.indices)) { index in
            face(index)
        } placements: { room, deal in
            Self.names.indices.map { place($0, deal, room) }
        }
        .phase($deal)
        // THE HAND DRIVES THE TURN ALONE, resting on a card; the spread has
        // no hand, so it needs no targets.
        .input(.scroll(.horizontal, pointsPerUnit: 90), drives: \.turn)
        .snap(\.turn, to: Self.names.indices.map(Double.init))
        .motion(.eased(.milliseconds(600), .cubicOut))
    }

    /// Where one card stands: between a pile and an arc by the spread, the
    /// card at the front in the middle either way.
    private func place(_ index: Int, _ deal: Deal, _ room: Rect) -> Placement {
        let step = Double(index) - deal.turn
        let width = min(room.width * 0.36, room.height * 0.5, 150)
        let height = width * 1.4

        // A PILE leaves each card a few points behind the one in front; an ARC
        // sets it most of a card along, lower and turned with the curve.
        let pile = 1 - deal.spread
        let across = step * (10 * pile + width * 0.75 * deal.spread)
        let down = abs(step) * (-6 * pile + width * 0.12 * deal.spread)

        return Placement(
            Rect(room.width / 2 - width / 2 + across, room.height / 2 - height / 2 + down, width, height),
            transform: .rotate(step * 10 * deal.spread).scale(1 - min(abs(step), 3) * 0.06),
            zIndex: 100 - Int(min(abs(step), 9) * 10))
    }

    /// One card's face: its colour and its name.
    private func face(_ index: Int) -> some View {
        ZStack {
            Rectangle(Color(Self.colours[index]))
                .cornerRadius(16)

            Text(Self.names[index])
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
            Text("The phase is a `LayoutPhase` of two axes: `turn`, the card at the front, and "
                + "`spread`, how far the pile is fanned out. Swipe to turn the cards, and switch "
                + "`Fan out` while they still move: each axis travels on its own under the layout's "
                + "`.motion`, so neither cuts the other short.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`.input(_:drives:)` gives the hand the turn alone, and `.snap(_:to:)` rests it on a "
                + "card whatever the spread does. The switch writes one axis, `deal.spread`; the "
                + "arithmetic is handed both as they stand each frame.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
