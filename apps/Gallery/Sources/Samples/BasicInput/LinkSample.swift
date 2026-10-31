import StateUI

/// Words opening an address in the application the system gives it: a page, a mail, and a page a state holds.
struct LinkSample: SampleContent, ExampleContent {
    // listing: LinkSample
    @State private var page = "https://www.swift.org"
    @State private var opened = 0
    @State private var enabled = true

    static let pages = ["https://www.swift.org", "https://developer.apple.com", "https://developer.android.com"]
    // listing: end

    static let id = "link"
    static let title = "Link"
    static let summary = "Words that open a page in the browser, or a new mail."

    // listing: LinkSample
    var body: some View {
        VStack {
            Link("Swift's home page", destination: "https://www.swift.org")
                .isEnabled(enabled)
                .onClicked { opened += 1 }

            Link("Write to us", destination: "mailto:hello@example.com")
                .isEnabled(enabled)
                .onClicked { opened += 1 }

            // The address is carried from the state: choosing another page
            // changes where the link leads, with no render of this view.
            Link("The page chosen below", destination: $page)
                .isEnabled(enabled)
                .onClicked { opened += 1 }

            Picker(Self.pages, selection: $page) { $0 }
                .placeholder("Page")

            Text("Opened \(opened) time\(opened == 1 ? "" : "s")")
                .fontSize(14)

            SwitchRow("Enabled", $enabled)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? { nil }
}
