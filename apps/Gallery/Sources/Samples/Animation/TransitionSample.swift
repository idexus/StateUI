import StateUI

/// A view coming and going by the transition it declares.
struct TransitionSample: SampleContent, ExampleContent {
    static let id = "transition"
    static let title = "A view that comes and goes"
    static let summary = "Add a note, then remove one: each comes from, and goes to, where its transition says."

    // listing: TransitionSample
    static let ways = ["Rising", "Growing", "From the side"]

    /// What a note comes from and goes to: faded and lower, faded and
    /// smaller, or faded and well to the side.
    static func effect(_ way: Int) -> TransitionEffect {
        switch way {
        case 1: .opacity.combined(with: .scale(0.6))
        case 2: .opacity.combined(with: .translation(x: 160))
        default: .opacity.combined(with: .translation(y: 24))
        }
    }

    @State private var cards: [Int] = []
    @State private var next = 1
    @State private var way = 0

    var body: some View {
        VStack {
            VStack {
                // INSIDE these braces, because that is where `cards` and
                // `way` are read: Add builds this closure, and the notes
                // left standing keep their views.
                DebugInfoLabel()

                ForEach(cards) { number in
                    ZStack {
                        Text("Note \(number)")
                            .fontSize(15)
                            .verticalAlignment(.center)
                    }
                    .style(.card)
                    .padding(horizontal: 12, vertical: 8)
                    .background(Palette.raised)
                    .lineWidth(0)
                    .height(40)
                    // HOW IT COMES AND GOES, as the stack gains and drops
                    // it: from the effect to how it stands, and back to the
                    // effect. A note already standing is not moved by a
                    // transition said again.
                    .transition(.symmetric(Self.effect(way)))
                    // UNDER ITS OWN MOTION, whatever carries the notes
                    // below it to their new places.
                    .motion(.spring(response: .milliseconds(450), damping: 0.7))
                }
            }
            .spacing(6)

            HStack {
                Button("Add").onClicked {
                    cards.insert(next, at: 0)
                    next += 1
                }
                .accessibilityIdentifier("transition.add")

                Button(Self.ways[way]).onClicked { way = (way + 1) % Self.ways.count }
                    .accessibilityIdentifier("transition.way")

                // A NOTE REMOVED is no more the stack's at once - the notes
                // under it close over its place - and is drawn until it has
                // gone where its transition says.
                Button("Remove").onClicked {
                    if !cards.isEmpty { cards.removeFirst() }
                }
                .accessibilityIdentifier("transition.remove")

                Button("Clear").onClicked { cards.removeAll() }
                    .accessibilityIdentifier("transition.clear")
            }
            .spacing(8)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Add a note. It comes from where its transition says - lower, "
                + "smaller, or from the side - on a spring of its own, while the "
                + "notes under it make room.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The second button chooses what the NEXT note comes from. The "
                + "notes already standing are given the new transition too, and "
                + "do not move for it: a transition is how a view comes and goes.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Remove takes the top note away. It goes where its transition "
                + "says while the notes under it close over its place; where a "
                + "platform keeps no leaving view, it is gone at once.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
