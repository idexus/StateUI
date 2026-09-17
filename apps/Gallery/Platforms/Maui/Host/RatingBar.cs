namespace Gallery;

/// <summary>
/// Five stars, filled up to a rating - an ordinary MAUI control with its one
/// value as a <see cref="BindableProperty"/>.
/// </summary>
/// <remarks>
/// That property is what the registration in <see cref="MauiProgram"/>
/// declares: the renderer assigns it whenever a message carries it, a style
/// sets it, and a state walks it, because a declared property joins the table
/// the library's own properties are resolved through.
/// </remarks>
public sealed class RatingBar : ContentView
{
    /// <summary>The rating changed - a tap on a star, or any assignment.</summary>
    /// <remarks>
    /// The registration reports it to Swift; an assignment the renderer makes,
    /// on a render or on a walked frame, is not reported.
    /// </remarks>
    public event EventHandler<double>? RatingChanged;

    /// <summary>How many stars are filled, 0 through 5. A fraction fills a
    /// star once the value reaches it, which is what a walk shows star by
    /// star.</summary>
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
            // Both colours are set locally in Repaint, so the stars look the
            // same in any application that adopts the control.
            _stars[index] = new Label { Text = "★", FontSize = 34 };
            row.Children.Add(_stars[index]);
        }

        // One recognizer on the row, the star read from the tap's position: a
        // TapGestureRecognizer on a Label does not fire on Mac Catalyst, and
        // the position needs no per-platform hit-testing.
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
