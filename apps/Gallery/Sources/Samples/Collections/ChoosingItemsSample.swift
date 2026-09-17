#if MAUI
import StateUI

/// Rows chosen by the handful, and the offset written to move the list.
private struct PickList: ExampleContent {
    @State private var chosen: Set<Int> = []

    /// Where the list is scrolled to, both ways.
    @State private var offset = Point.zero

    static let code = """
        @State private var chosen: Set<Int> = []
        @State private var offset = Point.zero

        Grid {
            HStack {
                // The list's own numbers arrive, so a write with no law of
                // its own jumps; these state the law they glide by.
                Button("Top")
                    .onClicked { try await $offset.journey.move(to: .zero, .eased(300, .cubicOut)) }

                // A stated row height makes a row's offset arithmetic.
                Button("Row 500")
                    .onClicked {
                        try await $offset.journey.move(to: Point(0, 500 * 44), .eased(300, .cubicOut))
                    }

                Button("Clear")
                    .isEnabled(!chosen.isEmpty)
                    .onClicked { chosen = [] }
            }
            .gridRow(0)

            ItemsView(0..<1_000) { number in
                HStack {
                    Label(chosen.contains(number) ? "✓" : "").width(22)
                    Label("Row \\(number)")
                }
                .padding(14, 10)
                .background(chosen.contains(number) ? Palette.selected : .transparent)
            }
            .itemSize(44)
            // A Set rather than one value: the binding's TYPE says how many
            // rows may be chosen.
            .selection($chosen)
            .scrollOffset($offset)
            .gridRow(1)

            DebugInfoLabel()
                .gridRow(2)

            Label("\\(chosen.count) chosen")
                .gridRow(2)
        }
        .rows(.auto, .fill, .auto)
        """

    var content: any View {
        Grid {
            HStack {
                Button("Top")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await $offset.journey.move(to: .zero, .eased(300, .cubicOut)) }

                Button("Row 500")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked {
                        try await $offset.journey.move(to: Point(0, 500 * 44), .eased(300, .cubicOut))
                    }

                Button("Clear")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(!chosen.isEmpty)
                    .onClicked { chosen = [] }
            }
            .spacing(10)
            .horizontalAlignment(.center)
            .gridRow(0)

            ItemsView(0..<1_000) { number in
                HStack {
                    Label(chosen.contains(number) ? "✓" : "")
                        .fontSize(14)
                        .textColor(Palette.accent)
                        .width(22)
                        .verticalAlignment(.center)

                    Label("Row \(number)")
                        .fontSize(14)
                        .verticalAlignment(.center)
                }
                .spacing(8)
                .padding(14, 10)
                .background(chosen.contains(number) ? Palette.selected : .transparent)
            }
            .itemSize(44)
            .selection($chosen)
            .scrollOffset($offset)
            .gridRow(1)

            DebugInfoLabel()
                .gridRow(2)

            Label("\(chosen.count) chosen")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(2)
        }
        .rows(.auto, .fill, .auto)
        .rowSpacing(10)
    }

    var notes: Element? {
        Label("Tap rows to choose several - a Set binding is what allows it. Top and Row 500 "
            + "write the offset and glide there; a row's offset is its number times the "
            + "stated height.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Choosing rows by the handful, and moving the list from Swift.
struct ChoosingItemsSample: SampleContent {
    static let id = "choosingItems"
    static let title = "Choosing items"
    static let summary = "Rows chosen by the handful, and the offset written to move the list."

    // The example IS a scroller, so the page does not put one inside another -
    // and it takes the window's height, since a list is worth as many rows as
    // there is room for.
    static let scrolls = false
    static let fills = true

    var examples: [Example] {
        [Example(PickList())]
    }
}
#endif
