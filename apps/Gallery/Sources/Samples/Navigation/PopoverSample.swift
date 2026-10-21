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
                .onClicked { filtering = true }
                .popover(isShown: $filtering) {
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

/// What a view shows in the platform's popover, by the view.
struct PopoverSample: SampleContent {
    static let id = "popover"
    static let title = "Popover"
    static let summary = "What a view shows over the page by itself, as long as a state says - a sheet on a phone."

    var examples: [Example] {
        [Example(MailFilters())]
    }
}
