import StateUI

/// A list that asks for thirty more as the user nears its end.
private struct LoadingList: ExampleContent {
    // listing: LoadingList
    @State private var first = 0
    @State private var count = 30
    @State private var asked = 0
    @State private var loading = false

    var body: some View {
        Grid {
            HStack {
                Button("Start over")
                    .isEnabled(first > 0 || count > 30)
                    .onClicked {
                        first = 0
                        count = 30
                        asked = 0
                    }

                Button("Other items")
                    .onClicked { first += 1000 }

                Text(loading ? "Loading" : "\(count) items, asked \(asked) times")
                    .fontSize(13)
                    .textColor(Palette.accent)
                    .verticalAlignment(.center)
            }
            .spacing(12)
            .gridRow(0)

            DebugInfoLabel()
                .gridRow(0)

            ItemsView(first..<first + count) { number in
                Text("Item \(number + 1)")
                    .fontSize(14)
                    .padding(horizontal: 14, vertical: 10)
            }
            // Within five items of the end, thirty more - one load at a time:
            // reaching the end again while one runs lets that go. Other items
            // swaps them for as many others, and the end asks again.
            .onEndReached(within: 5, policy: .ignoreWhileRunning) {
                asked += 1
                guard count < 300 else { return }

                loading = true
                try await Task.sleep(for: .milliseconds(400))
                count += 30
                loading = false
            }
            .gridRow(1)
        }
        .rows(.automatic, .fill)
        .rowSpacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Scroll towards the end: thirty more arrive, up to three hundred. Other items swaps them, and the end asks again.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A short list in a room that opens: its end is reached once its rows show, not before.
private struct ShortList: ExampleContent {
    // listing: ShortList
    @State private var shown = false
    @State private var asked = 0

    var body: some View {
        VStack {
            HStack {
                Switch("Show the list", isOn: $shown)
                    .accessibilityIdentifier("loading.short.shown")

                Text("asked \(asked) times")
                    .fontSize(13)
                    .textColor(Palette.accent)
                    .accessibilityIdentifier("loading.short.asked")
                    .verticalAlignment(.center)
            }
            .spacing(12)

            // Three items, all within five of the end - but while the list
            // has no room, it shows none of them, and no end is reached.
            ItemsView(0..<3) { number in
                Text("Item \(number + 1)")
                    .fontSize(14)
                    .padding(horizontal: 14, vertical: 10)
            }
            .onEndReached(within: 5) { asked += 1 }
            .height(shown ? 160 : 0)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("The list stands with no room until the switch shows it: three items, every one within five of the "
            + "end, and still no end is reached while none of them shows - the end comes once the rows do.")
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
        [Example(LoadingList()), Example(ShortList())]
    }
}
