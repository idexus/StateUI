#if MAUI
import StateUI

/// A registered control's declared property walked by the host:
/// `.rating($stars)` hands the state over, and `$stars.journey.move(to:_:)`
/// sends it. The RatingBar is in RatingBar.swift.
struct CustomAnimationSample: SampleContent, ExampleContent {
    /// Where the stars are going; `$stars.journey.value` is where they are.
    @State private var stars = 0.0

    /// The caption, which an engine works out from the stars.
    @State private var reading = "0.0 of 0"

    static let id = "customAnimation"
    static let title = "Animating a C# value"
    static let summary = "A registered control's declared property, walked by the host from a state."

    static let code = """
        // On the control, over the public registration for a walked value:
        //
        //     func rating(_ state: Binding<Double>) -> Modified {
        //         setValue(RatingBarContract.rating, on: state, mode: .inOut, kind: .property)
        //     }
        @State private var stars = 0.0
        @State private var reading = "0.0 of 0"

        VStack {
            // Nothing here reads `stars`: the bar and the caption are both
            // driven, so this stays at one build while the stars fill.
            DebugInfoLabel()

            RatingBar()
                .rating($stars)

            Label($reading)

            Button("Sweep to five")
                .onClicked {
                    try await $stars.journey.move(to: 5, .eased(1200, .sineInOut))
                }

            Button("Fall back to one")
                .onClicked {
                    try await $stars.journey.move(to: 1, .eased(600, .cubicOut))
                }

            // A snap puts the value there with no journey, and ends one.
            Button("Snap to three")
                .onClicked { $stars.journey.snap(to: 3) }
        }
        // Whole stars step and tenths glide; the caption is written on the
        // host's frames and costs no render.
        .engine(following: $stars) { _ in
            let tenths = Int(($stars.journey.value * 10).rounded())
            reading = "\\(tenths / 10).\\(tenths % 10) of \\(Int(stars))"
        }
        """

    static let hostCode = HostCode(
        heading: "In C#",
        language: .csharp,
        code: """
            // In MauiProgram.CreateMauiApp - the same registration again, and
            // nothing in it mentions animation.
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

            // A walked value arrives as a REGISTRATION and never as a value:
            // the host resolves RatingProperty through the same table a style
            // setter uses, and from then on reads the value off the state on
            // its own frames. No message after that one mentions the rating.
            // Every frame assigns RatingProperty under the host's own write,
            // so the RatingChanged it raises is refused before it reaches
            // Swift, and nothing on this page listens for a tapped star.
            """)

    var content: any View {
        VStack {
            DebugInfoLabel()

            RatingBar()
                .rating($stars)
                .horizontalAlignment(.center)

            Label($reading)
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Button("Sweep to five")
                .onClicked {
                    try await $stars.journey.move(to: 5, .eased(1200, .sineInOut))
                }

            Button("Fall back to one")
                .onClicked {
                    try await $stars.journey.move(to: 1, .eased(600, .cubicOut))
                }

            Button("Snap to three")
                .onClicked { $stars.journey.snap(to: 3) }
        }
        .spacing(8)
        .engine(following: $stars) { _ in
            let tenths = Int(($stars.journey.value * 10).rounded())
            reading = "\(tenths / 10).\(tenths % 10) of \(Int(stars))"
        }
    }

    var notes: Element? {
        VStack {
            Label("Declaring `RatingProperty` in the C# registration makes the value "
                + "styleable and walkable. The application adds one line - a "
                + "`.rating(_:)` taking a state, over the public "
                + "`setValue(_:on:mode:kind:)` - on the control itself, not on its "
                + "properties protocol.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The state answers both questions. `stars` is where the value is "
                + "going, so the caption's second number reads 5 at once; "
                + "`$stars.journey.value` is where it has got to, which the host writes "
                + "on every frame.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Nothing is described while the stars fill: the caption is a driven "
                + "text an engine writes on the display's frames, so a sweep costs the "
                + "arithmetic and no render. Snap to three is "
                + "`$stars.journey.snap(to: 3)`, the one write that does not travel.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
