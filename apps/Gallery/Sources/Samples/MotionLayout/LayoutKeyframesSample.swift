// listing: LayoutKeyframesSample
import StateUIFoundation
// listing: end
import StateUI

/// Three quite different layouts of the same cards - a ring, a grid and a
/// pile - each at a keyframe of one axis, and the hand moving through them.
struct LayoutKeyframesSample: SampleContent, ExampleContent {
    static let id = "layoutKeyframes"
    static let title = "Keyframes"
    static let summary = "A ring, a grid and a pile of the same cards - the hand moves each card from one to the next."

    // listing: LayoutKeyframesSample
    /// One card: its name, which is its identity, its color and its icon.
    struct Card {
        let name: String
        let color: Color
        let icon: Icon
    }

    /// The cards, dealt in this order.
    static let cards = [
        Card(name: "Mural", color: Color(hex: 0x7C3AED), icon: .star),
        Card(name: "Nebula", color: Color(hex: 0x2563EB), icon: .heart),
        Card(name: "Ridge", color: Color(hex: 0x0D9488), icon: .home),
        Card(name: "Bloom", color: Color(hex: 0xD97706), icon: .calendar),
        Card(name: "Tide", color: Color(hex: 0xDB2777), icon: .mail),
        Card(name: "Prism", color: Color(hex: 0x4F46E5), icon: .settings),
        Card(name: "Grove", color: Color(hex: 0x16A34A), icon: .person),
        Card(name: "Ember", color: Color(hex: 0xDC2626), icon: .play),
        Card(name: "Dune", color: Color(hex: 0xCA8A04), icon: .clock),
    ]

    /// Which layout stands: 0 the ring, 1 the grid - the one it opens on, in
    /// the middle - 2 the pile; handed on with `$`, never read in the body.
    @State private var arrangement = 1.0

    /// Whether the cards go between the layouts by a smooth curve rather than
    /// straight: read in the body.
    @State private var smooth = false

    /// Whether the hand moves through the layouts too, or the buttons alone.
    @State private var byHand = true
    // listing: end

    // The cards are moved by the hand of their own, so the example is not put
    // in a scroller.
    static let scrolls = false

    // And it takes the whole cell: the ring and the grid want the room.
    static let fills = true

    // listing: LayoutKeyframesSample
    var body: some View {
        Grid {
            Grid {
                cards
            }
            .gridRow(0)
            .clipsContent(true)

            // A WRITE TRAVELS: from the ring to the pile, the cards pass the grid.
            HStack {
                Button("Ring").onClicked { arrangement = 0 }
                Button("Grid").onClicked { arrangement = 1 }
                Button("Pile").onClicked { arrangement = 2 }
            }
            .spacing(8)
            .horizontalAlignment(.center)
            .gridRow(1)

            SwitchRow("Smooth curve", $smooth)
                .horizontalAlignment(.center)
                .gridRow(2)

            SwitchRow("The hand moves it", $byHand)
                .horizontalAlignment(.center)
                .gridRow(3)
        }
        .rows(.fill, .auto, .auto, .auto)
        .rowSpacing(10)
    }

    /// The cards: one arithmetic, asked at the keyframes alone.
    private var cards: some View {
        MotionLayout(Self.cards, id: \.name, parameters: $arrangement) { card in
            face(card)
        } placements: { room, arrangement in
            // ASKED AT 0, 1 AND 2 ALONE, each answering a whole layout.
            [ring(room), grid(room), pile(room)][Int(arrangement)]
        }
        // THE HAND MOVES THROUGH THE THREE, resting on each - or, with no
        // input, the axis is keyframes alone and the buttons move it.
        .axis(
            \.self, input: byHand ? .scroll(.horizontal, pointsPerUnit: 260) : nil, range: 0...2,
            keyframes: .every(1), snaps: byHand ? .every(1) : nil)
        // BETWEEN THEM each card goes straight, or by a curve its neighbors
        // shape.
        .interpolation(smooth ? LayoutCurve.catmullRom : .linear)
        .motion(.eased(.milliseconds(700), .cubicInOut))
    }

    /// How large a card is in every layout - the size the grid's cells allow -
    /// so a layout changes its scale, never its size.
    private func size(in room: Rect) -> (width: Double, height: Double) {
        let width = min(room.width / 3 * 0.86, room.height / 3 * 0.86 / 1.4, 130)
        return (width, width * 1.4)
    }

    /// A RING, smaller, the first card at the top.
    private func ring(_ room: Rect) -> [Placement] {
        let (width, height) = size(in: room)
        let radius = min(room.width, room.height) / 2 - height * 0.62 / 2 - 8

        return Self.cards.indices.map { index in
            let angle = Double(index) / Double(Self.cards.count) * 2 * .pi
            return Placement(
                Rect(
                    room.width / 2 + sin(angle) * radius - width / 2,
                    room.height / 2 - cos(angle) * radius - height / 2,
                    width, height),
                transform: .scale(0.62))
        }
    }

    /// A GRID of three by three, filling the room.
    private func grid(_ room: Rect) -> [Placement] {
        let (width, height) = size(in: room)

        return Self.cards.indices.map { index in
            let (row, column) = index.quotientAndRemainder(dividingBy: 3)
            return Placement(Rect(
                room.width / 3 * (Double(column) + 0.5) - width / 2,
                room.height / 3 * (Double(row) + 0.5) - height / 2,
                width, height))
        }
    }

    /// A PILE in the middle, each card turned a little, the last on top.
    private func pile(_ room: Rect) -> [Placement] {
        let (width, height) = size(in: room)

        return Self.cards.indices.map { index in
            let step = Double(index) - Double(Self.cards.count - 1) / 2
            return Placement(
                Rect(room.width / 2 - width / 2 + step * 3, room.height / 2 - height / 2 - step * 2, width, height),
                transform: .rotate(step * 4).scale(1.1),
                zIndex: index)
        }
    }

    /// One card's face: its color, its icon on a disc, and its name.
    private func face(_ card: Card) -> some View {
        ZStack {
            Rectangle()
                .fill(card.color)
                .cornerRadius(14)

            VStack {
                ZStack {
                    Rectangle()
                        .fill(.white)
                        .cornerRadius(22)
                        .opacity(0.3)

                    Image(.icon(card.icon))
                        .width(24)
                        .height(24)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                }
                .width(44)
                .height(44)
                .horizontalAlignment(.center)

                Text(card.name)
                    .fontSize(15)
                    .fontWeight(.bold)
                    .textColor(Palette.onBrand)
                    .horizontalAlignment(.center)
            }
            .spacing(8)
            .verticalAlignment(.center)
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("Drag across, or tap Ring, Grid or Pile: the arithmetic is asked at 0, 1 and 2 alone, and every card goes "
            + "from its place in one layout to its place in the next. Turn the hand off and the axis is keyframes "
            + "alone - no input - so only the buttons move it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
