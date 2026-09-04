import StateUI

/// Loading a list a batch at a time, as the reader nears the end.
struct IncrementalLoadSample: SampleContent {
    @State private var items: [Int] = []
    @State private var batches = 0

    static let id = "incrementalLoad"
    static let title = "Incremental loading"
    static let summary = "The list asks for more as you near the end - a batch at a time, up to 300."

    // The list scrolls itself, so the page holds still and scrolls the code.
    static let scrolls = false
    static let fills = true

    static let code = """
        @State private var items: [Int] = []
        @State private var batches = 0

        // The next batch, 30 at a time up to 300. The guard matters: the
        // list asks once per row the window moves by, and this is what
        // absorbs the repeats.
        private func load() {
            guard items.count < 300 else { return }
            batches += 1
            items += Array(items.count + 1 ... items.count + 30)
        }

        // A STAR row is what gives the list its height - it takes whatever
        // the chrome above it leaves. Row 0 is the default, so only the list
        // has to say where it is.
        Grid {
            VStack {
                Label("Batch \\(batches) - \\(items.count) of 300 rows loaded.")

                Button("Restart").onClicked {
                    batches = 0
                    items = []
                    load()
                }
            }

            // Nearing the end - within 8 rows nobody has scrolled to yet -
            // runs the handler, which appends the next batch. The FIRST batch
            // is the author's, from onLoaded: an empty list has nothing to
            // scroll, so nothing asks.
            CollectionView(items) { number in
                Label("Row \\(number)")
            }
            .remainingItemsThreshold(8)
            .onRemainingItemsThresholdReached {
                load()
            }
            .onLoaded {
                if items.isEmpty { load() }
            }
            .gridRow(1)
        }
        .rowDefinitions(.auto, .star)
        """

    /// The next batch, 30 at a time up to 300. The guard matters: the list
    /// asks once per row the window moves by, and this is what absorbs the
    /// repeats.
    private func load() {
        guard items.count < 300 else { return }
        batches += 1
        items += Array(items.count + 1 ... items.count + 30)
    }

    var example: Element {
        Grid {
            VStack {
                Label("Batch \(batches) - \(items.count) of 300 rows loaded.")
                    .fontSize(13)
                    .horizontalOptions(.center)

                Button("Restart")
                    .fontSize(13)
                    .horizontalOptions(.center)
                    .onClicked {
                        batches = 0
                        items = []
                        load()
                    }
            }
            .spacing(10)
            .gridRow(0)

            CollectionView(items) { number in
                Label("Row \(number)")
                    .fontSize(14)
                    .padding(12, 9)
                    .verticalOptions(.center)
            }
            .remainingItemsThreshold(8)
            .onRemainingItemsThresholdReached {
                load()
            }
            .gridRow(1)
            .onLoaded {
                if items.isEmpty { load() }
            }

        }
        .rowDefinitions(.auto, .star)
        .rowSpacing(10)
    }

    var notes: Element? {
        VStack {
            Label("Scrolling to within 8 rows of the end runs the handler, which appends 30 "
                + "more. The FIRST batch is the author's, from onLoaded: an empty list has "
                + "nothing to scroll, so nothing asks. The handler's own guard is what stops "
                + "it at 300 - the list asks once per row the window moves by, which is far "
                + "calmer than a platform engine asking on every scroll tick, but it is "
                + "still more than once.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("What an appended batch does NOT do is move the scroll: the list's height "
                + "is the count times the row height, so a batch at the end makes the "
                + "content taller and touches nothing the reader is looking at. Restart is "
                + "the same arithmetic backwards - the list shrinks, the reader lands within "
                + "the threshold again, and the next batch loads on the next row crossed.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
