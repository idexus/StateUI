// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Globalization;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Protocol;

/// <summary>
/// One render's worth of change, as Swift describes it.
/// </summary>
/// <remarks>
/// The generation is what the two sides agree on. It comes back with every
/// message and is quoted on the next request: a caller still holding the current
/// one is sent a patch, anyone else is sent the whole tree. That is what stops a
/// patch from ever being applied to a tree it was not computed against - after a
/// failure halfway through, or by a second host that has been showing something
/// else.
/// </remarks>
public sealed class SwiftMessage
{
    /// <summary>
    /// Which render produced this message. Quoted back on the next request; see
    /// the remarks on this class.
    /// </summary>
    public int Generation { get; set; }

    /// <summary>
    /// Whether the root describes the WHOLE tree rather than a change to it.
    /// </summary>
    /// <remarks>
    /// Said rather than inferred. A baseline of 0 is not what makes an answer
    /// complete - that is true of the first render and false of every other
    /// resync, since a host quoting a stale but non-zero generation is also
    /// sent the whole tree. Read as a patch, such a message makes the parts
    /// that can only be built refuse it and ask for it all over again.
    /// </remarks>
    public bool Complete { get; set; }

    /// <summary>
    /// The Application, and the change beneath it - its windows among them.
    /// Null only if Swift produced nothing, which it does not.
    /// </summary>
    public SwiftNode? Root { get; set; }
}

/// <summary>
/// An element's identity, in whichever of the two namespaces it lives in: a
/// number the Swift renderer assigned, or a name the author wrote with
/// <c>.id()</c>. The two can never collide because the kind travels with the
/// value.
/// </summary>
public readonly struct SwiftId
{
    private readonly string? _name;
    private readonly int _number;

    /// <summary>A renderer-assigned identity.</summary>
    internal SwiftId(int number) => _number = number;

    /// <summary>An author-written identity.</summary>
    internal SwiftId(string name) => _name = name;

    /// <summary>
    /// The identity as it is matched - quotes and all, so the two namespaces
    /// cannot meet: a renderer-assigned <c>12</c> reads as <c>12</c> and an
    /// author's <c>.id("12")</c> as <c>"12"</c>. Never shown to anyone.
    /// </summary>
    public string Key =>
        _name is null
            ? _number.ToString(CultureInfo.InvariantCulture)
            : "\"" + _name + "\"";

    /// <summary>The identity as a person reads it.</summary>
    public string Identity =>
        _name ?? _number.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// The identity the AUTHOR wrote, when they wrote one. Null means nobody
    /// named this element, which is not the same as it having no identity.
    /// </summary>
    public string? Name => _name;

}

/// <summary>
/// One element of the UI tree, and what changed about it.
/// </summary>
/// <remarks>
/// <para>
/// Mirrors <c>Patch</c> in <c>Core/Tree.swift</c>. Every NAME on it - the type,
/// each property key, each event - is resolved to its MEMBER by
/// <see cref="SwiftWire.ReadMessage"/>, once per name per session, as the
/// announcement is read: the renderer switches on <see cref="Type"/>, finds a
/// property under a <see cref="SwiftProp"/> and an event under a
/// <see cref="SwiftEvent"/>, and no spelling is compared anywhere below here.
/// </para>
/// <para>
/// An APPLICATION's own vocabulary is open, so it cannot be members: a control
/// it registered keeps its type's spelling in <see cref="TypeName"/> and its
/// own properties and events in <see cref="OwnProps"/> and
/// <see cref="OwnEvents"/>, under the names the application gave them.
/// </para>
/// <para>
/// The rule the whole file reads by: <b>a field that is not here did not
/// change</b>. An absent property is not a property that was unset - Swift says
/// that with <see cref="Replace"/>, because the renderer assigns only what
/// arrives and has nothing to overwrite a property with once it is gone.
/// </para>
/// </remarks>
public sealed class SwiftNode
{
    /// <summary>
    /// Who this element is. A number when the Swift renderer assigned it, a
    /// string when the author did with <c>.id()</c>.
    /// </summary>
    public SwiftId Id { get; set; }

