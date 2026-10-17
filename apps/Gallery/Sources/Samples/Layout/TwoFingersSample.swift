// listing: TwoFingersSample
import StateUIFoundation
// listing: end
import StateUI

/// A ring of cards two fingers turn and spread: a rotation and a
/// magnification, each driving an axis of its own, both at once.
struct TwoFingersSample: SampleContent, ExampleContent {
    static let id = "twoFingers"
    static let title = "Two fingers"
    static let summary = "A ring two fingers turn and spread - a rotation and a magnification at once."

    // listing: TwoFingersSample
    /// THE PHASE: how far the ring is turned, a card a unit, and how large it
    /// stands.
    struct Ring: LayoutPhase {
        var turn = 0.0
        var size = 1.0

        static var axes: [WritableKeyPath<Ring, Double>] { [\.turn, \.size] }
    }

    /// The cards: the gallery's groups' pictures.
    static let cards = [
        "cat_fundamentals.png", "cat_driven.png", "cat_state.png", "cat_animation.png",
        "cat_basicinput.png", "cat_text.png", "cat_layout.png", "cat_styles.png",
    ]

    /// Where the ring stands on both axes - handed on with `$`, never read in
    /// the body.
    @State private var ring = Ring()
    // listing: end

    // The ring is moved by two fingers of its own, so the example is not put
    // in a scroller.
    static let scrolls = false

    // And it takes the whole cell: the ring wants the room.
    static let fills = true

    // listing: TwoFingersSample
    var body: some View {
        let count = Double(Self.cards.count)

        return Grid {
            Rectangle(Palette.raised)
                .cornerRadius(14)

            LayoutEngine(Self.cards) { art in
                ZStack { Image(ImageSource(art)).contentMode(.fill) }
                    .shape(.roundedRectangle(14))
                    .clipsContent(true)
            } placements: { room, ring in
                Self.cards.indices.map { place($0, ring, room) }
            }
            .phase($ring)
            // TWO FINGERS TURNING turn the ring a card every eighth of a
            // turn, round and round; SPREADING, they grow it - both at once.
            .input(.rotation(degreesPerUnit: 360 / count), drives: \.turn)
            .snap(\.turn, to: Self.cards.indices.map(Double.init))
            .wraps(\.turn, every: count)
            .input(.magnification, drives: \.size)
            .snap(\.size, to: [0.6, 1, 1.5])
            .motion(.spring(response: .milliseconds(420), damping: 0.8))
        }
        .clipsContent(true)
    }

    /// Where the card at `index` stands: round the middle of the room, turned
    /// to face out, the ring and its cards as large as its size.
    private func place(_ index: Int, _ ring: Ring, _ room: Rect) -> Placement {
        let count = Double(Self.cards.count)
        let angle = (Double(index) + ring.turn) / count * 2 * .pi - .pi / 2
        let radius = min(room.width, room.height) * 0.3 * ring.size
        let width = min(room.width, room.height) * 0.16 * ring.size
        let height = width * 1.4
        let x = room.width / 2 + cos(angle) * radius
        let y = room.height / 2 + sin(angle) * radius

        return Placement(
            Rect(x - width / 2, y - height / 2, width, height),
            transform: .rotate(angle * 180 / .pi + 90),
            zIndex: Int(y))
    }
    // listing: end

    var notes: (any View)? {
        Text("On a touch screen or a trackpad, turn two fingers to turn the ring a card at a time, and spread or "
            + "pinch them to grow or shrink it - both at once. Let go with speed, and it goes on.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
