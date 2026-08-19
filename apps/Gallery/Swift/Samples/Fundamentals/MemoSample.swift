import StateUI

/// A subtree that is not rebuilt while its input is unchanged.
struct MemoSample: SampleContent {
    @State private var counter = 0
    @State private var items = ["Alpha", "Beta", "Gamma"]

    static let id = "memo"
    static let title = "Memoization"
    static let summary = "Skipping a subtree the differ would otherwise walk, compare and send."

    static let code = """
        @State private var counter = 0
        @State private var items = ["Alpha", "Beta", "Gamma"]

        VStack {
            Label("Count: \\(counter) - the rows below are not rebuilt by it")

            Button("Increment the count")
                .onClicked { counter += 1 }

            // Built only when `item` changes. Incrementing the counter
            // re-renders this page, and these rows are not built, not
            // compared and not sent.
            VStack {
                ForEach(items) { item in
                    MemoRow(item: item)
                        .memoized(by: item)
                        .id(item)
                }
            }
        }

        private struct MemoRow: ContentView {
            let item: String

            var content: Element {
                Label(item)
            }
        }
        """

    var content: Element {
        VStack {
            Label("Count: \(counter) - the rows below are not rebuilt by it")
                .fontSize(14)
                .horizontalTextAlignment(.center)

            Button("Increment the count")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { counter += 1 }

            // Built only when `item` changes. Incrementing the counter
            // re-renders this page, and these rows are not built, not compared
            // and not sent - the promise being that the row reads nothing else.
            VStack {
                ForEach(items) { item in
                    MemoRow(item: item)
                        .memoized(by: item)
                        .id(item)
                }
            }
            .spacing(6)

            Label("`.memoized(by:)` promises the view reads nothing but its input. "
                + "Reading state is still fine: a State is a reference, and a handler "
                + "reads it when it fires.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// One memoized row, factored out so there is a whole subtree to skip.
private struct MemoRow: ContentView {
    let item: String

    var content: Element {
        Label(item)
            .fontSize(15)
            .padding(12, 8)
    }
}
