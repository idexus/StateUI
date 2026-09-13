namespace Gallery;

/// <summary>
/// An ordinary MAUI control written in C# - three lamps in a housing, one lit
/// at a time. Nothing about it knows StateUI: it is registered in
/// <see cref="MauiProgram"/> with <c>StateUIControls.Add</c>, and that
/// registration is the whole bridge - see
/// Swift/Samples/Interop/CustomControlSample.swift for the other half.
/// </summary>
public sealed class TrafficLight : ContentView
{
    /// <summary>A lamp was tapped; the argument is its index, top to bottom.</summary>
    /// <remarks>
    /// The control does NOT switch itself: it reports, and whoever owns the
    /// state decides - which is exactly the split StateUI is built on, so
    /// the Swift side can own the state like it owns every other.
    /// </remarks>
    public event EventHandler<int>? LampTapped;

    /// <summary>
    /// Which lamp is lit, as the member the Swift side numbers: stop 0,
    /// caution 1, go 2. Anything else - the initial -1 included - lights
    /// nothing.
    /// </summary>
    /// <remarks>
    /// A NUMBER rather than a name, because the wire says so: a closed
    /// vocabulary crosses as its member and only text crosses as text. The
    /// two lists are this application's own contract, declared as
    /// <c>TrafficSignal</c> in Swift and as these three numbers here - there
    /// is no MAUI enum behind a control the application invented.
    /// </remarks>
    public int State
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

                // A composed control lives in whatever application adopts it,
                // and an implicit BoxView style there paints an accent
                // BackgroundColor - which would glow through the dimmed
                // lamps' alpha. A local value beats any style, which is
                // MAUI's own precedence and the ordinary answer.
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
            _lamps[index].Color = index == State
                ? LampColors[index]
                : LampColors[index].WithAlpha(0.18f);
        }
    }
}
