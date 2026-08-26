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

    static let id = "toolbar"
    static let title = "Toolbar and menus"
    static let summary = "Buttons in the navigation bar, and the desktop menu bar above it."

    static let code = """
        @State private var saved = 0
        @State private var recent = ["notes.txt", "budget.csv"]
        @State private var added = 0
        @State private var addFirst = false

        // Both belong to the PAGE, so they are asked for rather than written
        // into the content - the rule a title view already follows.
        var toolbarItems: [ToolbarItem] {
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

        var menuBarItems: [MenuBarItem] {
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

        var content: Element {
            VStack {
                Label("Saved \\(saved) time(s)")
                Label(recent.isEmpty ? "No recent files" : recent.joined(separator: ", "))

                HStack {
                    Switch($addFirst)

                    Label(addFirst
                        ? "Add asks first - .priority(0), against Save's 1"
                        : "Save asks first - .priority(0), against Add's 1")
                }
            }
        }
        """

    var toolbarItems: [ToolbarItem] {
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

    var menuBarItems: [MenuBarItem] {
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

    var content: Element {
        VStack {
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

                Label(addFirst
                    ? "Add asks first - `.priority(0)`, against Save's 1"
                    : "Save asks first - `.priority(0)`, against Add's 1")
                    .fontSize(14)
                    .verticalOptions(.center)
            }
            .spacing(10)

        }
        .spacing(12)
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
                + "disabled once the list is empty - a menu is rebuilt on every render, "
                + "like everything else here.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both belong to the PAGE rather than to the content, so a sample asks the "
                + "page for them - the rule a navigation bar's title view already follows.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
