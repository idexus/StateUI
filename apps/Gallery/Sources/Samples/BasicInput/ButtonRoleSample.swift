import StateUI

/// Buttons standing for the window's main action, its way out and an action that destroys something.
struct ButtonRoleSample: SampleContent, ExampleContent {
    // listing: ButtonRoleSample
    @State private var name = ""
    @State private var last = "nothing yet"
    // listing: end

    static let id = "buttonRole"
    static let title = "Button role"
    static let summary = "The window's main action, its way out and a destructive one, as the platform draws them."

    // listing: ButtonRoleSample
    var body: some View {
        VStack {
            Text("Press Return or Escape; in the field, Return ends the name instead.")
                .fontSize(14)

            TextField($name)
                .placeholder("Name")
                .onSubmitted { last = "the name \(name)" }

            HStack {
                // Drawn as the platform marks an action that destroys something.
                Button("Delete")
                    .style(.platform)
                    .role(.destructive)
                    .onClicked { last = "Delete" }

                // Escape presses the way out.
                Button("Cancel")
                    .style(.platform)
                    .role(.cancel)
                    .onClicked { last = "Cancel" }

                // Return presses the main action, drawn with the platform's emphasis.
                Button("Save")
                    .style(.platform)
                    .role(.primary)
                    .onClicked { last = "Save" }
            }
            .spacing(12)

            Text("Last: \(last)")
                .fontSize(13)
                .textColor(Palette.accent)
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("A shortcut the button states takes the place of its role's key. Where a platform has no look for a "
            + "role, the button keeps its plain one. These buttons wear the platform's own look, not the gallery's.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
