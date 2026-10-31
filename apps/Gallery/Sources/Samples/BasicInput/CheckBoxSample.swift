import StateUI

/// A box ticked or not, on its own and several at once.
struct CheckBoxSample: SampleContent, ExampleContent {
    // listing: CheckBoxSample
    @State private var agreed = false
    @State private var extras = [false, false, false]
    // listing: end

    static let id = "checkBox"
    static let title = "CheckBox"
    static let summary = "A box ticked or not, with the words it says beside it."

    // listing: CheckBoxSample
    var body: some View {
        VStack {
            // The ticks are read here, so every box builds this closure.
            DebugInfoLabel()

            CheckBox($agreed)
                .text("I have read the terms")
                .accessibilityIdentifier("checkBox.agreed")
                .tint(Palette.accent)

            Text(agreed ? "Ticked" : "Not ticked")
                .fontSize(15)
                .textColor(agreed ? Palette.accent : Palette.subtle)

            SectionTitle("Several of them")

            ForEach(Array(["Cheese", "Bacon", "Egg"].enumerated()), id: \.offset) { pair in
                let (index, name) = pair
                return CheckBox(extras[index])
                    .text(name)
                    .accessibilityIdentifier("checkBox.extra.\(index)")
                    .tint(Palette.accent)
                    .onToggled { ticked in extras[index] = ticked }
                    .id(name)
            }

            Text(chosen.isEmpty ? "Nothing extra" : "With \(chosen.joined(separator: ", "))")
                .fontSize(15)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Tap the words: they belong to the box, so they tick it, and a screen "
                + "reader calls the box by them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Boxes are independent - tick as many as you like. One choice out of "
                + "several is a `Picker` offered as radio buttons.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: CheckBoxSample
    /// What is ticked, in the order the boxes are drawn.
    private var chosen: [String] {
        ["Cheese", "Bacon", "Egg"].enumerated().filter { extras[$0.offset] }.map { $0.element }
    }
    // listing: end
}
