import StateUI

/// A view coming and going by the transition it declares.
struct TransitionSample: SampleContent, ExampleContent {
    static let id = "transition"
    static let title = "A view that comes and goes"
    static let summary = "Add a note, then remove one: each comes from, and goes to, where its transition says."

    var examples: [Example] {
        [Example(self), Example(SharedPictures()), Example(SharedTiles())]
    }

    // listing: TransitionSample
    static let ways = ["Rising", "Growing", "From outside"]

    /// What a note comes from and goes to: faded and lower, faded and
    /// smaller, or wholly out of sight to the right.
    static func effect(_ way: Int) -> TransitionEffect {
        switch way {
        case 1: .opacity.combined(with: .scale(0.6))
        case 2: .outside(.right)
        default: .opacity.combined(with: .translation(y: 24))
        }
    }

    @State private var cards: [Int] = []
    @State private var removed: [Int] = []
    @State private var next = 1
    @State private var way = 0
    @State private var detailed = false

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
                    if !cards.isEmpty { removed.append(cards.removeFirst()) }
                }
                .accessibilityIdentifier("transition.remove")
            }
            .spacing(8)

            HStack {
                // THE SAME NOTE PUT BACK while it is still leaving goes on
                // from where it is drawn. A list's item is known by its id
                // - its number here - as a named view is by its name.
                Button("Put back").onClicked {
                    if let number = removed.popLast() { cards.insert(number, at: 0) }
                }
                .accessibilityIdentifier("transition.putBack")

                Button("Clear").onClicked {
                    cards.removeAll()
                    removed.removeAll()
                }
                .accessibilityIdentifier("transition.clear")
            }
            .spacing(8)

            SwitchRow("Details", $detailed)
                .accessibilityIdentifier("transition.details")

            if detailed {
                // A VIEW WITH A NAME that comes back while it is still
                // leaving goes on from where it is drawn: off and on again,
                // the line neither stands twice nor jumps. It is another
                // view all the same - its state starts anew.
                Text("A named line, here while the switch is on.")
                    .fontSize(13)
                    .id("details")
                    .transition(Transition(
                        enter: .opacity.combined(with: .translation(y: -12)),
                        exit: .opacity.combined(with: .translation(y: 12))))
                    .motion(.eased(.milliseconds(900), curve: .sineInOut))
            }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Add a note. It comes from where its transition says - lower, "
                + "smaller, or from out of sight - on a spring of its own, "
                + "while the notes under it make room.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The second button chooses what the NEXT note comes from. The "
                + "notes already standing are given the new transition too, and "
                + "do not move for it: a transition is how a view comes and goes.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Turn Details off, and on again before the line has gone: it "
                + "comes back from where it is, not from where it enters.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Remove takes the top note away. It goes where its transition "
                + "says while the notes under it close over its place; where a "
                + "platform keeps no leaving view, it is gone at once. Put back "
                + "returns it: pressed before the note has gone, it comes back "
                + "from where it is.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// A thumbnail growing into its picture, and back: two views of one id.
struct SharedPictures: ExampleContent {
    // listing: SharedPictures
    static let tints: [Color] = [Palette.accent, Palette.brand, AppColors.violetLight]

    @State private var chosen: Int?

    var body: some View {
        ZStack {
            if let chosen {
                // THE PICTURE: another view than its thumbnail, of the same
                // id - it sets out from where the thumbnail is drawn. No other
                // view of the page wears the id: the tiles below have theirs.
                Rectangle()
                    .fill(Self.tints[chosen])
                    .cornerRadius(12)
                    .height(150)
                    .id("picture \(chosen)")
                    // Slow enough to see the way.
                    .motion(.eased(.milliseconds(700), curve: .sineInOut))
                    .onTapped { self.chosen = nil }
                    .accessibilityIdentifier("shared.picture")
            } else {
                HStack {
                    ForEach([0, 1, 2]) { item in
                        Rectangle()
                            .fill(Self.tints[item])
                            .cornerRadius(6)
                            .width(56)
                            .height(40)
                            // THE THUMBNAIL has the same id as its picture;
                            // going back, it sets out from where the picture
                            // is drawn at that moment.
                            .id("picture \(item)")
                            .motion(.eased(.milliseconds(700), curve: .sineInOut))
                            .onTapped { chosen = item }
                            .accessibilityIdentifier("shared.thumbnail.\(item)")
                    }
                }
                .spacing(8)
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
        }
        .height(150)
    }
    // listing: end

    var notes: (any View)? {
        Text("Press a thumbnail: its picture grows from it. Press the picture: the thumbnail comes back "
            + "from it - press it before the picture has finished growing, and it sets out from where "
            + "the picture has got to.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Tiles of an id each, standing as a row or as a grid: each goes from where it is drawn in the one onto its
/// place in the other.
struct SharedTiles: ExampleContent {
    // listing: SharedTiles
    static let tints: [Color] = [
        Color(hex: 0x7C3AED), Color(hex: 0x2563EB), Color(hex: 0x0D9488),
        Color(hex: 0xD97706), Color(hex: 0xDB2777), Color(hex: 0x16A34A),
    ]

    @State private var asGrid = false

    var body: some View {
        VStack {
            SwitchRow("As a grid", $asGrid)
                .accessibilityIdentifier("shared.tiles.grid")

            VStack {
                if asGrid {
                    // THE GRID: the same ids, larger, three to a row.
                    Grid {
                        ForEach(Array(Self.tints.indices)) { tile in
                            Self.tile(tile, corner: 12)
                                .gridRow(tile / 3)
                                .gridColumn(tile % 3)
                        }
                    }
                    .rows(.fixed(84, count: 2))
                    .columns(.fill(count: 3))
                    .rowSpacing(8)
                    .columnSpacing(8)
                } else {
                    // THE ROW: each tile small and round.
                    HStack {
                        ForEach(Array(Self.tints.indices)) { tile in
                            Self.tile(tile, corner: 20)
                                .width(40)
                                .height(40)
                        }
                    }
                    .spacing(8)
                }
            }
            .height(200)
        }
        .spacing(12)
    }

    /// One tile: its color, its corner, and its id - its number. The tile
    /// made takes over where the one of its id was drawn, how fast it was
    /// moving and its corner, and goes on from there onto its own place.
    static func tile(_ index: Int, corner: Double) -> some View {
        Rectangle()
            .fill(tints[index])
            .cornerRadius(corner)
            .id(index)
            .motion(.spring(response: .milliseconds(480), damping: 0.78))
    }
    // listing: end

    var notes: (any View)? {
        Text("Switch between the row and the grid: each tile goes from where it is onto its place in the other, "
            + "its corner with it. Switch back before the tiles have landed: they turn from where they are, "
            + "as fast as they were going.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
