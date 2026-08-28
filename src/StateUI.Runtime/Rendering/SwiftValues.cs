// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Controls.Shapes;
using Microsoft.Maui.Layouts;
using StateUI.Runtime.Protocol;

// One name out of the iOS platform-specific namespace, aliased rather than
// imported: that namespace repeats half of MAUI's control names as static
// classes of its own - Page, Entry, NavigationPage - and importing it would
// leave every one of them ambiguous here.
using UIModalPresentationStyle =
    Microsoft.Maui.Controls.PlatformConfiguration.iOSSpecific.UIModalPresentationStyle;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Reads MAUI-typed values out of a node's property bag.
/// </summary>
/// <remarks>
/// <para>
/// The Swift side writes MAUI property names, and a value in the shape the wire
/// gives it: <c>horizontalOptions</c> is a number, <c>padding: [24,24,24,24]</c>
/// is a <c>Thickness</c>, and a stroke shape is a list of its own parts. These
/// accessors are the one place that mapping lives.
/// </para>
/// <para>
/// A CLOSED VOCABULARY IS A NUMBER, not a spelling - wire version 8 - and the
/// numbers are THIS REPOSITORY's, never MAUI's. Every one of them has a mirror
/// in <c>Protocol/SwiftWireEnums.cs</c> carrying our numbering, and the accessor
/// here TRANSLATES that mirror onto the real MAUI member BY NAME, one switch arm
/// each. Nothing is ever cast straight from the wire into a MAUI enum: MAUI's
/// member numbers are MAUI's own business, and a release that renumbered one
/// would otherwise reinterpret every property carrying it, silently. The
/// reasoning in full is at the head of that file.
/// </para>
/// <para>
/// Every accessor returns null when the property is absent OR unrecognized, and
/// the renderer only assigns when it gets a value. That matters: writing a
/// property back with its own current value would turn an inherited style value
/// into an explicit local one, which wins over the style from then on. A NUMBER
/// no mirror declares is unrecognized in exactly that sense - it falls to the
/// default arm and answers null.
/// </para>
/// </remarks>
internal static class SwiftValues
{
    /// <summary>
    /// A colour, from the four channels it crossed as.
    /// </summary>
    /// <remarks>
    /// <para>
    /// One colour, always. A <c>Color(light:dark:)</c> picked its half on the
    /// Swift side, as the value was written onto the node - so nothing here
    /// asks what theme is in force, nothing binds, and a theme change is an
    /// ordinary render of the views that used one. See Types/Color.swift.
    /// </para>
    /// <para>
    /// MAUI holds the same four channels as floats over 0-1, which is the
    /// conversion and the whole of it: no parser, and no vocabulary of colour
    /// names that a second host would have to reproduce exactly.
    /// </para>
    /// </remarks>
    public static Color? GetColor(this SwiftNode node, SwiftKey key)
    {
        return node.GetRgba(key) is (byte red, byte green, byte blue, byte alpha)
            ? new Color(red / 255f, green / 255f, blue / 255f, alpha / 255f)
            : null;
    }

    /// <summary>
    /// Assigns a colour to a property.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Takes the <see cref="BindableProperty"/> rather than assigning through
    /// the control because a property MAUI types as a <see cref="Brush"/>
    /// takes a colour too, and this is the one place that says so out loud
    /// rather than leaving a Border's stroke to a conversion nothing here
    /// asked for.
    /// </para>
    /// </remarks>
    public static void SetColor(
        this SwiftNode node,
        SwiftKey key,
        BindableObject target,
        BindableProperty property)
    {
        if (node.GetColor(key) is Color color)
        {
            target.SetValue(
                property,
                property.ReturnType == typeof(Brush) ? new SolidColorBrush(color) : color);
        }
    }

    /// <summary>
    /// A picture: a file in the app's <c>Resources/Images</c>, by the name MAUI
    /// gives it once built.
    /// </summary>
    /// <remarks>
    /// One name, for the reason a colour is one colour: artwork drawn once per
    /// theme picked its half on the Swift side.
    /// </remarks>
    public static ImageSource? GetImageSource(this SwiftNode node, SwiftKey key)
    {
        return node.GetString(key) is string file ? File(file) : null;
    }

    /// <summary>Assigns a picture to a property.</summary>
    public static void SetImageSource(
        this SwiftNode node,
        SwiftKey key,
        BindableObject target,
        BindableProperty property)
    {
        if (node.GetImageSource(key) is ImageSource source)
        {
            target.SetValue(property, source);
        }
    }

    /// <summary>
    /// A picture from the app's resources, by the name MAUI gives it once built.
    /// </summary>
    private static ImageSource File(string name) => ImageSource.FromFile(name);

    /// <summary>
    /// What a WebView shows: a page fetched by address, or HTML written in
    /// place.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Two shapes under the one property name, the way a Brush takes a colour
    /// and a gradient - and the KIND says which, in front, rather than being
    /// inferred from how many parts arrived:
    /// </para>
    /// <code>
    /// [0, url]                a page to fetch
    /// [1, html, base]         a document, with what relative links resolve
    ///                         against - or `nothing` where there is none
    /// </code>
    /// </remarks>
    public static WebViewSource? GetWebViewSource(this SwiftNode node, SwiftKey key)
    {
        if (node.GetValues(key) is not [{ Enumeration: int kind }, .. SwiftWireValue[] rest])
        {
            return null;
        }

        return (SwiftWebViewSourceKind)kind switch
        {
            SwiftWebViewSourceKind.Url when rest is
                [{ Text: string url, Tag: SwiftWireValue.TagString }] =>
                new UrlWebViewSource { Url = url },

            SwiftWebViewSourceKind.Html when rest is
                [{ Text: string html, Tag: SwiftWireValue.TagString }, SwiftWireValue baseUrl] =>
                new HtmlWebViewSource
                {
                    Html = html,

                    // The base url is there when it is a STRING and absent
                    // otherwise, the wire's own nothing standing where there is
                    // none - which is not text, so the one test answers it.
                    BaseUrl = baseUrl.Tag == SwiftWireValue.TagString ? baseUrl.Text : null,
                },

            _ => null,
        };
    }

