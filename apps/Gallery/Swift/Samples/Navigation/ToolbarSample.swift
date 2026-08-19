import StateUI

/// MAUI: Page.ToolbarItems and Page.MenuBarItems.
struct ToolbarSample: SampleContent {
    @State private var saved = 0
    @State private var recent = ["notes.txt", "budget.csv"]

    static let id = "toolbar"
    static let title = "Toolbar and menus"
    static let summary = "Buttons in the navigation bar, and the desktop menu bar above it."

    static let code = """
        @State private var saved = 0
        @State private var recent = ["notes.txt", "budget.csv"]

        // Both belong to the PAGE, so they are asked for rather than written
        // into the content - the rule a title view already follows.
        var toolbarItems: [ToolbarItem] {
            [
                ToolbarItem("Save")
                    .id("save")
                    .onClicked { saved += 1 },

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
            }
        }
        """

    var toolbarItems: [ToolbarItem] {
        [
            ToolbarItem("Save")
                .id("save")
                .onClicked { saved += 1 },

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

            Label("Look at the navigation bar above: Save is on it, and Clear is behind the "
                + "overflow because it asked for `.secondary`. Both are MenuItems in MAUI - "
                + "a caption, a picture and something to run - so neither is a view.")
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
