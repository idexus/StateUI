import StateUI

/// MAUI: Page.ToolbarItems and Page.MenuBarItems.
struct ToolbarSample: SampleContent {
    @State private var saved = 0
    @State private var recent = ["notes.txt", "budget.csv"]

    /// How many files Add has made, so each gets a name of its own - a menu
    /// row is identified by the file it names, and two rows may not claim the
    /// same identity.
    @State private var added = 0

    /// Which of the two buttons ON the bar asks to be drawn first. The number
    /// it decides is `.priority`, and where the platform puts the lower one is
    /// the platform's own business - which is the thing to watch.
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
                // Written Save then Add whichever way the switch is set: what
                // the platform sorts them by is .priority, not this order.
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

        private var menus: [MenuBarItem] {
            [
                MenuBarItem("File") {
                    MenuFlyoutItem("Save")
                        .id("save")
                        .onClicked { saved += 1 }

                    MenuFlyoutSeparator()
                        .id("line")

                    MenuFlyoutSubItem("Recent") {
                        ForEach(recent) { file in
                            MenuFlyoutItem(file)
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
                page.menuBarItems = menus
            }
            .onChanged(addFirst) { page.toolbarItems = items + chrome }
            .onChanged(saved) { page.toolbarItems = items + chrome }
            .onChanged(recent) { page.menuBarItems = menus }
        }
        """

    /// The buttons this sample puts on the page's bar, before the gallery's
    /// own.
    private var items: [ToolbarItem] {
        [
            // Written Save then Add whichever way the switch is set: what the
            // platform sorts them by is `.priority`, not this order.
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
    private var menus: [MenuBarItem] {
        [
            MenuBarItem("File") {
                MenuFlyoutItem("Save")
                    .id("save")
                    .onClicked { saved += 1 }

                MenuFlyoutSeparator()
                    .id("line")

                MenuFlyoutSubItem("Recent") {
                    ForEach(recent) { file in
                        MenuFlyoutItem(file)
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

            Label("Look at the navigation bar above: Save and Add are on it, and Clear is "
                + "behind the overflow because it asked for `.secondary`. All three are "
                + "MenuItems in MAUI - a caption, a picture and something to run - so "
                + "none of them is a view. Add puts another name on the list.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("WHICH ONE COMES FIRST")

            HStack {
                Switch($addFirst)
                    .automationId("toolbar.addFirst")
                    .semanticDescription("Add asks first")

                Label(addFirst
                    ? "Add asks first - `.priority(0)`, against Save's 1"
                    : "Save asks first - `.priority(0)`, against Add's 1")
                    .fontSize(14)
                    .verticalOptions(.center)
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
            page.menuBarItems = menus
        }
        // What they say follows the state, so they are written again when it
        // moves: `saved` decides whether Clear can be pressed, `addFirst` the
        // priorities, `recent` the submenu.
        .onChanged(addFirst) { page.toolbarItems = items + chrome }
        .onChanged(saved) { page.toolbarItems = items + chrome }
        .onChanged(recent) { page.menuBarItems = menus }
    }

    var notes: Element? {
        VStack {
            Label("`.priority` is the number the platform sorts a page's items by, over "
                + "the order they are written in - and the two are written Save then Add "
                + "whichever way this switch is set, so anything that moves up there "
                + "moved because of the number. It is passed to MAUI untouched, and "
                + "which end of the range is drawn first is the platform's own business: "
                + "flip the switch and read the bar to find out which way round it is "
                + "here.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The File menu is on the desktop menu bar, at the top of the screen on a "
                + "Mac. A phone has nowhere to put one and shows none of it, which is what "
                + "MAUI does too.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Choosing a file under Recent takes it off the list, and the submenu is "
                + "disabled once the list is empty - the menu is written again "
                + "whenever the list moves.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both belong to the PAGE rather than to the content, so a sample writes "
                + "them into the page's session - its buttons before the gallery's own - "
                + "and writes them again when what they say moves.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
