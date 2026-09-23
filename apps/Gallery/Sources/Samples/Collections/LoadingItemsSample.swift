#if MAUI
import StateUI

/// A list that asks for more as the user nears its end.
private struct LoadingList: ExampleContent {
    @State private var count = 30

    /// Whether a batch is on its way, which is what the handler guards on.
    @State private var loading = false

    static let code = """
        @State private var count = 30
        @State private var loading = false

        Grid {
            // The tally and Start over stay at the top, where they are in
            // reach however far down the list the user has gone.
            HStack {
                Label(loading ? "Loading" : "\\(count) items")

                Button("Start over")
                    .isEnabled(count > 30)
                    .onClicked { count = 30 }
            }
            .gridRow(0)

            DebugInfoLabel()
                .gridRow(0)

            ItemsView(0..<count) { number in
                Label("Item \\(number + 1)").padding(14, 10)
            }
            // Within five items of the end: the next batch is appended, and is
            // there when the user arrives.
            .onEndReached(within: 5) {
                // Asked more than once while the user stays near the end, so
                // the handler guards on what it is already doing.
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

    var content: any View {
        Grid {
            HStack {
                Label(loading ? "Loading" : "\(count) items")
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
                Label("Item \(number + 1)")
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

    var notes: Element? {
        Label("Scroll towards the end: within five items of it the next thirty arrive, up "
            + "to three hundred. Start over is at the top, in reach from anywhere in the "
            + "list.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A list that grows as the user reaches its end.
struct LoadingItemsSample: SampleContent {
    static let id = "loadingItems"
    static let title = "Loading more items"
    static let summary = "A list that asks for more as the user nears its end."

    // The example IS a scroller, so the page does not put one inside another -
    // and it takes the window's height, since a list is worth as many rows as
    // there is room for.
    static let scrolls = false
    static let fills = true

    var examples: [Example] {
        [Example(LoadingList())]
    }
}
#endif
