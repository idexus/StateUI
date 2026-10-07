import StateUI

/// `@State` owns a value, `@Binding` borrows one - the whole of how this library
/// remembers anything.
struct StateSample: SampleContent, ExampleContent {
    // listing: StateSample
    @State private var counter = 0
    @State private var name = ""
    // listing: end

    static let id = "state"
    static let title = "State and bindings"
    static let summary = "A view is a value, made again and again - and its @State survives that."

    // listing: StateSample
    var body: some View {
        // THE TWO CLOSURES ARE DRAWN, each inside an outline of its own, because
        // what a write rebuilds is easier to believe as a rectangle than as a
        // rule. The outlines are decoration: the reader of a value is the VStack
        // whose braces the get sits in, and that is where each reading is
        // taken.
        ZStack {
            VStack {
                Text("This closure reads `counter`")
                    .fontSize(11)
                    .tracking(1)
                    .textColor(Palette.accent)

                // THIS closure reads `counter`, so a write to it rebuilds THIS
                // closure - and the reading says `for counter`.
                DebugInfoLabel()

                Text("Count: \(counter)")
                    .fontSize(22)
                    .horizontalTextAlignment(.center)

                HStack {
                    Button("Increment")
                        .onClicked { counter += 1 }

                    Button("Reset")
                        .isEnabled(counter != 0)
                        .onClicked { counter = 0 }
                }
                .spacing(12)
                .horizontalAlignment(.center)

                ZStack {
                    VStack {
                        Text("And this one reads `name`")
                            .fontSize(11)
                            .tracking(1)
                            .textColor(Palette.accent)

                        DebugInfoLabel()

                        TextField($name)
                            .accessibilityIdentifier("state.name")
                            .accessibilityLabel("Name")
                            .placeholder("And the same for text")

                        Text(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")
                            .fontSize(17)
                            .horizontalTextAlignment(.center)
                    }
                    .spacing(14)
                }
                .style("Card")
                .padding(14)
                .stroke(Palette.accent)
                .lineWidth(1)
                .shape(.roundedRectangle(10))
            }
            .spacing(14)
        }
        .style("Card")
        .padding(14)
        .stroke(Palette.accent)
        .lineWidth(1)
        .shape(.roundedRectangle(12))
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("This view is a value, made afresh whenever the closure around it runs, "
                + "and its @State is declared right on it. The same view at the same place "
                + "keeps its state through every build; nothing is invalidated by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A child view borrows a value with @Binding - `$name` lends it - and "
                + "writes through it reach the owner. Lending makes no reader: what makes "
                + "a reader is reading the value inside a closure, and only that closure "
                + "is rebuilt when the value is written.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The two rectangles are those two closures drawn. The outlines are "
                + "decoration: the reader is the VStack whose braces the get sits in. "
                + "Increment rebuilds the outer closure and the inner one goes with it, "
                + "which is what `with its parent` means; typing rebuilds the inner "
                + "closure alone and leaves the one around it standing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("State lives as long as its owner is held - by the tree, or here by the "
                + "catalog each gallery window keeps, so the count is still here when you "
                + "come back.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
