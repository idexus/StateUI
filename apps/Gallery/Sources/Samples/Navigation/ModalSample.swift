import StateUI

/// A page presented over everything by application state.
struct ModalSample: SampleContent, ExampleContent {
    // listing: ModalSample
    let nav: Navigation
    // listing: end

    static let id = "modal"
    static let title = "Presenting over everything"
    static let summary = "A state presents a page over everything, and a sheet may present another."

    static var code: String { Listings.joined("Navigation.sheets", "MainPage.modal", "ModalPage", "ModalSample") }

    var notes: (any View)? { nil }

    // listing: ModalSample
    var body: some View {
        VStack {
            DebugInfoLabel()

            Button("Present native modal")
                .accessibilityIdentifier("modal.present")
                .horizontalAlignment(.center)
                .onClicked { nav.presentsPage = true }

            Text(nav.presentsPage ? "Presented" : "Nothing presented")
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }
    // listing: end
}