    /// <summary>
    /// What this element IS, as the member the renderer switches on. Always
    /// sent. <see cref="SwiftNodeType.None"/> for a type this runtime has no
    /// case for - an application's own registered control, or one from a Swift
    /// side newer than this host, which renders as a red marker rather than
    /// throwing.
    /// </summary>
    internal SwiftNodeType Type { get; set; }

    private string? _typeName;

    /// <summary>
    /// The MAUI class name - <c>Label</c>, <c>VerticalStackLayout</c>, or an
    /// application's own <c>Gallery.TrafficLight</c>.
    /// </summary>
    /// <remarks>
    /// Two things need the spelling and only two: an application's control,
    /// which has no member and is found in the registry by name, and every
    /// diagnostic that has to say WHICH type it could not make sense of. A node
    /// this side builds rather than reads off the wire says its type and lets
    /// the spelling follow from it.
    /// </remarks>
    public string TypeName
    {
        get => _typeName ?? SwiftTokenNames<SwiftNodeType>.Spelling(Type);
        set => _typeName = value;
    }

    /// <summary>
    /// The control cannot be updated into what this node says, so it is thrown
    /// away and built again. Swift sets it when the MAUI type changed, and for
    /// the few lost properties nothing here can put back, and sends a complete
    /// node with it.
    /// </summary>
    public bool Replace { get; set; }

    /// <summary>Only the library's properties that changed, by member.</summary>
    internal Dictionary<SwiftProp, SwiftWireValue>? Props { get; set; }

    /// <summary>
    /// The properties this element described last render and does not describe
    /// now. Null on almost every node there ever is.
    /// </summary>
    /// <remarks>
    /// Each is cleared off the control - <c>ClearValue</c> on the
    /// BindableProperty <see cref="Rendering.SwiftStyles"/> knows it by - so
    /// what the modifier stood for goes back to MAUI's own default. Only the
    /// KEYS arrive: there is no value to send for a property that is gone, and
    /// what it falls back to is MAUI's business. A key in whichever vocabulary
    /// it belongs to, exactly as a property is, so an application's own
    /// control clears its own declared properties too.
    /// </remarks>
    internal List<SwiftKey>? Cleared { get; set; }

    /// <summary>
    /// The properties an APPLICATION declared on a control of its own, by the
    /// names it gave them. Null on every node but one of those.
    /// </summary>
    /// <remarks>
    /// A bag of its own because the vocabulary is: every app-declared name
    /// resolves to <see cref="SwiftProp.None"/>, so a control with two of them
    /// would lose one to the other as a duplicate key. A name the library ALSO
    /// has - <c>value</c>, <c>text</c> - arrives in <see cref="Props"/>
    /// instead, the reader having no way to tell whose it was, which is why a
    /// <see cref="SwiftKey"/> looks in both.
    /// </remarks>
    internal Dictionary<string, SwiftWireValue>? OwnProps { get; set; }

    /// <summary>
    /// The properties this element is to be WALKED to rather than assigned.
    /// Null on almost every node there ever is.
    /// </summary>
    /// <remarks>
    /// A flown property is an ordinary property in every other respect - its
    /// target sits in the bag it belongs to, under the same key, in the same
    /// shape, so a registered control's own property is walked exactly as a
    /// Label's opacity is. This says only how long the walk takes, on what
    /// curve, and which completion the Swift handler that started it is
    /// waiting on. A renderer that ignored this list would assign the targets
    /// and be correct, just not animated.
    /// </remarks>
    internal List<SwiftTransition>? Transitions { get; set; }

    /// <summary>
    /// The properties whose value is read off a DRIVEN STATE rather than off this
    /// message, or null when the message did not say - which means unchanged.
    /// </summary>
    /// <remarks>
    /// An EMPTY list is not null: it says this element has stopped tying any
    /// property to a state, and whatever was registered for it is to be given
    /// up. A property with a state behind it carries no value on any later
    /// message at all - the host reads it off the image on its own frames -
    /// though one that ALSO has a stated value still carries that, and then
    /// the newest of the two setpoints is the one in force.
    /// </remarks>
    internal List<SwiftStateEntry>? States { get; set; }

