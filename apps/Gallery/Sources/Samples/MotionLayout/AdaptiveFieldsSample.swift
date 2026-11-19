import StateUI

/// Two fields side by side while the room holds them, one under the other
/// where it does not: a layout that measures its views, and says its own
/// size from the same arithmetic.
struct AdaptiveFieldsSample: SampleContent, ExampleContent {
    static let id = "adaptiveFields"
    static let title = "Adaptive fields"
    static let summary = "A row that becomes a column where the room runs out - a layout measuring its views."

    // listing: AdaptiveFieldsSample
    /// Where the fields stand, and how large that makes the layout.
    struct Plan {
        var size = LayoutSize.zero
        var placements: [Placement] = []
    }

    @State private var name = "Ada"
    @State private var city = "London"

    /// The most room the fields are given, across.
    @State private var room = 640.0

    /// The layout has no parameter to move: its arithmetic is of its room
    /// and its views alone.
    @State private var still = 0.0

    var body: some View {
        VStack {
            MotionLayout([0, 1], id: \.self, parameters: $still) { index in
                TextField(index == 0 ? $name : $city)
                    .accessibilityIdentifier(index == 0 ? "adaptive.name" : "adaptive.city")
                    .minimumWidth(140)
            } placements: { context, _ in
                // THE ROOM'S WIDTH IS WHAT THE VIEWS ARE OFFERED.
                Self.plan(LayoutProposal(width: context.bounds.width), context.subviews).placements
            }
            // THE LAYOUT'S OWN SIZE, from the same arithmetic: as tall as
            // one field in a row, as both in a column.
            .measure { context, _ in
                Self.plan(context.proposal, context.subviews).size
            }
            .maximumWidth($room)
            .background(Palette.well)
            .accessibilityIdentifier("adaptive.fields")

            Slider($room)
                .accessibilityIdentifier("adaptive.room")
                .accessibilityLabel("Room")
                .minimum(160)
                .maximum(640)
        }
        .spacing(16)
    }

    /// The fields in the width offered: side by side, sharing it, where
    /// their own widths fit - else each the whole width, one under the other.
    @MainActor
    static func plan(_ proposal: LayoutProposal, _ fields: LayoutSubviews<Int>) -> Plan {
        let gap = 12.0
        // WHAT EACH FIELD TAKES BY ITSELF: nothing offered.
        let own = fields.map { $0.sizeThatFits(LayoutProposal()) }
        let row = own.reduce(0) { $0 + $1.width } + gap * Double(max(own.count - 1, 0))
        let width = proposal.width ?? row
        let sideBySide = row <= width

        var plan = Plan()
        var (across, down) = (0.0, 0.0)
        for field in fields {
            let share = sideBySide ? (width - gap * Double(own.count - 1)) / Double(own.count) : width
            // A FIELD OFFERED A WIDTH says how tall it stands in it.
            let height = field.sizeThatFits(LayoutProposal(width: share)).height
            plan.placements.append(Placement(Rect(across, down, share, height)))
            plan.size.height = max(plan.size.height, down + height)
            if sideBySide { across += share + gap } else { down += height + gap }
        }
        plan.size.width = width
        return plan
    }
    // listing: end

    var notes: (any View)? {
        Text("Drag the slider to narrow the fields' room: where they no longer fit side by side they stand one "
            + "under the other, and the layout grows as tall as both. Type in a field first - what you typed, and "
            + "the cursor, stay where they are.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
