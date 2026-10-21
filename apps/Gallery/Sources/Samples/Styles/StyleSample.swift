import StateUI

/// Where the gallery's appearance actually comes from.
struct StyleSample: SampleContent, ExampleContent {
    // listing: StyleSample
    @State private var enabled = true
    @State private var platformLook = false
    // listing: end

    static let id = "styles"
    static let title = "Styles"
    static let summary = "One description of what a control looks like, applied to every one of them."

    static var code: String { Listings.joined("GalleryApp", "Palette.sample", "AppStyles.sample", "StyleSample") }

    // listing: StyleSample
    var body: some View {
        // The gallery's styles, or the platform's own look.
        let look: StyleKey<Button>? = platformLook ? .platform : nil

        return VStack {
            DebugInfoLabel()

            // Neither of these says anything of its own look: the violet, the
            // corners and the padding come from Style<Button> in AppStyles.swift,
            // which every button wears.
            HStack {
                Button("Save").style(look)
                Button("Cancel").style(look)
            }
            .spacing(12)
            .horizontalAlignment(.center)

            // A style can say what a control looks like in a STATE; hearing
            // the control enter one is what .onVisualStateChanged is for, next
            // door in the Visual states sample.
            Button(enabled ? "Enabled" : "Disabled")
                .style(look)
                .isEnabled(enabled)
                .horizontalAlignment(.center)
                .onClicked {}

            Switch($enabled)
                .text("Enabled")
                .accessibilityIdentifier("styles.enabled")
                .horizontalAlignment(.center)

            Switch($platformLook)
                .text("Platform look")
                .horizontalAlignment(.center)

            SectionTitle("A style for a role")

            // Each wears the style its role chooses, over the one every button
            // wears: the role's style says only what the role changes.
            HStack {
                Button("Keep").style(look).role(.cancel)
                Button("Delete").style(look).role(.destructive)
            }
            .spacing(12)
            .horizontalAlignment(.center)

            SectionTitle("A style asked for by name")

            // A keyed style is asked for; a keyed style REPLACES the implicit
            // one, so it says everything it needs.
            Text("Headline")
                .style(.headline)

            SectionTitle("A style written from another")

            // The same words twice. "Quote" states the shape; "QuoteLoud" is
            // `.basedOn(.quote)` plus one color - so everything that matches
            // below is inherited, and the one thing that differs is the one
            // thing it declares.
            Text("The same eleven words, and one of these declares a color.")
                .style(.quote)

            Text("The same eleven words, and one of these declares a color.")
                .style(.quoteLoud)
        }
        .spacing(14)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("\"Save\" and \"Cancel\" say nothing of their look: both wear the gallery's "
                + "`Style<Button>()`, which every button wears. Platform look shows them in the platform's own.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("\"Keep\" and \"Delete\" wear `Style<Button>(role:)`, the style of their role, standing over "
                + "`Style<Button>()`: each says only what its role changes.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A style with no key is implicit: every control of its type wears it, "
                + "as every button here wears `Style<Button>()`. `Headline` has a key "
                + "and is asked for by name, and a keyed style REPLACES the implicit one, "
                + "so it says everything it needs.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Both quotes are italic, both are 17 point, both are centered, both "
                + "carry the same letter spacing - and only one of them says so. "
                + "`QuoteLoud` is `.basedOn(.quote)` and a text color, which "
                + "is the whole of its declaration. A property the child states "
                + "wins; every property it leaves out comes from the parent.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Every color these styles use is one `Color(light:dark:)`, a value "
                + "for each theme. None of this crosses the boundary: the styles are "
                + "resolved in Swift, into the controls, so what the host receives is "
                + "a button with its colors already on it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
