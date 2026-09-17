// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Protocol;

/// <summary>
/// One value as it crossed the wire: a tag and the payload the tag says is
/// there. What an act's argument is made of - see <c>Core/Wire.swift</c>
/// for the tags.
/// </summary>
public readonly struct HostValue
{
    internal const byte TagFalse = 1;
    internal const byte TagTrue = 2;
    internal const byte TagNumber = 3;
    internal const byte TagString = 4;
    internal const byte TagNumbers = 5;
    internal const byte TagStrings = 6;

    // 7 is unused, and nothing is renumbered to close the gap: a number costs
    // nothing left alone, while moving one has to land on both halves in the
    // same breath. A name crosses as TagName.

    /// <summary>
    /// A colour, as the four channels it is - each 0 to 255, sRGB, alpha
    /// included. The value this tree carries most of, and the cheapest to say
    /// exactly: four bytes, no parser, no vocabulary. The Swift side has
    /// already picked the half for the theme in force, so one of these is one
    /// colour and never a pair.
    /// </summary>
    internal const byte TagColor = 8;

    /// <summary>
    /// A list of values of any kind - what a value made of parts travels as: a
    /// brush, a stroke shape, a flex basis, a grid length and a list of them, a
    /// drawing, a WebView's source, a render transform, the safe-area edges, a
    /// button's content layout; and, from this side, the connection profiles.
    /// </summary>
    internal const byte TagValues = 9;

    /// <summary>
    /// One member of a CLOSED vocabulary, as its own number.
    /// </summary>
    /// <remarks>
    /// The number is THIS REPOSITORY's, declaration order from 0, in BOTH
    /// directions: an <c>internal enum</c> in <c>Protocol/HostEnums.cs</c>
    /// mirrors every Swift vocabulary member for member, and the translation
    /// onto MAUI's own member is a switch naming it literally. A bit set is one
    /// of these too, carrying our bits from 1&lt;&lt;0. Signed and four bytes
    /// wide: room enough for a bit set of any width, and for the negative
    /// number a translation answers to say a member is one it cannot read.
    /// </remarks>
    internal const byte TagEnumeration = 10;

    /// <summary>
    /// A NAME from an OPEN vocabulary - a visual state and its group, a radio
    /// group, a font family, a window's kind, a kept state's key.
    /// </summary>
    /// <remarks>
    /// Text an author wrote, but a name rather than prose: it repeats across a
    /// tree and means the same thing every time, so it rides the session's
    /// dictionary as its number exactly as a property key does - announced
    /// once, two bytes thereafter - and is resolved back here. Reads as a
    /// string through <see cref="HostPatch.GetName(string)"/>, which is deliberately
    /// NOT <see cref="HostPatch.GetString(string)"/>: a name and a piece of text are
    /// different things and this wire keeps them apart.
    /// </remarks>
    internal const byte TagName = 11;

    /// <summary>
    /// NOTHING - a value that is not there, carrying no payload at all.
    /// </summary>
    /// <remarks>
    /// An argument list has no such thing as a field left out, and a value list
    /// no such thing as a gap, so absence needs saying, and this is how it is
    /// said: a dialog's missing cancel, destruction or placeholder caption, a
    /// missing maximum length, "no day" in <c>getUtcOffset</c> and "no base
    /// url" in a WebView's HTML source all cross as NOTHING, where an empty
    /// string, a -1 or an empty list would each read as a value someone meant.
    /// Every typed accessor answers null for one, which is what makes an absent
    /// argument indistinguishable from a caller that never sent it.
    /// </remarks>
    internal const byte TagNothing = 12;

    internal readonly byte Tag;
    internal readonly double Number;
    internal readonly int Member;
    internal readonly string? Text;
    internal readonly double[]? Numbers;
    internal readonly string[]? Strings;
    internal readonly HostValue[]? Values;
    internal readonly byte Red;
    internal readonly byte Green;
    internal readonly byte Blue;
    internal readonly byte Alpha;

    internal HostValue(byte tag) => Tag = tag;

    internal HostValue(byte red, byte green, byte blue, byte alpha)
    {
        Tag = TagColor;
        Red = red;
        Green = green;
        Blue = blue;
        Alpha = alpha;
    }

    internal HostValue(HostValue[] values)
    {
        Tag = TagValues;
        Values = values;
    }

    internal HostValue(double number)
    {
        Tag = TagNumber;
        Number = number;
    }

    internal HostValue(string text)
    {
        Tag = TagString;
        Text = text;
    }

    internal HostValue(byte tag, string text)
    {
        Tag = tag;
        Text = text;
    }

    /// <summary>
    /// A member of a closed vocabulary - the tag says which kind of number it
    /// is, and the number is kept apart from <see cref="Number"/> so that
    /// nothing can read an alignment as a font size.
    /// </summary>
    internal HostValue(byte tag, int member)
    {
        Tag = tag;
        Member = member;
    }

    internal HostValue(double[] numbers)
    {
        Tag = TagNumbers;
        Numbers = numbers;
    }

    internal HostValue(string[] strings)
    {
        Tag = TagStrings;
        Strings = strings;
    }

    /// <summary>
    /// The member's number, when this value is one of a closed vocabulary -
    /// null for anything else, a plain number included, so nothing reads a
    /// font size as an alignment.
    /// </summary>
    internal int? Enumeration => Tag == TagEnumeration ? Member : null;

    /// <summary>
    /// The spelling, when this value is a NAME - null for anything else, TEXT
    /// included. The two are different things and this wire keeps them apart.
    /// </summary>
    internal string? Name => Tag == TagName ? Text : null;

    /// <summary>Text - an Entry's new value, a url, a search query.</summary>
    public static HostValue Of(string text) => new(text);

    /// <summary>
    /// A QUANTITY - a slider's value, an index, a count. Never a member of a
    /// vocabulary, however int-shaped it looks: that is
    /// <see cref="OfMember(int)"/>.
    /// </summary>
    public static HostValue Of(double number) => new(number);

    /// <summary>
    /// One member of a CLOSED vocabulary, as THIS REPOSITORY's number for it -
    /// a gesture's status, a battery state, why a navigation happened.
    /// </summary>
    /// <remarks>
    /// Named apart from <see cref="Of(double)"/> rather than overloading it,
    /// and that is the whole point: a member and a quantity are different
    /// things, an <c>int</c> widens into a double without a word, and the two
    /// calls would then differ only in the type of what was passed. The caller
    /// translates MAUI's member onto the mirror in
    /// <c>Protocol/HostEnums.cs</c> first - never a cast, which would put
    /// MAUI's own number on the wire and leave a MAUI release free to
    /// reinterpret it.
    /// </remarks>
    /// <param name="member">The mirror's member, cast to its number.</param>
    public static HostValue OfMember(int member) => new(TagEnumeration, member);

    /// <summary>
    /// A list of values of any kind - what several members travel as, there
    /// being no run of them the way there is a run of numbers.
    /// </summary>
    public static HostValue OfValues(params HostValue[] values) => new(values);

    /// <summary>True or false - a switch's state, a focus, a can-go-back.</summary>
    public static HostValue Of(bool value) => new(value ? TagTrue : TagFalse);

    /// <summary>
    /// A list of numbers - a point's pair, a date's three, a frame report's
    /// eight, a selection's positions.
    /// </summary>
    public static HostValue Of(params double[] numbers) => new(numbers);
}
