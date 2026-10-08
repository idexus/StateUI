import StateUI

/// Children drawn one over another, each in the whole room or in the area it
/// names, and which of them is on top.
struct ZStackSample: SampleContent {
    static let id = "zStack"
    static let title = "ZStack"
    static let summary = "Children drawn one over another, each in the whole room or in an area of its own."

    var examples: [Example] {
        [Example(Areas()), Example(Layers())]
    }
}

/// Two markers aligned in the whole room, and a panel in an area a switch
/// states in fractions or in device units.
private struct Areas: ExampleContent {
    // listing: Areas
    @State private var proportional = true

    var body: some View {
        VStack {
            // NO BUILD READING HERE. `proportional` is read inside the stack's
            // own braces, and a container describes its children when the
            // differ asks, so the only closure this switch rebuilds is that one.
            ZStack {
                // No area: the whole room, filled.
                ColorBox(Palette.outline)

                // The panel fills the area it names: the right half of the
                // room, or 120 by 60 at 16, 16 whatever the room's size.
                ColorBox(Color("#1E88E5"))
                    .area(proportional ? .proportional(0.5, 0, 0.5, 1) : .absolute(16, 16, 120, 60))

                // Its natural size, where its alignments put it.
                Badge(text: "start", color: "#E53935")
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)

                Badge(text: "end", color: "#00897B")
                    .horizontalAlignment(.end)
                    .verticalAlignment(.end)
            }
            .height(180)

            SwitchRow("Proportional area", $proportional)
                .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Resize the window: a proportional area follows the room, an absolute one stays put.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Two boxes overlapping in the middle, and which is drawn on top.
private struct Layers: ExampleContent {
    // listing: Layers
    @State private var redInFront = false

    var body: some View {
        VStack {
            // Left alone, the child written last is drawn on top; the higher
            // zIndex is nearer the front, and nothing moves.
            ZStack {
                ColorBox(Color("#E53935"))
                    .width(150)
                    .height(70)
                    .horizontalAlignment(.start)
                    .zIndex(redInFront ? 1 : 0)

                ColorBox(Color("#1E88E5"))
                    .width(150)
                    .height(70)
                    .horizontalAlignment(.end)
                    .zIndex(redInFront ? 0 : 1)
            }
            .height(70)
            .maximumWidth(240)
            .horizontalAlignment(.center)

            SwitchRow("Red in front", $redInFront)
                .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? { nil }
}

// listing: Areas
/// One labelled badge, so the sample says what is being positioned rather than
/// how it is drawn.
private struct Badge: View {
    let text: String
    let color: String

    var body: some View {
        Text(text)
            .fontSize(12)
            .textColor(.white)
            .background(Color(color))
            .padding(horizontal: 10, vertical: 6)
    }
}
// listing: end
