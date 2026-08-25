import StateUI

/// `@State` owns a value, `@Binding` borrows one - the whole of how this library
/// remembers anything.
struct StateSample: SampleContent {
    @State private var counter = 0
    @State private var name = ""

    static let id = "state"
    static let title = "State and bindings"
    static let summary = "A view is rebuilt on every render - and its @State survives that."

    static let code = """
        @State private var counter = 0
        @State private var name = ""

        VStack {
            Label("Count: \\(counter)")
                .horizontalTextAlignment(.center)

            HStack {
                Button("Increment")
                    .onClicked { counter += 1 }

                Button("Reset")
                    .isEnabled(counter != 0)
                    .onClicked { counter = 0 }
            }

            Entry($name)
                .placeholder("And the same for text")

            Label(name.isEmpty ? "Hello, stranger" : "Hello, \\(name)!")
        }
        """

    var content: Element {
        VStack {
            Label("Count: \(counter)")
                .fontSize(22)
                .horizontalTextAlignment(.center)

            HStack {
                Button("Increment")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .onClicked { counter += 1 }

                Button("Reset")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .isEnabled(counter != 0)
                    .onClicked { counter = 0 }
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label("This view is a value, rebuilt on every render - and this @State is "
                + "declared right on it. The same view at the same place keeps its "
                + "state through the rebuild; nothing is invalidated by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Entry($name)
                .placeholder("And the same for text")

            Label(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")
                .fontSize(17)
                .horizontalTextAlignment(.center)

        }
        .spacing(14)
    }

    var notes: Element? {
        Label("A child view borrows a value with @Binding - `$name` lends it - and "
            + "writes through it reach the owner. State lives as long as its owner "
            + "stays in the tree; this gallery keeps its samples in the catalog its "
            + "pages hold, so the count is still here when you come back.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
