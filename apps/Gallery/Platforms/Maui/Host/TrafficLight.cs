namespace Gallery;

/// <summary>
/// Three lamps in a housing, one lit at a time - an ordinary MAUI control that
/// knows nothing of StateUI.
/// </summary>
/// <remarks>
/// <see cref="MauiProgram"/> registers it with <c>StateUIControls.Add</c>, and
/// that registration is the whole bridge. The Swift half is
/// <c>Sources/Samples/Interop/CustomControlSample.swift</c>.
/// </remarks>
public sealed class TrafficLight : ContentView
{
    /// <summary>A lamp was tapped; the argument is its index, top to bottom.</summary>
    /// <remarks>
    /// The control does not switch itself: it reports, and whoever owns the
    /// state decides.
    /// </remarks>
    public event EventHandler<int>? LampTapped;

    /// <summary>
    /// Which lamp is lit, as the member number the Swift side sends: stop 0,
    /// caution 1, go 2. Anything else - the initial -1 included - lights
    /// nothing.
    /// </summary>
    /// <remarks>
    /// A number, because a closed vocabulary crosses as its member. The three
    /// numbers are this application's own contract, declared as
    /// <c>TrafficSignal</c> in Swift and mirrored here.
    /// </remarks>
    public int Signal
    {
        get;
        set { field = value; Repaint(); }
    } = -1;

    private static readonly Color[] LampColors =
    [
        Color.FromArgb("#E5484D"),
        Color.FromArgb("#F5B546"),
        Color.FromArgb("#46B45F"),
    ];

    private readonly BoxView[] _lamps = new BoxView[3];

    /// <summary>The housing and its three lamps, wired once.</summary>
    public TrafficLight()
    {
        var column = new VerticalStackLayout { Spacing = 10, Padding = new Thickness(12) };

        for (int index = 0; index < _lamps.Length; index++)
        {
            var lamp = new BoxView
            {
                WidthRequest = 44,
                HeightRequest = 44,
                CornerRadius = 22,

                // Set locally, so nothing behind a dimmed lamp shows through
                // its alpha in any application that adopts the control.
                BackgroundColor = Colors.Transparent,
            };

            int tapped = index;
            var tap = new TapGestureRecognizer();
            tap.Tapped += (_, _) => LampTapped?.Invoke(this, tapped);
            lamp.GestureRecognizers.Add(tap);

            _lamps[index] = lamp;
            column.Children.Add(lamp);
        }

        Content = new Border
        {
            BackgroundColor = Color.FromArgb("#1A1725"),
            StrokeThickness = 0,
            StrokeShape = new Microsoft.Maui.Controls.Shapes.RoundRectangle { CornerRadius = 18 },
            HorizontalOptions = LayoutOptions.Center,
            Content = column,
        };

        Repaint();
    }

    /// <summary>The lit lamp at full colour, the others dimmed to embers.</summary>
    private void Repaint()
    {
        for (int index = 0; index < _lamps.Length; index++)
        {
            _lamps[index].Color = index == Signal
                ? LampColors[index]
                : LampColors[index].WithAlpha(0.18f);
        }
    }
}