    /// <summary>
    /// Everything a Window node says about the window itself: what it is called,
    /// where it opens and how big it is.
    /// </summary>
    /// <remarks>
    /// <para>
    /// One method for both targets, because both end up at a real MAUI Window:
    /// <see cref="StateUIWindow"/> IS one, and <see cref="StateUIHost"/>
    /// walks up to the one it was placed in. It is also the one place a window
    /// property has to be added.
    /// </para>
    /// <para>
    /// Position and size are the desktop properties; a phone ignores them, the
    /// app being the whole screen. Windows applies all of them itself. Mac
    /// Catalyst applies the minimum and the maximum, ignores <c>X</c> and
    /// <c>Y</c>, and would ignore <c>Width</c> and <c>Height</c> - which is
    /// what <see cref="SwiftWindowSize"/> is for.
    /// </para>
    /// <para>
    /// Assigned only when the property arrived, like everywhere else: a message
    /// carries what changed, and a window nobody resized is not in it.
    /// </para>
    /// </remarks>
    public static void ApplyWindow(this SwiftNode node, Window window)
    {
        if (node.GetString(SwiftProp.Title) is string title) { window.Title = title; }

        if (node.GetNumber(SwiftProp.X) is double x) { window.X = x; }
        if (node.GetNumber(SwiftProp.Y) is double y) { window.Y = y; }

        if (node.GetNumber(SwiftProp.Width) is double width) { window.Width = width; }
        if (node.GetNumber(SwiftProp.Height) is double height) { window.Height = height; }

        if (node.GetBool(SwiftProp.IsMaximizable) is bool maximizable) { window.IsMaximizable = maximizable; }
        if (node.GetBool(SwiftProp.IsMinimizable) is bool minimizable) { window.IsMinimizable = minimizable; }
        if (node.GetNumber(SwiftProp.MinimumWidth) is double minimumWidth) { window.MinimumWidth = minimumWidth; }
        if (node.GetNumber(SwiftProp.MinimumHeight) is double minimumHeight) { window.MinimumHeight = minimumHeight; }
        if (node.GetNumber(SwiftProp.MaximumWidth) is double maximumWidth) { window.MaximumWidth = maximumWidth; }
        if (node.GetNumber(SwiftProp.MaximumHeight) is double maximumHeight) { window.MaximumHeight = maximumHeight; }

        // Last, and only where the platform needs asking: it reads the maximum
        // assigned above to know what to give back afterwards.
        SwiftWindowSize.OpenAtRequestedSize(window, node);
    }

    /// <summary>Left, top, right, bottom - the order MAUI's constructor takes.</summary>
    public static Thickness? GetThickness(this SwiftNode node, SwiftKey key)
    {
        double[]? values = node.GetNumbers(key);

        return values?.Length switch
        {
            1 => new Thickness(values[0]),
            2 => new Thickness(values[0], values[1]),
            4 => new Thickness(values[0], values[1], values[2], values[3]),
            _ => null,
        };
    }

    /// <summary>Reads which safe-area edges a layout respects.</summary>
    /// <remarks>
    /// <para>
    /// Either ONE region, meaning all four edges, or four of them - left, top,
    /// right, bottom, the order MAUI's own constructor takes and the order a
    /// Thickness travels in.
    /// </para>
    /// <para>
    /// Built here rather than handed to MAUI's
    /// <c>SafeAreaEdgesTypeConverter</c>: the converter reads comma-separated
    /// region NAMES, and there are no names on this wire to give it.
    /// </para>
    /// </remarks>
    /// <param name="node">The node carrying the property.</param>
    /// <param name="key">The property's name.</param>
    /// <returns>Null when the property is absent or names no region.</returns>
    public static SafeAreaEdges? GetSafeAreaEdges(this SwiftNode node, SwiftKey key)
    {
        if (node.GetEnumeration(key) is int uniform)
        {
            return Region(uniform) is SafeAreaRegions region ? new SafeAreaEdges(region) : null;
        }

        // Four MEMBERS, one per edge, each a value of its own - a run of
        // numbers would say these were quantities.
        if (node.GetValues(key) is not
            [
                { Tag: SwiftWireValue.TagEnumeration } left,
                { Tag: SwiftWireValue.TagEnumeration } top,
                { Tag: SwiftWireValue.TagEnumeration } right,
                { Tag: SwiftWireValue.TagEnumeration } bottom,
            ])
        {
            return null;
        }

        return (Region(left.Member), Region(top.Member), Region(right.Member), Region(bottom.Member)) is
            (SafeAreaRegions one, SafeAreaRegions two, SafeAreaRegions three, SafeAreaRegions four)
            ? new SafeAreaEdges(one, two, three, four)
            : null;
    }

    /// <summary>One region, from the number one edge crossed as.</summary>
    /// <remarks>
    /// MAUI numbers its own <c>All</c> 32768 and has a fifth member,
    /// <c>Default</c>, at -1. Neither number crosses: ours are 0 to 3, and
    /// <c>Default</c> is not a thing this wire can say.
    /// </remarks>
    private static SafeAreaRegions? Region(int member)
    {
        return (SwiftSafeAreaRegions)member switch
        {
            SwiftSafeAreaRegions.None => SafeAreaRegions.None,
            SwiftSafeAreaRegions.SoftInput => SafeAreaRegions.SoftInput,
            SwiftSafeAreaRegions.Container => SafeAreaRegions.Container,
            SwiftSafeAreaRegions.All => SafeAreaRegions.All,
            _ => null,
        };
    }

    /// <summary>
    /// A position and a size: x, y, width, height - the order MAUI's constructor
    /// takes.
    /// </summary>
    /// <remarks>
    /// A length of -1 is MAUI's <c>AbsoluteLayout.AutoSize</c>, which is the
    /// value it is on both sides and needs no reading here.
    /// </remarks>
    public static Rect? GetRect(this SwiftNode node, SwiftKey key)
    {
        return node.GetNumbers(key) is [double x, double y, double width, double height]
            ? new Rect(x, y, width, height)
            : null;
    }

    /// <summary>
    /// A number, narrowed. Everything numeric travels as a double, and MAUI
    /// wants an int for a few of them - MaxLines, CornerRadius, SelectedIndex.
    /// </summary>
    public static int? GetInt(this SwiftNode node, SwiftKey key)
    {
        return node.GetNumber(key) is double value ? (int)value : null;
    }

