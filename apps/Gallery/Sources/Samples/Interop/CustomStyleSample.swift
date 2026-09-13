import StateUI

/// A `Style` whose target is a REGISTERED control: a style resolves on this
/// side by the node type `RatingBar()` makes, exactly as a Label's does, so
/// the shared tier's setters land, and the control's own declared property
/// takes a setter too. The conformances that make it compile are in
/// RatingBar.swift.
struct CustomStyleSample: SampleContent {
    @State private var styled = 0.0
    @State private var plain = 0.0

    static let id = "custom-style"
    static let title = "Styling a C# control"
    static let summary = "Style<RatingBar> - a registered type as a style's target."

    static let code = """
        // Two lines make an app control styleable - a style target is any
        // VisualElement with an empty init, and the property protocol is
        // what hands the style the control's own setters:
        extension RatingBar: StyleTarget {}
        extension StyleBag: RatingBarProperties where Target == RatingBar {}

        // The style itself, in the app's resources - keyed, so only the
        // control that asks wears it. `rating` is the app's own setter,
        // `backgroundColor` is the shared tier's:
        Style<RatingBar>("FourStars")
            .rating(4)
            .backgroundColor(Palette.selected)

        @State private var styled = 0.0
        @State private var plain = 0.0

        VStack {
            // Both values are read here, so a report from either bar builds
            // this closure.
            DebugInfoLabel()

            Label("STYLED - FourStars" + (styled > 0 ? ", tapped \\(Int(styled))" : ""))

            // Asked for by key - four stars and a wash arrive from the
            // style, with not one modifier written here. The bar LISTENS
            // without writing: RatingBar($styled) would set the value as a
            // local one, and a local value beats a style, MAUI's own
            // precedence.
            RatingBar()
                .style("FourStars")
                .onRatingChanged { styled = $0 }

            Label("BARE" + (plain > 0 ? ", tapped \\(Int(plain))" : ""))

            // The same control bare, its value the binding's.
            RatingBar($plain)
        }
        """

    /// The other half: the registration, and nothing more. The style resolves
    /// on the Swift side and arrives as the control's own values, and `rating`
    /// lands because the registration declares it.
    static let codeCSharp = """
        StateUIControls.Add("Gallery.RatingBar",
            create: raise =>
            {
                var stars = new RatingBar();
                stars.RatingChanged += (_, rating) =>
                    raise(stars, "ratingChanged", SwiftWireValue.Of(rating));
                return stars;
            },
            properties: new Dictionary<string, BindableProperty>
            {
                ["rating"] = RatingBar.RatingProperty,
            });

        // A style is resolved on the Swift side, by node type, and arrives here
        // as the control's own values: "rating" lands because it is declared
        // above, through the same table a driven property goes through.
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label("STYLED - FourStars" + (styled > 0 ? ", tapped \(Int(styled))" : ""))
                .fontSize(12)
                .textColor(Palette.subtle)

            RatingBar()
                .style("FourStars")
                .onRatingChanged { styled = $0 }
                .horizontalOptions(.center)

            Label("BARE" + (plain > 0 ? ", tapped \(Int(plain))" : ""))
                .fontSize(12)
                .textColor(Palette.subtle)

            RatingBar($plain)
                .horizontalOptions(.center)

        }
        .spacing(8)
    }

    var notes: Element? {
        Label("The styled bar starts at four stars on a wash, and not one "
            + "modifier above says so - the keyed style carries both, the "
            + "app's own `rating` setter beside the shared tier's "
            + "backgroundColor. It listens without writing, on purpose: "
            + "RatingBar($styled) would set the value as a LOCAL one, and "
            + "a local value beats a style - MAUI's own precedence, the "
            + "same rule every built-in follows. The bare bar below wears "
            + "no style, and starts at its own 0.")
            .fontSize(14)
            .textColor(Palette.subtle)
    }
}
