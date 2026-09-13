namespace Gallery;

/// <summary>
/// A count bubble over whatever it is given - an ordinary MAUI control
/// written in C#, with ONE SLOT for content it does not describe itself.
/// That slot is what its registration's <c>content</c> fills (see
/// <see cref="MauiProgram"/>): the Swift side writes <c>Badge { … }</c>, the
/// child travels as the node's child, and the renderer reconciles it into
/// <see cref="Inner"/> - created, patched and kept by identity, the way a
/// Border's content is.
/// </summary>
public sealed class Badge : ContentView
{
    /// <summary>What the bubble says. At 0 the bubble hides - a badge with
    /// nothing to count is just its content.</summary>
    public static readonly BindableProperty CountProperty = BindableProperty.Create(
        nameof(Count), typeof(int), typeof(Badge), 0,
        propertyChanged: (bindable, _, _) => ((Badge)bindable).Repaint());

    /// <summary>The CLR face of <see cref="CountProperty"/>.</summary>
    public int Count
    {
        get => (int)GetValue(CountProperty);
        set => SetValue(CountProperty, value);
    }

    /// <summary>
    /// The one slot, filled by the renderer through the registration's
    /// <c>content</c> setter - only when the slot changes hands, so a patch
    /// that merely updates the held view never lands here.
    /// </summary>
    public View? Inner
    {
        set
        {
            if (_inner is not null)
            {
                _grid.Children.Remove(_inner);
            }

            _inner = value;

            if (value is not null)
            {
                // Under the bubble, which stays the topmost child.
                _grid.Children.Insert(0, value);
            }
        }
    }

    private readonly Grid _grid;
    private readonly Border _bubble;
    private readonly Label _count;
    private View? _inner;

    /// <summary>The bubble, wired once; the content arrives later.</summary>
    public Badge()
    {
        // Every colour is a LOCAL value on purpose: the adopting app's
        // implicit styles reach a composed control's children - the
        // TrafficLight lesson - and a badge must look like a badge whatever
        // the app dressed its Labels as.
        _count = new Label
        {
            TextColor = Colors.White,
            FontSize = 12,
            FontAttributes = FontAttributes.Bold,
            HorizontalTextAlignment = TextAlignment.Center,
            VerticalTextAlignment = TextAlignment.Center,
        };

        _bubble = new Border
        {
            BackgroundColor = Color.FromArgb("#E5484D"),
            Stroke = null,
            StrokeThickness = 0,
            StrokeShape = new Microsoft.Maui.Controls.Shapes.RoundRectangle
            {
                CornerRadius = new CornerRadius(11),
            },
            MinimumWidthRequest = 22,
            HeightRequest = 22,
            Padding = new Thickness(6, 0),
            HorizontalOptions = LayoutOptions.End,
            VerticalOptions = LayoutOptions.Start,
            // Overhangs the content's corner, which is where a badge sits.
            TranslationX = 10,
            TranslationY = -10,
            Content = _count,
        };

        _grid = new Grid();
        _grid.Children.Add(_bubble);

        Content = _grid;
        Repaint();
    }

    /// <summary>The bubble shows the count, or nothing at zero.</summary>
    private void Repaint()
    {
        _count.Text = Count.ToString();
        _bubble.IsVisible = Count > 0;
    }
}
