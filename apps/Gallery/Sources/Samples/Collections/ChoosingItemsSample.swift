import StateUI

/// Rows chosen by the handful, and the list scrolled to a row from code.
private struct PickList: ExampleContent {
    @State private var chosen: Set<Int> = []
    @Aim(ItemsViewContract.self) private var list

    static let code = """
        @State private var chosen: Set<Int> = []
        @Aim(ItemsViewContract.self) private var list

        Grid {
            HStack {
                Button("Top")
                    .onClicked { try await list.scrollTo(0, anchor: .start) }
                Button("Row 500")
                    .onClicked { try await list.scrollTo(500, anchor: .start) }
                Button("Clear")
                    .isEnabled(!chosen.isEmpty)
                    .onClicked { chosen = [] }
            }
            .gridRow(0)

            // A Set binding: as many chosen as the user likes.
            ItemsView(0..<1_000) { number in
                Text("Row \\(number)").padding(14, 10)
            }
            .selection($chosen)
            .aim(list)
            .gridRow(1)

            DebugInfoLabel()
                .gridRow(2)

            Text("\\(chosen.count) chosen")
                .gridRow(2)
        }
        .rows(.auto, .fill, .auto)
        """

    var body: some View {
        Grid {
            HStack {
                Button("Top")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await list.scrollTo(0, anchor: .start) }

                Button("Row 500")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { try await list.scrollTo(500, anchor: .start) }

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
                Text("Row \(number)")
                    .fontSize(14)
                    .padding(14, 10)
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

    var notes: (any View)? {
        Text("Tap rows to choose several; Row 500 scrolls there.")
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
