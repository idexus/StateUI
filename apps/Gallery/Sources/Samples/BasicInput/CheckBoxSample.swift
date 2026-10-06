import StateUI

/// A box ticked or not, on its own and several at once.
struct CheckBoxSample: SampleContent, ExampleContent {
    // listing: CheckBoxSample
    @State private var agreed = false
    @State private var extras = [false, false, false]
    // listing: end

    static let id = "checkBox"
    static let title = "CheckBox"
    static let summary = "A box ticked or not, with no caption of its own."

    // listing: CheckBoxSample
    var body: some View {
        VStack {
            // The ticks are read here, so every box builds this closure.
            DebugInfoLabel()

            HStack {
                CheckBox($agreed)
                    .accessibilityIdentifier("checkBox.agreed")
                    .accessibilityLabel("Agreed")
                    .tint(Palette.accent)

                Text("I have read the terms")
                    .fontSize(15)
                    .verticalAlignment(.center)
            }
            .spacing(4)

            Text(agreed ? "Ticked" : "Not ticked")
                .fontSize(15)
                .textColor(agreed ? Palette.accent : Palette.subtle)

            SectionTitle("Several of them")

            ForEach(Array(["Cheese", "Bacon", "Egg"].enumerated()), id: \.offset) { pair in
                let (index, name) = pair
                return HStack {
                    CheckBox(extras[index])
                        .accessibilityIdentifier("checkBox.extra.\(index)")
                        .accessibilityLabel(name)
                        .tint(Palette.accent)
                        .onToggled { ticked in extras[index] = ticked }

                    Text(name)
                        .fontSize(15)
                        .verticalAlignment(.center)
                }
                .spacing(4)
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
            Text("A `CheckBox` is the box and nothing else: it has no caption, so the words "
                + "beside it are a `Text`. Tapping the words does nothing; that is the "
                + "platform's behaviour.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Boxes are independent - tick as many as you like. One choice out of "
                + "several is a `RadioButton`.")
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
