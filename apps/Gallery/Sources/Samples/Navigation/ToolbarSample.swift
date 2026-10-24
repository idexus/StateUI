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

    /// Whether the sample's group stands at the bar's start.
    @State private var atStart = false

    /// Whether Add shows its words beside its picture on the bar.
    @State private var addWords = false

    /// Whether the page is a favorite: a setting on the bar and in the File
    /// menu, one state for both.
    @State private var favorite = false

    /// Whether Save's menu opens as the button is held rather than from an
    /// arrow of its own.
    @State private var saveHeld = false

    /// Whether Sort shows the arrow saying its click opens a menu.
    @State private var sortArrow = true

    /// Whether the branch declaring the actions is disabled.
    @State private var locked = false
    // listing: end

    static let id = "toolbar"
    static let title = "Toolbar and menus"
    static let summary = "Buttons in the navigation bar, and the desktop menu bar above it."

    // listing: ToolbarSample
    var body: some View {
        VStack {
            VStack {
                // The counts are read here, so every toolbar item that acts
                // builds this closure.
                DebugInfoLabel()

                Text("Saved \(saved) time(s)")
                    .fontSize(17)

                Text(recent.isEmpty ? "No recent files" : recent.joined(separator: ", "))
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Text(favorite ? "A favorite" : "Not a favorite")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                Text("Press Save, Add and the star; Sort and Save's arrow open menus; Clear is in the overflow.")
                    .fontSize(12)
                    .textColor(Palette.subtle)

                SectionTitle("Where the actions stand")

                switchRow($afterGallery, "After the gallery's actions", id: "toolbar.afterGallery")
                switchRow($atStart, "At the start", id: "toolbar.atStart")

                SectionTitle("A picture and its words")

                switchRow($addWords, "Add's words beside its picture", id: "toolbar.addWords")

                SectionTitle("A button's menu")

                switchRow($saveHeld, "Save's menu held", id: "toolbar.saveHeld")
                switchRow($sortArrow, "Sort's arrow", id: "toolbar.sortArrow")
            }
            .spacing(12)
            // The page's actions, declared where their state lives: they follow
            // it as the body builds - `saved` decides whether Clear can be pressed,
            // `addWords` Add's words, the two switches where the group stands.
            .toolbar {
                ToolbarGroup {
                    // Its click its own, its menu apart: from an arrow of its
                    // own, or held.
                    ToolbarButton("Save")
                        .id("save")
                        .onClicked { saved += 1 }
                        .menu(saveHeld ? .held : .split) {
                            MenuItem("Save a copy")
                                .id("saveCopy")
                                .onClicked {
                                    saved += 1
                                    added += 1
                                    recent.append("copy\(added).txt")
                                }
                        }

                    // A picture alone, unless it asks for its words beside it.
                    ToolbarButton("Add")
                        .id("add")
                        .icon(ImageSource(light: "menu_duplicate.png", dark: "menu_duplicate_dark.png"))
                        .showsText(addWords)
                        .onClicked {
                            added += 1
                            recent.append("file\(added).txt")
                        }
                }
                .placement(at: atStart ? .start : .end, order: afterGallery ? 1 : 0)

                // A menu its click opens, an arrow saying so.
                ToolbarButton("Sort")
                    .id("sort")
                    .showsMenuArrow(sortArrow)
                    .menu {
                        MenuItem("A to Z").id("sort.up").onClicked { recent.sort() }
                        MenuItem("Z to A").id("sort.down").onClicked { recent.sort(by: >) }
                    }

                // A setting: on and off, its filled star while on.
                ToolbarToggle("Favorite", isOn: $favorite)
                    .id("favorite")
                    .icon(
                        ImageSource(light: "menu_star.png", dark: "menu_star_dark.png"),
                        on: ImageSource(light: "menu_star_on.png", dark: "menu_star_on_dark.png"))

                ToolbarButton("Clear")
                    .id("clear")
                    .placement(at: .overflow)
                    .role(.destructive)
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

                    // The bar's setting again, checked as the state is.
                    MenuToggle("Favorite", isOn: $favorite)
                        .id("favorite")

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
            // Locked, the branch takes no input: its switches, and the
            // actions and menu items declared on it, dimmed with it.
            .isEnabled(!locked)

            SectionTitle("Out of reach")

            switchRow($locked, "Lock the switches and actions above", id: "toolbar.locked")
        }
        .spacing(12)
    }

    /// A switch and what it says, told apart for scripts by `id`.
    private func switchRow(_ value: Binding<Bool>, _ words: String, id: String) -> some View {
        Switch(value)
            .text(words)
            .accessibilityIdentifier(id)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Save and Add are on the page's bar. Clear is a destructive item in the "
                + "native overflow, enabled once something is saved.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The gallery's own actions stand at the edge on every page; the sample's "
                + "group comes in from the title's side. `order: 1` moves it after them, "
                + "`.start` takes it to the other edge.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Add shows its picture alone, its words in its tip; `.showsText(true)` "
                + "puts them beside it where the platform's bar can.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Sort is a menu its click opens, an arrow saying so where the platform's bar "
                + "draws one. Save splits: its click saves, and Save a copy opens from its arrow "
                + "- or, held, as the button is held.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The star is a `ToolbarToggle`: the platform's two-state button, its filled "
                + "picture while on. The File menu's `MenuToggle` holds the same state.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Recent files live in the desktop File menu, after Save: "
                + "Add puts one there, choosing one removes it, and the submenu is disabled "
                + "while it is empty.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Lock disables the view declaring the actions: its switches go out of reach, "
                + "and Save, Add, Sort, the star, Clear and the File menu's items with them. The gallery's own "
                + "actions, declared around it, stay.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
