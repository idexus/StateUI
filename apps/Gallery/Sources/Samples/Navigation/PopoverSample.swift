import StateUI

/// A button's popover of filters, which Done or a tap beside it closes.
private struct MailFilters: ExampleContent {
    // listing: MailFilters
    @State private var filtering = false
    @State private var unreadOnly = false
    @State private var flaggedOnly = false

    var body: some View {
        VStack {
            Button("Filters")
                .horizontalAlignment(.start)
                .onClicked { filtering = true }
                .popover(isPresented: $filtering) {
                    VStack {
                        Switch($unreadOnly).text("Unread only")
                        Switch($flaggedOnly).text("Flagged only")
                        Button("Done").onClicked { filtering = false }
                    }
                    .spacing(12)
                    .padding(16)
                }

            Text(filtering ? "The popover shows" : "The popover is closed")
                .fontSize(13)
                .textColor(Palette.accent)
        }
        .spacing(10)
        .horizontalAlignment(.start)
    }
    // listing: end

    var notes: (any View)? {
        Text("Open the filters, then close them with Done or by tapping beside them.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A popover of the explanation a state holds: another topic shows another in its place.
private struct Explanations: ExampleContent {
    // listing: Explanations
    @State private var explained: String?

    var body: some View {
        HStack {
            Button("Sync").onClicked { explained = "Sync keeps your mail the same on every device." }
            Button("Backup").onClicked { explained = "Backup saves a copy of your mail every night." }
        }
        .spacing(10)
        .popover(item: $explained) { words in
            Text(words).width(220).padding(16)
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("Tap a topic, then the other while its explanation shows.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// What a view shows in the platform's popover, by the view.
struct PopoverSample: SampleContent {
    static let id = "popover"
    static let title = "Popover"
    static let summary = "What a view shows over the page by itself, as long as a state says."

    var examples: [Example] {
        [Example(MailFilters()), Example(Explanations())]
    }
}
