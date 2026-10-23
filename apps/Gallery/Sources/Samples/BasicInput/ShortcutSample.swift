import StateUI

/// Keyboard shortcuts on buttons, a menu bar's entry and a bar's item: Command or Control with S, with Shift too,
/// and a key alone.
struct ShortcutSample: SampleContent, ExampleContent {
    // listing: ShortcutSample
    @State private var saved = 0
    @State private var last = "nothing yet"
    @State private var note = ""
    // listing: end

    static let id = "shortcut"
    static let title = "Keyboard shortcut"
    static let summary = "Keys that press a button, a menu's entry or a bar's item while its window is in front."

    // listing: ShortcutSample
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
            .id(StandardMenu.file)
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
