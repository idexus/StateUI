// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Numerics;
using Microsoft.Maui.Controls.Shapes;
using Microsoft.Maui.Layouts;
using StateUI.Maui.Protocol;

// One name out of the iOS platform-specific namespace, aliased rather than
// imported: that namespace repeats half of MAUI's control names as static
// classes of its own - Page, Entry, NavigationPage - and importing it would
// leave every one of them ambiguous here.
using UIModalPresentationStyle =
    Microsoft.Maui.Controls.PlatformConfiguration.iOSSpecific.UIModalPresentationStyle;

namespace StateUI.Maui.Rendering;

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
/// A CLOSED VOCABULARY IS A NUMBER, not a spelling, and the
/// numbers are THIS REPOSITORY's, never MAUI's. Every one of them has a mirror
/// in <c>Protocol/HostEnums.cs</c> carrying our numbering, and the accessor
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
internal static class Values
{
    /// <summary>
    /// A colour, from the four channels it crossed as.
    /// </summary>
    /// <remarks>
    /// <para>
    /// One colour, always. A <c>Color(light:dark:)</c> carries both halves only
    /// as far as the differ, which picks the half in force as it builds the
    /// element wearing it - so the wire never carries a pair, nothing here
    /// asks what theme is in force, nothing binds, and a theme change builds
    /// again exactly the elements that wear one. See Types/Color.swift.
    /// </para>
    /// <para>
    /// MAUI holds the same four channels as floats over 0-1, which is the
    /// conversion and the whole of it: no parser, and no vocabulary of colour
    /// names that a second host would have to reproduce exactly.
    /// </para>
    /// </remarks>
    public static Color? GetColor(this HostPatch node, HostPropKey key)
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
        this HostPatch node,
        HostPropKey key,
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
    public static ImageSource? GetImageSource(this HostPatch node, HostPropKey key)
    {
        return node.GetString(key) is string file ? File(file) : null;
    }

