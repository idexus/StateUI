import StateUI

/// Where the gallery's appearance actually comes from.
struct StyleSample: SampleContent, ExampleContent {
    // listing: StyleSample
    @State private var enabled = true
    // listing: end

    static let id = "styles"
    static let title = "Styles"
    static let summary = "One description of what a control looks like, applied to every one of them."

    static var code: String { Listings.joined("GalleryApp", "Palette.sample", "AppStyles.sample", "StyleSample") }

    // listing: StyleSample
    var body: some View {
        VStack {
            DebugInfoLabel()

            // Neither of these says anything of its own look: the violet, the
            // corners and the padding come from Style<Button> in AppStyles.swift,
            // which every button wears.
            HStack {
                Button("Save")
                Button("Cancel")
            }
            .spacing(12)
            .horizontalAlignment(.center)

            // A style can say what a control looks like in a STATE; hearing
            // the control enter one is what .onVisualStateChanged is for, next
            // door in the Visual states sample.
            Button(enabled ? "Enabled" : "Disabled")
                .isEnabled(enabled)
                .horizontalAlignment(.center)
                .onClicked {}

            HStack {
                Text("Enabled")
                    .verticalAlignment(.center)

                Switch($enabled)
                    .accessibilityIdentifier("styles.enabled")
                    .accessibilityLabel("Enabled")
            }
            .spacing(12)
            .horizontalAlignment(.center)

            SectionTitle("A style for every control of a type")

            // None of these names a colour: a style with no key is implicit,
            // and every ColorBox wears the one `Style<ColorBox>()` gives.
            HStack {
                ColorBox()
                    .width(40)
                    .height(40)
                ColorBox()
                    .width(40)
                    .height(40)
                ColorBox()
                    .width(40)
                    .height(40)
            }
            .spacing(12)
            .horizontalAlignment(.center)

            SectionTitle("A style asked for by name")

            // A keyed style is asked for; a keyed style REPLACES the implicit
            // one, so it says everything it needs.
            Text("Headline")
                .style("Headline")

            SectionTitle("A style written from another")

            // The same words twice. "Quote" states the shape; "QuoteLoud" is
            // `.basedOn("Quote")` plus one colour - so everything that matches
            // below is inherited, and the one thing that differs is the one
            // thing it declares.
            Text("The same eleven words, and one of these declares a colour.")
                .style("Quote")

            Text("The same eleven words, and one of these declares a colour.")
                .style("QuoteLoud")
        }
        .spacing(14)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("\"Save\" and \"Cancel\" say nothing of their look: both wear the gallery's "
                + "`Style<Button>()`, which every button wears.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A style with no key is implicit: every control of its type wears it, "
                + "as every ColorBox here wears `Style<ColorBox>()`. `Headline` has a key "
                + "and is asked for by name, and a keyed style REPLACES the implicit one, "
                + "so it says everything it needs.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Both quotes are italic, both are 17 point, both are centred, both "
                + "carry the same letter spacing - and only one of them says so. "
                + "`QuoteLoud` is `.basedOn(\"Quote\")` and a text colour, which "
                + "is the whole of its declaration. A property the child states "
                + "wins; every property it leaves out comes from the parent.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Every colour these styles use is one `Color(light:dark:)`, a value "
                + "for each theme. None of this crosses the boundary: the styles are "
                + "resolved in Swift, into the controls, so what the host receives is "
                + "a button with its colours already on it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
