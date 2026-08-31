import StateUI

/// Flying a registered control's own value: the registration DECLARED the
/// BindableProperty, the app's own `.rating($stars)` writes it FROM the state -
/// which ARMS it - and `$stars.animateTo(…)` walks it. Two states, because they
/// answer two questions: where the value is GOING, and where the control has
/// GOT to. The shared RatingBar struct is in RatingBar.swift, beside this file.
struct CustomAnimationSample: SampleContent {
    @State private var stars = 0.0
    @State private var shown = 0.0

    static let id = "custom-animation"
    static let title = "Animating a C# value"
    static let summary = "A registered control's declared property, armed by its binding and flown."

    /// `shown` to one decimal, which is what makes the walk visible: whole
    /// stars step, tenths glide.
    private var showing: String {
        let tenths = Int((shown * 10).rounded())
        return "\(tenths / 10).\(tenths % 10)"
    }

    static let code = """
        // The registration DECLARES the property (see Binding a C# value), and
        // that one declaration is what makes it both styleable and walkable.
        // The app's own armed modifier is one line over setValue(armedOn:):
        //
        //     func rating(_ value: Binding<Double>) -> Modified {
        //         setValue(.rating, .number(value.wrappedValue), armedOn: value)
        //     }
        //
        // Two states, because they answer two different questions.
        @State private var stars = 0.0   // where the value is going
        @State private var shown = 0.0   // where the control has got to

        // `shown` to one decimal, which is what makes the walk visible:
        // whole stars step, tenths glide.
        private var showing: String {
            let tenths = Int((shown * 10).rounded())
            return "\\(tenths / 10).\\(tenths % 10)"
        }

        VStack {
            RatingBar()
                .rating($stars)                     // armed: the flight walks it
                .onRatingChanged { shown = $0 }     // the control's own report

            Label("going to \\(Int(stars)) — showing \\(showing)")

            Button("Sweep to five")
                .onClicked {
                    try await $stars.animateTo(5, .eased(1200, .sinInOut))
                }

            Button("Fall back to one")
                .onClicked {
                    try await $stars.animateTo(1, .eased(600, .cubicOut))
                }

            // The other spelling: an assignment snaps, and ends any walk.
            Button("Snap to three")
                .onClicked { stars = 3 }
        }
        """

    /// The half that makes the walk possible: the registration DECLARES the
    /// BindableProperty, so the host can resolve it by name and walk it. The
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

        // A flown property arrives as a value with a transition beside it. The
        // host takes it OUT of the patch - so the assignment that would have
        // snapped never happens - resolves RatingProperty through the same
        // table a style setter uses, and walks it from wherever the control is
        // now. Every frame assigns RatingProperty, so the control raises
        // RatingChanged as it always did; nothing here knows a flight from a
        // tapped star, and that event is where the intermediate values are.
        """

    var content: Element {
        VStack {
            RatingBar()
                .rating($stars)
                .onRatingChanged { shown = $0 }
                .horizontalOptions(.center)

            Label("going to \(Int(stars)) — showing \(showing)")
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
                .onClicked { stars = 3 }
        }
        .spacing(5)
    }

    var notes: Element? {
        VStack {
            Label("A control the app registered is flown exactly like a library one. "
                + "Declaring RatingProperty in the registration is what makes the value "
                + "styleable and animatable; the app then adds one line - a `.rating` "
                + "modifier taking a Binding, written over `setValue(_:_:armedOn:)`, on "
                + "the control itself rather than on its properties protocol.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The state is given the target AT ONCE: press Sweep to five and "
                + "\"going to 5\" reads immediately, while the stars take 1200ms to fill. "
                + "The tree says where the value is GOING; the walk is the control's. "
                + "Snap to three is the other spelling - a plain assignment to an armed "
                + "property snaps it, and ends any walk it was on.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A reading that SWEEPS is a second state: `.onRatingChanged` puts what "
                + "the control reports into `shown`, and the label glides while the model "
                + "stands at its target. Do not write those back into `stars` - assigning "
                + "an armed property ends the flight on its first frame.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
