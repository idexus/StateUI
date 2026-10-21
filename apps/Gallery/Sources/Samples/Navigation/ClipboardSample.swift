import StateUI

/// The system's clipboard: words copied to it and pasted back.
struct ClipboardSample: SampleContent, ExampleContent {
    // listing: ClipboardSample
    @Environment(\.application) private var application
    @State private var words = "Copy me somewhere"
    @State private var answer = "nothing copied or pasted yet"
    // listing: end

    static let id = "clipboard"
    static let title = "Clipboard"
    static let summary = "Words copied to the system's clipboard and pasted back - from this or any application."

    // listing: ClipboardSample
    var body: some View {
        VStack {
            TextField($words)
                .accessibilityIdentifier("clipboard.words")
                .accessibilityLabel("Words to copy")

            Button("Copy")
                .accessibilityIdentifier("clipboard.copy")
                .onClicked(gate: .ignoreWhileRunning) {
                    try await application.clipboard.write(text: words)
                    answer = "copied"
                }

            // What another application copied pastes here too; nil is an empty clipboard.
            Button("Paste")
                .accessibilityIdentifier("clipboard.paste")
                .onClicked(gate: .ignoreWhileRunning) {
                    guard let pasted = try await application.clipboard.text() else { return answer = "the clipboard is empty" }
                    words = pasted
                    answer = "pasted"
                }

            Text(answer)
                .fontSize(15)
                .horizontalTextAlignment(.center)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Copy here, paste in another application - or copy there and paste here. A platform may ask before "
            + "the application reads what another put on the clipboard.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
