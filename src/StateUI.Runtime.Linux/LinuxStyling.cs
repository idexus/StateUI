// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text;
using Gtk;
using Microsoft.Maui.Handlers;
using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Gives every widget one style sheet of its own, holding everything at once.
/// </summary>
/// <remarks>
/// <para>
/// The GTK4 backend styles a widget by writing CSS, and it keeps ONE
/// <c>CssProvider</c> per handler: <c>ApplyCss</c> REMOVES the provider it made
/// last before adding the next. So the mappers overwrite each other, and what a
/// widget ends up wearing is whichever of them ran last - for a Label that is
/// <c>MapCharacterSpacing</c>, which runs unconditionally, so without this a
/// label carries a letter-spacing and nothing else, and a gradient is never
/// painted at all.
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
[System.Runtime.Versioning.SupportedOSPlatform("linux")]
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
        "BorderColor", "BorderWidth", "CornerRadius",
        "Color", "Fill", "Stroke", "StrokeThickness", "Opacity", "Padding",
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
    /// <remarks>
    /// WEAKLY KEYED, for the reason <see cref="Worn"/> gives just above: a set
    /// of every view ever dressed is a hand on every control the application
    /// has ever built, and a page is built again on every visit.
    /// </remarks>
    private static readonly ConditionalWeakTable<VisualElement, object> Heard = [];

    /// <summary>Arms every handler in the application.</summary>
    internal static void Install()
    {
        Dressed();
        Toggled();
    }

    /// <summary>
    /// Paints the navigation bar's flyout button in the bar's own text colour.
    /// </summary>
    /// <remarks>
    /// The backend's <c>ApplyNavBarStyle</c> paints the bar's background, its
    /// title and its Back button from <c>BarTextColor</c>, and leaves the
    /// button that opens the flyout in the theme's own - which on a bar with a
    /// colour of its own is a dark glyph on a dark bar, invisible. The button
    /// is the FIRST child of the bar, which is the first child of the
    /// handler's own box, and it is dressed like any other widget here.
    /// </remarks>
    private static void Toggled() =>
        NavigationPageHandler.Mapper.AppendToMapping<IStackNavigationView, NavigationPageHandler>(
            "StateUILinuxNavBar",
            (handler, view) =>
            {
                if (view is not NavigationPage page
                    || page.BarTextColor is not { } colour
                    || handler.PlatformView?.GetFirstChild() is not Gtk.Box bar
                    || bar.GetFirstChild() is not Gtk.Button toggle)
                {
                    return;
                }

                Ink(toggle, colour);
            });

    /// <summary>Paints one widget's text, above whatever the backend wrote.</summary>
    /// <param name="widget">The widget to paint.</param>
    /// <param name="colour">What colour its text should be.</param>
    internal static void Ink(Widget widget, Color colour) =>
        Dress(widget, $"color: {Rgba(colour)};");

    /// <summary>Arms the style sheet every widget wears.</summary>
    private static void Dressed()
    {
        // A LABEL'S OWN MAPPER, because the backend writes the padding as a
        // margin from THERE - after the shared view mapper this one is
        // appended to, which is why zeroing it alongside the CSS was undone a
        // moment later (measured: the margins read 0/0 where this runs and
        // 8/8 by the time anything measures the widget).
        Microsoft.Maui.Platforms.Linux.Gtk4.Handlers.LabelHandler.Mapper.AppendToMapping(
            "StateUILinuxLabelPadding",
            (handler, view) =>
            {
                if (handler.PlatformView is Widget widget)
                {
                    Once(widget, view);
                }
            });

        Sheeted();
    }

    /// <summary>Dresses every widget in the CSS its view asks for.</summary>
    private static void Sheeted() =>
        ViewHandler.ViewMapper.AppendToMapping("StateUILinuxStyling", (handler, view) =>
        {
            if (handler.PlatformView is not Widget widget)
            {
                return;
            }

            Dress(widget, Sheet(view));

            if (view is VisualElement element)
            {
                Listen(element);
            }
        });

    /// <summary>
    /// Says a label's padding ONCE, where the backend's margin and this sheet's
    /// CSS would say it twice.
    /// </summary>
    /// <remarks>
    /// The backend hands a label's <c>Padding</c> to GTK as the widget's
    /// MARGIN, which leaves that room OUTSIDE the widget's own background -
    /// the reason the padding is written as CSS here at all, since a chosen
    /// row's colour has to cover it. The two together are the padding twice:
    /// measured on the gallery's *Selection*, whose rows are
    /// <c>.padding(12, 8)</c> labels, the widget asked for 51 points where its
    /// own drawing filled 35, and every list in the gallery laid its rows out
    /// a row's padding apart. The CSS is the half that paints, so the margin
    /// is the half that goes.
    /// </remarks>
    /// <param name="widget">What is drawn.</param>
    /// <param name="view">What described it.</param>
    private static void Once(Widget widget, ILabel view)
    {
        if (widget is Gtk.Label && view is Microsoft.Maui.Controls.Label { Padding: var room }
            && room != default)
        {
            widget.MarginTop = 0;
            widget.MarginBottom = 0;
            widget.MarginStart = 0;
            widget.MarginEnd = 0;
        }
    }

    /// <summary>Hears one view's own writes, once.</summary>
    /// <remarks>
    /// NOTHING THE SUBSCRIPTION MAKES MAY HOLD THE VIEW: the handler is a
    /// static method reading its own sender, so the delegate has no target to
    /// keep a control alive with, and the table it is remembered in is weakly
    /// keyed. The subscription itself lives on the view and goes with it. The
    /// same shape as <c>LinuxTransforms.Listen</c>, for the same reason.
    /// </remarks>
    /// <param name="view">The view to hear.</param>
    private static void Listen(VisualElement view)
    {
        if (Heard.TryGetValue(view, out _))
        {
            return;
        }

        Heard.AddOrUpdate(view, view);
        view.PropertyChanged += Redressed;
    }

    /// <summary>One view saying something it is drawn from was written.</summary>
    /// <param name="sender">The view.</param>
    /// <param name="what">Which property was written.</param>
    private static void Redressed(object? sender, System.ComponentModel.PropertyChangedEventArgs what)
    {
        if (sender is VisualElement element && what.PropertyName is { } name
            && Watched.Contains(name) && element.Handler?.PlatformView is Widget drawn)
        {
            Dress(drawn, Sheet(element));

            // AND A WIDGET THAT DRAWS ITSELF IS ASKED TO DRAW AGAIN. What a
            // BoxView or a shape looks like is painted in its own draw
            // function, and nothing here asks for one when the value it paints
            // from is written - so a colour CARRIED to a new one was worked out
            // sixty times a second and shown once, whenever something else
            // happened to repaint (measured on the gallery's *Motion*: the
            // trace walked the colour across a fifth of a second and the screen
            // answered with two frames).
            drawn.QueueDraw();
        }
    }

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

        // A BUTTON'S EDGE IS THE AUTHOR'S, and nothing here draws one: MAUI's
        // Button carries its stroke on IButtonStroke - what `.borderColor`,
        // `.borderWidth` and `.cornerRadius` write - and this backend maps none
        // of the three, so a button asking for an outline was drawn as bare
        // text on the page's own ground (measured on the gallery's *A binding
        // is no reader*, whose `Empty` button beside a filled `Full` had no
        // edge at all).
        //
        // Only what the author ASKED for is written: MAUI's unset thickness and
        // radius are negative, and writing a zero of our own would take away
        // the edge the desktop's own theme draws on every button.
        if (view is IButtonStroke stroke)
        {
            if (stroke.StrokeThickness > 0)
            {
                css.Append("border-style: solid;")
                    .Append($"border-width: {stroke.StrokeThickness.ToString("F1", CultureInfo.InvariantCulture)}px;");
            }

            if (stroke.StrokeColor is { } edge)
            {
                css.Append($"border-color: {Rgba(edge)};");
            }

            if (stroke.CornerRadius >= 0)
            {
                css.Append($"border-radius: {stroke.CornerRadius}px;");
            }
        }

        // A STROKE IS A BRUSH TOO, and a gradient one is drawn by nothing
        // here: the backend inks a border from a colour and a CSS border has
        // no other kind. What CSS does have is a border IMAGE, which takes the
        // same gradient the background does - so a stroke that is a gradient
        // is written as one.
        if (view is Microsoft.Maui.IBorderStroke edged
            && edged.StrokeThickness > 0
            && Ramp(edged.Stroke) is { } painted)
        {
            css.Append("border-style: solid;")
                .Append($"border-width: {edged.StrokeThickness.ToString("F1", CultureInfo.InvariantCulture)}px;")
                .Append($"border-image: {painted} 1;");
        }

        // A LABEL'S PADDING HAS TO COVER ITS BACKGROUND, and the backend's
        // does not: MAUI hands `Label.Padding` to the handler rather than
        // laying it out itself, and this backend hands it to GTK as the
        // widget's MARGIN, outside the widget's own background - so a
        // background colour behind a padded label covered the text and
        // nothing more (measured on the gallery's *Selection*, whose chosen
        // row was a bar as tall as its letters). Written as CSS the widget
        // grows by it, which is what makes the background cover the row - and
        // `Once` takes the backend's margin off, or the padding is there twice.
        //
        // A LABEL ALONE: every other view here is padded by MAUI's own
        // arrangement, and a second padding in CSS would be that padding
        // twice.
        if (view is Microsoft.Maui.Controls.Label padded && padded.Padding != default)
        {
            Thickness room = padded.Padding;

            css.Append(string.Create(
                CultureInfo.InvariantCulture,
                $"padding: {room.Top:F1}px {room.Right:F1}px {room.Bottom:F1}px {room.Left:F1}px;"));
        }

        if (view is ILabel label)
        {
            css.Append($"letter-spacing: {label.CharacterSpacing.ToString("F2", CultureInfo.InvariantCulture)}px;");
            css.Append(Decorations(label.TextDecorations));
        }

        return css.ToString();
    }

    /// <summary>A gradient brush as CSS writes one, or nothing for any other.</summary>
    /// <param name="brush">What the author asked for.</param>
    /// <returns>The declaration's value, or nothing where the brush is not a gradient.</returns>
    private static string? Ramp(Paint? brush) =>
        brush switch
        {
            LinearGradientPaint line =>
                $"linear-gradient({Angle(line.StartPoint, line.EndPoint):F0}deg, {Stops(line)})",
            RadialGradientPaint ring =>
                $"radial-gradient(circle {ring.Radius * 100:F0}% at "
                    + $"{ring.Center.X * 100:F0}% {ring.Center.Y * 100:F0}%, {Stops(ring)})",
            _ => null,
        };

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