    /// <summary>
    /// How this element's children TRAVEL when it puts them somewhere new, or
    /// null when the message did not say - which means unchanged.
    /// </summary>
    /// <remarks>
    /// Said only by an element that places children - and by the APPLICATION,
    /// whose answer the rest of them inherit - because where a child sits is
    /// worked out here rather than described: it is not a property, so there is
    /// no transition for it to ride beside. See <c>MotionArranger</c>.
    /// </remarks>
    internal MotionSpec? Motion { get; set; }

    /// <summary>
    /// Whether the message SAID anything about how this element's children
    /// travel - which a null <see cref="Motion"/> alone cannot distinguish
    /// from silence.
    /// </summary>
    /// <remarks>
    /// Said with nothing behind it means "the application's", which is what
    /// every layout is until it is told otherwise. A layout that STOPS saying
    /// how its children travel has to be heard saying so, or the host would go
    /// on carrying them the old way.
    /// </remarks>
    internal bool Moves { get; set; }

    /// <summary>
    /// Which parts of a child's PLACE travel when this element puts it
    /// somewhere new - its corner, its width, its height.
    /// </summary>
    /// <remarks>
    /// Said with <see cref="Motion"/> and always beside it, since a layout may
    /// travel the way the application does and still hold one part of a place
    /// still. See <c>MotionArranger</c>.
    /// </remarks>
    internal SwiftMotionLanes Lanes { get; set; } = SwiftMotionLanes.All;

    /// <summary>
    /// The complete map of the library's events, sent only when the set of
    /// handled events changed. Handler ids belong to the element and outlive
    /// any one render, so an unchanged set needs no message.
    /// </summary>
    internal Dictionary<SwiftEvent, int>? Events { get; set; }

    /// <summary>
    /// The same, for the events an APPLICATION raises from a control of its
    /// own - by the names it raises them under. Sent and replaced with
    /// <see cref="Events"/>, being the other half of one map.
    /// </summary>
    internal Dictionary<string, int>? OwnEvents { get; set; }

    /// <summary>
    /// Whether <see cref="Children"/> is the COMPLETE list, in order - sent
    /// exactly when the arrangement changed: something added, removed or
    /// moved.
    /// </summary>
    /// <remarks>
    /// The list itself then carries everything a rearrangement needs: its
    /// order is the order, its length is the count, and an item whose
    /// identity is absent from it has left. A child that merely stands where
    /// it stood rides along as a stub - its identity and type and nothing
    /// else. When this is false, <see cref="Children"/> names only the
    /// children whose content changed, each found by its identity, and
    /// nothing else is touched.
    /// </remarks>
    public bool Arranged { get; set; }

    /// <summary>
    /// Whether this element's children are ROWS - interchangeable subtrees, a
    /// few described at a time out of many. Null when the message did not say,
    /// which means unchanged.
    /// </summary>
    /// <remarks>
    /// What it buys: a child that leaves the described list is KEPT rather
    /// than dropped, and a child that arrives is given one of the kept
    /// controls when their <see cref="Shape"/>s match. Written by the Swift
    /// side's own list and carousel on the layout their rows sit in, and by
    /// nothing else.
    /// </remarks>
    public bool? Recycles { get; set; }

    /// <summary>
    /// What this element's subtree LOOKS like with every value taken out of
    /// it - its types, its property keys and its event keys, recursively.
    /// Null when the message did not say, which means unchanged; zero says
    /// this subtree may not be recycled at all.
    /// </summary>
    /// <remarks>
    /// Two subtrees of one shape name the same properties on the same
    /// controls in the same places, so a control adopted under a matching
    /// shape is given a value for every property it already carries. That is
    /// what makes adoption safe: nothing is left over to clear, and nothing
    /// the arriving row names is missing from the leaving one. The number is
    /// the Swift side's - see <c>Core/Recycling.swift</c>, which is also where
    /// the list of types that may be pooled at all lives.
    /// </remarks>
    public ulong? Shape { get; set; }

