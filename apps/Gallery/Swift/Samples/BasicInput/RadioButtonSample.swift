import StateUI

/// MAUI: RadioButton.
struct RadioButtonSample: SampleContent {
    @State private var size = "Medium"

    static let id = "radioButton"
    static let title = "RadioButton"
    static let summary = "One choice out of several - the group is what makes it exclusive."

    static let code = """
        @State private var size = "Medium"

        VStack {
            ForEach(["Small", "Medium", "Large"]) { name in
                RadioButton(name)
                    .groupName("size")
                    .isChecked(size == name)
                    // Fires on the button that WAS chosen too, with false - so
                    // the state is written only by the one that won.
                    .onCheckedChanged { chosen in
                        if chosen {
                            size = name
                        }
                    }
                    .id(name)
            }

            Label("Chosen: \\(size)")
        }
        """

    var example: Element {
        VStack {
            ForEach(sizes) { name in
                RadioButton(name)
                    .groupName("size")
                    .isChecked(size == name)
                    // Fires on the button that WAS chosen too, with false - so
                    // the state is written only by the one that won.
                    .onCheckedChanged { chosen in
                        if chosen {
                            size = name
                        }
                    }
                    .id(name)
            }

            Label("Chosen: \(size)")
                .fontSize(17)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("MAUI unchecks the others in the same `groupName` and reports BOTH "
                + "changes - false on the button that lost, true on the new one. So a "
                + "handler that writes only when it hears true is the whole of it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The caption is `content`, not `text`: MAUI's RadioButton has no Text "
                + "property, and this library does not invent one.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    private var sizes: [String] { ["Small", "Medium", "Large"] }
}
