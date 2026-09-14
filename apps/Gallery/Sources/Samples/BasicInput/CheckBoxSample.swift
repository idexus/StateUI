import StateUI

/// A box ticked or not, on its own and several at once.
struct CheckBoxSample: SampleContent, ExampleContent {
    @State private var agreed = false
    @State private var extras = [false, false, false]

    static let id = "checkBox"
    static let title = "CheckBox"
    static let summary = "A box ticked or not, with no caption of its own."

    static let code = """
        @State private var agreed = false
        @State private var extras = [false, false, false]

        VStack {
            // The ticks are read here, so every box builds this closure.
            DebugInfoLabel()

            HStack {
                CheckBox($agreed)

                Label("I have read the terms")
                    .verticalAlignment(.center)
            }

            Label(agreed ? "Ticked" : "Not ticked")

            ForEach(Array(["Cheese", "Bacon", "Egg"].enumerated()), id: \\.offset) { pair in
                let (index, name) = pair
                return HStack {
                    CheckBox(extras[index])
                        .onToggled { ticked in extras[index] = ticked }

                    Label(name)
                        .verticalAlignment(.center)
                }
                .id(name)
            }

            Label(chosen.isEmpty ? "Nothing extra" : "With \\(chosen.joined(separator: ", "))")
        }

        /// What is ticked, in the order the boxes are drawn.
        private var chosen: [String] {
            ["Cheese", "Bacon", "Egg"].enumerated().filter { extras[$0.offset] }.map { $0.element }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            HStack {
                CheckBox($agreed)
                    .automationId("checkBox.agreed")
                    .semanticDescription("Agreed")
                    .color(Palette.accent)

                Label("I have read the terms")
                    .fontSize(15)
                    .verticalAlignment(.center)
            }
            .spacing(4)

            Label(agreed ? "Ticked" : "Not ticked")
                .fontSize(15)
                .textColor(agreed ? Palette.accent : Palette.subtle)

            SectionTitle("Several of them")

            ForEach(Array(["Cheese", "Bacon", "Egg"].enumerated()), id: \.offset) { pair in
                let (index, name) = pair
                return HStack {
                    CheckBox(extras[index])
                        .automationId("checkBox.extra.\(index)")
                        .semanticDescription(name)
                        .color(Palette.accent)
                        .onToggled { ticked in extras[index] = ticked }

                    Label(name)
                        .fontSize(15)
                        .verticalAlignment(.center)
                }
                .spacing(4)
                .id(name)
            }

            Label(chosen.isEmpty ? "Nothing extra" : "With \(chosen.joined(separator: ", "))")
                .fontSize(15)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A `CheckBox` is the box and nothing else: it has no caption, so the words "
                + "beside it are a `Label`. Tapping the words does nothing; that is the "
                + "platform's behaviour.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Boxes are independent - tick as many as you like. One choice out of "
                + "several is a `RadioButton`.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// What is ticked, in the order the boxes are drawn.
    private var chosen: [String] {
        ["Cheese", "Bacon", "Egg"].enumerated().filter { extras[$0.offset] }.map { $0.element }
    }
}
