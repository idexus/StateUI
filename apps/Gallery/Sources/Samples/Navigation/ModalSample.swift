import StateUI

/// A native modal stack owned by application state.
struct ModalSample: SampleContent, ExampleContent {
    // listing: ModalSample
    let nav: Navigation
    // listing: end

    static let id = "modal"
    static let title = "Presenting over everything"
    static let summary = "One array drives the platform's native modal stack."

    static var code: String { Listings.joined("Navigation.sheets", "MainPage.modal", "ModalPage", "ModalSample") }

    var notes: (any View)? { nil }

    // listing: ModalSample
    var body: some View {
        VStack {
            DebugInfoLabel()

            Button("Present native modal")
                .accessibilityIdentifier("modal.present")
                .horizontalAlignment(.center)
                .onClicked { nav.present(.page) }

            Text(nav.sheets.isEmpty ? "Nothing presented" : "Depth: \(nav.sheets.count)")
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }
    // listing: end
}