    /// <summary>
    /// The children - all of them, in order, when <see cref="Arranged"/>; only
    /// the changed ones otherwise. Null when nothing below this element
    /// changed at all.
    /// </summary>
    public List<SwiftNode>? Children { get; set; }

    /// <summary>
    /// The identity as it is matched - see <see cref="SwiftId.Key"/>.
    /// </summary>
    public string Key => Id.Key;

    /// <summary>The identity as a person reads it.</summary>
    public string Identity => Id.Identity;

    /// <summary>
    /// The identity the AUTHOR wrote, when they wrote one.
    /// </summary>
    /// <remarks>
    /// The two namespaces, read the other way round: a string is a name someone
    /// chose - <c>.id("row-7")</c>, a style's resource key - and a number is one
    /// the Swift renderer handed out. Null means nobody named this element, which
    /// is not the same as it having no identity.
    /// </remarks>
    public string? Name => Id.Name;

    // Property accessors. Each returns null when the key is absent or holds
    // something of another shape, so the renderer can ask for anything and
    // assign only what actually arrived.
    //
    // Two of each: the renderer names a MEMBER, which is a lookup and no
    // spelling compared, and an APPLICATION names its own property the only way
    // it can - `node.GetString("state")` inside a registered control's `apply`.
    // A name is resolved once, here, and looked for in whichever bag it belongs
    // to; see SwiftKey.

    /// <summary>A property as text, or null when it is absent or not a string.</summary>
    /// <remarks>
    /// TEXT SOMEONE WROTE - a caption, a placeholder, a url, an SVG path, a
    /// .NET format string - and nothing else. A closed vocabulary is
    /// <see cref="GetEnumeration(string)"/>, a name is
    /// <see cref="GetName(string)"/>, and a value with parts is
    /// <see cref="GetValues(string)"/>.
    /// </remarks>
    public string? GetString(string key) => GetString(SwiftKey.Own(key));

    /// <summary>A property as text - see <see cref="GetString(string)"/>.</summary>
    internal string? GetString(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value) && value.Tag is SwiftWireValue.TagString
            ? value.Text
            : null;

    /// <summary>
    /// A property as the number of the vocabulary member it is, or null when it
    /// is absent or is something else.
    /// </summary>
    /// <remarks>
    /// The number is THIS REPOSITORY's, never MAUI's: every closed vocabulary
    /// has a mirror in <c>Protocol/SwiftWireEnums.cs</c> carrying the wire's
    /// own numbering, and <see cref="Rendering.SwiftValues"/> translates that
    /// mirror onto the real MAUI member BY NAME, one switch arm each. A bit set
    /// arrives as one of these too, carrying our bits.
    /// </remarks>
    public int? GetEnumeration(string key) => GetEnumeration(SwiftKey.Own(key));

    /// <summary>A member's number - see <see cref="GetEnumeration(string)"/>.</summary>
    internal int? GetEnumeration(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value) ? value.Enumeration : null;

    /// <summary>
    /// A property as the NAME it is - a style key, a visual state and its
    /// group, a radio group, a font family - or null when it is absent or is
    /// something else.
    /// </summary>
    /// <remarks>
    /// It rode the session's dictionary as a number, exactly as a property key
    /// does, and is resolved back to its spelling before it gets here.
    /// Deliberately not answered by <see cref="GetString(string)"/>: a name
    /// repeats across a tree and means the same thing every time, which is what
    /// earns it two bytes instead of its letters, and prose does neither.
    /// </remarks>
    public string? GetName(string key) => GetName(SwiftKey.Own(key));

    /// <summary>A property as a name - see <see cref="GetName(string)"/>.</summary>
    internal string? GetName(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value) ? value.Name : null;

