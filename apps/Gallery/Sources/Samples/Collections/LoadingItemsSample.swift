import StateUI

/// A list that asks for thirty more as the user nears its end.
private struct LoadingList: ExampleContent {
    @State private var count = 30
    @State private var loading = false

    static let code = """
        @State private var count = 30
        @State private var loading = false

        Grid {
            HStack {
                Text(loading ? "Loading" : "\\(count) items")
                Button("Start over")
                    .isEnabled(count > 30)
                    .onClicked { count = 30 }
            }
            .gridRow(0)

            DebugInfoLabel()
                .gridRow(0)

            ItemsView(0..<count) { number in
                Text("Item \\(number + 1)").padding(14, 10)
            }
            // Within five items of the end, thirty more - once each time.
            .onEndReached(within: 5) {
                guard !loading, count < 300 else { return }

                loading = true
                try await Task.sleep(for: .milliseconds(400))
                count += 30
                loading = false
            }
            .gridRow(1)
        }
        .rows(.auto, .fill)
        """

    var body: some View {
        Grid {
            HStack {
                Text(loading ? "Loading" : "\(count) items")
                    .fontSize(13)
                    .textColor(Palette.accent)
                    .verticalAlignment(.center)

                Button("Start over")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(count > 30)
                    .onClicked { count = 30 }
            }
            .spacing(12)
            .gridRow(0)

            DebugInfoLabel()
                .gridRow(0)

            ItemsView(0..<count) { number in
                Text("Item \(number + 1)")
                    .fontSize(14)
                    .padding(14, 10)
            }
            .onEndReached(within: 5) {
                guard !loading, count < 300 else { return }

                loading = true
                try await Task.sleep(for: .milliseconds(400))
                count += 30
                loading = false
            }
            .gridRow(1)
        }
        .rows(.auto, .fill)
        .rowSpacing(10)
    }

    var notes: (any View)? {
        Text("Scroll towards the end: thirty more arrive, up to three hundred.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A list that grows as the user reads.
struct LoadingItemsSample: SampleContent {
    static let id = "loadingItems"
    static let title = "Loading more items"
    static let summary = "A list that asks for more as the user nears its end."

    static let scrolls = false
    static let fills = true

    var examples: [Example] {
        [Example(LoadingList())]
    }
}
