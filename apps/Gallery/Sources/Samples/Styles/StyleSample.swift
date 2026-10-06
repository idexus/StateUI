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

            // Neither of these says anything about its own appearance. The
            // orange, the corners, the padding and the 44pt minimum all come
            // from Style<Button> in AppStyles.swift.
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
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($enabled)
                    .accessibilityIdentifier("styles.enabled")
                    .accessibilityLabel("Enabled")
            }
            .spacing(12)
            .horizontalAlignment(.center)

            SectionTitle("A style asked for by name")

            // The others are implicit - they have no key, so every control of
            // the type gets them. This one has one, and is asked for; a keyed
            // style REPLACES the implicit one, so it says everything it needs.
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
            Text("No button in the example sets a colour, a size or a corner: every "
                + "button takes all of it from the gallery's one `Style<Button>`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A style with no key is implicit: every control of its type wears it. "
                + "`Headline` has a key and is asked for by name, and a keyed style "
                + "REPLACES the implicit one, so it says everything it needs.")
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
