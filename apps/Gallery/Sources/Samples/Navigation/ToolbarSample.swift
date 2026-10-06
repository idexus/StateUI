import StateUI

/// Page-owned native toolbar and menu items.
struct ToolbarSample: SampleContent, ExampleContent {
    // listing: ToolbarSample
    @State private var saved = 0
    @State private var recent = ["notes.txt", "budget.csv"]

    /// How many files Add has made, so each gets a name of its own - a menu
    /// row is identified by the file it names, and two rows may not claim the
    /// same identity.
    @State private var added = 0

    /// Whether the sample's group stands after the gallery's, by its order.
    @State private var afterGallery = false

    /// Whether the sample's actions join the gallery's own group, by its id.
    @State private var inGallery = false

    /// Whether the sample's group stands at the bar's leading edge.
    @State private var atLeading = false

    /// Whether Add shows its words beside its picture on the bar.
    @State private var addWords = false
    // listing: end

    static let id = "toolbar"
    static let title = "Toolbar and menus"
    static let summary = "Buttons in the navigation bar, and the desktop menu bar above it."

    // listing: ToolbarSample
    var body: some View {
        VStack {
            // The counts are read here, so every toolbar item that acts
            // builds this closure.
            DebugInfoLabel()

            Text("Saved \(saved) time(s)")
                .fontSize(17)

            Text(recent.isEmpty ? "No recent files" : recent.joined(separator: ", "))
                .fontSize(13)
                .textColor(Palette.subtle)

            Text("Press Save and Add on the bar; Clear is in its overflow.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("Where the actions stand")

            switchRow($afterGallery, "After the gallery's actions", id: "toolbar.afterGallery")
            switchRow($inGallery, "In the gallery's group", id: "toolbar.inGallery")
            switchRow($atLeading, "At the leading edge", id: "toolbar.atLeading")

            SectionTitle("A picture and its words")

            switchRow($addWords, "Add's words beside its picture", id: "toolbar.addWords")
        }
        .spacing(12)
        // The page's actions, declared where their state lives: they follow
        // it as the body builds - `saved` decides whether Clear can be pressed,
        // `addWords` Add's words, the three switches where the group stands.
        .toolbar(atLeading ? .leading : .trailing, id: inGallery ? "gallery" : "sample", order: afterGallery ? 1 : 0) {
            ToolbarItem("Save")
                .id("save")
                .onClicked { saved += 1 }

            // A picture alone, unless it asks for its words beside it. The
            // white one reads on the accent bar in both themes.
            ToolbarItem("Add")
                .id("add")
                .icon("menu_duplicate_dark.png")
                .showsText(addWords)
                .onClicked {
                    added += 1
                    recent.append("file\(added).txt")
                }

            ToolbarItem("Clear")
                .id("clear")
                .placement(.overflow)
                .isDestructive(true)
                .isEnabled(saved > 0)
                .onClicked { saved = 0 }
        }
        // The desktop File menu, declared the same way: Save, and the recent
        // files following the state.
        .menuBar {
            Menu("File") {
                MenuItem("Save")
                    .id("save")
                    .onClicked { saved += 1 }

                Menu("Recent") {
                    recent.map { file in
                        MenuItem(file)
                            .id(file)
                            .onClicked { recent.removeAll { $0 == file } }
                    }
                }
                .id("recent")
                .isEnabled(!recent.isEmpty)
            }
            .id(StandardMenu.file)
        }
    }

    /// A switch and what it says, told apart for scripts by `id`.
    private func switchRow(_ value: Binding<Bool>, _ words: String, id: String) -> HStack {
        HStack {
            Switch(value)
                .accessibilityIdentifier(id)
                .accessibilityLabel(words)

            Text(words)
                .fontSize(14)
                .verticalAlignment(.center)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Save and Add are on the page's bar. Clear is a destructive item in the "
                + "native overflow, enabled once something is saved.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The gallery's own actions stand at the edge on every page; the sample's "
                + "come in from the title's side. `order: 1` moves its group after them, "
                + "`id: \"gallery\"` joins their group, `.leading` takes it to the other edge.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Add shows its picture alone, its words in its tip; `.showsText(true)` "
                + "puts them beside it where the platform's bar can.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Recent files live in the desktop File menu, after Save: "
                + "Add puts one there, choosing one removes it, and an empty submenu disables "
                + "itself.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