    /// <summary>Where a view sits in the space its layout gives it.</summary>
    /// <remarks>
    /// MAUI's LayoutOptions is a STRUCT of a <c>LayoutAlignment</c> and an
    /// obsolete "expands" flag, so each of these translates onto one of MAUI's
    /// four ready-made statics - that alignment with the flag false. The flag
    /// never crosses: MAUI marked it obsolete and every platform ignores it.
    /// </remarks>
    public static LayoutOptions? GetLayoutOptions(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftLayoutOptions)member switch
            {
                SwiftLayoutOptions.Start => LayoutOptions.Start,
                SwiftLayoutOptions.Center => LayoutOptions.Center,
                SwiftLayoutOptions.End => LayoutOptions.End,
                SwiftLayoutOptions.Fill => LayoutOptions.Fill,
                _ => null,
            };
    }

    /// <summary>Where text sits within a control's own bounds.</summary>
    public static TextAlignment? GetTextAlignment(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftTextAlignment)member switch
            {
                SwiftTextAlignment.Start => TextAlignment.Start,
                SwiftTextAlignment.Center => TextAlignment.Center,
                SwiftTextAlignment.End => TextAlignment.End,
                _ => null,
            };
    }

    /// <summary>Bold, italic, both or neither.</summary>
    /// <remarks>
    /// A bit set rather than a choice, so it is read one bit at a time and a bit
    /// nobody declared refuses the whole value - a switch cannot stand in,
    /// there being one number per COMBINATION.
    /// </remarks>
    public static FontAttributes? GetFontAttributes(this SwiftNode node, SwiftKey key)
    {
        const SwiftFontAttributes declared = SwiftFontAttributes.Bold | SwiftFontAttributes.Italic;

        if (node.GetEnumeration(key) is not int bits || (bits & ~(int)declared) != 0)
        {
            return null;
        }

        var carried = (SwiftFontAttributes)bits;
        var attributes = FontAttributes.None;

        if (carried.HasFlag(SwiftFontAttributes.Bold)) { attributes |= FontAttributes.Bold; }
        if (carried.HasFlag(SwiftFontAttributes.Italic)) { attributes |= FontAttributes.Italic; }

        return attributes;
    }

    /// <summary>Underlined, struck through, both or neither.</summary>
    /// <remarks>A bit set; see <see cref="GetFontAttributes"/>.</remarks>
    public static TextDecorations? GetTextDecorations(this SwiftNode node, SwiftKey key)
    {
        const SwiftTextDecorations declared =
            SwiftTextDecorations.Underline | SwiftTextDecorations.Strikethrough;

        if (node.GetEnumeration(key) is not int bits || (bits & ~(int)declared) != 0)
        {
            return null;
        }

        var carried = (SwiftTextDecorations)bits;
        var decorations = TextDecorations.None;

        if (carried.HasFlag(SwiftTextDecorations.Underline))
        {
            decorations |= TextDecorations.Underline;
        }

        if (carried.HasFlag(SwiftTextDecorations.Strikethrough))
        {
            decorations |= TextDecorations.Strikethrough;
        }

        return decorations;
    }

    /// <summary>What happens to text too long for its space.</summary>
    public static LineBreakMode? GetLineBreakMode(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftLineBreakMode)member switch
            {
                SwiftLineBreakMode.NoWrap => LineBreakMode.NoWrap,
                SwiftLineBreakMode.WordWrap => LineBreakMode.WordWrap,
                SwiftLineBreakMode.CharacterWrap => LineBreakMode.CharacterWrap,
                SwiftLineBreakMode.HeadTruncation => LineBreakMode.HeadTruncation,
                SwiftLineBreakMode.TailTruncation => LineBreakMode.TailTruncation,
                SwiftLineBreakMode.MiddleTruncation => LineBreakMode.MiddleTruncation,
                _ => null,
            };
    }

    /// <summary>Which keyboard a text input asks for.</summary>
    public static Keyboard? GetKeyboard(this SwiftNode node, SwiftKey key)
    {
        return KeyboardOf(node.GetEnumeration(key));
    }

    /// <summary>
    /// The same lookup from the member's number itself - the shape a command
    /// argument carries it in, where a property carries it on a node.
    /// </summary>
    /// <remarks>
    /// A lookup rather than a cast for the reason every vocabulary here is one,
    /// and one more besides: MAUI's Keyboard members are static properties on a
    /// CLASS, so there is no enum on that side to cast to at all.
    /// </remarks>
    /// <param name="member">
    /// The keyboard's number, as <see cref="SwiftKeyboard"/> - or null where the
    /// argument was absent, which an act reads straight off the wire.
    /// </param>
    /// <returns>The MAUI keyboard, or null for a number naming none.</returns>
    public static Keyboard? KeyboardOf(int? member)
    {
        return (SwiftKeyboard?)member switch
        {
            SwiftKeyboard.Default => Keyboard.Default,
            SwiftKeyboard.Plain => Keyboard.Plain,
            SwiftKeyboard.Chat => Keyboard.Chat,
            SwiftKeyboard.Email => Keyboard.Email,
            SwiftKeyboard.Numeric => Keyboard.Numeric,
            SwiftKeyboard.Telephone => Keyboard.Telephone,
            SwiftKeyboard.Text => Keyboard.Text,
            SwiftKeyboard.Url => Keyboard.Url,
            _ => null,
        };
    }

    /// <summary>What the keyboard's return key says.</summary>
    public static ReturnType? GetReturnType(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftReturnType)member switch
            {
                SwiftReturnType.Default => ReturnType.Default,
                SwiftReturnType.Done => ReturnType.Done,
                SwiftReturnType.Go => ReturnType.Go,
                SwiftReturnType.Next => ReturnType.Next,
                SwiftReturnType.Search => ReturnType.Search,
                SwiftReturnType.Send => ReturnType.Send,
                _ => null,
            };
    }

    /// <summary>When an Entry shows the platform's clear button.</summary>
    public static ClearButtonVisibility? GetClearButtonVisibility(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftClearButtonVisibility)member switch
            {
                SwiftClearButtonVisibility.Never => ClearButtonVisibility.Never,
                SwiftClearButtonVisibility.WhileEditing => ClearButtonVisibility.WhileEditing,
                _ => null,
            };
    }

    /// <summary>
    /// Row definitions: a list of lengths, each its own two parts.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The LIST says how many rows there are, and each entry is the kind - a
    /// <see cref="SwiftGridLengthKind"/> - then the number that kind takes:
    /// </para>
    /// <code>
    /// [[2, 1], [1, 1], [1, 2], [0, 100]]     Auto, *, 2*, 100
    /// </code>
    /// <para>
    /// Read here rather than by MAUI's <c>RowDefinitionCollectionTypeConverter</c>,
    /// which reads XAML's <c>Auto,*,2*,100</c>: a length crosses as its two
    /// parts, so there is no text to hand it.
    /// </para>
    /// </remarks>
    public static RowDefinitionCollection? GetRowDefinitions(this SwiftNode node, SwiftKey key)
    {
        if (Lengths(node, key) is not List<GridLength> lengths)
        {
            return null;
        }

        var definitions = new RowDefinitionCollection();

        foreach (GridLength length in lengths)
        {
            definitions.Add(new RowDefinition { Height = length });
        }

        return definitions;
    }

    /// <summary>The same, for columns.</summary>
    public static ColumnDefinitionCollection? GetColumnDefinitions(this SwiftNode node, SwiftKey key)
    {
        if (Lengths(node, key) is not List<GridLength> lengths)
        {
            return null;
        }

        var definitions = new ColumnDefinitionCollection();

        foreach (GridLength length in lengths)
        {
            definitions.Add(new ColumnDefinition { Width = length });
        }

        return definitions;
    }

    /// <summary>
    /// The lengths behind a row or column list, or null when one of them will
    /// not read.
    /// </summary>
    /// <remarks>
    /// All or nothing, because half a grid is not a grid: a definition list is
    /// the SHAPE of the layout, and dropping one row silently would move every
    /// child below it.
    /// </remarks>
    private static List<GridLength>? Lengths(SwiftNode node, SwiftKey key)
    {
        if (node.GetValues(key) is not SwiftWireValue[] values)
        {
            return null;
        }

        var lengths = new List<GridLength>(values.Length);

        foreach (SwiftWireValue value in values)
        {
            if (value.Values is not
                [{ Enumeration: int kind }, { Tag: SwiftWireValue.TagNumber } size])
            {
                return null;
            }

            GridUnitType? unit = (SwiftGridLengthKind)kind switch
            {
                SwiftGridLengthKind.Absolute => GridUnitType.Absolute,
                SwiftGridLengthKind.Star => GridUnitType.Star,
                SwiftGridLengthKind.Auto => GridUnitType.Auto,
                _ => null,
            };

            if (unit is not GridUnitType measured)
            {
                return null;
            }

            // Auto carries 1, which is what MAUI's own GridLength.Auto carries:
            // a GridLength compares by both fields, so a 0 there would build a
            // length equal to no static MAUI declares.
            lengths.Add(new GridLength(size.Number, measured));
        }

        return lengths;
    }

    /// <summary>Whether an Editor grows with its text.</summary>
    public static EditorAutoSizeOption? GetEditorAutoSize(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftEditorAutoSizeOption)member switch
            {
                SwiftEditorAutoSizeOption.Disabled => EditorAutoSizeOption.Disabled,
                SwiftEditorAutoSizeOption.TextChanges => EditorAutoSizeOption.TextChanges,
                _ => null,
            };
    }

    /// <summary>
    /// Whether the text is drawn as written or in one case throughout.
    /// </summary>
    /// <remarks>
    /// Only the controls that re-expose <c>TextElement.TextTransformProperty</c>
    /// read this - Label, Span, Button, RadioButton and the three InputViews.
    /// A Picker, DatePicker or TimePicker implements ITextElement explicitly
    /// and answers a hard-coded <c>Default</c>, so there is nothing to write.
    /// </remarks>
    /// <param name="node">The node to read.</param>
    /// <param name="key">The property's name.</param>
    /// <returns>The transform, or null where the message did not say.</returns>
    public static TextTransform? GetTextTransform(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftTextTransform)member switch
            {
                SwiftTextTransform.None => TextTransform.None,
                SwiftTextTransform.Default => TextTransform.Default,
                SwiftTextTransform.Lowercase => TextTransform.Lowercase,
                SwiftTextTransform.Uppercase => TextTransform.Uppercase,
                _ => null,
            };
    }

    /// <summary>Whether a scroll bar is shown, hidden, or left to the platform.</summary>
    public static ScrollBarVisibility? GetScrollBarVisibility(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftScrollBarVisibility)member switch
            {
                SwiftScrollBarVisibility.Default => ScrollBarVisibility.Default,
                SwiftScrollBarVisibility.Always => ScrollBarVisibility.Always,
                SwiftScrollBarVisibility.Never => ScrollBarVisibility.Never,
                _ => null,
            };
    }

    /// <summary>A day: year, month, day, in that order.</summary>
    /// <remarks>
    /// Three numbers rather than <c>2026-08-02</c>. The Swift side has no
    /// calendar and no formatter - both would mean ICU - so it sends the three
    /// fields a <c>CalendarDate</c> is, and building the DateTime happens here,
    /// where a calendar costs nothing. A trio that names no real day - a 31st of
    /// February, a month 13 - answers null, like any other unreadable value.
    /// </remarks>
    public static DateTime? GetDate(this SwiftNode node, SwiftKey key)
    {
        if (node.GetNumbers(key) is not [double year, double month, double day])
        {
            return null;
        }

        try
        {
            return new DateTime((int)year, (int)month, (int)day);
        }
        catch (ArgumentOutOfRangeException)
        {
            return null;
        }
    }

    /// <summary>A time of day: hour, minute, second, in that order.</summary>
    /// <remarks>
    /// Three numbers, for the reason <see cref="GetDate"/> takes three. What
    /// MAUI wants is a <c>TimeSpan</c> - a length since midnight - which is
    /// what those three add up to. No millisecond: a TimePicker neither shows
    /// nor keeps one.
    /// </remarks>
    public static TimeSpan? GetTime(this SwiftNode node, SwiftKey key)
    {
        if (node.GetNumbers(key) is not [double hour, double minute, double second])
        {
            return null;
        }

        try
        {
            return new TimeSpan((int)hour, (int)minute, (int)second);
        }
        catch (ArgumentOutOfRangeException)
        {
            return null;
        }
    }

    /// <summary>The outline of a Border: the kind, then what that kind takes.</summary>
    /// <remarks>
    /// <c>[1, 12]</c> is a round rectangle of 12; the other two carry nothing.
    /// Built here rather than by MAUI's <c>StrokeShapeTypeConverter</c>, which
    /// reads XAML's <c>RoundRectangle 12</c>: a string on this wire is text
    /// someone wrote, and a shape is not that.
    /// </remarks>
    /// <summary>
    /// A Path's RenderTransform: the kind, then the numbers that kind is made
    /// of - and for a group, the parts as values of their own.
    /// </summary>
    /// <remarks>
    /// Null for anything that will not read, which the caller answers by
    /// leaving the property alone: a transform that half-parsed would draw a
    /// shape nobody asked for.
    /// </remarks>
    public static Transform? GetTransform(this SwiftNode node, SwiftKey key) =>
        ReadTransform(node.GetValues(key));

    private static Transform? ReadTransform(SwiftWireValue[]? values)
    {
        if (values is not [{ Enumeration: int kind }, .. SwiftWireValue[] rest])
        {
            return null;
        }

        double[]? numbers = Numbers(rest);

        return (SwiftTransformKind)kind switch
        {
            SwiftTransformKind.Rotate when numbers is [double angle, double x, double y] =>
                new RotateTransform { Angle = angle, CenterX = x, CenterY = y },

            SwiftTransformKind.Scale when numbers is
                [double scaleX, double scaleY, double x, double y] =>
                new ScaleTransform { ScaleX = scaleX, ScaleY = scaleY, CenterX = x, CenterY = y },

            SwiftTransformKind.Skew when numbers is
                [double angleX, double angleY, double x, double y] =>
                new SkewTransform { AngleX = angleX, AngleY = angleY, CenterX = x, CenterY = y },

            SwiftTransformKind.Translate when numbers is [double x, double y] =>
                new TranslateTransform { X = x, Y = y },

            SwiftTransformKind.Matrix when numbers is
                [double m11, double m12, double m21, double m22, double offsetX, double offsetY] =>
                new MatrixTransform { Matrix = new Matrix(m11, m12, m21, m22, offsetX, offsetY) },

            SwiftTransformKind.Group => Group(rest),

            _ => null,
        };
    }

    /// <summary>Every value read as a number, or null if one of them is not.</summary>
    private static double[]? Numbers(SwiftWireValue[] values)
    {
        var read = new double[values.Length];

        for (int at = 0; at < values.Length; at++)
        {
            if (values[at] is not { Tag: SwiftWireValue.TagNumber } number) { return null; }
            read[at] = number.Number;
        }

        return read;
    }

    /// <summary>
    /// A group's parts, each a transform of its own - so a group may hold a
    /// group, which is what the Swift side's `indirect` allows.
    /// </summary>
    private static Transform? Group(SwiftWireValue[] parts)
    {
        var group = new TransformGroup();

        foreach (SwiftWireValue part in parts)
        {
            if (ReadTransform(part.Values) is not Transform one) { return null; }
            group.Children.Add(one);
        }

        return group;
    }

    public static IShape? GetStrokeShape(this SwiftNode node, SwiftKey key)
    {
        if (node.GetValues(key) is not [{ Enumeration: int kind }, .. SwiftWireValue[] rest])
        {
            return null;
        }

        return (SwiftStrokeShapeKind)kind switch
        {
            SwiftStrokeShapeKind.Rectangle when rest is [] => new Rectangle(),

            SwiftStrokeShapeKind.RoundRectangle when rest is
                [{ Tag: SwiftWireValue.TagNumber } radius] =>
                new RoundRectangle { CornerRadius = new CornerRadius(radius.Number) },

            SwiftStrokeShapeKind.Ellipse when rest is [] => new Ellipse(),

            _ => null,
        };
    }

    /// <summary>
    /// Where a Button's picture sits beside its caption, and how far from it:
    /// the position, then the spacing.
    /// </summary>
    public static Button.ButtonContentLayout? GetButtonContentLayout(this SwiftNode node, SwiftKey key)
    {
        if (node.GetValues(key) is not
            [{ Enumeration: int member }, { Tag: SwiftWireValue.TagNumber } spacing])
        {
            return null;
        }

        Button.ButtonContentLayout.ImagePosition? position =
            (SwiftButtonContentPosition)member switch
            {
                SwiftButtonContentPosition.Left => Button.ButtonContentLayout.ImagePosition.Left,
                SwiftButtonContentPosition.Top => Button.ButtonContentLayout.ImagePosition.Top,
                SwiftButtonContentPosition.Right => Button.ButtonContentLayout.ImagePosition.Right,
                SwiftButtonContentPosition.Bottom => Button.ButtonContentLayout.ImagePosition.Bottom,
                _ => null,
            };

        return position is Button.ButtonContentLayout.ImagePosition side
            ? new Button.ButtonContentLayout(side, spacing.Number)
            : null;
    }

    /// <summary>Which way a view lays its content out. MAUI: FlowDirection.</summary>
    public static FlowDirection? GetFlowDirection(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlowDirection)member switch
            {
                SwiftFlowDirection.MatchParent => FlowDirection.MatchParent,
                SwiftFlowDirection.LeftToRight => FlowDirection.LeftToRight,
                SwiftFlowDirection.RightToLeft => FlowDirection.RightToLeft,
                _ => null,
            };
    }

    /// <summary>Whether a Label's text is markup. MAUI: TextType.</summary>
    public static TextType? GetTextType(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftTextType)member switch
            {
                SwiftTextType.Text => TextType.Text,
                SwiftTextType.Html => TextType.Html,
                _ => null,
            };
    }

    /// <summary>What a map pin stands for. MAUI: PinType.</summary>
    public static Microsoft.Maui.Controls.Maps.PinType? GetPinType(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftPinType)member switch
            {
                SwiftPinType.Generic => Microsoft.Maui.Controls.Maps.PinType.Generic,
                SwiftPinType.Place => Microsoft.Maui.Controls.Maps.PinType.Place,
                SwiftPinType.SavedPin => Microsoft.Maui.Controls.Maps.PinType.SavedPin,
                SwiftPinType.SearchResult => Microsoft.Maui.Controls.Maps.PinType.SearchResult,
                _ => null,
            };
    }

    /// <summary>How an Image fills the space it is given.</summary>
    public static Aspect? GetAspect(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftAspect)member switch
            {
                SwiftAspect.AspectFit => Aspect.AspectFit,
                SwiftAspect.AspectFill => Aspect.AspectFill,
                SwiftAspect.Fill => Aspect.Fill,
                SwiftAspect.Center => Aspect.Center,
                _ => null,
            };
    }

    /// <summary>Which ways a swipe is listened for.</summary>
    /// <remarks>
    /// A bit set, so a view listening every way is 15 rather than four names
    /// joined by commas. See <see cref="GetFontAttributes"/> for why the bits
    /// are read one at a time rather than switched on.
    /// </remarks>
    public static SwipeDirection? GetSwipeDirection(this SwiftNode node, SwiftKey key)
    {
        if (node.GetEnumeration(key) is not int bits
            || (bits & ~(int)SwiftSwipeDirection.All) != 0)
        {
            return null;
        }

        var carried = (SwiftSwipeDirection)bits;
        SwipeDirection directions = 0;

        if (carried.HasFlag(SwiftSwipeDirection.Right)) { directions |= SwipeDirection.Right; }
        if (carried.HasFlag(SwiftSwipeDirection.Left)) { directions |= SwipeDirection.Left; }
        if (carried.HasFlag(SwiftSwipeDirection.Up)) { directions |= SwipeDirection.Up; }
        if (carried.HasFlag(SwiftSwipeDirection.Down)) { directions |= SwipeDirection.Down; }

        return directions;
    }

    /// <summary>How a FlyoutPage shows its two halves.</summary>
    public static FlyoutLayoutBehavior? GetFlyoutLayoutBehavior(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlyoutLayoutBehavior)member switch
            {
                SwiftFlyoutLayoutBehavior.Default => FlyoutLayoutBehavior.Default,
                SwiftFlyoutLayoutBehavior.Popover => FlyoutLayoutBehavior.Popover,
                SwiftFlyoutLayoutBehavior.Split => FlyoutLayoutBehavior.Split,
                SwiftFlyoutLayoutBehavior.SplitOnLandscape => FlyoutLayoutBehavior.SplitOnLandscape,
                SwiftFlyoutLayoutBehavior.SplitOnPortrait => FlyoutLayoutBehavior.SplitOnPortrait,
                _ => null,
            };
    }

    /// <summary>How a page presented over the window covers the screen.</summary>
    /// <remarks>
    /// UIKit's own list, which MAUI exposes as an iOS platform-specific. The
    /// other platforms have no such choice, and the property they ignore is set
    /// on them all the same - it is an ordinary bindable property of MAUI's
    /// shared assembly, and one arm here beats an <c>#if</c> per platform.
    /// </remarks>
    public static UIModalPresentationStyle? GetModalPresentationStyle(
        this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftUIModalPresentationStyle)member switch
            {
                SwiftUIModalPresentationStyle.FullScreen => UIModalPresentationStyle.FullScreen,
                SwiftUIModalPresentationStyle.FormSheet => UIModalPresentationStyle.FormSheet,
                SwiftUIModalPresentationStyle.Automatic => UIModalPresentationStyle.Automatic,
                SwiftUIModalPresentationStyle.PageSheet => UIModalPresentationStyle.PageSheet,
                SwiftUIModalPresentationStyle.OverFullScreen =>
                    UIModalPresentationStyle.OverFullScreen,
                SwiftUIModalPresentationStyle.Popover => UIModalPresentationStyle.Popover,
                _ => null,
            };
    }

    /// <summary>Which way a ScrollView scrolls.</summary>
    public static ScrollOrientation? GetScrollOrientation(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftScrollOrientation)member switch
            {
                SwiftScrollOrientation.Vertical => ScrollOrientation.Vertical,
                SwiftScrollOrientation.Horizontal => ScrollOrientation.Horizontal,
                SwiftScrollOrientation.Both => ScrollOrientation.Both,
                SwiftScrollOrientation.Neither => ScrollOrientation.Neither,
                _ => null,
            };
    }

    /// <summary>
    /// Which parts of a child's bounds an AbsoluteLayout reads as fractions.
    /// </summary>
    /// <remarks>
    /// A bit set whose composites are the OR of their parts, so <c>all</c> is 15
    /// - four bits - where MAUI's own <c>All</c> is -1, every bit there is. The
    /// two behave alike, MAUI reading this a bit at a time, and 15 is the one
    /// that lets a bit nobody declared refuse the value.
    /// </remarks>
    public static AbsoluteLayoutFlags? GetAbsoluteLayoutFlags(this SwiftNode node, SwiftKey key)
    {
        if (node.GetEnumeration(key) is not int bits
            || (bits & ~(int)SwiftAbsoluteLayoutFlags.All) != 0)
        {
            return null;
        }

        var carried = (SwiftAbsoluteLayoutFlags)bits;
        var flags = AbsoluteLayoutFlags.None;

        if (carried.HasFlag(SwiftAbsoluteLayoutFlags.XProportional))
        {
            flags |= AbsoluteLayoutFlags.XProportional;
        }

        if (carried.HasFlag(SwiftAbsoluteLayoutFlags.YProportional))
        {
            flags |= AbsoluteLayoutFlags.YProportional;
        }

        if (carried.HasFlag(SwiftAbsoluteLayoutFlags.WidthProportional))
        {
            flags |= AbsoluteLayoutFlags.WidthProportional;
        }

        if (carried.HasFlag(SwiftAbsoluteLayoutFlags.HeightProportional))
        {
            flags |= AbsoluteLayoutFlags.HeightProportional;
        }

        return flags;
    }

    /// <summary>Which way a FlexLayout's children run.</summary>
    public static FlexDirection? GetFlexDirection(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlexDirection)member switch
            {
                SwiftFlexDirection.Row => FlexDirection.Row,
                SwiftFlexDirection.RowReverse => FlexDirection.RowReverse,
                SwiftFlexDirection.Column => FlexDirection.Column,
                SwiftFlexDirection.ColumnReverse => FlexDirection.ColumnReverse,
                _ => null,
            };
    }

    /// <summary>Whether a line that runs out of room starts another.</summary>
    public static FlexWrap? GetFlexWrap(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlexWrap)member switch
            {
                SwiftFlexWrap.NoWrap => FlexWrap.NoWrap,
                SwiftFlexWrap.Wrap => FlexWrap.Wrap,
                SwiftFlexWrap.Reverse => FlexWrap.Reverse,
                _ => null,
            };
    }

    /// <summary>How the spare room along the direction is shared out.</summary>
    public static FlexJustify? GetFlexJustify(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlexJustify)member switch
            {
                SwiftFlexJustify.Center => FlexJustify.Center,
                SwiftFlexJustify.Start => FlexJustify.Start,
                SwiftFlexJustify.End => FlexJustify.End,
                SwiftFlexJustify.SpaceBetween => FlexJustify.SpaceBetween,
                SwiftFlexJustify.SpaceAround => FlexJustify.SpaceAround,
                SwiftFlexJustify.SpaceEvenly => FlexJustify.SpaceEvenly,
                _ => null,
            };
    }

    /// <summary>Where each child sits across the direction.</summary>
    public static FlexAlignItems? GetFlexAlignItems(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlexAlignItems)member switch
            {
                SwiftFlexAlignItems.Stretch => FlexAlignItems.Stretch,
                SwiftFlexAlignItems.Center => FlexAlignItems.Center,
                SwiftFlexAlignItems.Start => FlexAlignItems.Start,
                SwiftFlexAlignItems.End => FlexAlignItems.End,
                _ => null,
            };
    }

    /// <summary>The same for whole lines, once the layout wraps.</summary>
    public static FlexAlignContent? GetFlexAlignContent(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlexAlignContent)member switch
            {
                SwiftFlexAlignContent.Stretch => FlexAlignContent.Stretch,
                SwiftFlexAlignContent.Center => FlexAlignContent.Center,
                SwiftFlexAlignContent.Start => FlexAlignContent.Start,
                SwiftFlexAlignContent.End => FlexAlignContent.End,
                SwiftFlexAlignContent.SpaceBetween => FlexAlignContent.SpaceBetween,
                SwiftFlexAlignContent.SpaceAround => FlexAlignContent.SpaceAround,
                SwiftFlexAlignContent.SpaceEvenly => FlexAlignContent.SpaceEvenly,
                _ => null,
            };
    }

    /// <summary>One child's answer to the layout's AlignItems.</summary>
    public static FlexAlignSelf? GetFlexAlignSelf(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlexAlignSelf)member switch
            {
                SwiftFlexAlignSelf.Auto => FlexAlignSelf.Auto,
                SwiftFlexAlignSelf.Stretch => FlexAlignSelf.Stretch,
                SwiftFlexAlignSelf.Center => FlexAlignSelf.Center,
                SwiftFlexAlignSelf.Start => FlexAlignSelf.Start,
                SwiftFlexAlignSelf.End => FlexAlignSelf.End,
                _ => null,
            };
    }

    /// <summary>Whether a FlexLayout places its children at all.</summary>
    public static FlexPosition? GetFlexPosition(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFlexPosition)member switch
            {
                SwiftFlexPosition.Relative => FlexPosition.Relative,
                SwiftFlexPosition.Absolute => FlexPosition.Absolute,
                _ => null,
            };
    }

    /// <summary>
    /// How much room a child asks for: the kind, then the length where there is
    /// one.
    /// </summary>
    /// <remarks>
    /// A relative length is the SHARE, from 0 to 1, which is what MAUI's own
    /// constructor takes - XAML's <c>50%</c> is 0.5 on this wire, and nothing
    /// here divides by a hundred. Built here rather than by MAUI's
    /// <c>FlexBasisTypeConverter</c>, which is internal to MAUI.
    /// </remarks>
    public static FlexBasis? GetFlexBasis(this SwiftNode node, SwiftKey key)
    {
        if (node.GetValues(key) is not [{ Enumeration: int kind }, .. SwiftWireValue[] rest])
        {
            return null;
        }

        return (SwiftFlexBasisKind)kind switch
        {
            SwiftFlexBasisKind.Auto when rest is [] => FlexBasis.Auto,

            SwiftFlexBasisKind.Relative when rest is [{ Tag: SwiftWireValue.TagNumber } share] =>
                new FlexBasis((float)share.Number, true),

            SwiftFlexBasisKind.Absolute when rest is [{ Tag: SwiftWireValue.TagNumber } length] =>
                new FlexBasis((float)length.Number, false),

            _ => null,
        };
    }

    /// <summary>How the world is drawn - streets, photography, or both.</summary>
    public static Microsoft.Maui.Maps.MapType? GetMapType(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftMapType)member switch
            {
                SwiftMapType.Street => Microsoft.Maui.Maps.MapType.Street,
                SwiftMapType.Satellite => Microsoft.Maui.Maps.MapType.Satellite,
                SwiftMapType.Hybrid => Microsoft.Maui.Maps.MapType.Hybrid,
                _ => null,
            };
    }

    /// <summary>
    /// A point on the world: latitude then longitude, as a list of two numbers -
    /// the shape a Thickness travels in, two values long.
    /// </summary>
    public static Location? GetLocation(this SwiftNode node, SwiftKey key)
    {
        return node.GetNumbers(key) is [double latitude, double longitude]
            ? new Location(latitude, longitude)
            : null;
    }

    /// <summary>
    /// A region of the world: the point above plus a radius in METERS, which
    /// is what MAUI's <c>Distance</c> is at bottom.
    /// </summary>
    public static Microsoft.Maui.Maps.MapSpan? GetMapSpan(this SwiftNode node, SwiftKey key)
    {
        return node.GetNumbers(key) is [double latitude, double longitude, double radius]
            ? MapSpan(latitude, longitude, radius)
            : null;
    }

    /// <summary>
    /// The same region from the three numbers themselves - the shape the
    /// <c>Map.MoveToRegion</c> act carries them in, where the property above
    /// carries them as one array.
    /// </summary>
    public static Microsoft.Maui.Maps.MapSpan MapSpan(
        double latitude, double longitude, double radiusMeters)
    {
        return Microsoft.Maui.Maps.MapSpan.FromCenterAndRadius(
            new Location(latitude, longitude),
            Microsoft.Maui.Maps.Distance.FromMeters(radiusMeters));
    }

    /// <summary>Whether a swipe reveals its items or runs the first of them.</summary>
    public static SwipeMode? GetSwipeMode(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftSwipeMode)member switch
            {
                SwiftSwipeMode.Reveal => SwipeMode.Reveal,
                SwiftSwipeMode.Execute => SwipeMode.Execute,
                _ => null,
            };
    }

    /// <summary>What the open items do once one of them has run.</summary>
    public static SwipeBehaviorOnInvoked? GetSwipeBehaviorOnInvoked(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftSwipeBehaviorOnInvoked)member switch
            {
                SwiftSwipeBehaviorOnInvoked.Auto => SwipeBehaviorOnInvoked.Auto,
                SwiftSwipeBehaviorOnInvoked.Close => SwipeBehaviorOnInvoked.Close,
                SwiftSwipeBehaviorOnInvoked.RemainOpen => SwipeBehaviorOnInvoked.RemainOpen,
                _ => null,
            };
    }

    /// <summary>Which of a SwipeView's four collections a set of items is.</summary>
    /// <remarks>
    /// MAUI has four separate PROPERTIES rather than an enum - XAML names the
    /// collection by the element the items sit inside - so this answers the
    /// mirror itself and the renderer picks the collection. NOT
    /// <see cref="SwipeDirection"/>: the left items are what a swipe to the
    /// RIGHT reveals, so the two vocabularies agree on every name and disagree
    /// on every meaning.
    /// </remarks>
    public static SwiftSwipeSide? GetSwipeSide(this SwiftNode node, SwiftKey key)
    {
        // The one accessor with no MAUI member to translate onto, so the guard
        // is all there is - and it is <see cref="Enum.IsDefined{T}(T)"/> over
        // OUR own mirror, which is a fact about this repository rather than
        // about a MAUI release.
        return node.GetEnumeration(key) is int member && Enum.IsDefined((SwiftSwipeSide)member)
            ? (SwiftSwipeSide)member
            : null;
    }

    // ---- Brushes -----------------------------------------------------------

    /// <summary>
    /// What a shape, a border or a background is painted with.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A brush arrives either as a plain colour - which a Brush property takes
    /// - or as a list of typed values, the kind first:
    /// </para>
    /// <code>
    /// [1, colour]                                        a solid colour
    /// [2, [x1,y1,x2,y2], offset, colour, offset, colour] a linear gradient
    /// [3, [cx,cy,r],     offset, colour, offset, colour] a radial gradient
    /// </code>
    /// <para>
    /// Which is a format of this library's own, and the one place a value MAUI
    /// has a syntax for does not travel in it. MAUI's <c>BrushTypeConverter</c>
    /// reads the CSS spelling and reads it partially - measured against 10.0.20:
    /// <c>linear-gradient(to right, red, blue)</c> produces a brush with NO
    /// stops, a stop written without a percentage lands at offset -1, and
    /// <c>to bottom right</c> gives the points of <c>to right</c>. Each of those
    /// draws nothing or draws the wrong thing, and none of them says a word.
    /// </para>
    /// <para>
    /// One brush, always: each stop's colour picked its half for the theme in
    /// force on the Swift side, so there is nothing to bind and nothing to
    /// build again when the system flips.
    /// </para>
    /// </remarks>
    public static Brush? GetBrush(this SwiftNode node, SwiftKey key)
    {
        if (node.GetValues(key) is not [{ Enumeration: int kind }, .. SwiftWireValue[] rest])
        {
            // Not a brush, then: a plain colour, which a Brush property takes.
            return node.GetColor(key) is Color colour ? new SolidColorBrush(colour) : null;
        }

        return (SwiftBrushKind)kind switch
        {
            SwiftBrushKind.SolidColor when rest is [SwiftWireValue only]
                && Colour(only) is Color colour => new SolidColorBrush(colour),

            SwiftBrushKind.LinearGradient when rest is
                [{ Numbers: [double x1, double y1, double x2, double y2] }, .. var stops] =>
                new LinearGradientBrush
                {
                    GradientStops = Stops(stops),
                    StartPoint = new Point(x1, y1),
                    EndPoint = new Point(x2, y2),
                },

            SwiftBrushKind.RadialGradient when rest is
                [{ Numbers: [double x, double y, double radius] }, .. var stops] =>
                new RadialGradientBrush
                {
                    GradientStops = Stops(stops),
                    Center = new Point(x, y),
                    Radius = radius,
                },

            _ => null,
        };
    }

    /// <summary>Assigns a brush to a property.</summary>
    public static void SetBrush(
        this SwiftNode node,
        SwiftKey key,
        BindableObject target,
        BindableProperty property)
    {
        if (node.GetBrush(key) is not Brush brush)
        {
            return;
        }

        target.SetValue(property, brush);
    }

    /// <summary>
    /// The stops of a gradient, in the order they were written: an offset and
    /// a colour, over and over.
    /// </summary>
    /// <remarks>
    /// A pair that will not read is skipped, which is the rule an unrecognized
    /// property follows everywhere else - and a trailing half-pair cannot make
    /// this walk off the end.
    /// </remarks>
    private static GradientStopCollection Stops(SwiftWireValue[] values)
    {
        var stops = new GradientStopCollection();

        for (int at = 0; at + 1 < values.Length; at += 2)
        {
            if (values[at].Tag == SwiftWireValue.TagNumber && Colour(values[at + 1]) is Color colour)
            {
                stops.Add(new GradientStop(colour, (float)values[at].Number));
            }
        }

        return stops;
    }

    /// <summary>One value as a colour, or null when it is something else.</summary>
    private static Color? Colour(SwiftWireValue value)
    {
        return value.Tag == SwiftWireValue.TagColor
            ? new Color(value.Red / 255f, value.Green / 255f, value.Blue / 255f, value.Alpha / 255f)
            : null;
    }

    // ---- Shapes ------------------------------------------------------------

    /// <summary>
    /// Corners, either all four the same or each one named.
    /// </summary>
    /// <remarks>
    /// One number is the shorthand MAUI's own constructor takes; four are top
    /// left, top right, bottom left and bottom right, which is the order it
    /// takes them in.
    /// </remarks>
    public static CornerRadius? GetCornerRadius(this SwiftNode node, SwiftKey key)
    {
        if (node.GetNumbers(key) is [double topLeft, double topRight, double bottomLeft, double bottomRight])
        {
            return new CornerRadius(topLeft, topRight, bottomLeft, bottomRight);
        }

        return node.GetNumber(key) is double radius ? new CornerRadius(radius) : null;
    }

    /// <summary>The corners of a polygon: x, y, x, y, one pair per point.</summary>
    /// <remarks>
    /// A flat list rather than a list of pairs. An odd count is a half point
    /// and reads as nothing at all.
    /// </remarks>
    public static PointCollection? GetPoints(this SwiftNode node, SwiftKey key)
    {
        if (node.GetNumbers(key) is not double[] numbers || numbers.Length % 2 != 0)
        {
            return null;
        }

        var points = new PointCollection();

        for (int at = 0; at + 1 < numbers.Length; at += 2)
        {
            points.Add(new Point(numbers[at], numbers[at + 1]));
        }

        return points;
    }

    /// <summary>An outline in SVG path syntax, likewise.</summary>
    public static Geometry? GetGeometry(this SwiftNode node, SwiftKey key)
    {
        return node.GetString(key) is string value
            ? new PathGeometryConverter().ConvertFromInvariantString(value) as Geometry
            : null;
    }

    /// <summary>The dashes and the gaps between them.</summary>
    public static DoubleCollection? GetDoubleCollection(this SwiftNode node, SwiftKey key)
    {
        return node.GetNumbers(key) is double[] values ? [.. values] : null;
    }

    /// <summary>How the end of an open line is drawn.</summary>
    public static PenLineCap? GetPenLineCap(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftPenLineCap)member switch
            {
                SwiftPenLineCap.Flat => PenLineCap.Flat,
                SwiftPenLineCap.Round => PenLineCap.Round,
                SwiftPenLineCap.Square => PenLineCap.Square,
                _ => null,
            };
    }

    /// <summary>How two segments meet at a corner.</summary>
    public static PenLineJoin? GetPenLineJoin(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftPenLineJoin)member switch
            {
                SwiftPenLineJoin.Miter => PenLineJoin.Miter,
                SwiftPenLineJoin.Bevel => PenLineJoin.Bevel,
                SwiftPenLineJoin.Round => PenLineJoin.Round,
                _ => null,
            };
    }

    /// <summary>
    /// What a shape does with the room it is given - Shape.Aspect, which is a
    /// Stretch rather than the Aspect an Image has.
    /// </summary>
    public static Stretch? GetStretch(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftStretch)member switch
            {
                SwiftStretch.None => Stretch.None,
                SwiftStretch.Fill => Stretch.Fill,
                SwiftStretch.Uniform => Stretch.Uniform,
                SwiftStretch.UniformToFill => Stretch.UniformToFill,
                _ => null,
            };
    }

    /// <summary>Which parts of a self-crossing outline count as inside it.</summary>
    public static FillRule? GetFillRule(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftFillRule)member switch
            {
                SwiftFillRule.EvenOdd => FillRule.EvenOdd,
                SwiftFillRule.Nonzero => FillRule.Nonzero,
                _ => null,
            };
    }

    /// <summary>Where a toolbar item goes - on the bar, or behind the overflow.</summary>
    public static ToolbarItemOrder? GetToolbarItemOrder(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftToolbarItemOrder)member switch
            {
                SwiftToolbarItemOrder.Default => ToolbarItemOrder.Default,
                SwiftToolbarItemOrder.Primary => ToolbarItemOrder.Primary,
                SwiftToolbarItemOrder.Secondary => ToolbarItemOrder.Secondary,
                _ => null,
            };
    }

    /// <summary>What one dot of an IndicatorView is drawn as.</summary>
    public static IndicatorShape? GetIndicatorShape(this SwiftNode node, SwiftKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (SwiftIndicatorShape)member switch
            {
                SwiftIndicatorShape.Circle => IndicatorShape.Circle,
                SwiftIndicatorShape.Square => IndicatorShape.Square,
                _ => null,
            };
    }

    /// <summary>
    /// What a GraphicsView draws: the canvas calls its drawing would have made,
    /// one value list per call - the kind first, then its arguments.
    /// </summary>
    /// <remarks>
    /// A list of lists, one per canvas call. See <see cref="SwiftDrawable"/>.
    /// </remarks>
    public static IDrawable? GetDrawable(this SwiftNode node, SwiftKey key)
    {
        return node.GetValues(key) is SwiftWireValue[] commands
            ? new SwiftDrawable(commands)
            : null;
    }
}
