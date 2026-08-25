// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Reads an application's own properties off a node as the MAUI values they
/// stand for - a colour, a thickness, a picture, a brush, a day, a time.
/// </summary>
/// <remarks>
/// <para>
/// What a registered control's <c>apply</c> is handed is a
/// <see cref="SwiftNode"/>, and <see cref="SwiftNode.GetString(string)"/> and
/// its eight companions answer the WIRE's shapes: text, a number, a bit set, a
/// colour's four channels. These answer MAUI's types instead, so a control's
/// own property arrives ready to assign:
/// </para>
/// <code>
/// StateUIControls.Add("Gallery.Gauge",
///     create: _ => new Gauge(),
///     apply: (gauge, node) =>
///     {
///         if (node.GetColor("needleColor") is Color colour) { gauge.Needle = colour; }
///         if (node.GetThickness("inset") is Thickness inset) { gauge.Inset = inset; }
///     });
/// </code>
/// <para>
/// The Swift half writes those with the library's own public value types -
/// <c>setValue(Prop("needleColor"), Color(hex: "#E5484D").propValue)</c> - and
/// there is one reader here per such type, plus <see cref="GetInt"/> for the
/// narrowing every number needs. A property the renderer can assign by itself
/// needs none of this: name it in <c>StateUIControls.Add(..., properties:)</c>
/// and its BindableProperty is written whenever a message carries it, animations
/// included.
/// </para>
/// <para>
/// Every one of them takes the property's NAME, because an application's
/// vocabulary is its own - open, declared control by control, and numbered by
/// the session rather than known to this library. And every one answers null
/// when the property is absent or arrived in another shape, which is what lets a
/// control ask for everything it understands and assign only what came.
/// </para>
/// </remarks>
public static class StateUIValues
{
    /// <summary>
    /// A property as a whole number - what an index, a count or a step is read
    /// with.
    /// </summary>
    /// <remarks>
    /// Everything numeric crosses as a double, so this is the narrowing and
    /// nothing more: it TRUNCATES rather than rounds, so 2.7 answers 2. Ask for
    /// <see cref="SwiftNode.GetNumber(string)"/> where the fraction matters.
    /// </remarks>
    /// <param name="node">The node the property arrived on.</param>
    /// <param name="key">The property's name, as the application declared it.</param>
    /// <returns>The number, truncated - or null when the property is absent or
    /// is not a number.</returns>
    public static int? GetInt(this SwiftNode node, string key) =>
        node.GetInt(SwiftKey.Own(key));

    /// <summary>A property as a colour.</summary>
    /// <remarks>
    /// One colour, always. A Swift <c>Color(light:dark:)</c> picked its half as
    /// the value was written, so nothing here asks what theme is in force and a
    /// theme change simply renders the views that used one again.
    /// </remarks>
    /// <param name="node">The node the property arrived on.</param>
    /// <param name="key">The property's name, as the application declared it.</param>
    /// <returns>The colour, or null when the property is absent or is not one.</returns>
    public static Color? GetColor(this SwiftNode node, string key) =>
        node.GetColor(SwiftKey.Own(key));

    /// <summary>A property as a thickness - left, top, right, bottom.</summary>
    /// <remarks>
    /// A Swift <c>Thickness</c> written with one length or two spreads itself
    /// over the four the same way MAUI's own constructors do, so what arrives
    /// here is always the whole rectangle.
    /// </remarks>
    /// <param name="node">The node the property arrived on.</param>
    /// <param name="key">The property's name, as the application declared it.</param>
    /// <returns>The thickness, or null when the property is absent or is not
    /// one.</returns>
    public static Thickness? GetThickness(this SwiftNode node, string key) =>
        node.GetThickness(SwiftKey.Own(key));

    /// <summary>A property as a rectangle - x, y, width, height.</summary>
    /// <param name="node">The node the property arrived on.</param>
    /// <param name="key">The property's name, as the application declared it.</param>
    /// <returns>The rectangle, or null when the property is absent or is not
    /// one.</returns>
    public static Rect? GetRect(this SwiftNode node, string key) =>
        node.GetRect(SwiftKey.Own(key));

    /// <summary>
    /// A property as a picture: a file in the application's
    /// <c>Resources/Images</c>, by the name MAUI gives it once built - so
    /// <c>logo.svg</c> is asked for as <c>logo.png</c>, exactly as it would be
    /// in XAML.
    /// </summary>
    /// <remarks>
    /// One picture, for the reason a colour is one colour: artwork drawn twice
    /// with <c>ImageSource(light:dark:)</c> picked its half on the Swift side.
    /// </remarks>
    /// <param name="node">The node the property arrived on.</param>
    /// <param name="key">The property's name, as the application declared it.</param>
    /// <returns>The picture, or null when the property is absent or is not
    /// text.</returns>
    public static ImageSource? GetImageSource(this SwiftNode node, string key) =>
        node.GetImageSource(SwiftKey.Own(key));

    /// <summary>
    /// A property as a brush - a solid colour, a linear gradient or a radial
    /// one.
    /// </summary>
    /// <remarks>
    /// A plain colour answers a <c>SolidColorBrush</c>, so a property MAUI types
    /// as a Brush takes either and the Swift side need not say which.
    /// </remarks>
    /// <param name="node">The node the property arrived on.</param>
    /// <param name="key">The property's name, as the application declared it.</param>
    /// <returns>The brush, or null when the property is absent or is neither a
    /// brush nor a colour.</returns>
    public static Brush? GetBrush(this SwiftNode node, string key) =>
        node.GetBrush(SwiftKey.Own(key));

    /// <summary>A property as a day, from the Swift <c>CalendarDate</c> that
    /// crossed.</summary>
    /// <remarks>
    /// Midnight of that day, in no zone - a <c>CalendarDate</c> is three
    /// integers and names no instant. A trio that names no real day, a 31st of
    /// February among them, answers null.
    /// </remarks>
    /// <param name="node">The node the property arrived on.</param>
    /// <param name="key">The property's name, as the application declared it.</param>
    /// <returns>The day, or null when the property is absent, is not a date, or
    /// names no real one.</returns>
    public static DateTime? GetDate(this SwiftNode node, string key) =>
        node.GetDate(SwiftKey.Own(key));

    /// <summary>A property as a time of day, from the Swift <c>ClockTime</c>
    /// that crossed.</summary>
    /// <remarks>
    /// A length since midnight, which is what MAUI's own time properties take.
    /// Hours, minutes and seconds - a <c>ClockTime</c> keeps no millisecond.
    /// </remarks>
    /// <param name="node">The node the property arrived on.</param>
    /// <param name="key">The property's name, as the application declared it.</param>
    /// <returns>The time of day, or null when the property is absent, is not a
    /// time, or names no real one.</returns>
    public static TimeSpan? GetTime(this SwiftNode node, string key) =>
        node.GetTime(SwiftKey.Own(key));
}
