import StateUI

/// Buttons a keyboard shortcut presses: Command or Control with S, and with Shift too.
struct ShortcutSample: SampleContent, ExampleContent {
    // listing: ShortcutSample
    @State private var saved = 0
    @State private var last = "nothing yet"
    @State private var note = ""
    // listing: end

    static let id = "shortcut"
    static let title = "Keyboard shortcut"
    static let summary = "Keys that press a button while its window is in front, with a modifier or alone."

    // listing: ShortcutSample
    var body: some View {
        VStack {
            Text("Press Command or Control with S, then with Shift and S, then 1 alone.")
                .fontSize(14)

            HStack {
                // Command on Apple's platforms, Control elsewhere.
                Button("Save")
                    .keyboardShortcut("s")
                    .onClicked {
                        saved += 1
                        last = "Save"
                    }

                Button("Save As")
                    .keyboardShortcut("s", modifiers: [.primary, .shift])
                    .onClicked {
                        saved += 1
                        last = "Save As"
                    }

                // A key alone is a shortcut too.
                Button("First")
                    .keyboardShortcut("1", modifiers: [])
                    .onClicked {
                        saved += 1
                        last = "First"
                    }
            }
            .spacing(12)

            // While this field is typed into, 1 writes a 1.
            TextField($note)
                .placeholder("Type here")

            Text("Pressed \(saved) time\(saved == 1 ? "" : "s"), last: \(last)")
                .fontSize(13)
                .textColor(Palette.accent)
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("A phone without a keyboard has no shortcuts; a button keeps its click.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
