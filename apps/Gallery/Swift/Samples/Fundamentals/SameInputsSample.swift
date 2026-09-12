import StateUI

/// A composed view is built again when what it was built with changed, or
/// when a state it read changed - and not otherwise.
struct SameInputsSample: SampleContent {
    @State private var counter = 0
    @State private var items = ["Alpha", "Beta", "Gamma"]

    static let id = "inputs"
    static let title = "Same inputs"
    static let summary =
        "A view built with the same inputs is not built again, however often the "
        + "view around it is - and what counts as the same."

    static let code = """
        @State private var counter = 0
        @State private var items = ["Alpha", "Beta", "Gamma"]

        VStack {
            // This closure reads the count, so a press builds it again -
            // and constructs every view below afresh. Which of them is BUILT
            // is each view's own question.
            DebugInfoLabel()

            Button("Count \\(counter)")
                .onClicked { counter += 1 }

            // CARRIED: built with a constant, reading nothing. Its count
            // stays at one for good.
            Block(caption: "a constant", value: "fixed")

            // BUILT AGAIN: the count is what it was built with.
            Block(caption: "the count", value: "\\(counter)")

            // BUILT AGAIN TOO, for the other reason: it is lent the same
            // state every time - that input never changes - but it READS it.
            Reads(count: $counter)

            // AND ROWS: each depends on its item and nothing else, so the
            // button builds none of them.
            ForEach(items) { item in
                Row(item: item)
                    .id(item)
            }
        }

        private struct Block: ContentView {
            let caption: String
            let value: String

            var content: any View {
                VStack {
                    Label("built with \\(caption): \\(value)")
                    DebugInfoLabel()
                }
            }
        }

        private struct Reads: ContentView {
            @Binding var count: Int

            var content: any View {
                VStack {
                    Label("reads the count: \\(count)")
                    DebugInfoLabel()
                }
            }
        }

        private struct Row: ContentView {
            let item: String

            var content: any View {
                VStack {
                    Label(item)
                    DebugInfoLabel()
                }
            }
        }
        """

    var content: any View {
        VStack {
            // This closure reads the count, so a press builds it again - and
            // constructs every view below afresh. Which of them is BUILT is
            // each view's own question.
            DebugInfoLabel()

            Button("Count \(counter)")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { counter += 1 }

            Label("Three views under one button. Press it and read the three counts: "
                + "the first stands still, the other two move - each for a reason of its own.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            // CARRIED: built with a constant, reading nothing.
            Block(caption: "A CONSTANT", value: "fixed", tint: Palette.accent)

            // BUILT AGAIN: the count is what it was built with.
            Block(caption: "THE COUNT", value: "\(counter)", tint: Palette.brand)

            // BUILT AGAIN TOO, for the other reason: lent the same state every
            // time, and reading it.
            Reads(count: $counter, tint: Palette.brand)

            Label("Rows built with their item - the button builds none of them")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            VStack {
                ForEach(items) { item in
                    Row(item: item)
                        .id(item)
                }
            }
            .spacing(6)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A composed view - a ContentView of your own - is built again in two "
                + "cases and no other: when what it was built with changed, or when a "
                + "state it read changed. Otherwise it is carried whole, with its state, "
                + "its handlers and everything under it, however often the view around it "
                + "is built.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("What it was built with is its stored properties. A value counts as "
                + "the same when it is equal; a state lent to it - a Binding - when it is "
                + "the same state, whatever the value in it; an object when it is the same "
                + "object. A closure handed to a view always counts as changed: nothing "
                + "can compare two closures, so the view is built to be safe.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The third block shows the other half of the rule. Its one input is the "
                + "same state every time, so by its inputs alone it would be carried - "
                + "but it READS that state, and whoever reads a value is built again when "
                + "it changes.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// One block: the caption, and the value it was built with. Whether it is
/// built again is decided by that value alone, which is what its own reading
/// says.
private struct Block: ContentView {
    let caption: String
    let value: String
    let tint: Color

    var content: any View {
        VStack {
            Label("BUILT WITH \(caption)")
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(tint)

            Label(value)
                .fontSize(20)
                .fontAttributes(.bold)

            DebugInfoLabel()
        }
        .spacing(4)
        .padding(14)
    }
}

/// A block lent the count, and reading it.
private struct Reads: ContentView {
    @Binding var count: Int
    let tint: Color

    var content: any View {
        VStack {
            Label("READS THE COUNT")
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(tint)

            Label("\(count)")
                .fontSize(20)
                .fontAttributes(.bold)

            DebugInfoLabel()
        }
        .spacing(4)
        .padding(14)
    }
}

/// One row, built with its item and nothing else.
private struct Row: ContentView {
    let item: String

    var content: any View {
        VStack {
            Label(item)
                .fontSize(15)

            DebugInfoLabel()
        }
        .spacing(2)
        .padding(12, 8)
    }
}
