import StateUI

/// Rows chosen by the handful, and the list scrolled to a row from code.
private struct PickList: ExampleContent {
    // listing: PickList
    @State private var chosen: Set<Int> = []
    @Aim(ItemsViewContract.self) private var list

    var body: some View {
        Grid {
            HStack {
                Button("Top")
                    .onClicked(.cancelPrevious) { try await list.scrollTo(0, anchor: .start) }

                Button("Row 500")
                    .onClicked(.cancelPrevious) { try await list.scrollTo(500, anchor: .start) }

                Button("Clear")
                    .isEnabled(!chosen.isEmpty)
                    .onClicked { chosen = [] }
            }
            .spacing(10)
            .horizontalAlignment(.center)
            .gridRow(0)

            // A Set binding: as many chosen as the user likes.
            ItemsView(0..<1_000) { number in
                Text("Row \(number)")
                    .fontSize(14)
                    .padding(horizontal: 14, vertical: 10)
            }
            .selection($chosen)
            .aim(list)
            .gridRow(1)

            DebugInfoLabel()
                .gridRow(2)

            Text("\(chosen.count) chosen")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(2)
        }
        .rows(.auto, .fill, .auto)
        .rowSpacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Choose several rows; Row 500 scrolls there.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Several rows chosen at once, and the list moved to a row from code.
struct ChoosingItemsSample: SampleContent {
    static let id = "choosingItems"
    static let title = "Choosing items"
    static let summary = "Rows chosen by the handful, and the list scrolled to a row from code."

    static let scrolls = false
    static let fills = true

    var examples: [Example] {
        [Example(PickList())]
    }
}
