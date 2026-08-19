import StateUI

/// A value the user changes on the platform side, lent to the control with
/// `$` - the pattern every built-in input follows, on a control the app
/// registered itself. The shared RatingBar struct is in RatingBar.swift,
/// beside this file; the style and animation samples drive the same control.
struct CustomBindingSample: SampleContent {
    @State private var stars = 3.0

    static let id = "custom-binding"
    static let title = "Binding a C# value"
    static let summary = "A registered control lent a value with $ - two-way, like Entry."

    static let code = """
        // The C# RatingBar and its registration are the IN C# listing below.
        // The binding form is the library's own pattern written by hand: the
        // init sets the value and registers the write-back - through
        // onEvent, so a handler written after it runs BESIDE it. The
        // property modifier sits on a protocol, the library's own shape,
        // which is also what lets a Style set it (see Styling a C# control).
        extension NodeType { static let ratingBar = NodeType("Gallery.RatingBar") }
        extension Prop { static let rating = Prop("rating") }
        extension Event { static let ratingChanged = Event("ratingChanged") }

        protocol RatingBarProperties: PropertyContainer {}

        extension RatingBarProperties {
            func rating(_ value: Double) -> Modified {
                setValue(.rating, .number(value))
            }
        }

        struct RatingBar: View, RatingBarProperties {
            var node = Node(type: .ratingBar)

            init() {}

            init(_ rating: Binding<Double>) {
                self = self
                    .rating(rating.wrappedValue)
                    .onRatingChanged { rating.wrappedValue = $0 }
            }

            func onRatingChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
                onEvent(.ratingChanged) { payload in
                    if let rating = payload.value()?.number {
                        try await handler(rating)
                    }
                }
            }
        }

        @State private var stars = 3.0

        VStack {
            // Tap a star and the binding writes the state; write the state
            // - the Clear button - and the next render writes the control.
            RatingBar($stars)

            Label("you gave \\(Int(stars)) of 5")

            Button("Clear")
                .onClicked { stars = 0 }
        }
        """

    /// The other half: the value as a BindableProperty, and a registration
    /// that DECLARES it - no applier to write by hand.
    static let codeCSharp = """
        public sealed class RatingBar : ContentView
        {
            public event EventHandler<double>? RatingChanged;

            public static readonly BindableProperty RatingProperty = BindableProperty.Create(
                nameof(Rating), typeof(double), typeof(RatingBar), 0.0,
                propertyChanged: (bindable, _, now) =>
                {
                    var bar = (RatingBar)bindable;
                    bar.Repaint();
                    bar.RatingChanged?.Invoke(bar, (double)now);
                });

            public double Rating
            {
                get => (double)GetValue(RatingProperty);
                set => SetValue(RatingProperty, value);
            }

            public RatingBar()
            {
                var row = new HorizontalStackLayout { Spacing = 6 };

                for (int index = 0; index < _stars.Length; index++)
                {
                    _stars[index] = new Label { Text = "★", FontSize = 34 };
                    row.Children.Add(_stars[index]);
                }

                // ONE recognizer on the row, the star read from the tap's
                // position - a per-Label recognizer does not fire on Mac
                // Catalyst, and the position form needs no per-platform
                // hit-testing at all.
                var tap = new TapGestureRecognizer();
                tap.Tapped += (_, e) =>
                {
                    if (e.GetPosition(row) is Point at && row.Width > 0)
                    {
                        int star = (int)(at.X / (row.Width / _stars.Length));
                        Rating = Math.Clamp(star, 0, _stars.Length - 1) + 1;
                    }
                };
                row.GestureRecognizers.Add(tap);

                Content = row;
                Repaint();
            }

            private void Repaint()
            {
                for (int index = 0; index < _stars.Length; index++)
                {
                    _stars[index].TextColor = Rating >= index + 1 ? Lit : Ember;
                }
            }

            private static readonly Color Lit = Color.FromArgb("#F5B546");
            private static readonly Color Ember = Lit.WithAlpha(0.22f);
            private readonly Label[] _stars = new Label[5];
        }

        // And the registration, in MauiProgram.CreateMauiApp - the value is
        // DECLARED, so the renderer assigns it, an animation can walk it and
        // a style can set it:
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
        """

    var content: Element {
        VStack {
            RatingBar($stars)
                .horizontalOptions(.center)

            Label("you gave \(Int(stars)) of 5")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Button("Clear")
                .onClicked { stars = 0 }

            Label("The `$` is the whole pattern: RatingBar($stars) sets the value "
                + "and registers the write-back in one place, exactly as "
                + "Entry($text) does. Tap a star and the C# control raises its "
                + "event, the binding writes the @State, and the label follows; "
                + "press Clear and the state writes the control back. The "
                + "renderer swallows the echo - a value assigned during a render "
                + "never reports itself as a tap.")
                .fontSize(14)
                .textColor(Palette.subtle)
        }
        .spacing(5)
    }
}
