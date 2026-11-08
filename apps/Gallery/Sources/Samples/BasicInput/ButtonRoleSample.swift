import StateUI

/// Buttons standing for the window's main action, its way out and an action that destroys something.
struct ButtonRoleSample: SampleContent, ExampleContent {
    // listing: ButtonRoleSample
    @State private var name = ""
    @State private var last = "nothing yet"
    @State private var platformLook = false
    @State private var saveIsMain = true
    // listing: end

    static let id = "buttonRole"
    static let title = "Button role"
    static let summary = "The window's main action, its way out and a destructive one, each looking its role."

    // listing: ButtonRoleSample
    var body: some View {
        // The gallery's style for each role, or the platform's own look.
        let look: StyleKey<Button>? = platformLook ? .platform : nil

        return VStack {
            Text("Press Return or Escape; in the field, Return ends the name instead.")
                .fontSize(14)

            TextField($name)
                .placeholder("Name")
                .onSubmitted { last = "the name \(name)" }

            HStack {
                // Marked as an action that destroys something.
                Button("Delete")
                    .style(look)
                    .role(.destructive)
                    .onClicked { last = "Delete" }

                // Escape presses the way out.
                Button("Cancel")
                    .style(look)
                    .role(.cancel)
                    .onClicked { last = "Cancel" }

                // Return presses the main action; an ordinary button has no key.
                Button("Save")
                    .style(look)
                    .role(saveIsMain ? .primary : .normal)
                    .onClicked { last = "Save" }
            }
            .spacing(12)

            Switch("Save is the main action", isOn: $saveIsMain)

            Switch("Platform look", isOn: $platformLook)

            Text("Last: \(last)")
                .fontSize(13)
                .textColor(Palette.accent)
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("A shortcut the button states takes the place of its role's key. The gallery styles each role over "
            + "its every button's style; Platform look shows the platform's own, and where it has no look for a "
            + "role, the button keeps its plain one.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
