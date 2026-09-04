import StateUI

/// Moving a registered control's own value: the registration DECLARED the
/// BindableProperty, the app's own `.rating($stars)` drives it from a state the
/// HOST carries, and `$stars.animateTo(…)` sends it. ONE state, because an
/// animated value already answers both questions - `value` is where the control
/// has got to, `setPoint` where it is going. The shared RatingBar struct is in
/// RatingBar.swift, beside this file.
struct CustomAnimationSample: SampleContent {
    /// Where the stars are, and where they are going. The host moves it.
    @Bus private var stars = AnimatedValue(0.0)

    /// What the caption says, which an engine works out from the stars.
    @Bus private var reading = "0.0 of 0"

    static let id = "custom-animation"
    static let title = "Animating a C# value"
    static let summary = "A registered control's declared property, driven by a bus."

    static let code = """
        // The registration DECLARES the property (see Binding a C# value), and
        // that one declaration is what makes it both styleable and movable.
        // The app's own driven modifier is one line over setValue(on:mode:kind:):
        //
        //     func rating(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        //         setValue(.rating, on: state, mode: .inOut, kind: .property)
        //     }
        //
        // ONE state: an animated value holds where the control HAS GOT TO and
        // where it is GOING, so nothing needs a second one.
        @Bus private var stars = AnimatedValue(0.0)
        @Bus private var reading = "0.0 of 0"

        VStack {
            RatingBar()
                .rating($stars)     // driven: the host moves RatingProperty

            // Off the driven state: written every frame, described never.
            Label().text($reading)

            Button("Sweep to five")
                .onClicked {
                    try await $stars.animateTo(5, .eased(1200, .sinInOut))
                }

            Button("Fall back to one")
                .onClicked {
                    try await $stars.animateTo(1, .eased(600, .cubicOut))
                }

            // The other spelling: a VALUE written is a snap, and it ends any
            // movement the property was on.
            Button("Snap to three")
                .onClicked { stars.value = 3 }
        }
        // Whole stars step, tenths glide - which is what makes the movement
        // visible, and it costs no render at all.
        .engine(in: $stars) { _ in
            let tenths = Int((stars.value * 10).rounded())
            reading = "\\(tenths / 10).\\(tenths % 10) of \\(Int(stars.setPoint))"
        }
        """

    /// The half that makes the movement possible: the registration DECLARES the
    /// BindableProperty, so the host can resolve it by name and move it. The
    /// control itself is the binding sample's.
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

        // A driven property arrives as a REGISTRATION and never as a value: the
        // host resolves RatingProperty through the same table a style setter
        // uses, and from then on it reads the property off the state on its own
        // frames. No message after that one mentions the rating at all. Every
        // frame assigns RatingProperty, so the control raises RatingChanged as
        // it always did - which is what makes a tapped star reach the state
        // too, the report arriving from outside the host's own write.
        """

    var example: Element {
        VStack {
            RatingBar()
                .rating($stars)
                .horizontalOptions(.center)

            Label()
                .text($reading)
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Button("Sweep to five")
                .onClicked {
                    try await $stars.animateTo(5, .eased(1200, .sinInOut))
                }

            Button("Fall back to one")
                .onClicked {
                    try await $stars.animateTo(1, .eased(600, .cubicOut))
                }

            Button("Snap to three")
                .onClicked { stars.value = 3 }
        }
        .spacing(5)
        .engine(in: $stars) { _ in
            let tenths = Int((stars.value * 10).rounded())
            reading = "\(tenths / 10).\(tenths % 10) of \(Int(stars.setPoint))"
        }
    }

    var notes: Element? {
        VStack {
            Label("A control the app registered is moved exactly like a library one. "
                + "Declaring RatingProperty in the registration is what makes the value "
                + "styleable and movable; the app then adds one line - a `.rating` "
                + "modifier taking a driven state, written over `setValue(_:on:mode:kind:)`, "
                + "on the control itself rather than on its properties protocol.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The state holds both readings at once: press Sweep to five and the "
                + "caption's second number reads 5 immediately, while the first counts "
                + "up over 1200ms. `setPoint` is where the value is going, `value` is "
                + "where it has got to, and the host writes the second one every frame.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Nothing on this page is described while the stars fill. The caption "
                + "is a driven text an engine writes, and the engine runs on the "
                + "display's own frames - so a 1200ms sweep costs the arithmetic and "
                + "no renders at all. Snap to three writes `stars.value`, which is the "
                + "one write that does not travel.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
