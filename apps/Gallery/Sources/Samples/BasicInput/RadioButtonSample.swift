import StateUI

/// Three buttons in one group, with one state for what is chosen.
struct RadioButtonSample: SampleContent, ExampleContent {
    @State private var size = "Medium"

    static let id = "radioButton"
    static let title = "RadioButton"
    static let summary = "One choice out of several - the group is what makes it exclusive."

    static let code = """
        @State private var size = "Medium"

        VStack {
            // The chosen one is read here, so picking builds this closure.
            DebugInfoLabel()

            ForEach(["Small", "Medium", "Large"]) { name in
                RadioButton(name)
                    .groupName("size")
                    .isOn(size == name)
                    // Fires on the button that WAS chosen too, with false - so
                    // the state is written only by the one that won.
                    .onToggled { chosen in
                        if chosen {
                            size = name
                        }
                    }
                    .id(name)
            }

            Text("Chosen: \\(size)")
        }
        """

    var content: some View {
        VStack {
            DebugInfoLabel()

            ForEach(sizes) { name in
                RadioButton(name)
                    .groupName("size")
                    .isOn(size == name)
                    // Fires on the button that WAS chosen too, with false - so
                    // the state is written only by the one that won.
                    .onToggled { chosen in
                        if chosen {
                            size = name
                        }
                    }
                    .id(name)
            }

            Text("Chosen: \(size)")
                .fontSize(17)
        }
        .spacing(12)
    }

    var notes: (any View)? {
        VStack {
            Text("Picking one unchecks the others in the same `groupName`, and BOTH changes "
                + "are reported - false on the button that lost, true on the new one. So a "
                + "handler that writes only when it hears true is the whole of it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("One `@State` holds the whole group's choice rather than one Bool per "
                + "button: what is chosen is a single value, and each button is checked "
                + "when it matches it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    private var sizes: [String] { ["Small", "Medium", "Large"] }
}
