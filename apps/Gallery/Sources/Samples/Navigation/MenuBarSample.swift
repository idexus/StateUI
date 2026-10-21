import StateUI

/// A page's own menus: File joined by its identity with the platform's where it has one, an entry that comes and
/// goes with the state, and a menu of its own.
struct MenuBarSample: SampleContent, ExampleContent {
    // listing: MenuBarSample
    @State private var saved = 0
    @State private var exported = 0

    /// Whether this page saves: its File menu then holds Save.
    @State private var pageSaves = false

    /// Whether this page adds a menu of its own.
    @State private var ownMenu = false

    /// Words to edit through the Edit menu's own entries.
    @State private var note = "Edit me"
    // listing: end

    static let id = "menuBar"
    static let title = "Menu bar"
    static let summary = "A page's own menus, joined with the platform's by identity."

    // listing: MenuBarSample
    var body: some View {
        VStack {
            // The counts are read here, so every entry that acts builds
            // this closure.
            DebugInfoLabel()

            Text("Saved \(saved) time(s), exported \(exported)")
                .fontSize(17)

            Text("Open the File menu - on Android, in the bar's overflow; on GNOME, in its main menu.")
                .fontSize(12)
                .textColor(Palette.subtle)

            switchRow($pageSaves, "This page saves", id: "menubar.pageSaves")
            switchRow($ownMenu, "A menu of its own", id: "menubar.ownMenu")

            Text("Select words here, then Cut, Copy, Paste or Undo from Edit.")
                .fontSize(12)
                .textColor(Palette.subtle)

            TextField($note)
                .accessibilityIdentifier("menubar.note")
                .accessibilityLabel("Words to edit")
        }
        .spacing(12)
        // File, joined by its identity with the platform's own where it has
        // one: this page's entries are a section of their own.
        .menuBar {
            Menu("File") {
                if pageSaves {
                    MenuItem("Save")
                        .id("save")
                        .onClicked { saved += 1 }
                }

                MenuItem("Export…")
                    .id("export")
                    .onClicked { exported += 1 }
            }
            .id(StandardMenu.file)

            // Edit holds the platform's own entries, acting on the field the
            // user typed into; Clear stands after them, this page's own.
            Menu("Edit") {
                MenuItem("Clear")
                    .id("clear")
                    .onClicked { note = "" }
            }
            .id(StandardMenu.edit)

            if ownMenu {
                Menu("Sample") {
                    MenuItem("Save twice")
                        .onClicked { saved += 2 }
                }
                .id("sample")
            }
        }
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
            Text("This page declares File: Save while it saves, and Export…. On the Mac it joins the "
                + "system's own File menu, its entries a section after a line. Going to another page "
                + "takes them away.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A menu of its own stands after File, before the platform's Window and "
                + "Help. File is joined by `.id(StandardMenu.file)`, never by its caption. Android "
                + "puts the menus behind the bar's overflow, GNOME in the bar's main menu; an "
                + "iPhone shows none.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Edit, joined by `.id(StandardMenu.edit)`, holds the platform's own Undo, Redo, Cut, "
                + "Copy, Paste, Delete and Select All before this page's Clear - on the Mac and the iPad "
                + "the system's own, on Windows, GNOME and the Web the same entries StateUI keeps. They "
                + "act on the field you typed into, though opening the menu took the focus.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
