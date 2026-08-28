using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text;
using Gtk;
using Microsoft.Maui.Handlers;

namespace Gallery;

/// <summary>
/// Gives every widget one style sheet of its own, holding everything at once.
/// </summary>
/// <remarks>
/// <para>
/// The GTK4 backend styles a widget by writing CSS, and it keeps ONE
/// <c>CssProvider</c> per handler: <c>ApplyCss</c> REMOVES the provider it made
/// last before adding the next. So the mappers overwrite each other, and what a
/// widget ends up wearing is whichever of them ran last - for a Label that is
/// <c>MapCharacterSpacing</c>, which runs unconditionally, so every label on
/// screen carries a letter-spacing and nothing else. Measured in a MAUI app with
/// none of this library in it: a 34-point bold white label drew at the theme's
/// size in the theme's colour, and a Border given a gradient drew nothing.
/// </para>
/// <para>
/// This is a provider of OUR OWN, at a priority above theirs, carrying every
/// property together - so nothing they do can remove it and nothing they write
/// can outrank it. What is left to them is what this does not name.
/// </para>
/// <para>
/// It is hung on <c>ViewHandler.ViewMapper</c>, which is MAUI's own and the
/// bottom of every handler's chain on this platform, so one hook dresses every
/// view there is - under a key of its OWN, because a mapper resolves a key by
/// the FIRST holder it finds and a concrete handler declaring "TextColor" would
/// hide anything appended to the base's. A key nobody else has is run for every
/// view all the same, as the handler is built.
/// </para>
/// <para>
/// What happens AFTERWARDS is the view's own to report: a mapper runs again only
/// for the property that changed, and that is one of the keys just described as
/// hidden. So the sheet is rewritten from <c>PropertyChanged</c>, which every
/// VisualElement raises and nothing can shadow.
/// </para>
/// </remarks>
internal static class LinuxStyling
{
    /// <summary>
    /// Above the backend's 600, so what this writes is what is drawn.
    /// GTK's own application priority is 600 and a theme's is 200.
    /// </summary>
    private const uint Priority = 700;

    /// <summary>
    /// What a view can change that this sheet is written from. Anything else it
    /// reports is somebody else's business and costs nothing to ignore.
    /// </summary>
    private static readonly HashSet<string> Watched =
    [
        "Background", "BackgroundColor", "TextColor", "FontSize", "FontFamily",
        "FontAttributes", "CharacterSpacing", "TextDecorations", "LineHeight",
    ];

    /// <summary>
    /// The sheet each widget is wearing, so it can be taken off again.
    /// </summary>
    /// <remarks>
    /// KEYED BY THE WIDGET rather than by its address: a widget that goes away
    /// frees its address for the next one, and an entry left under that number
    /// would have the next widget's sheet taken off by a provider that was never
    /// on it. A weak table also forgets on its own, where a dictionary of every
    /// widget ever drawn would not.
    /// </remarks>
    private static readonly ConditionalWeakTable<Widget, CssProvider> Worn = [];

    /// <summary>The views already listened to, so each is heard once.</summary>
    private static readonly HashSet<VisualElement> Heard = [];

    /// <summary>Arms every handler in the application.</summary>
    internal static void Install() =>
        ViewHandler.ViewMapper.AppendToMapping("StateUILinuxStyling", (handler, view) =>
        {
            if (handler.PlatformView is not Widget widget)
            {
                return;
            }

            Dress(widget, Sheet(view));

            if (view is VisualElement element && Heard.Add(element))
            {
                element.PropertyChanged += (_, what) =>
                {
                    if (what.PropertyName is { } name && Watched.Contains(name)
                        && element.Handler?.PlatformView is Widget drawn)
                    {
                        Dress(drawn, Sheet(element));
                    }
                };
            }
        });

