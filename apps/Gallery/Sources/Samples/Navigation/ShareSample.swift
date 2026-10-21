import StateUI

/// Words and a link offered to the platform's share sheet.
struct ShareSample: SampleContent, ExampleContent {
    // listing: ShareSample
    @Environment(\.window) private var window
    @State private var words = "The language I mentioned"
    @State private var link = "https://www.swift.org"
    @State private var answer = "nothing shared yet"
    // listing: end

    static let id = "share"
    static let title = "Share"
    static let summary = "Words and a link offered to the platform's share sheet - sent where the user chooses."

    // listing: ShareSample
    var body: some View {
        VStack {
            TextField($words)
                .accessibilityLabel("Words to share")
            TextField($link)
                .accessibilityLabel("Link to share")

            // False is a cancel; a platform with no share sheet throws why.
            Button("Share")
                .accessibilityIdentifier("share.share")
                .onClicked(gate: .ignoreWhileRunning) {
                    do {
                        let shared = try await window.share(text: words, link: link)
                        answer = shared ? "shared" : "cancelled"
                    } catch {
                        answer = "\(error)"
                    }
                }

            Text(answer)
                .fontSize(15)
                .horizontalTextAlignment(.center)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Pick a place the platform offers - or cancel the sheet.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
