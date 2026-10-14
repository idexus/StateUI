import StateUI

/// A button opening its menu, a split button, a button whose menu is held, and a menu's arrow shown or not.
struct ButtonMenuSample: SampleContent, ExampleContent {
    // listing: ButtonMenuSample
    @State private var last = "nothing yet"
    @State private var showsArrow = true
    @State private var platformLook = false
    // listing: end

    static let id = "buttonMenu"
    static let title = "Button menu"
    static let summary = "A button opening a menu, a split button, and a menu held."

    // listing: ButtonMenuSample
    var body: some View {
        // The platform's own buttons, or the gallery's every button wears.
        let look: StyleKey<Button>? = platformLook ? .platform : nil

        return VStack {
            Text("Share opens its menu. Save saves, its arrow offers more. Hold Open for a recent file.")
                .fontSize(14)

            HStack {
                Button("Share").style(look).menu {
                    MenuItem("Mail").onClicked { last = "Share by mail" }
                    MenuItem("Message").onClicked { last = "Share by message" }
                    MenuSeparator()
                    MenuItem("Copy link").onClicked { last = "Link copied" }
                }

                Button("Save")
                    .style(look)
                    .onClicked { last = "Saved" }
                    .menu {
                        MenuItem("Save as…").onClicked { last = "Saved as" }
                        MenuItem("Save a copy").onClicked { last = "Saved a copy" }
                    }

                Button("Open")
                    .style(look)
                    .onClicked { last = "Opened" }
                    .menu(.held) {
                        MenuItem("Report.txt").onClicked { last = "Opened Report.txt" }
                        MenuItem("Notes.txt").onClicked { last = "Opened Notes.txt" }
                    }
            }
            .spacing(12)

            HStack {
                Button(icon: .icon(.more))
                    .style(look)
                    .accessibilityLabel("More")
                    .menu {
                        MenuItem("Rename").onClicked { last = "Renamed" }
                        MenuItem("Delete").onClicked { last = "Deleted" }
                    }
                    .showsMenuArrow(showsArrow)

                Switch($showsArrow)
                    .accessibilityLabel("Arrow")
                    .verticalAlignment(.center)

                Text("Arrow")
                    .verticalAlignment(.center)
            }
            .spacing(12)

            HStack {
                Switch($platformLook)
                    .accessibilityLabel("Platform look")

                Text("Platform look")
                    .verticalAlignment(.center)
            }
            .spacing(12)

            Text("Last: \(last)")
                .fontSize(14)
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("Open's menu opens as it is held; on Windows and the Web, with the mouse's other button too.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
