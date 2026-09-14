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

        // A BORDER ROUND EACH CLOSURE, so what a write rebuilds is a rectangle
        // you can see. The borders are drawing and nothing else: the reader of
        // a value is the VStack whose braces the get sits in, either way.
        Border {
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

                Border {
                    VStack {
                        // And this closure reads `name` alone. Typing rebuilds
                        // it and leaves the one around it standing still;
                        // `$name` lends the value to the Entry and makes a
                        // reader of nobody.
                        DebugInfoLabel()

                        Entry($name)
                            .placeholder("And the same for text")

                        Label(name.isEmpty ? "Hello, stranger" : "Hello, \\(name)!")
                    }
                }
                .stroke(Palette.accent)
                .strokeShape(.roundRectangle(10))
            }
        }
        .stroke(Palette.accent)
        .strokeShape(.roundRectangle(12))
        """

    var content: any View {
        // THE TWO CLOSURES ARE DRAWN, each inside a border of its own, because
        // what a write rebuilds is easier to believe as a rectangle than as a
        // rule. The borders are decoration: the reader of a value is the VStack
        // whose braces the get sits in, and that is where each reading is
        // taken.
        Border {
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
                        .cornerRadius(8)
                        .padding(20, 10)
                        .onClicked { counter += 1 }

                    Button("Reset")
                        .borderColor(Palette.outline)
                        .borderWidth(1)
                        .background(.transparent)
                        .textColor(Palette.subtle)
                        .cornerRadius(8)
                        .padding(20, 10)
                        .isEnabled(counter != 0)
                        .onClicked { counter = 0 }
                }
                .spacing(12)
                .horizontalAlignment(.center)

                Border {
                    VStack {
                        Label("And this one reads `name`")
                            .fontSize(11)
                            .characterSpacing(1)
                            .textColor(Palette.accent)

                        DebugInfoLabel()

                        Entry($name)
                            .automationId("state.name")
                            .semanticDescription("Name")
                            .placeholder("And the same for text")

                        Label(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")
                            .fontSize(17)
                            .horizontalTextAlignment(.center)
                    }
                    .spacing(14)
                }
                .padding(14)
                .stroke(Palette.accent)
                .strokeThickness(1)
                .strokeShape(.roundRectangle(10))
            }
            .spacing(14)
        }
        .padding(14)
        .stroke(Palette.accent)
        .strokeThickness(1)
        .strokeShape(.roundRectangle(12))
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

            Label("The two rectangles are those two closures drawn. The borders are "
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
