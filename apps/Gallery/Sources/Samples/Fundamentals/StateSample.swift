import StateUI

/// `@State` owns a value, `@Binding` borrows one - the whole of how this library
/// remembers anything.
struct StateSample: SampleContent, ExampleContent {
    @State private var counter = 0
    @State private var name = ""

    static let id = "state"
    static let title = "State and bindings"
    static let summary = "A view is rebuilt on every render - and its @State survives that."

    static let code = """
        @State private var counter = 0
        @State private var name = ""

        // AN OUTLINE ROUND EACH CLOSURE, so what a write rebuilds is a rectangle
        // you can see. The outlines are drawing and nothing else: the reader of
        // a value is the VStack whose braces the get sits in, either way.
        ZStack {
            VStack {
                // THIS closure reads `counter`, so a write to it rebuilds THIS
                // closure - and the reading says `for counter`.
                DebugInfoLabel()

                Label("Count: \\(counter)")
                    .horizontalTextAlignment(.center)

                HStack {
                    Button("Increment")
                        .onClicked { counter += 1 }

                    Button("Reset")
                        .isEnabled(counter != 0)
                        .onClicked { counter = 0 }
                }

                ZStack {
                    VStack {
                        // And this closure reads `name` alone. Typing rebuilds
                        // it and leaves the one around it standing still;
                        // `$name` lends the value to the TextField and makes a
                        // reader of nobody.
                        DebugInfoLabel()

                        TextField($name)
                            .placeholder("And the same for text")

                        Label(name.isEmpty ? "Hello, stranger" : "Hello, \\(name)!")
                    }
                }
                .style("Card")
                .stroke(Palette.accent)
                .shape(.roundedRectangle(10))
            }
        }
        .style("Card")
        .stroke(Palette.accent)
        .shape(.roundedRectangle(12))
        """

    var content: any View {
        // THE TWO CLOSURES ARE DRAWN, each inside an outline of its own, because
        // what a write rebuilds is easier to believe as a rectangle than as a
        // rule. The outlines are decoration: the reader of a value is the VStack
        // whose braces the get sits in, and that is where each reading is
        // taken.
        ZStack {
            VStack {
                Label("This closure reads `counter`")
                    .fontSize(11)
                    .characterSpacing(1)
                    .textColor(Palette.accent)

                DebugInfoLabel()

                Label("Count: \(counter)")
                    .fontSize(22)
                    .horizontalTextAlignment(.center)

                HStack {
                    Button("Increment")
                        .background(Palette.accent)
                        .shape(.roundedRectangle(8))
                        .padding(20, 10)
                        .onClicked { counter += 1 }

                    Button("Reset")
                        .stroke(Palette.outline)
                        .strokeWidth(1)
                        .background(.transparent)
                        .textColor(Palette.subtle)
                        .shape(.roundedRectangle(8))
                        .padding(20, 10)
                        .isEnabled(counter != 0)
                        .onClicked { counter = 0 }
                }
                .spacing(12)
                .horizontalAlignment(.center)

                ZStack {
                    VStack {
                        Label("And this one reads `name`")
                            .fontSize(11)
                            .characterSpacing(1)
                            .textColor(Palette.accent)

                        DebugInfoLabel()

                        TextField($name)
                            .accessibilityIdentifier("state.name")
                            .accessibilityLabel("Name")
                            .placeholder("And the same for text")

                        Label(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")
                            .fontSize(17)
                            .horizontalTextAlignment(.center)
                    }
                    .spacing(14)
                }
                .style("Card")
                .padding(14)
                .stroke(Palette.accent)
                .strokeWidth(1)
                .shape(.roundedRectangle(10))
            }
            .spacing(14)
        }
        .style("Card")
        .padding(14)
        .stroke(Palette.accent)
        .strokeWidth(1)
        .shape(.roundedRectangle(12))
    }

    var notes: Element? {
        VStack {
            Label("This view is a value, rebuilt on every render, and its @State is "
                + "declared right on it. The same view at the same place keeps its state "
                + "through the rebuild; nothing is invalidated by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A child view borrows a value with @Binding - `$name` lends it - and "
                + "writes through it reach the owner. Lending makes no reader: what makes "
                + "a reader is reading the value inside a closure, and only that closure "
                + "is rebuilt when the value is written.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The two rectangles are those two closures drawn. The outlines are "
                + "decoration: the reader is the VStack whose braces the get sits in. "
                + "Increment rebuilds the outer closure and the inner one goes with it, "
                + "which is what `with its parent` means; typing rebuilds the inner "
                + "closure alone and leaves the one around it standing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("State lives as long as its owner stays in the tree. This gallery keeps "
                + "its samples in the catalog its pages hold, so the count is still here "
                + "when you come back.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