    /// <summary>Assigns a picture to a property.</summary>
    public static void SetImageSource(
        this HostPatch node,
        HostPropKey key,
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
    public static WebViewSource? GetWebViewSource(this HostPatch node, HostPropKey key)
    {
        if (node.GetValues(key) is not [{ Enumeration: int kind }, .. HostValue[] rest])
        {
            return null;
        }

        return (HostWebViewSourceKind)kind switch
        {
            HostWebViewSourceKind.Url when rest is
                [{ Text: string url, Tag: HostValue.TagString }] =>
                new UrlWebViewSource { Url = url },

            HostWebViewSourceKind.Html when rest is
                [{ Text: string html, Tag: HostValue.TagString }, HostValue baseUrl] =>
                new HtmlWebViewSource
                {
                    Html = html,

                    // The base url is there when it is a STRING and absent
                    // otherwise, the wire's own nothing standing where there is
                    // none - which is not text, so the one test answers it.
                    BaseUrl = baseUrl.Tag == HostValue.TagString ? baseUrl.Text : null,
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
    /// app being the whole screen. On Windows they are written on the platform
    /// window itself - see <c>WindowGeometry</c>. Mac Catalyst applies
    /// the minimum and the maximum, ignores <c>X</c> and <c>Y</c>, and would
    /// ignore <c>Width</c> and <c>Height</c> - which is what
    /// <see cref="WindowSize"/> is for.
    /// </para>
    /// <para>
    /// Assigned only when the property arrived, like everywhere else: a message
    /// carries what changed, and a window nobody resized is not in it.
    /// </para>
    /// </remarks>
    public static void ApplyWindow(this HostPatch node, Window window)
    {
        if (node.GetString(HostProp.Title) is string title) { window.Title = title; }

#if WINDOWS
        // WINUI'S FRAME REPORT RE-ENTERS THESE FOUR SETTERS and moves the
        // window for ever. See WindowGeometry.
        WindowGeometry.Apply(window, node);
#else
        if (node.GetNumber(HostProp.X) is double x) { window.X = x; }
        if (node.GetNumber(HostProp.Y) is double y) { window.Y = y; }

        if (node.GetNumber(HostProp.Width) is double width) { window.Width = width; }
        if (node.GetNumber(HostProp.Height) is double height) { window.Height = height; }
#endif

        if (node.GetBool(HostProp.IsMaximizable) is bool maximizable) { window.IsMaximizable = maximizable; }
        if (node.GetBool(HostProp.IsMinimizable) is bool minimizable) { window.IsMinimizable = minimizable; }
        if (node.GetNumber(HostProp.MinimumWidth) is double minimumWidth) { window.MinimumWidth = minimumWidth; }
        if (node.GetNumber(HostProp.MinimumHeight) is double minimumHeight) { window.MinimumHeight = minimumHeight; }
        if (node.GetNumber(HostProp.MaximumWidth) is double maximumWidth) { window.MaximumWidth = maximumWidth; }
        if (node.GetNumber(HostProp.MaximumHeight) is double maximumHeight) { window.MaximumHeight = maximumHeight; }

        // Last, and only where the platform needs asking: it reads the maximum
        // assigned above to know what to give back afterwards.
        WindowSize.OpenAtRequestedSize(window, node);
    }

    /// <summary>Left, top, right, bottom - the order MAUI's constructor takes.</summary>
    public static Thickness? GetThickness(this HostPatch node, HostPropKey key)
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
    public static SafeAreaEdges? GetSafeAreaEdges(this HostPatch node, HostPropKey key)
    {
        if (node.GetEnumeration(key) is int uniform)
        {
            return Region(uniform) is SafeAreaRegions region ? new SafeAreaEdges(region) : null;
        }

        // Four MEMBERS, one per edge, each a value of its own - a run of
        // numbers would say these were quantities.
        if (node.GetValues(key) is not
            [
                { Tag: HostValue.TagEnumeration } left,
                { Tag: HostValue.TagEnumeration } top,
                { Tag: HostValue.TagEnumeration } right,
                { Tag: HostValue.TagEnumeration } bottom,
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
        return (HostSafeArea)member switch
        {
            HostSafeArea.None => SafeAreaRegions.None,
            HostSafeArea.Keyboard => SafeAreaRegions.SoftInput,
            HostSafeArea.Container => SafeAreaRegions.Container,
            HostSafeArea.All => SafeAreaRegions.All,
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
    public static Rect? GetRect(this HostPatch node, HostPropKey key)
    {
        return node.GetNumbers(key) is [double x, double y, double width, double height]
            ? new Rect(x, y, width, height)
            : null;
    }

    /// <summary>
    /// A number, narrowed. Everything numeric travels as a double, and MAUI
    /// wants an int for a few of them - MaxLines, CornerRadius, SelectedIndex.
    /// </summary>
    public static int? GetInt(this HostPatch node, HostPropKey key)
    {
        return node.GetNumber(key) is double value ? (int)value : null;
    }

    /// <summary>Where a view sits in the space its layout gives it.</summary>
    /// <remarks>
    /// MAUI's LayoutOptions is a STRUCT of a <c>LayoutAlignment</c> and an
    /// "expands" flag whose four <c>…AndExpand</c> statics MAUI marks obsolete;
    /// each of these translates onto one of the four plain statics - that
    /// alignment with the flag false - and the flag never crosses.
    /// </remarks>
    public static LayoutOptions? GetLayoutOptions(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostAlignment)member switch
            {
                HostAlignment.Start => LayoutOptions.Start,
                HostAlignment.Center => LayoutOptions.Center,
                HostAlignment.End => LayoutOptions.End,
                HostAlignment.Fill => LayoutOptions.Fill,
                _ => null,
            };
    }

    /// <summary>Where text sits within a control's own bounds.</summary>
    public static TextAlignment? GetTextAlignment(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostTextAlignment)member switch
            {
                HostTextAlignment.Start => TextAlignment.Start,
                HostTextAlignment.Center => TextAlignment.Center,
                HostTextAlignment.End => TextAlignment.End,
                _ => null,
            };
    }

    /// <summary>Bold, italic, both or neither.</summary>
    /// <remarks>
    /// A bit set rather than a choice, so it is read one bit at a time and a bit
    /// nobody declared refuses the whole value - a switch cannot stand in,
    /// there being one number per COMBINATION.
    /// </remarks>
    public static FontAttributes? GetFontAttributes(this HostPatch node, HostPropKey key)
    {
        const HostFontAttributes declared = HostFontAttributes.Bold | HostFontAttributes.Italic;

        if (node.GetEnumeration(key) is not int bits || (bits & ~(int)declared) != 0)
        {
            return null;
        }

        var carried = (HostFontAttributes)bits;
        var attributes = FontAttributes.None;

        if (carried.HasFlag(HostFontAttributes.Bold)) { attributes |= FontAttributes.Bold; }
        if (carried.HasFlag(HostFontAttributes.Italic)) { attributes |= FontAttributes.Italic; }

        return attributes;
    }

    /// <summary>Underlined, struck through, both or neither.</summary>
    /// <remarks>A bit set; see <see cref="GetFontAttributes"/>.</remarks>
    public static TextDecorations? GetTextDecorations(this HostPatch node, HostPropKey key)
    {
        const HostTextDecorations declared =
            HostTextDecorations.Underline | HostTextDecorations.Strikethrough;

        if (node.GetEnumeration(key) is not int bits || (bits & ~(int)declared) != 0)
        {
            return null;
        }

        var carried = (HostTextDecorations)bits;
        var decorations = TextDecorations.None;

        if (carried.HasFlag(HostTextDecorations.Underline))
        {
            decorations |= TextDecorations.Underline;
        }

        if (carried.HasFlag(HostTextDecorations.Strikethrough))
        {
            decorations |= TextDecorations.Strikethrough;
        }

        return decorations;
    }

    /// <summary>What happens to text too long for its space.</summary>
    public static LineBreakMode? GetLineBreakMode(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostLineBreak)member switch
            {
                HostLineBreak.NoWrap => LineBreakMode.NoWrap,
                HostLineBreak.WordWrap => LineBreakMode.WordWrap,
                HostLineBreak.CharacterWrap => LineBreakMode.CharacterWrap,
                HostLineBreak.HeadTruncation => LineBreakMode.HeadTruncation,
                HostLineBreak.TailTruncation => LineBreakMode.TailTruncation,
                HostLineBreak.MiddleTruncation => LineBreakMode.MiddleTruncation,
                _ => null,
            };
    }

    /// <summary>Which keyboard a text input asks for.</summary>
    public static Keyboard? GetKeyboard(this HostPatch node, HostPropKey key)
    {
        return KeyboardOf(node.GetEnumeration(key));
    }

    /// <summary>
    /// The same lookup from the member's number itself - the shape an act's
    /// argument carries it in, where a property carries it on a node.
    /// </summary>
    /// <remarks>
    /// A lookup rather than a cast for the reason every vocabulary here is one,
    /// and one more besides: MAUI's Keyboard members are static properties on a
    /// CLASS, so there is no enum on that side to cast to at all.
    /// </remarks>
    /// <param name="member">
    /// The keyboard's number, as <see cref="HostInputPurpose"/> - or null where the
    /// argument was absent, which an act reads straight off the wire.
    /// </param>
    /// <returns>The MAUI keyboard, or null for a number naming none.</returns>
    public static Keyboard? KeyboardOf(int? member)
    {
        return (HostInputPurpose?)member switch
        {
            HostInputPurpose.Default => Keyboard.Default,
            HostInputPurpose.Plain => Keyboard.Plain,
            HostInputPurpose.Chat => Keyboard.Chat,
            HostInputPurpose.Email => Keyboard.Email,
            HostInputPurpose.Numeric => Keyboard.Numeric,
            HostInputPurpose.Telephone => Keyboard.Telephone,
            HostInputPurpose.Text => Keyboard.Text,
            HostInputPurpose.Url => Keyboard.Url,
            _ => null,
        };
    }

    /// <summary>What the keyboard's return key says.</summary>
    public static ReturnType? GetReturnType(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostReturnKey)member switch
            {
                HostReturnKey.Default => ReturnType.Default,
                HostReturnKey.Done => ReturnType.Done,
                HostReturnKey.Go => ReturnType.Go,
                HostReturnKey.Next => ReturnType.Next,
                HostReturnKey.Search => ReturnType.Search,
                HostReturnKey.Send => ReturnType.Send,
                _ => null,
            };
    }

    /// <summary>
    /// Row definitions: a list of lengths, each its own two parts.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The LIST says how many rows there are, and each entry is the kind - a
    /// <see cref="HostGridLengthKind"/> - then the number that kind takes:
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
    public static RowDefinitionCollection? GetRowDefinitions(this HostPatch node, HostPropKey key)
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
    public static ColumnDefinitionCollection? GetColumnDefinitions(this HostPatch node, HostPropKey key)
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
    private static List<GridLength>? Lengths(HostPatch node, HostPropKey key)
    {
        if (node.GetValues(key) is not HostValue[] values)
        {
            return null;
        }

        var lengths = new List<GridLength>(values.Length);

        foreach (HostValue value in values)
        {
            if (value.Values is not
                [{ Enumeration: int kind }, { Tag: HostValue.TagNumber } size])
            {
                return null;
            }

            GridUnitType? unit = (HostGridLengthKind)kind switch
            {
                HostGridLengthKind.Fixed => GridUnitType.Absolute,
                HostGridLengthKind.Proportional => GridUnitType.Star,
                HostGridLengthKind.Auto => GridUnitType.Auto,
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
    public static TextTransform? GetTextTransform(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostTextCase)member switch
            {
                HostTextCase.None => TextTransform.None,
                HostTextCase.Default => TextTransform.Default,
                HostTextCase.Lowercase => TextTransform.Lowercase,
                HostTextCase.Uppercase => TextTransform.Uppercase,
                _ => null,
            };
    }

    /// <summary>Whether a scroll bar is shown, hidden, or left to the platform.</summary>
    public static ScrollBarVisibility? GetScrollBarVisibility(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostScrollBarVisibility)member switch
            {
                HostScrollBarVisibility.Default => ScrollBarVisibility.Default,
                HostScrollBarVisibility.Always => ScrollBarVisibility.Always,
                HostScrollBarVisibility.Never => ScrollBarVisibility.Never,
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
    public static DateTime? GetDate(this HostPatch node, HostPropKey key)
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
    public static TimeSpan? GetTime(this HostPatch node, HostPropKey key)
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

    /// <summary>
    /// A shape's geometry transform: the six numbers of the matrix the Swift
    /// side composed - the two columns of the linear part, then the offsets -
    /// read into the matrix every platform runs the shape's path through.
    /// </summary>
    /// <remarks>
    /// Null for anything that will not read, which the caller answers by
    /// leaving the property alone: a transform that half-parsed would draw a
    /// shape nobody asked for.
    /// </remarks>
    public static Matrix3x2? GetGeometryTransform(this HostPatch node, HostPropKey key)
    {
        if (node.GetValues(key) is not HostValue[] values) { return null; }

        if (Numbers(values) is not
            [double m11, double m12, double m21, double m22, double offsetX, double offsetY])
        {
            return null;
        }

        return new Matrix3x2(
            (float)m11, (float)m12, (float)m21, (float)m22, (float)offsetX, (float)offsetY);
    }

    /// <summary>Every value read as a number, or null if one of them is not.</summary>
    private static double[]? Numbers(HostValue[] values)
    {
        var read = new double[values.Length];

        for (int at = 0; at < values.Length; at++)
        {
            if (values[at] is not { Tag: HostValue.TagNumber } number) { return null; }
            read[at] = number.Number;
        }

        return read;
    }

    /// <summary>The outline of a Border: the kind, then what that kind takes.</summary>
    /// <remarks>
    /// <c>[1, 12]</c> is a round rectangle of 12; the other two carry nothing.
    /// Built here rather than by MAUI's <c>StrokeShapeTypeConverter</c>, which
    /// reads XAML's <c>RoundRectangle 12</c>: a string on this wire is text
    /// someone wrote, and a shape is not that.
    /// </remarks>
    public static IShape? GetStrokeShape(this HostPatch node, HostPropKey key)
    {
        if (node.GetValues(key) is not [{ Enumeration: int kind }, .. HostValue[] rest])
        {
            return null;
        }

        return (HostBorderShapeKind)kind switch
        {
            HostBorderShapeKind.Rectangle when rest is [] => new Rectangle(),

            HostBorderShapeKind.RoundedRectangle when rest is
                [{ Tag: HostValue.TagNumber } radius] =>
                new RoundRectangle { CornerRadius = new CornerRadius(radius.Number) },

            HostBorderShapeKind.Ellipse when rest is [] => new Ellipse(),

            _ => null,
        };
    }

    /// <summary>Which side of a button's caption its icon is on.</summary>
    /// <remarks>
    /// Leading and trailing are MAUI's left and right: a button laid out right
    /// to left mirrors its content, the picture included.
    /// </remarks>
    public static Button.ButtonContentLayout.ImagePosition? GetIconPosition(
        this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostIconPosition)member switch
            {
                HostIconPosition.Leading => Button.ButtonContentLayout.ImagePosition.Left,
                HostIconPosition.Top => Button.ButtonContentLayout.ImagePosition.Top,
                HostIconPosition.Trailing => Button.ButtonContentLayout.ImagePosition.Right,
                HostIconPosition.Bottom => Button.ButtonContentLayout.ImagePosition.Bottom,
                _ => null,
            };
    }

    /// <summary>Which way a view lays its content out. MAUI: FlowDirection.</summary>
    public static FlowDirection? GetFlowDirection(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostLayoutDirection)member switch
            {
                HostLayoutDirection.Inherited => FlowDirection.MatchParent,
                HostLayoutDirection.LeftToRight => FlowDirection.LeftToRight,
                HostLayoutDirection.RightToLeft => FlowDirection.RightToLeft,
                _ => null,
            };
    }

    /// <summary>How deep a heading is. MAUI: SemanticHeadingLevel.</summary>
    public static SemanticHeadingLevel? GetSemanticHeadingLevel(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostHeadingLevel)member switch
            {
                HostHeadingLevel.None => SemanticHeadingLevel.None,
                HostHeadingLevel.Level1 => SemanticHeadingLevel.Level1,
                HostHeadingLevel.Level2 => SemanticHeadingLevel.Level2,
                HostHeadingLevel.Level3 => SemanticHeadingLevel.Level3,
                HostHeadingLevel.Level4 => SemanticHeadingLevel.Level4,
                HostHeadingLevel.Level5 => SemanticHeadingLevel.Level5,
                HostHeadingLevel.Level6 => SemanticHeadingLevel.Level6,
                HostHeadingLevel.Level7 => SemanticHeadingLevel.Level7,
                HostHeadingLevel.Level8 => SemanticHeadingLevel.Level8,
                HostHeadingLevel.Level9 => SemanticHeadingLevel.Level9,
                _ => null,
            };
    }

    /// <summary>What a map pin stands for. MAUI: PinType.</summary>
    public static Microsoft.Maui.Controls.Maps.PinType? GetPinType(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostPinType)member switch
            {
                HostPinType.Generic => Microsoft.Maui.Controls.Maps.PinType.Generic,
                HostPinType.Place => Microsoft.Maui.Controls.Maps.PinType.Place,
                HostPinType.SavedPin => Microsoft.Maui.Controls.Maps.PinType.SavedPin,
                HostPinType.SearchResult => Microsoft.Maui.Controls.Maps.PinType.SearchResult,
                _ => null,
            };
    }

    /// <summary>How an image fills the room it is given.</summary>
    public static Aspect? GetAspect(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostAspect)member switch
            {
                HostAspect.Fit => Aspect.AspectFit,
                HostAspect.Fill => Aspect.AspectFill,
                HostAspect.Stretch => Aspect.Fill,
                HostAspect.Center => Aspect.Center,
                _ => null,
            };
    }

    /// <summary>Which ways a swipe is listened for.</summary>
    /// <remarks>
    /// A bit set, so a view listening every way is 15 rather than four names
    /// joined by commas. See <see cref="GetFontAttributes"/> for why the bits
    /// are read one at a time rather than switched on.
    /// </remarks>
    public static SwipeDirection? GetSwipeDirection(this HostPatch node, HostPropKey key)
    {
        if (node.GetEnumeration(key) is not int bits
            || (bits & ~(int)HostSwipeDirection.All) != 0)
        {
            return null;
        }

        var carried = (HostSwipeDirection)bits;
        SwipeDirection directions = 0;

        if (carried.HasFlag(HostSwipeDirection.Right)) { directions |= SwipeDirection.Right; }
        if (carried.HasFlag(HostSwipeDirection.Left)) { directions |= SwipeDirection.Left; }
        if (carried.HasFlag(HostSwipeDirection.Up)) { directions |= SwipeDirection.Up; }
        if (carried.HasFlag(HostSwipeDirection.Down)) { directions |= SwipeDirection.Down; }

        return directions;
    }

    /// <summary>Which way a ScrollView scrolls.</summary>
    public static ScrollOrientation? GetScrollOrientation(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostScrollOrientation)member switch
            {
                HostScrollOrientation.Vertical => ScrollOrientation.Vertical,
                HostScrollOrientation.Horizontal => ScrollOrientation.Horizontal,
                HostScrollOrientation.Both => ScrollOrientation.Both,
                HostScrollOrientation.Neither => ScrollOrientation.Neither,
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
    public static AbsoluteLayoutFlags? GetAbsoluteLayoutFlags(this HostPatch node, HostPropKey key)
    {
        if (node.GetEnumeration(key) is not int bits
            || (bits & ~(int)HostAbsoluteLayoutProportions.All) != 0)
        {
            return null;
        }

        var carried = (HostAbsoluteLayoutProportions)bits;
        var flags = AbsoluteLayoutFlags.None;

        if (carried.HasFlag(HostAbsoluteLayoutProportions.X))
        {
            flags |= AbsoluteLayoutFlags.XProportional;
        }

        if (carried.HasFlag(HostAbsoluteLayoutProportions.Y))
        {
            flags |= AbsoluteLayoutFlags.YProportional;
        }

        if (carried.HasFlag(HostAbsoluteLayoutProportions.Width))
        {
            flags |= AbsoluteLayoutFlags.WidthProportional;
        }

        if (carried.HasFlag(HostAbsoluteLayoutProportions.Height))
        {
            flags |= AbsoluteLayoutFlags.HeightProportional;
        }

        return flags;
    }

    /// <summary>How the world is drawn - streets, photography, or both.</summary>
    public static Microsoft.Maui.Maps.MapType? GetMapType(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostMapType)member switch
            {
                HostMapType.Street => Microsoft.Maui.Maps.MapType.Street,
                HostMapType.Satellite => Microsoft.Maui.Maps.MapType.Satellite,
                HostMapType.Hybrid => Microsoft.Maui.Maps.MapType.Hybrid,
                _ => null,
            };
    }

    /// <summary>
    /// A point on the world: latitude then longitude, as a list of two numbers -
    /// the shape a Thickness travels in, two values long.
    /// </summary>
    public static Location? GetLocation(this HostPatch node, HostPropKey key)
    {
        return node.GetNumbers(key) is [double latitude, double longitude]
            ? new Location(latitude, longitude)
            : null;
    }

    /// <summary>
    /// A region of the world: the point above plus a radius in METERS, which
    /// is what MAUI's <c>Distance</c> is at bottom.
    /// </summary>
    public static Microsoft.Maui.Maps.MapSpan? GetMapSpan(this HostPatch node, HostPropKey key)
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
    public static SwipeMode? GetSwipeMode(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostSwipeMode)member switch
            {
                HostSwipeMode.Reveal => SwipeMode.Reveal,
                HostSwipeMode.Execute => SwipeMode.Execute,
                _ => null,
            };
    }

    /// <summary>What the open items do once one of them has run.</summary>
    public static SwipeBehaviorOnInvoked? GetSwipeBehaviorOnInvoked(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostSwipeBehaviorOnInvoked)member switch
            {
                HostSwipeBehaviorOnInvoked.Auto => SwipeBehaviorOnInvoked.Auto,
                HostSwipeBehaviorOnInvoked.Close => SwipeBehaviorOnInvoked.Close,
                HostSwipeBehaviorOnInvoked.RemainOpen => SwipeBehaviorOnInvoked.RemainOpen,
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
    public static HostSwipeSide? GetSwipeSide(this HostPatch node, HostPropKey key)
    {
        // The one accessor with no MAUI member to translate onto, so the guard
        // is all there is - and it is <see cref="Enum.IsDefined{T}(T)"/> over
        // OUR own mirror, which is a fact about this repository rather than
        // about a MAUI release.
        return node.GetEnumeration(key) is int member && Enum.IsDefined((HostSwipeSide)member)
            ? (HostSwipeSide)member
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
    public static Brush? GetBrush(this HostPatch node, HostPropKey key)
    {
        if (node.GetValues(key) is not [{ Enumeration: int kind }, .. HostValue[] rest])
        {
            // Not a brush, then: a plain colour, which a Brush property takes.
            return node.GetColor(key) is Color colour ? new SolidColorBrush(colour) : null;
        }

        return (HostBrushKind)kind switch
        {
            HostBrushKind.SolidColor when rest is [HostValue only]
                && Colour(only) is Color colour => new SolidColorBrush(colour),

            HostBrushKind.LinearGradient when rest is
                [{ Numbers: [double x1, double y1, double x2, double y2] }, .. var stops] =>
                new LinearGradientBrush
                {
                    GradientStops = Stops(stops),
                    StartPoint = new Point(x1, y1),
                    EndPoint = new Point(x2, y2),
                },

            HostBrushKind.RadialGradient when rest is
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

    /// <summary>
    /// A view's one background: a colour lands on MAUI's BackgroundColor and
    /// takes any brush away, a gradient lands on Background.
    /// </summary>
    /// <remarks>
    /// StateUI has one background, a colour or a brush, and a view wears the
    /// one it was given last. MAUI keeps two and draws the brush over the
    /// colour, so a colour that arrives clears the brush. A colour stays on
    /// BackgroundColor because that is the property a visual state, a
    /// transition and a driven value walk.
    /// </remarks>
    public static void SetBackground(this HostPatch node, HostPropKey key, VisualElement target)
    {
        // A solid brush is a colour, and goes where a colour goes.
        if ((node.GetColor(key) ?? (node.GetBrush(key) as SolidColorBrush)?.Color) is Color color)
        {
            target.ClearValue(VisualElement.BackgroundProperty);
            target.BackgroundColor = color;
        }
        else if (node.GetBrush(key) is Brush brush)
        {
            target.Background = brush;
        }
    }

    /// <summary>Assigns a brush to a property.</summary>
    public static void SetBrush(
        this HostPatch node,
        HostPropKey key,
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
    private static GradientStopCollection Stops(HostValue[] values)
    {
        var stops = new GradientStopCollection();

        for (int at = 0; at + 1 < values.Length; at += 2)
        {
            if (values[at].Tag == HostValue.TagNumber && Colour(values[at + 1]) is Color colour)
            {
                stops.Add(new GradientStop(colour, (float)values[at].Number));
            }
        }

        return stops;
    }

    /// <summary>One value as a colour, or null when it is something else.</summary>
    private static Color? Colour(HostValue value)
    {
        return value.Tag == HostValue.TagColor
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
    public static CornerRadius? GetCornerRadius(this HostPatch node, HostPropKey key)
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
    public static PointCollection? GetPoints(this HostPatch node, HostPropKey key)
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
    public static Geometry? GetGeometry(this HostPatch node, HostPropKey key)
    {
        return node.GetString(key) is string value
            ? new PathGeometryConverter().ConvertFromInvariantString(value) as Geometry
            : null;
    }

    /// <summary>The dashes and the gaps between them.</summary>
    public static DoubleCollection? GetDoubleCollection(this HostPatch node, HostPropKey key)
    {
        return node.GetNumbers(key) is double[] values ? [.. values] : null;
    }

    /// <summary>How the end of an open line is drawn.</summary>
    public static PenLineCap? GetPenLineCap(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostLineCap)member switch
            {
                HostLineCap.Flat => PenLineCap.Flat,
                HostLineCap.Round => PenLineCap.Round,
                HostLineCap.Square => PenLineCap.Square,
                _ => null,
            };
    }

    /// <summary>How two segments meet at a corner.</summary>
    public static PenLineJoin? GetPenLineJoin(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostLineJoin)member switch
            {
                HostLineJoin.Miter => PenLineJoin.Miter,
                HostLineJoin.Bevel => PenLineJoin.Bevel,
                HostLineJoin.Round => PenLineJoin.Round,
                _ => null,
            };
    }

    /// <summary>
    /// How a shape fills the room it is given. The one Aspect an image and a
    /// shape share; MAUI names a shape's a Stretch.
    /// </summary>
    public static Stretch? GetShapeAspect(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostAspect)member switch
            {
                HostAspect.Fit => Stretch.Uniform,
                HostAspect.Fill => Stretch.UniformToFill,
                HostAspect.Stretch => Stretch.Fill,
                HostAspect.Center => Stretch.None,
                _ => null,
            };
    }

    /// <summary>Which parts of a self-crossing outline count as inside it.</summary>
    public static FillRule? GetFillRule(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostFillRule)member switch
            {
                HostFillRule.EvenOdd => FillRule.EvenOdd,
                HostFillRule.Nonzero => FillRule.Nonzero,
                _ => null,
            };
    }

    /// <summary>Where a toolbar item goes - on the bar, or behind the overflow.</summary>
    public static ToolbarItemOrder? GetToolbarItemOrder(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostToolbarItemPlacement)member switch
            {
                HostToolbarItemPlacement.Automatic => ToolbarItemOrder.Default,
                HostToolbarItemPlacement.Bar => ToolbarItemOrder.Primary,
                HostToolbarItemPlacement.Overflow => ToolbarItemOrder.Secondary,
                _ => null,
            };
    }

    /// <summary>What one dot of an IndicatorView is drawn as.</summary>
    public static IndicatorShape? GetIndicatorShape(this HostPatch node, HostPropKey key)
    {
        return node.GetEnumeration(key) is not int member
            ? null
            : (HostIndicatorShape)member switch
            {
                HostIndicatorShape.Circle => IndicatorShape.Circle,
                HostIndicatorShape.Square => IndicatorShape.Square,
                _ => null,
            };
    }

    /// <summary>
    /// What a GraphicsView draws: the canvas calls its drawing would have made,
    /// one value list per call - the kind first, then its arguments.
    /// </summary>
    /// <remarks>
    /// A list of lists, one per canvas call. See <see cref="ViewDrawing"/>.
    /// </remarks>
    public static IDrawable? GetDrawable(this HostPatch node, HostPropKey key)
    {
        return node.GetValues(key) is HostValue[] commands
            ? new ViewDrawing(commands)
            : null;
    }
}
