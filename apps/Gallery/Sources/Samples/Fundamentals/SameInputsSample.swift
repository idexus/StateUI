import StateUI

/// A composed view is built again when what it was built with changed, or
/// when a state it read changed - and not otherwise.
struct SameInputsSample: SampleContent, ExampleContent {
    // listing: SameInputsSample
    @State private var counter = 0
    @State private var items = ["Alpha", "Beta", "Gamma"]
    // listing: end

    static let id = "inputs"
    static let title = "Same inputs"
    static let summary = "A view with the same inputs, reading nothing that moved, is not built again when its parent is."

    // listing: SameInputsSample
    var body: some View {
        VStack {
            // This closure reads the count, so a press builds it again - and
            // constructs every view below afresh. Which of them is BUILT is
            // each view's own question.
            DebugInfoLabel()

            Button("Count \(counter)")
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }

            // CARRIED: built with a constant, reading nothing.
            Block(caption: "a constant", value: "fixed", tint: Palette.accent)

            // BUILT AGAIN: the count is what it was built with.
            Block(caption: "the count", value: "\(counter)", tint: Palette.brand)

            // BUILT AGAIN TOO, for the other reason: lent the same state every
            // time, and reading it.
            Reads(count: $counter, tint: Palette.brand)

            Text("Rows built with their item")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            VStack {
                // AND ROWS: each depends on its item and nothing else, so the
                // button builds none of them.
                ForEach(items) { item in
                    Row(item: item)
                        .id(item)
                }
            }
            .spacing(6)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Press the button and read the three counts: the first block stands "
                + "still and the other two move, each for a reason of its own. The rows "
                + "under them are built with their item alone, so the button builds none "
                + "of them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A composed view - a View of your own - is built again when what it "
                + "was built with changed, or when a state it read changed. Otherwise it "
                + "is carried whole, with its state, its handlers and everything under it, "
                + "however often the view around it is built.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("What it was built with is its stored properties - and what its parent "
                + "wrote on it, the objects provided above it and the application's "
                + "styles. A value counts as "
                + "the same when it is equal; a state lent to it - a Binding - when it is "
                + "the same state, whatever the value in it; an object when it is the same "
                + "object. A closure handed to a view always counts as changed: nothing "
                + "can compare two closures, so the view is built to be safe.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The third block shows the other half of the rule. It is lent the same "
                + "state every time, so by its inputs alone it would be carried - but it "
                + "READS that state, and whoever reads a value is built again when it "
                + "changes.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

// listing: SameInputsSample
/// One block: the caption, and the value it was built with. It reads nothing,
/// so what it is built with alone decides whether it is built again.
private struct Block: View {
    let caption: String
    let value: String
    let tint: Color

    var body: some View {
        VStack {
            Text("Built with \(caption)")
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(tint)

            Text(value)
                .fontSize(20)
                .fontAttributes(.bold)

            DebugInfoLabel()
        }
        .spacing(4)
        .padding(14)
    }
}
// listing: end

// listing: SameInputsSample
/// A block lent the count, and reading it.
private struct Reads: View {
    @Binding var count: Int
    let tint: Color

    var body: some View {
        VStack {
            Text("Reads the count")
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(tint)

            Text("\(count)")
                .fontSize(20)
                .fontAttributes(.bold)

            DebugInfoLabel()
        }
        .spacing(4)
        .padding(14)
    }
}
// listing: end

// listing: SameInputsSample
/// One row, built with its item and nothing else.
private struct Row: View {
    let item: String

    var body: some View {
        VStack {
            Text(item)
                .fontSize(15)

            DebugInfoLabel()
        }
        .spacing(2)
        .padding(horizontal: 12, vertical: 8)
    }
}
// listing: end
