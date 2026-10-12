import StateUI

/// A button opening its menu, and a split button: its click its own action, its menu apart.
struct ButtonMenuSample: SampleContent, ExampleContent {
    // listing: ButtonMenuSample
    @State private var last = "nothing yet"
    // listing: end

    static let id = "buttonMenu"
    static let title = "Button menu"
    static let summary = "A button opening a menu, and a split button with an action of its own."

    // listing: ButtonMenuSample
    var body: some View {
        VStack {
            Text("Share opens its menu. Save saves with a click, and offers more in its menu.")
                .fontSize(14)

            HStack {
                Button("Share").menu {
                    MenuItem("Mail").onClicked { last = "Share by mail" }
                    MenuItem("Message").onClicked { last = "Share by message" }
                    MenuSeparator()
                    MenuItem("Copy link").onClicked { last = "Link copied" }
                }

                Button("Save")
                    .onClicked { last = "Saved" }
                    .menu {
                        MenuItem("Save as…").onClicked { last = "Saved as" }
                        MenuItem("Save a copy").onClicked { last = "Saved a copy" }
                    }
            }
            .spacing(12)

            Text("Last: \(last)")
                .fontSize(14)
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("Where the platform draws no split button, Save's menu opens with a long press or a right click.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