    /// <summary>
    /// A property as a number, or null when it is absent or not one. Everything
    /// numeric travels as a double; <c>SwiftValues.GetInt</c> narrows it where
    /// MAUI wants an int. A non-finite number reads as "not a number".
    /// </summary>
    public double? GetNumber(string key) => GetNumber(SwiftKey.Own(key));

    /// <summary>A property as a number - see <see cref="GetNumber(string)"/>.</summary>
    internal double? GetNumber(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value)
            && value.Tag == SwiftWireValue.TagNumber
            && double.IsFinite(value.Number)
            ? value.Number
            : null;

    /// <summary>A property as true or false, or null when it is absent or neither.</summary>
    public bool? GetBool(string key) => GetBool(SwiftKey.Own(key));

    /// <summary>A property as true or false - see <see cref="GetBool(string)"/>.</summary>
    internal bool? GetBool(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value)
            ? value.Tag switch
            {
                SwiftWireValue.TagTrue => true,
                SwiftWireValue.TagFalse => false,
                _ => (bool?)null,
            }
            : null;

    /// <summary>
    /// An array of numbers - how the structured value types travel. A
    /// Thickness arrives as left, top, right, bottom.
    /// </summary>
    public double[]? GetNumbers(string key) => GetNumbers(SwiftKey.Own(key));

    /// <summary>A run of numbers - see <see cref="GetNumbers(string)"/>.</summary>
    internal double[]? GetNumbers(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value) && value.Tag == SwiftWireValue.TagNumbers
            ? value.Numbers
            : null;

    /// <summary>An array of strings - what a Picker is given to choose from.</summary>
    public string[]? GetStrings(string key) => GetStrings(SwiftKey.Own(key));

    /// <summary>A run of strings - see <see cref="GetStrings(string)"/>.</summary>
    internal string[]? GetStrings(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value) && value.Tag == SwiftWireValue.TagStrings
            ? value.Strings
            : null;

    /// <summary>
    /// A property as a colour's four channels, each 0 to 255 - or null when it
    /// is absent or is something else.
    /// </summary>
    /// <remarks>
    /// Answered as channels rather than as a MAUI <c>Color</c> so that this
    /// layer stays what it is: the shape of the bytes, with nothing of the
    /// framework in it. <c>SwiftValues.GetColor</c> is where one becomes a
    /// colour.
    /// </remarks>
    public (byte Red, byte Green, byte Blue, byte Alpha)? GetRgba(string key) =>
        GetRgba(SwiftKey.Own(key));

    /// <summary>A colour's four channels - see <see cref="GetRgba(string)"/>.</summary>
    internal (byte Red, byte Green, byte Blue, byte Alpha)? GetRgba(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value) && value.Tag == SwiftWireValue.TagColor
            ? (value.Red, value.Green, value.Blue, value.Alpha)
            : null;

    /// <summary>
    /// A property as a list of values of mixed kinds - what a Brush travels
    /// as. Null when the property is absent or is anything else.
    /// </summary>
    public SwiftWireValue[]? GetValues(string key) => GetValues(SwiftKey.Own(key));

    /// <summary>A value with parts - see <see cref="GetValues(string)"/>.</summary>
    internal SwiftWireValue[]? GetValues(SwiftKey key) =>
        TryGet(key, out SwiftWireValue value) && value.Tag == SwiftWireValue.TagValues
            ? value.Values
            : null;

    /// <summary>The raw value behind a key, when the node carries one at all.</summary>
    /// <remarks>
    /// An application's bag first, because only a key that named itself can be
    /// in it - and the library's second, since a key can be in exactly one of
    /// them: the reader put each name where its member said it belonged.
    /// <see cref="Props"/> never holds <see cref="SwiftProp.None"/>, so a key
    /// with no member finds nothing there.
    /// </remarks>
    private bool TryGet(SwiftKey key, out SwiftWireValue value)
    {
        if (key.Name is string own && OwnProps is not null
            && OwnProps.TryGetValue(own, out value))
        {
            return true;
        }

        if (Props is not null && Props.TryGetValue(key.Prop, out value))
        {
            return true;
        }

        value = default;
        return false;
    }
}

