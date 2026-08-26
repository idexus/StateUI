// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Protocol;

/// <summary>
/// One act the Swift side has asked the host to perform.
/// </summary>
/// <remarks>
/// <para>
/// The tree says what the interface is; this says what should HAPPEN. Swift can
/// no more navigate than it can create a Label - both are MAUI methods on MAUI
/// objects - so it queues the request and the host performs it, which is the
/// same split the whole bridge is built on.
/// </para>
/// <para>
/// <see cref="Name"/> is the MAUI method being asked for, camelCased, so the
/// queue reads like the code it turns into: <c>displayAlertAsync</c> with three
/// arguments. On
/// the wire it travelled as an id from the ledger - see
/// <see cref="SwiftWire"/> - and was resolved back to the name here, so
/// everything downstream still reads MAUI's own spelling.
/// </para>
/// <para>
/// An argument that is NOT THERE - a dialog with no destructive button, an
/// offset asked for no particular day - crosses as the wire's own nothing and
/// answers null from every accessor here, because each of them asks the tag
/// first. No sentinel stands in for it: an empty string and a -1 are each
/// indistinguishable from a value someone meant.
/// </para>
/// </remarks>
public sealed class SwiftCommand
{
    /// <summary>Parsed off the wire by <see cref="SwiftWire.ReadCommands"/>.</summary>
    internal SwiftCommand(
        SwiftAct act,
        string name,
        IReadOnlyList<SwiftWireValue> arguments,
        int? completion)
    {
        Act = act;
        Name = name;
        Arguments = arguments;
        Completion = completion;
    }

    /// <summary>
    /// The act, as the number that crossed the wire - what <c>Perform</c>
    /// switches on. <see cref="SwiftAct.None"/> for a by-name escape, which
    /// the default arm answers under its <see cref="Name"/>.
    /// </summary>
    public SwiftAct Act { get; }

    /// <summary>
    /// The MAUI method being asked for, camelCased, e.g.
    /// <c>displayAlertAsync</c> - the same spelling as <see cref="Act"/>'s
    /// member. A name the host does not know is reported to the completion and
    /// otherwise ignored.
    /// </summary>
    public string Name { get; }

    /// <summary>Its arguments, in the order MAUI takes them.</summary>
    public IReadOnlyList<SwiftWireValue> Arguments { get; }

    /// <summary>
    /// The handler id to report back to when the act finishes, if the caller
    /// wanted to know. Always negative - event handler ids are positive and
    /// belong to elements, and the boundary carries nothing but a number.
    /// </summary>
    public int? Completion { get; }

    /// <summary>
    /// An argument as a string, or null when there is none or it is something
    /// else - a name, a member of a closed vocabulary, a number.
    /// </summary>
    public string? GetString(int index) =>
        At(index) is { Tag: SwiftWireValue.TagString } value ? value.Text : null;

    /// <summary>
    /// An argument as a NAME from an open vocabulary - a style key, a kept
    /// state's key - or null when there is none or it is something else.
    /// </summary>
    /// <remarks>
    /// Deliberately not <see cref="GetString"/>: a name and a piece of text
    /// are different things on this wire and travel differently - a name rides
    /// the session's dictionary and costs two bytes after the first use - so
    /// nothing can take a label's words for a key somebody named.
    /// </remarks>
    public string? GetName(int index) =>
        At(index) is { Tag: SwiftWireValue.TagName } value ? value.Text : null;

    /// <summary>An argument as a whole number, or null when there is none.</summary>
    public int? GetInt(int index) => GetDouble(index) is double value ? (int)value : null;

    /// <summary>An argument as a number, or null when there is none.</summary>
    /// <remarks>
    /// Everything numeric crosses as a double - an opacity, an angle, a length
    /// in milliseconds - and narrowing it is whoever reads it's business, the
    /// same rule the tree's properties follow. A NaN crosses as its own bits
    /// and reads as "not a number" here, which is what makes the session
    /// refuse it rather than animate to a zero nobody asked for.
    /// </remarks>
    public double? GetDouble(int index) =>
        At(index) is { Tag: SwiftWireValue.TagNumber } value && double.IsFinite(value.Number)
            ? value.Number
            : null;

    /// <summary>An argument as a boolean, or null when there is none.</summary>
    public bool? GetBool(int index) => At(index)?.Tag switch
    {
        SwiftWireValue.TagTrue => true,
        SwiftWireValue.TagFalse => false,
        _ => null,
    };

    /// <summary>
    /// An argument as a member of a closed vocabulary, or null when there is
    /// none - which a keyboard is asked for with.
    /// </summary>
    /// <remarks>
    /// Deliberately not <see cref="GetInt"/>: a member's number and a quantity
    /// are different things on this wire and read through different doors, so
    /// nothing can take a maximum length for a keyboard.
    /// </remarks>
    public int? GetEnumeration(int index) =>
        At(index) is { Tag: SwiftWireValue.TagEnumeration } value ? value.Member : null;

    /// <summary>
    /// An argument as a list of numbers, or null when there is none - what a
    /// day travels as, three of them.
    /// </summary>
    public IReadOnlyList<double>? GetNumbers(int index) =>
        At(index) is { Tag: SwiftWireValue.TagNumbers } value ? value.Numbers : null;


    /// <summary>The argument at an index, or null when there is none.</summary>
    private SwiftWireValue? At(int index) =>
        index >= 0 && index < Arguments.Count ? Arguments[index] : null;
}
