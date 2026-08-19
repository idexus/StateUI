import StateUI

/// Where the gallery's appearance actually comes from.
struct StyleSample: SampleContent {
    @State private var enabled = true

    static let id = "styles"
    static let title = "Styles"
    static let summary = "One description of what a control looks like, applied to every one of them."

    static let code = """
        // The colours, each written once for both themes:
        enum Palette {
            static let accent = Color(light: AppColors.swiftOrangeDeep,
                                      dark: AppColors.swiftOrangeLight)
            static let onAccent = Color(light: AppColors.white, dark: AppColors.ink)
            static let disabled = Color(light: AppColors.muted, dark: AppColors.mutedDark)
            static let outline = Color(light: AppColors.line, dark: AppColors.lineDark)
        }

        // On the application, which is where MAUI keeps them:
        var styles: StyleSheet? {
            StyleSheet {
                Style<Button>()
                    .textColor(Palette.onAccent)
                    .backgroundColor(Palette.accent)
                    .cornerRadius(10)
                    .padding(16, 11)
                    .visualState(.disabled) { $0
                        .textColor(Palette.disabled)
                        .backgroundColor(Palette.outline)
                    }

                Style<Label>("Headline")
                    .fontSize(32)
                    .horizontalTextAlignment(.center)
            }
        }

        // And in the view, where nothing says how a button looks:
        @State private var enabled = true

        VStack {
            HStack {
                Button("Save")
                Button("Cancel")
            }

            Button(enabled ? "Enabled" : "Disabled")
                .isEnabled(enabled)
                .onClicked {}

            Switch($enabled)

            // The one style with a key, asked for by name.
            Label("Headline")
                .style("Headline")
        }
        """

    var content: Element {
        VStack {
            // Neither of these says anything about its own appearance. The
            // purple, the corners, the padding and the 44pt minimum all come
            // from Style<Button> in Styles/AppStyles.swift.
            Label("Nothing below sets a colour, a size or a corner")
                .fontSize(13)
                .textColor(Palette.subtle)

            HStack {
                Button("Save")
                Button("Cancel")
            }
            .spacing(12)
            .horizontalOptions(.center)

            // A style can say what a control looks like in a STATE, which is
            // MAUI's VisualStateManager - the platform enters the state, and
            // hearing that is what .onVisualStateChanged is for, next door in
            // the Visual states sample.
            Button(enabled ? "Enabled" : "Disabled")
                .isEnabled(enabled)
                .horizontalOptions(.center)
                .onClicked {}

            HStack {
                Label("Enabled")
                    .fontSize(14)
                    .verticalOptions(.center)

                Switch($enabled)
            }
            .spacing(12)
            .horizontalOptions(.center)

            SectionTitle("A STYLE ASKED FOR BY NAME")

            // The others are implicit - they have no key, so every control of
            // the type gets them. This one has one, and is asked for; a keyed
            // style REPLACES the implicit one, so it says everything it needs.
            Label("Headline")
                .style("Headline")

            Label("Every colour above is written twice, once per theme - "
                + "Color(light:dark:). None of this crosses the boundary: the "
                + "styles are resolved in Swift, into the controls, so what the "
                + "host receives is a button with its colours already on it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(14)
    }
}