/// <summary>One property of one element, tied to a state.</summary>
/// <remarks>
/// Nine bytes on the wire and no law: a law belongs to the animated value's own
/// lanes, where a per-write law has to live anyway, so this says only which
/// number, which way it crosses, and which of the host's doors the value goes
/// through.
/// </remarks>
/// <param name="Property">The property, as a token this runtime knows.</param>
/// <param name="PropertyName">
/// Its name, which is what resolves a property of a control an application
/// registered.
/// </param>
/// <param name="Number">The number the value rides on.</param>
/// <param name="Mode">Which way it crosses.</param>
/// <param name="Kind">Which of the host's doors it goes through.</param>
internal readonly record struct SwiftStateEntry(
    SwiftProp Property,
    string PropertyName,
    int Number,
    SwiftStateMode Mode,
    SwiftStateKind Kind)
{
    /// <summary>
    /// The property this registration is about, as a key that reads either bag.
    /// </summary>
    internal SwiftKey Key => SwiftKey.Of(Property, PropertyName);
}

/// <summary>
/// One property being walked to rather than assigned, as Swift describes it.
/// </summary>
/// <remarks>
/// One flight is one <see cref="Channel"/>, however many properties and
/// however many controls it moves: a piece of state armed on three views
/// arrives as three of these carrying the same number, and the handler that
/// started it is resumed once, when the last of them is done.
/// </remarks>
/// <param name="Property">
/// The member whose value in <see cref="SwiftNode.Props"/> is the target, or
/// <see cref="SwiftProp.None"/> for a property an application declared on a
/// control of its own, whose target is in <see cref="SwiftNode.OwnProps"/>
/// under <paramref name="PropertyName"/>.
/// </param>
/// <param name="PropertyName">
/// The property's spelling - what an application's own is found by, what
/// <c>SwiftStyles.Property</c> resolves through, and what names the MAUI
/// animation so that a second walk on the same property replaces the first.
/// </param>
/// <param name="Law">
/// Which law it travels under - a stated length or a spring - as the number
/// the Swift <c>Motion.Law</c> enum gives it, mirrored by
/// <see cref="SwiftMotionLaw"/>.
/// </param>
/// <param name="Millis">
/// How long the walk takes, in milliseconds - or, for a spring, how quickly it
/// answers.
/// </param>
/// <param name="Easing">
/// The curve it walks on, as the number the Swift <c>Easing</c> enum gives it -
/// this repository's own, like every closed vocabulary on this wire, mirrored by
/// <see cref="SwiftEasing"/> and translated onto a MAUI easing by
/// <c>SwiftFlights.Read</c>.
/// </param>
/// <param name="Factor">
/// A spring's damping - the number that law needs beside its milliseconds.
/// </param>
/// <param name="Channel">
/// The completion the Swift handler is waiting on - one of the negative ids
/// every act already answers on - or ZERO where nobody is waiting, which is
/// what a value moving because it CHANGED carries.
/// </param>
/// <param name="Report">
/// How many milliseconds of the walk between saying where it has got to, or 0
/// when nobody asked. Counted on the WALK's clock rather than the wall's, so
/// what the author stated is what they get however the frames fall.
/// </param>
internal readonly record struct SwiftTransition(
    SwiftProp Property,
    string PropertyName,
    int Law,
    uint Millis,
    int Easing,
    double Factor,
    int Channel,
    uint Report = 0)
{
    /// <summary>The law this walk travels under, as the engine states one.</summary>
    internal MotionSpec Spec => (SwiftMotionLaw)Law switch
    {
        SwiftMotionLaw.Spring => MotionSpec.Spring(Millis, Factor),
        _ => MotionSpec.Eased(Millis, Easing),
    };

    /// <summary>
    /// The property this walk is about, as a key that reads either bag - so a
    /// registered control's own animatable property is found exactly as a
    /// Label's opacity is.
    /// </summary>
    internal SwiftKey Key => SwiftKey.Of(Property, PropertyName);
}
