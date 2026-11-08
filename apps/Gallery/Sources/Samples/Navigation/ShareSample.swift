import StateUI

/// Words and an address offered to the platform's share sheet.
struct ShareSample: SampleContent, ExampleContent {
    // listing: ShareSample
    @Environment(\.window) private var window
    @State private var words = "The language I mentioned"
    @State private var address = "https://www.swift.org"
    @State private var answer = "nothing shared yet"
    // listing: end

    static let id = "share"
    static let title = "Share"
    static let summary = "Words and an address offered to the platform's share sheet - sent where the user chooses."

    // listing: ShareSample
    var body: some View {
        VStack {
            TextField($words)
                .accessibilityLabel("Words to share")
            TextField($address)
                .accessibilityLabel("Address to share")

            // False is a cancel; a platform with no share sheet throws why.
            Button("Share")
                .accessibilityIdentifier("share.share")
                .onClicked(policy: .ignoreWhileRunning) {
                    do {
                        let shared = try await window.share(text: words, address: address)
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
