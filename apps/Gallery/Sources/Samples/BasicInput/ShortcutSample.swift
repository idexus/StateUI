import StateUI

/// Keyboard shortcuts on buttons, a menu bar's entry and a bar's item: Command or Control with S, with Shift too,
/// and a key alone.
struct ShortcutSample: SampleContent {
    static let id = "shortcut"
    static let title = "Keyboard shortcut"
    static let summary = "Keys that press a button, a menu's entry or a bar's item while its window is in front."

    var examples: [Example] {
        [Example(ShortcutKeys()), Example(SidebarShortcut())]
    }
}

/// Shortcuts on buttons, a menu's entry and a bar's item.
private struct ShortcutKeys: ExampleContent {
    // listing: ShortcutKeys
    @State private var saved = 0
    @State private var last = "nothing yet"
    @State private var note = ""

    var body: some View {
        VStack {
            Text("Press Command or Control with S, with Shift and S, with Shift and E, then 1 or 2 alone.")
                .fontSize(14)

            HStack {
                // Command on Apple's platforms, Control elsewhere.
                Button("Save")
                    .keyboardShortcut("s")
                    .onClicked { pressed("Save") }

                Button("Save As")
                    .keyboardShortcut("s", modifiers: [.primary, .shift])
                    .onClicked { pressed("Save As") }

                // A key alone is a shortcut too.
                Button("First")
                    .keyboardShortcut("1", modifiers: [])
                    .onClicked { pressed("First") }
            }
            .spacing(12)

            // While this field is typed into, 1 and 2 write themselves.
            TextField($note)
                .placeholder("Type here")

            Text("Pressed \(saved) time\(saved == 1 ? "" : "s"), last: \(last)")
                .fontSize(13)
                .textColor(Palette.accent)
                // A context menu shows the shortcut; the menu bar's entry acts on it.
                .contextMenu {
                    MenuItem("Export…")
                        .keyboardShortcut("e", modifiers: [.primary, .shift])
                        .onClicked { pressed("Export from the context menu") }
                }
        }
        .spacing(16)
        .menuBar {
            Menu("File") {
                MenuItem("Export…")
                    .keyboardShortcut("e", modifiers: [.primary, .shift])
                    .onClicked { pressed("Export") }
            }
            .joins(.file)
        }
        .toolbar {
            ToolbarButton("Mark")
                .keyboardShortcut("2", modifiers: [])
                .onClicked { pressed("Mark") }
        }
    }

    private func pressed(_ name: String) {
        saved += 1
        last = name
    }
    // listing: end

    var notes: (any View)? {
        Text("A phone without a keyboard has no shortcuts; a button keeps its click. A context menu's entry only "
            + "shows its shortcut.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// One key on a sidebar's button and on its detail's: the button in sight takes it.
private struct SidebarShortcut: ExampleContent {
    // listing: SidebarShortcut
    @State private var open = false
    @State private var showsSidebar = true
    @State private var last = "nothing yet"

    var body: some View {
        VStack {
            Text("Open the split view, hide its sidebar and press 3.")
                .fontSize(14)

            Button("Open the split view")
                .accessibilityIdentifier("shortcut.split.open")
                .onClicked { open = true }

            Text("Last pressed: \(last)")
                .fontSize(13)
                .textColor(Palette.accent)
        }
        .spacing(12)
        .sheet(isPresented: $open) {
            SplitView {
                VStack {
                    Button("The sidebar's 3")
                        .keyboardShortcut("3", modifiers: [])
                        .onClicked { last = "the sidebar's" }
                }
                .padding(16)
                .pageTitle("Sidebar")
            } detail: {
                VStack {
                    Button("The detail's 3")
                        .keyboardShortcut("3", modifiers: [])
                        .onClicked { last = "the detail's" }

                    Switch("Sidebar", isOn: $showsSidebar)
                        .accessibilityIdentifier("shortcut.split.sidebar")

                    Text("Last pressed: \(last)")

                    Button("Done")
                        .accessibilityIdentifier("shortcut.split.done")
                        .onClicked { open = false }
                }
                .spacing(12)
                .padding(16)
                .pageTitle("Detail")
            }
            .showsSidebar($showsSidebar)
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("A shortcut acts from the views in sight. With the sidebar hidden only the detail's 3 stands in "
            + "sight, and takes the key; shown beside it, the key is stated twice in one window - StateUI says "
            + "so, and one of the two acts.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
