namespace Gallery;

/// <summary>
/// Five stars, filled up to a rating - an ordinary MAUI control written in
/// C#, with its one value as a <see cref="BindableProperty"/>. That backing
/// is what its registration DECLARES (see <see cref="MauiProgram"/>): the
/// renderer then assigns the property whenever a message carries it, and an
/// animation can walk it, because a declared property joins the same table
/// the library's own properties sit in.
/// </summary>
public sealed class RatingBar : ContentView
{
    /// <summary>The rating changed - a tap on a star, or any assignment,
    /// which is MAUI's own convention for value controls.</summary>
    public event EventHandler<double>? RatingChanged;

    /// <summary>How many stars are filled, 0 through 5. A fraction fills a
    /// star once the value reaches it, which is what an ANIMATED sweep shows
    /// star by star.</summary>
    public static readonly BindableProperty RatingProperty = BindableProperty.Create(
        nameof(Rating), typeof(double), typeof(RatingBar), 0.0,
        propertyChanged: (bindable, _, now) =>
        {
            var bar = (RatingBar)bindable;
            bar.Repaint();
            bar.RatingChanged?.Invoke(bar, (double)now);
        });

    /// <summary>The CLR face of <see cref="RatingProperty"/>.</summary>
    public double Rating
    {
        get => (double)GetValue(RatingProperty);
        set => SetValue(RatingProperty, value);
    }

    private static readonly Color Lit = Color.FromArgb("#F5B546");
    private static readonly Color Ember = Color.FromArgb("#F5B546").WithAlpha(0.22f);

    private readonly Label[] _stars = new Label[5];

    /// <summary>The five stars, wired once.</summary>
    public RatingBar()
    {
        var row = new HorizontalStackLayout { Spacing = 6 };

        for (int index = 0; index < _stars.Length; index++)
        {
            // The adopting app's implicit Label style would colour these; a
            // local value - set in Repaint below, both states - is MAUI's
            // own precedence and the ordinary answer.
            _stars[index] = new Label { Text = "★", FontSize = 34 };
            row.Children.Add(_stars[index]);
        }

        // ONE recognizer on the row, the star read from the tap's position -
        // a per-Label recognizer does not fire on Mac Catalyst (measured:
        // the same taps land on a BoxView's), and the position form needs no
        // per-platform hit-testing at all.
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

    /// <summary>Stars up to the rating lit, the rest embers.</summary>
    private void Repaint()
    {
        for (int index = 0; index < _stars.Length; index++)
        {
            _stars[index].TextColor = Rating >= index + 1 ? Lit : Ember;
        }
    }
}
