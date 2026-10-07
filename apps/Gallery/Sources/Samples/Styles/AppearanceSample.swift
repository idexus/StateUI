import StateUI

/// The look the gallery wears, all of it in one place: its bars, the tint its
/// pages stand in, and its window's material.
struct AppearanceSample: SampleContent, ExampleContent {
    // listing: AppearanceSample
    /// The gallery's look, which every gallery window wears.
    let style: SessionStyle

    /// The window this page stands in.
    @Environment(\.window) private var window

    /// Whether the desktop shows through the window, as the switch last said.
    @State private var translucent = false
    // listing: end

    static let id = "appearance"
    static let title = "Appearance"
    static let summary = "The bars, a tint under the pages and the window's material: "
        + "the platform's own, or the gallery's."

    // listing: AppearanceSample
    var body: some View {
        // Read here, so a choice made anywhere - this page, the Colours
        // window - builds the picker again at its new place.
        let accents = AccentChoice.allCases
        let chosen = accents.firstIndex(of: style.accent) ?? 0
        let style = self.style

        return VStack {
            SectionTitle("The bars")

            Picker(accents.map(\.name))
                .accessibilityIdentifier("appearance.bars")
                .accessibilityLabel("Bars")
                .selectedIndex(Binding(get: { chosen }, set: { style.accent = accents[$0] }))

            SwitchRow("Tint the pages lightly", style.$tintsPages)
                .isEnabled(style.accent != .platform)

            SectionTitle("The window")

            SwitchRow("Show the desktop through it", $translucent)
                .onChanged(translucent) { window.isTranslucent = translucent }
        }
        .spacing(12)
        .onCreated { translucent = window.isTranslucent == true }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("\"The platform's own\" leaves the bars unwritten: each platform draws its "
                + "own, in the user's accent and material. A colour paints the bars alone, "
                + "and the tint lays a light wash of it under every page.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The window shows the desktop through it where the platform can: on a Mac, "
                + "under the pages and around the sidebar, the tint over it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