    /// <summary>Everything this view asks to look like, as one block of CSS.</summary>
    /// <param name="view">The view to read.</param>
    /// <returns>The declarations, or an empty string where it asks for nothing.</returns>
    private static string Sheet(IView view)
    {
        var css = new StringBuilder();

        switch (view.Background)
        {
            case SolidPaint solid when solid.Color is { } fill:
                css.Append($"background-image: none; background-color: {Rgba(fill)};");
                break;

            case LinearGradientPaint ramp:
                css.Append("background-color: transparent; background-image: linear-gradient(")
                    .Append($"{Angle(ramp.StartPoint, ramp.EndPoint):F0}deg, {Stops(ramp)});");
                break;

            case RadialGradientPaint ring:
                css.Append("background-color: transparent; background-image: radial-gradient(")
                    .Append($"circle {ring.Radius * 100:F0}% at ")
                    .Append($"{ring.Center.X * 100:F0}% {ring.Center.Y * 100:F0}%, {Stops(ring)});");
                break;
        }

        if (view is ITextStyle text)
        {
            if (text.TextColor is { } colour)
            {
                css.Append($"color: {Rgba(colour)};");
            }

            Microsoft.Maui.Font font = text.Font;

            if (font.Size > 0 && !double.IsNaN(font.Size))
            {
                css.Append($"font-size: {font.Size.ToString("F1", CultureInfo.InvariantCulture)}px;");
            }

            if (!string.IsNullOrEmpty(font.Family))
            {
                css.Append($"font-family: \"{font.Family}\";");
            }

            // MAUI's weights are CSS's own numbers, so they travel as they are -
            // and the italic half of Font is a slant rather than a weight.
            css.Append($"font-weight: {(int)font.Weight};");
            css.Append(font.Slant == FontSlant.Default ? "font-style: normal;" : "font-style: italic;");
        }

        if (view is ILabel label)
        {
            css.Append($"letter-spacing: {label.CharacterSpacing.ToString("F2", CultureInfo.InvariantCulture)}px;");
            css.Append(Decorations(label.TextDecorations));
        }

        return css.ToString();
    }

    /// <summary>What underline and strikethrough are called in CSS.</summary>
    /// <param name="decorations">What the label asked for.</param>
    /// <returns>One declaration, always - a label that asks for nothing says so.</returns>
    private static string Decorations(TextDecorations decorations)
    {
        bool underline = decorations.HasFlag(TextDecorations.Underline);
        bool strike = decorations.HasFlag(TextDecorations.Strikethrough);

        return (underline, strike) switch
        {
            (true, true) => "text-decoration-line: underline line-through;",
            (true, false) => "text-decoration-line: underline;",
            (false, true) => "text-decoration-line: line-through;",
            _ => "text-decoration-line: none;",
        };
    }

    /// <summary>A gradient's stops, in the order CSS wants them.</summary>
    /// <param name="paint">The gradient to read.</param>
    /// <returns>The stops, comma separated.</returns>
    private static string Stops(GradientPaint paint) =>
        string.Join(", ", paint.GradientStops
            .OrderBy(stop => stop.Offset)
            .Select(stop => $"{Rgba(stop.Color)} {(stop.Offset * 100).ToString("F0", CultureInfo.InvariantCulture)}%"));

    /// <summary>
    /// The direction of a gradient, as the angle CSS measures - clockwise from
    /// "up", where MAUI gives two points in the view's own unit square.
    /// </summary>
    /// <param name="start">Where the first stop sits.</param>
    /// <param name="end">Where the last one does.</param>
    /// <returns>The angle in degrees.</returns>
    private static double Angle(Point start, Point end) =>
        (Math.Atan2(end.X - start.X, start.Y - end.Y) * 180 / Math.PI + 360) % 360;

    /// <summary>A colour, as CSS spells one.</summary>
    /// <param name="colour">The colour to write.</param>
    /// <returns>An rgba() call.</returns>
    private static string Rgba(Color colour) =>
        string.Create(CultureInfo.InvariantCulture,
            $"rgba({(int)(colour.Red * 255)},{(int)(colour.Green * 255)},{(int)(colour.Blue * 255)},{colour.Alpha})");

    /// <summary>Puts one sheet on one widget, taking off the one before it.</summary>
    /// <param name="widget">The widget to dress.</param>
    /// <param name="css">What it should wear.</param>
    private static void Dress(Widget widget, string css)
    {
        StyleContext context = widget.GetStyleContext();

        if (Worn.TryGetValue(widget, out CssProvider? before))
        {
            Worn.Remove(widget);
            context.RemoveProvider(before);
        }

        if (css.Length == 0)
        {
            return;
        }

        var provider = CssProvider.New();
        provider.LoadFromString("* { " + css + " }");
        context.AddProvider(provider, Priority);
        Worn.Add(widget, provider);
    }
}
