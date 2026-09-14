import StateUI

/// Page-owned native toolbar and menu items.
struct ToolbarSample: SampleContent, ExampleContent {
    @State private var saved = 0
    @State private var recent = ["notes.txt", "budget.csv"]

    /// How many files Add has made, so each gets a name of its own - a menu
    /// row is identified by the file it names, and two rows may not claim the
    /// same identity.
    @State private var added = 0

    /// Which of the two buttons ON the bar asks to be drawn first. The number
    /// it decides is `.priority`; the lower number appears first.
    @State private var addFirst = false

    /// The page this sample is on, whose bar and menus these are.
    @Environment private var page: PageSession

    /// What the page's bar held before this sample added to it - the
    /// gallery's own buttons, which stay after the sample's.
    @State private var chrome: [ToolbarItem] = []

    static let id = "toolbar"
    static let title = "Toolbar and menus"
    static let summary = "Buttons in the navigation bar, and the desktop menu bar above it."

    static let code = """
        @State private var saved = 0
        @State private var recent = ["notes.txt", "budget.csv"]
        @State private var added = 0
        @State private var addFirst = false

        @Environment private var page: PageSession
        @State private var chrome: [ToolbarItem] = []

        // Both belong to the PAGE, so they are written into its session -
        // and written again when what they say moves.
        private var items: [ToolbarItem] {
            [
                // Written Save then Add whichever way the switch is set; the
                // lower priority still appears first.
                ToolbarItem("Save")
                    .id("save")
                    .priority(addFirst ? 1 : 0)
                    .onClicked { saved += 1 },

                ToolbarItem("Add")
                    .id("add")
                    .priority(addFirst ? 0 : 1)
                    .onClicked {
                        added += 1
                        recent.append("file\\(added).txt")
                    },

                ToolbarItem("Clear")
                    .id("clear")
                    .order(.secondary)
                    .isDestructive(true)
                    .isEnabled(saved > 0)
                    .onClicked { saved = 0 },
            ]
        }

        private var menus: [Menu] {
            [
                Menu("File") {
                    MenuItem("Save")
                        .id("save")
                        .onClicked { saved += 1 }

                    MenuSeparator()
                        .id("line")

                    Menu("Recent") {
                        ForEach(recent) { file in
                            MenuItem(file)
                                .id(file)
                                .onClicked { recent.removeAll { $0 == file } }
                        }
                    }
                    .id("recent")
                    .isEnabled(!recent.isEmpty)
                }
                .id("file"),
            ]
        }

        var content: any View {
            VStack {
                // The counts are read here, so every toolbar item that acts
                // builds this closure.
                DebugInfoLabel()

                Label("Saved \\(saved) time(s)")
                Label(recent.isEmpty ? "No recent files" : recent.joined(separator: ", "))

                HStack {
                    Switch($addFirst)

                    Label(addFirst
                        ? "Add asks first - .priority(0), against Save's 1"
                        : "Save asks first - .priority(0), against Add's 1")
                }
            }
            .onCreated {
                chrome = page.toolbarItems      // what the page put there first
                page.toolbarItems = items + chrome
                page.menuBar = menus
            }
            .onChanged(addFirst) { page.toolbarItems = items + chrome }
            .onChanged(saved) { page.toolbarItems = items + chrome }
            .onChanged(recent) { page.menuBar = menus }
        }
        """

    /// The buttons this sample puts on the page's bar, before the gallery's
    /// own.
    private var items: [ToolbarItem] {
        [
            // Written Save then Add whichever way the switch is set; the lower
            // priority still appears first.
            ToolbarItem("Save")
                .id("save")
                .priority(addFirst ? 1 : 0)
                .onClicked { saved += 1 },

            ToolbarItem("Add")
                .id("add")
                .priority(addFirst ? 0 : 1)
                .onClicked {
                    added += 1
                    recent.append("file\(added).txt")
                },

            ToolbarItem("Clear")
                .id("clear")
                .order(.secondary)
                .isDestructive(true)
                .isEnabled(saved > 0)
                .onClicked { saved = 0 },
        ]
    }

    /// And the desktop menu bar's File menu.
    private var menus: [Menu] {
        [
            Menu("File") {
                MenuItem("Save")
                    .id("save")
                    .onClicked { saved += 1 }

                MenuSeparator()
                    .id("line")

                Menu("Recent") {
                    ForEach(recent) { file in
                        MenuItem(file)
                            .id(file)
                            .onClicked { recent.removeAll { $0 == file } }
                    }
                }
                .id("recent")
                .isEnabled(!recent.isEmpty)
            }
            .id("file"),
        ]
    }

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label("Saved \(saved) time(s)")
                .fontSize(17)

            Label(recent.isEmpty ? "No recent files" : recent.joined(separator: ", "))
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Press Save and Add on the bar; Clear is in its overflow.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("Which one comes first")

            HStack {
                Switch($addFirst)
                    .automationId("toolbar.addFirst")
                    .semanticDescription("Add asks first")

                Label(addFirst
                    ? "Add asks first - `.priority(0)`, against Save's 1"
                    : "Save asks first - `.priority(0)`, against Add's 1")
                    .fontSize(14)
                    .verticalAlignment(.center)
            }
            .spacing(10)
        }
        .spacing(12)
        // The bar and the menus are the PAGE's, so this sample writes them
        // into the page's session - its buttons before the gallery's own,
        // which the page wrote a moment earlier, being further out.
        .onCreated {
            chrome = page.toolbarItems
            page.toolbarItems = items + chrome
            page.menuBar = menus
        }
        // What they say follows the state, so they are written again when it
        // moves: `saved` decides whether Clear can be pressed, `addFirst` the
        // priorities, `recent` the submenu.
        .onChanged(addFirst) { page.toolbarItems = items + chrome }
        .onChanged(saved) { page.toolbarItems = items + chrome }
        .onChanged(recent) { page.menuBar = menus }
    }

    var notes: Element? {
        VStack {
            Label("Save and Add are on the page's bar. Clear is a destructive item in the "
                + "native overflow, enabled once something is saved.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Lower priority appears first; equal priority keeps source order. "
                + "Flip the switch and the same native items exchange places.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Recent files live in the desktop File menu: Add puts one there, "
                + "choosing one removes it, and an empty submenu disables itself.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The bar and the menus belong to the page, so they are written into "
                + "its `PageSession` - and written again whenever the state they show "
                + "moves.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
