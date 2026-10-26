import StateUI

/// One hand over five strips of cards, each strip an axis declared its own
/// way: anywhere in its range, on snaps, on its ends alone, round and round
/// anywhere, and round and round a card at a time.
struct LayoutAxesSample: SampleContent, ExampleContent {
    static let id = "layoutAxes"
    static let title = "Axes"
    static let summary = "One hand moves five strips of cards at once - each strip's axis resting its own way."

    // listing: LayoutAxesSample
    /// THE PHASE: five strips, each an axis of its own - which card stands in
    /// the middle of the strip.
    struct Strips: AxesPhase {
        var free = 1.5
        var snapping = 1.0
        var limits = 0.0
        var round = 0.0
        var stepping = 0.0

        static var axes: [WritableKeyPath<Strips, Double>] {
            [\.free, \.snapping, \.limits, \.round, \.stepping]
        }
    }

    /// Each strip's declaration, shown over it.
    static let declarations = [
        "range: 0...3",
        "range: 0...3, snaps: [1, 2]",
        "range: 0...3, snaps: .limits",
        "range: 0...4, wraps: true",
        "range: 0...4, snaps: .every(1), wraps: true",
    ]

    /// The pictures on the cards: the gallery's groups'.
    static let pictures = [
        "cat_fundamentals.png", "cat_animation.png", "cat_layout.png", "cat_shapes.png",
        "cat_gestures.png", "cat_media.png", "cat_styles.png", "cat_text.png",
    ]

    /// What the layout places for each strip: its words, the frame in its
    /// middle a card rests in, and its four cards.
    enum Part: Hashable {
        case words(Int), frame(Int), card(Int, Int)
    }

    static let parts = declarations.indices.flatMap { strip in
        [Part.words(strip), .frame(strip)] + (0..<4).map { Part.card(strip, $0) }
    }

    /// Where the strips stand - handed on with `$`, never read in the body.
    @State private var strips = Strips()
    // listing: end

    // The strips are moved by the hand of their own, so the example is not put
    // in a scroller.
    static let scrolls = false

    // And it takes the whole cell: the strips want the room.
    static let fills = true

    // listing: LayoutAxesSample
    var body: some View {
        // ONE INPUT: the hand dragged across, carrying the cards with it...
        let hand = LayoutInput.scroll(.horizontal)

        return Grid {
            PhaseLayout(Self.parts, phase: $strips) { part in
                view(part)
            } placements: { room, strips in
                Self.parts.map { place($0, strips, room) }
            }
            // ...MOVES FIVE STRIPS, each resting its own way: anywhere between
            // its ends, coming back only from past one...
            .axis(\.free, input: hand, range: 0...3)
            // ...on a card - 1 or 2 - or on an end...
            .axis(\.snapping, input: hand, range: 0...3, snaps: [1, 2])
            // ...on an end alone: the first card or the last...
            .axis(\.limits, input: hand, range: 0...3, snaps: .limits)
            // ...round and round, anywhere - 4 is 0 a turn on...
            .axis(\.round, input: hand, range: 0...4, wraps: true)
            // ...and round and round, a card at a time.
            .axis(\.stepping, input: hand, range: 0...4, snaps: .every(1), wraps: true)
            .motion(.spring(response: .milliseconds(360), damping: 0.8))
        }
        .clipsContent(true)
    }

    /// The view for one part: words, a frame or a card.
    @ViewBuilder
    private func view(_ part: Part) -> some View {
        switch part {
        case .words(let strip):
            Text(Self.declarations[strip])
                .fontFamily("Menlo")
                .fontSize(11)
                .textColor(Palette.subtle)
        case .frame:
            Rectangle()
                .fill(Palette.field)
                .cornerRadius(10)
        case .card(let strip, let index):
            ZStack { Image(ImageSource(Self.pictures[(strip + index) % Self.pictures.count])).contentMode(.fill) }
                .shape(.roundedRectangle(8))
                .clipsContent(true)
        }
    }

    /// Where one part stands: a row a strip down the room, its words over it
    /// and its frame in its middle; each card as far from the middle as its
    /// strip's axis says - on a strip that comes round, the turn nearest the
    /// middle, fading out at the strip's ends.
    private func place(_ part: Part, _ strips: Strips, _ room: Rect) -> Placement {
        let row = min(room.height / 5, 104)
        let height = row - 34
        let width = height * 0.75
        let top = (room.height - 5 * row) / 2

        switch part {
        case .words(let strip):
            return Placement(Rect(16, top + Double(strip) * row + 4, room.width - 32, 16))
        case .frame(let strip):
            return Placement(Rect(
                room.width / 2 - width / 2 - 4, top + Double(strip) * row + 20, width + 8, height + 8))
        case .card(let strip, let index):
            let along = Double(index) - strips[keyPath: Strips.axes[strip]]
            let comesRound = strip >= 3
            let step = comesRound ? along - ((along + 2) / 4).rounded(.down) * 4 : along

            return Placement(
                Rect(room.width / 2 + step * (width + 10) - width / 2, top + Double(strip) * row + 24, width, height),
                opacity: comesRound ? min(max((2 - abs(step)) * 2, 0), 1) : 1,
                zIndex: 1)
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("Drag across: one hand moves all five strips, and let go, each comes to rest the way its axis says - "
            + "a card in the middle frame, or anywhere.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
