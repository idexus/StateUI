#if MAUI
import StateUI

/// A `Style` whose target is a registered control. The conformances are in
/// RatingBar.swift and the keyed style is in Styles/AppStyles.swift.
struct CustomStyleSample: SampleContent, ExampleContent {
    @State private var styled = 0.0
    @State private var plain = 0.0

    static let id = "customStyle"
    static let title = "Styling a C# control"
    static let summary = "Style<RatingBar> - a style whose target is a control the app registered."

    static let code = """
        // Two lines make the registered control styleable:
        extension RatingBar: StyleTarget {}
        extension StyleBag: RatingBarProperties where Target == RatingBar {}

        // In the application's style sheet - keyed, so only a bar that asks
        // wears it. `rating` is the control's own setter, `background` is
        // every view's:
        Style<RatingBar>("FourStars")
            .rating(4)
            .background(Palette.selected)

        @State private var styled = 0.0
        @State private var plain = 0.0

        VStack {
            // Both values are read here, so a tap on either bar builds this
            // closure.
            DebugInfoLabel()

            Label(styled > 0 ? "FourStars, tapped \\(Int(styled))" : "FourStars")

            // The style gives four stars and the wash. The bar listens and
            // writes nothing: a value written on the control beats its style.
            RatingBar()
                .style("FourStars")
                .onRatingChanged { styled = $0 }

            Label(plain > 0 ? "No style, tapped \\(Int(plain))" : "No style")

            RatingBar($plain)
        }
        """

    static let hostCode = HostCode(
        heading: "In C#",
        language: .csharp,
        code: """
            // In MauiProgram.CreateMauiApp - the same registration the other
            // samples use, and nothing in it mentions styling.
            StateUIControls.Add("Gallery.RatingBar",
                create: raise =>
                {
                    var stars = new RatingBar();
                    stars.RatingChanged += (_, rating) =>
                        raise(stars, "ratingChanged", HostValue.Of(rating));
                    return stars;
                },
                properties: new Dictionary<string, BindableProperty>
                {
                    ["rating"] = RatingBar.RatingProperty,
                });

            // A style is resolved on the Swift side, by node type, and arrives
            // here as the control's own values: "rating" lands because it is
            // declared above, through the same table a walked value goes
            // through.
            """)

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label(styled > 0 ? "FourStars, tapped \(Int(styled))" : "FourStars")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            RatingBar()
                .style("FourStars")
                .onRatingChanged { styled = $0 }
                .horizontalAlignment(.center)

            Label(plain > 0 ? "No style, tapped \(Int(plain))" : "No style")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            RatingBar($plain)
                .horizontalAlignment(.center)
        }
        .spacing(8)
    }

    var notes: Element? {
        VStack {
            Label("The styled bar starts at four stars on a wash, and no modifier on it "
                + "says so: the keyed style carries both - the control's own `rating` "
                + "setter beside the `background` every view has.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A style resolves on this side, by the node type `RatingBar()` makes, "
                + "so the host receives a control with the values already on it; "
                + "`rating` lands because the C# registration declares it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The styled bar listens without writing: `RatingBar($styled)` would "
                + "put the value on the control itself, and a value written on a control "
                + "beats its style, property by property. The bar below wears no style "
                + "and starts at its own 0.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
