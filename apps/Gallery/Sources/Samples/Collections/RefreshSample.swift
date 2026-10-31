import StateUI

/// A list pulled down for what is new: fresh items arrive at its top.
private struct RefreshingList: ExampleContent {
    // listing: RefreshingList
    @State private var items = ["Weekly notes", "Old news"]
    @State private var refreshing = false
    @State private var fetched = 0

    var body: some View {
        Grid {
            HStack {
                // Where the platform has no pull, a command refreshes - its spinner showing where it has one.
                Button("Refresh")
                    .isEnabled(!refreshing)
                    .onClicked(.ignoreWhileRunning) { try await fetch() }

                Button("Clear")
                    .onClicked { items = [] }

                Text(refreshing ? "Refreshing" : items.count == 1 ? "1 item" : "\(items.count) items")
                    .fontSize(13)
                    .textColor(Palette.accent)
                    .verticalAlignment(.center)
            }
            .spacing(12)
            .gridRow(0)

            ItemsView(items, id: \.self) { item in
                Text(item)
                    .fontSize(14)
                    .padding(horizontal: 14, vertical: 10)
            }
            // An empty list keeps its pull.
            .emptyView(Text("Nothing yet").textColor(Palette.subtle))
            .isRefreshing($refreshing)
            .onRefreshRequested(.ignoreWhileRunning) { try await fetch() }
            .gridRow(1)
        }
        .rows(.auto, .fill)
        .rowSpacing(10)
    }

    /// Fetches what is new, the spinner showing until it is in.
    private func fetch() async throws {
        refreshing = true
        defer { refreshing = false }
        try await Task.sleep(for: .milliseconds(900))
        fetched += 1
        items.insert("Fresh \(fetched)", at: 0)
    }
    // listing: end

    var notes: (any View)? {
        Text("Pull the list down - or press Refresh: what is new arrives at its top.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A list the user pulls down for what is new.
struct RefreshSample: SampleContent {
    static let id = "pullToRefresh"
    static let title = "Pull to refresh"
    static let summary = "A list the user pulls down for what is new, its spinner showing until it is in."

    static let scrolls = false
    static let fills = true

    var examples: [Example] {
        [Example(RefreshingList())]
    }
}
