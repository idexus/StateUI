// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Buffers.Binary;
using System.Text;

using StateUI.Maui.Rendering;

namespace StateUI.Maui.Protocol;

/// <summary>
/// The binary wire format, mirroring <c>Core/Wire.swift</c> byte for byte:
/// this side READS the tree, the acts and the persistent-key announcement, and
/// WRITES the other five channels - an act's reply, an event's payload, a host
/// event, an environment push and what the store held.
/// </summary>
/// <remarks>
/// <para>
/// One process, one address space, every target little-endian - so numbers
/// cross as their own bytes and this reader walks the NATIVE buffer in place:
/// no UTF-16 round trip, no intermediate document, nothing materialized but
/// the values themselves.
/// </para>
/// <para>
/// A name - a node type, a property key, an event, an act - travels as a
/// number from the SESSION's dictionary: the first message to use one
/// announces the pair in its head, and this side learns it as it parses. See
/// <see cref="WireDictionary"/>. There is no static table, so there is
/// nothing to be out of step with, and an application's own names ride
/// numbers exactly as the library's do.
/// </para>
/// <para>
/// Anything malformed - a truncated value, a tag this version does not know,
/// an id no message announced - throws <see cref="InvalidDataException"/>,
/// and the caller cashes the receipt so every act in the unreadable batch
/// fails back to its awaiting handler. See
/// <c>Pump.PerformActCalls</c>.
/// </para>
/// </remarks>
/// 
/// 
internal static partial class WireCodec
{
    /// <summary>
    /// The format version this runtime reads and writes. Checked against
    /// <c>stateui_wire_version</c> before the first render, and against the
    /// first byte of every message. The format carries TYPED VALUES throughout
    /// - replies and event payloads included - where A STRING IS TEXT SOMEONE
    /// WROTE and nothing else is one: a closed vocabulary rides its member's
    /// NUMBER (<see cref="HostValue.TagEnumeration"/>, this repository's
    /// own, translated onto the MAUI member by name - see
    /// <see cref="Rendering.Values"/> for why, and for the mirrors), an
    /// open-vocabulary NAME rides the session's dictionary like a property key
    /// (<see cref="HostValue.TagName"/>), a value with parts rides as its
    /// parts, a colour is four bytes carrying one theme's half, and an absent
    /// argument is <see cref="HostValue.TagNothing"/>. An act's arguments are
    /// the values its member declares, each one value - a list, an action
    /// sheet's buttons, crosses as one. Every name is
    /// NUMBERED PER SESSION and announced by the message that first uses it.
    /// The arrangement
    /// is the children list itself - <see cref="HostPatch.Arranged"/> - order,
    /// count and removals in one. A property an element STOPS describing is
    /// named in <see cref="HostPatch.Cleared"/> and the host CLEARS it. An
    /// element may say its children are ROWS - <see cref="HostPatch.Recycles"/>
    /// - each saying what its subtree LOOKS like as one number,
    /// <see cref="HostPatch.Shape"/>, so a control whose row scrolled away is
    /// kept for the next row of the same shape. An element carries a MOTION
    /// FIELD of its own, saying how it moves what no property of it carries - a
    /// child's place in a layout and a visual state, both of which this side
    /// works out. A property may be TIED TO A DRIVEN STATE -
    /// <see cref="HostPatch.States"/> - naming the number this side reads its
    /// value from, after which it carries no value on any message. And a
    /// transition - <see cref="HostPatch.Transitions"/> - is a LAW AND NOTHING
    /// ELSE: no walk of a described value is awaited, what is awaited being a
    /// driven value, which rides the states field.
    /// </summary>
    internal const byte Version = 15;

    /// <summary>Reads a whole render message: the envelope, the names the
    /// message is the first to use, then the tree.</summary>
    internal static HostRender ReadMessage(ReadOnlySpan<byte> bytes, WireDictionary names)
    {
        var reader = new Reader(bytes);

        byte version = reader.U8();
        if (version != Version)
        {
            throw new InvalidDataException(
                $"the message says wire version {version} and this runtime reads {Version}");
        }

        bool complete = reader.U8() != 0;
        int generation = reader.I32();
        ReadAnnouncements(ref reader, names);
        HostPatch root = ReadNode(ref reader, names);

        if (!reader.AtEnd)
        {
            throw new InvalidDataException("the message carries bytes past its root");
        }

        return new HostRender { Generation = generation, Complete = complete, Root = root };
    }

    /// <summary>
    /// The head's dictionary section: the names this message is the first in
    /// its session to use. At the head, BEFORE anything that could refer to
    /// them, so a batch that fails later in its bytes has still taught this
    /// side its names.
    /// </summary>
    private static void ReadAnnouncements(ref Reader reader, WireDictionary names)
    {
        int count = reader.U16();
        for (int i = 0; i < count; i++)
        {
            ushort id = reader.U16();
            names.Set(id, reader.Str());
        }
    }

    /// <summary>
    /// One element's patch, and recursively the elements under it. The
    /// identity and the type come first, always; every other field is marked
    /// and present only when it changed - "a field that is not here did not
    /// change".
    /// </summary>
    private static HostPatch ReadNode(
        ref Reader reader, WireDictionary names, int depth = 0)
    {
        if (depth > MostNesting)
        {
            throw new InvalidDataException(
                $"the tree nests deeper than {MostNesting} levels");
        }

        // The identity, then the type - this file's promise about the bytes,
        // which an argument list would leave to the language.
        HostElementId id = ReadId(ref reader);
        WireDictionary.Entry type = ReadName(ref reader, names);

        var node = new HostPatch
        {
            Id = id,
            Type = type.NodeType,
            TypeName = type.Name,
        };

        while (true)
        {
            byte field = reader.U8();
            switch (field)
            {
                case 0:
                    return node;

                case 1:
                    node.Replace = true;
                    break;

                case 2:
                {
                    int count = reader.U16();

                    // The library's bag is made whether or not anything lands
                    // in it: "the node spoke about properties" is what its
                    // presence means downstream, and a control with nothing but
                    // its own said so too.
                    node.Props = new Dictionary<HostProp, HostValue>(count);

                    for (int i = 0; i < count; i++)
                    {
                        WireDictionary.Entry key = ReadName(ref reader, names);
                        HostValue value = reader.Value(names);

                        if (key.Prop != HostProp.None)
                        {
                            node.Props[key.Prop] = value;
                        }
                        else
                        {
                            (node.OwnProps ??= [])[key.Name] = value;
                        }
                    }
                    break;
                }

                case 3:
                {
                    int count = reader.U16();
                    node.Events = new Dictionary<HostEvent, int>(count);

                    for (int i = 0; i < count; i++)
                    {
                        WireDictionary.Entry name = ReadName(ref reader, names);
                        int handler = reader.I32();

                        if (name.Event != HostEvent.None)
                        {
                            node.Events[name.Event] = handler;
                        }
                        else
                        {
                            (node.OwnEvents ??= [])[name.Name] = handler;
                        }
                    }
                    break;
                }

                case 8:
                    node.Recycles = reader.U8() == 1;
                    break;

                case 9:
                    node.Shape = reader.U64();
                    break;

                case 7:
                {
                    int count = reader.U16();
                    node.Cleared = new List<HostPropKey>(count);

                    for (int i = 0; i < count; i++)
                    {
                        WireDictionary.Entry key = ReadName(ref reader, names);
                        node.Cleared.Add(HostPropKey.Of(key.Prop, key.Name));
                    }
                    break;
                }

                case 6:
                {
                    int count = reader.U16();
                    node.Transitions = new List<HostTransition>(count);
                    for (int i = 0; i < count; i++)
                    {
                        // Read into locals rather than into an argument list:
                        // the order of these is this file's promise about the
                        // bytes, not the language's about its arguments.
                        WireDictionary.Entry property = ReadName(ref reader, names);
                        int law = reader.I32();
                        uint millis = reader.U32();
                        int easing = reader.I32();
                        double factor = reader.F64();
                        node.Transitions.Add(new HostTransition(
                            property.Prop, property.Name, law, millis, easing, factor));
                    }
                    break;
                }

                case 11:
                {
                    int count = reader.U16();
                    node.States = new List<HostStateBinding>(count);

                    for (int i = 0; i < count; i++)
                    {
                        WireDictionary.Entry property = ReadName(ref reader, names);
                        int number = reader.I32();
                        byte mode = reader.U8();
                        byte kind = reader.U8();

                        // RANGE-CHECKED, both of them: a mode or a door this
                        // runtime does not know is a message from a newer
                        // Swift half, and reading it as the member that
                        // happens to share its number would tie a property to
                        // the wrong end of a state in silence.
                        if (mode > (byte)HostStateMode.InOut)
                        {
                            throw new InvalidDataException($"unknown number mode {mode}");
                        }

                        if (kind > (byte)HostStateKind.Plain)
                        {
                            throw new InvalidDataException($"unknown number kind {kind}");
                        }

                        node.States.Add(new HostStateBinding(
                            property.Prop,
                            property.Name,
                            number,
                            (HostStateMode)mode,
                            (HostStateKind)kind));
                    }
                    break;
                }

                case 10:
                {
                    int law = reader.I32();
                    node.Moves = true;

                    // -1 is the application's own, which is what a layout is
                    // until it is told otherwise - and carries no numbers.
                    if (law < 0)
                    {
                        node.Motion = null;
                    }
                    else
                    {
                        uint millis = reader.U32();
                        int easing = reader.I32();
                        double factor = reader.F64();

                        node.Motion = HostMotion.Of(law, millis, easing, factor);
                    }

                    // Always, whichever law: a layout may travel the way the
                    // application does and still hold one part of a place still.
                    node.Lanes = (HostMotionLanes)reader.U8();
                    break;
                }

                case 4:
                case 5:
                {
                    int count = reader.U16();
                    node.Arranged = field == 5;
                    node.Children = new List<HostPatch>(count);
                    for (int i = 0; i < count; i++)
                    {
                        node.Children.Add(
                            ReadNode(ref reader, names, depth + 1));
                    }
                    break;
                }

                default:
                    throw new InvalidDataException($"unknown node field {field}");
            }
        }
    }

    /// <summary>An identity, in whichever namespace its tag says.</summary>
    private static HostElementId ReadId(ref Reader reader) => reader.U8() switch
    {
        1 => new HostElementId(reader.I32()),
        2 => new HostElementId(reader.Str()),
        var tag => throw new InvalidDataException($"unknown identity tag {tag}"),
    };

    /// <summary>
    /// A name slot: the session dictionary's number, resolved to everything it
    /// stands for - its member in each vocabulary, and the spelling the
    /// registry and the diagnostics need. A name this RUNTIME does not
    /// recognize still degrades as it always did - an unknown property is
    /// ignored, an unknown type draws the marker - but an id no message ever
    /// announced is a protocol error, not a name, and refusing the message is
    /// what keeps the two sides from quietly disagreeing about what anything
    /// means.
    /// </summary>
    private static WireDictionary.Entry ReadName(ref Reader reader, WireDictionary names)
    {
        ushort id = reader.U16();

        return names.At(id)
            ?? throw new InvalidDataException($"the message uses name #{id}, never announced");
    }

    /// <summary>
    /// Reads the persistent-key announcement: which store the application
    /// keeps state in, and every key it keeps there.
    /// </summary>
    /// <remarks>
    /// <code>
    /// [version: U8][storage: string][count: U16]
    /// per key: [name: string][kind: U8]
    /// </code>
    /// <para>
    /// Names in full rather than dictionary numbers: this is the first thing
    /// either side says, before any message has announced anything, and the
    /// names belong to the platform's store rather than to a session.
    /// </para>
    /// </remarks>
    /// <param name="bytes">The buffer Swift answered with.</param>
    /// <returns>The store's name and the keys, in the order declared.</returns>
    internal static (string Storage, List<HostPersistentKey> Keys) ReadPersistentKeys(
        ReadOnlySpan<byte> bytes)
    {
        var reader = new Reader(bytes);

        byte version = reader.U8();
        if (version != Version)
        {
            throw new InvalidDataException(
                $"the keys say wire version {version} and this runtime reads {Version}");
        }

        string storage = reader.Str();
        int count = reader.U16();
        var keys = new List<HostPersistentKey>(count);

        for (int i = 0; i < count; i++)
        {
            string name = reader.Str();
            keys.Add(new HostPersistentKey(name, (HostPersistentKind)reader.U8()));
        }

        if (!reader.AtEnd)
        {
            throw new InvalidDataException(
                "the keys carry bytes past the last one");
        }

        return (storage, keys);
    }

    /// <summary>
    /// Serializes what the store held, for Swift to hydrate its kept state
    /// with - a name and a value per key that was THERE.
    /// </summary>
    /// <remarks>
    /// <code>
    /// [version: U8][count: U16]
    /// per entry: [name: string][value]
    /// </code>
    /// <para>
    /// A key the store had nothing under is simply left out, which is what
    /// leaves the Swift state holding the value written beside it. No sentinel
    /// stands in for absence here, the wire's rule.
    /// </para>
    /// </remarks>
    /// <param name="found">Name and value, for the keys the store had.</param>
    internal static byte[] WritePersistent(
        IReadOnlyList<(string Name, HostValue Value)> found)
    {
        var bytes = new List<byte>(32) { Version };
        Write(bytes, Count16(found.Count, "kept values"));

        foreach ((string name, HostValue value) in found)
        {
            Write(bytes, name);
            Write(bytes, value);
        }

        return [.. bytes];
    }

    /// <summary>Reads a whole batch of acts, announcements first.</summary>
    internal static List<HostActCall> ReadActCalls(ReadOnlySpan<byte> bytes, WireDictionary names)
    {
        var reader = new Reader(bytes);

        byte version = reader.U8();
        if (version != Version)
        {
            throw new InvalidDataException(
                $"the batch says wire version {version} and this runtime reads {Version}");
        }

        ReadAnnouncements(ref reader, names);

        int count = reader.U16();
        var calls = new List<HostActCall>(count);

        for (int i = 0; i < count; i++)
        {
            string name = ReadName(ref reader, names).Name;

            // The name decides the arm ONCE, here - Perform still switches on
            // the enum, and a name it maps to nothing fails in the default
            // arm, or runs what the application registered for it.
            HostAct act = TokenNames<HostAct>.Parse(name);

            int completion = reader.I32();
            int argCount = reader.U8();

            var arguments = new List<HostValue>(argCount);
            for (int a = 0; a < argCount; a++)
            {
                arguments.Add(reader.Value(names));
            }

            calls.Add(new HostActCall(act, name, arguments, completion == 0 ? null : completion));
        }

        if (!reader.AtEnd)
        {
            throw new InvalidDataException("the batch carries bytes past its last act");
        }

        return calls;
    }

    /// <summary>
    /// How deep a tree or a list value may nest before a reader refuses.
    /// A real page is tens of levels; the bound turns a corrupt length
    /// field into <see cref="InvalidDataException"/> instead of a stack
    /// overflow the process cannot catch.
    /// </summary>
    private const int MostNesting = 256;

    /// <summary>
    /// Narrows a count to the one byte its wire field has, refusing a list
    /// too long to say. A plain cast would truncate the count and the far
    /// side would refuse the buffer over its leftover bytes - misread as a
    /// version mismatch, where this names the list and the limit.
    /// </summary>
    private static byte Count8(int count, string of) =>
        count <= byte.MaxValue
            ? (byte)count
            : throw new ArgumentException(
                $"{count} {of}, and the wire counts them in one byte - "
                + $"at most {byte.MaxValue}");

    /// <summary>The two-byte form of <see cref="Count8"/>.</summary>
    private static ushort Count16(int count, string of) =>
        count <= ushort.MaxValue
            ? (ushort)count
            : throw new ArgumentException(
                $"{count} {of}, and the wire counts them in two bytes - "
                + $"at most {ushort.MaxValue}");

    // ---- Writing payloads, host events, environment pushes, replies -----

    /// <summary>
    /// Serializes an event's payload: one typed value per property of the
    /// MAUI EventArgs, in the order MAUI declares them. Answers null for no
    /// values - an event with nothing to say crosses no bytes at all, which
    /// is the common case and allocates nothing.
    /// </summary>
    internal static byte[]? WritePayload(params HostValue[] values)
    {
        if (values.Length == 0)
        {
            return null;
        }

        var bytes = new List<byte>(16);
        bytes.Add(Version);
        bytes.Add(Count8(values.Length, "values in one payload"));

        foreach (HostValue value in values)
        {
            Write(bytes, value);
        }

        return [.. bytes];
    }

    /// <summary>
    /// Serializes an event the host raises by NAME - no element behind it, so
    /// the name travels in the buffer, ahead of the same counted value list
    /// every channel shares. The Swift side reads it with
    /// <c>Wire.decodeHostEvent</c> and runs whatever <c>HostEvents.on</c>
    /// subscribed.
    /// </summary>
    internal static byte[] WriteHostEvent(string eventName, params HostValue[] values)
    {
        var bytes = new List<byte>(32);
        bytes.Add(Version);
        Write(bytes, eventName);
        bytes.Add(Count8(values.Length, "values on one host event"));

        foreach (HostValue value in values)
        {
            Write(bytes, value);
        }

        return [.. bytes];
    }

    /// <summary>
    /// Serializes what this host realizes - the elements it makes a view for
    /// and the members it realizes on each - said once, at start-up, through
    /// <see cref="Interop.CoreLink.SetRealization"/>. The Swift side reads it
    /// with <c>Wire.decodeRealization</c>.
    /// </summary>
    /// <remarks>
    /// <code>
    /// [version: U8][elements: U16] per element: [name: string]
    /// [members: U16] per member: [element: string][owner: string][member: string]
    /// </code>
    /// <para>
    /// Elements sorted by name and members by element, owner and member,
    /// ordinally - the Swift side's order for these names - so one
    /// realization is one run of bytes. Names in full: nothing has announced
    /// a dictionary yet.
    /// </para>
    /// </remarks>
    /// <param name="elements">The elements, by node type name.</param>
    /// <param name="members">The members, each on its element, by its owner's name and its own.</param>
    internal static byte[] WriteRealization(
        IEnumerable<string> elements,
        IEnumerable<(string Element, string Owner, string Member)> members)
    {
        string[] named = [.. elements.Distinct().Order(StringComparer.Ordinal)];
        (string Element, string Owner, string Member)[] realized =
        [
            .. members.Distinct()
                .OrderBy(member => member.Element, StringComparer.Ordinal)
                .ThenBy(member => member.Owner, StringComparer.Ordinal)
                .ThenBy(member => member.Member, StringComparer.Ordinal),
        ];

        var bytes = new List<byte>(64) { Version };
        Write(bytes, Count16(named.Length, "realized elements"));

        foreach (string element in named)
        {
            Write(bytes, element);
        }

        Write(bytes, Count16(realized.Length, "realized members"));

        foreach ((string element, string owner, string member) in realized)
        {
            Write(bytes, element);
            Write(bytes, owner);
            Write(bytes, member);
        }

        return [.. bytes];
    }

    /// <summary>
    /// Serializes what this host DECLARES: the elements it makes a view for
    /// and, on each, the members it takes and the events it raises - read off
    /// the registrations themselves, written to <c>exports/</c>, and joined
    /// with the contracts on the Swift side.
    /// </summary>
    /// <remarks>
    /// <code>
    /// [version: U8][elements: U16] per element: [name: string]
    ///   [members: U16] per member: [name: string]
    ///   [events: U16] per event: [name: string]
    /// [shared members: U16] per member: [name: string]
    /// [shared events: U16] per event: [name: string]
    /// [acts: U16] per act: [name: string]
    /// </code>
    /// <para>
    /// The SHARED members ride last and under no element: this host applies
    /// margins, opacity, the gestures and the focus and frame reports AROUND
    /// every view it makes rather than in a registration, so each of them
    /// belongs to a tier and reaches whichever elements wear it - which the
    /// side holding the contracts works out.
    /// </para>
    /// <para>
    /// A declaration states PRESENCE and never ownership, and that is the
    /// whole difference from <see cref="WriteRealization"/>: whether
    /// <c>borderColor</c> is a button's own member or one of a tier it wears
    /// is a fact of the CONTRACT, which this host does not hold. So each
    /// member rides under its element and the side holding the contracts names
    /// its owner - an owner never written by hand cannot be written wrong.
    /// </para>
    /// <para>
    /// Elements, members and events are each sorted ordinally, so one
    /// declaration is one run of bytes whatever order the registry was built
    /// in. Names in full: nothing has announced a dictionary here.
    /// </para>
    /// </remarks>
    /// <param name="elements">
    /// Each element, with the members its registration takes and the events it
    /// raises.
    /// </param>
    /// <param name="sharedMembers">
    /// The members the shared machinery takes on every element wearing the
    /// contract declaring them.
    /// </param>
    /// <param name="sharedEvents">The events it raises on every one of them.</param>
    /// <param name="acts">
    /// The acts this host performs, whichever element they are aimed at - an
    /// act names its view and is performed against that identity, so nothing
    /// about the call says which element declares it.
    /// </param>
    internal static byte[] WriteDeclaration(
        IEnumerable<(string Element, IEnumerable<string> Members, IEnumerable<string> Events)> elements,
        IEnumerable<string> sharedMembers,
        IEnumerable<string> sharedEvents,
        IEnumerable<string> acts)
    {
        (string Element, string[] Members, string[] Events)[] declared =
        [
            .. elements
                .Select(element => (
                    element.Element,
                    Members: element.Members.Distinct().Order(StringComparer.Ordinal).ToArray(),
                    Events: element.Events.Distinct().Order(StringComparer.Ordinal).ToArray()))
                .OrderBy(element => element.Element, StringComparer.Ordinal),
        ];

        var bytes = new List<byte>(256) { Version };
        Write(bytes, Count16(declared.Length, "declared elements"));

        foreach ((string element, string[] members, string[] events) in declared)
        {
            Write(bytes, element);
            Write(bytes, members, "members on one element");
            Write(bytes, events, "events on one element");
        }

        Write(bytes, [.. sharedMembers.Distinct().Order(StringComparer.Ordinal)], "shared members");
        Write(bytes, [.. sharedEvents.Distinct().Order(StringComparer.Ordinal)], "shared events");
        Write(bytes, [.. acts.Distinct().Order(StringComparer.Ordinal)], "performed acts");

        return [.. bytes];
    }

    /// <summary>A counted run of names, as a declaration writes them.</summary>
    private static void Write(List<byte> bytes, string[] names, string of)
    {
        Write(bytes, Count16(names.Length, of));

        foreach (string name in names)
        {
            Write(bytes, name);
        }
    }

    /// <summary>
    /// Serializes a standard-environment push: which provider the values are
    /// for - one byte, the closed vocabulary both sides of the repository
    /// spell, see <see cref="Rendering.StateUIEnvironment"/> - then the
    /// same counted value list every channel shares, one value per property
    /// in the order the Swift provider declares them.
    /// </summary>
    internal static byte[] WriteEnvironment(byte domain, params HostValue[] values)
    {
        var bytes = new List<byte>(32);
        bytes.Add(Version);
        bytes.Add(domain);
        bytes.Add(Count8(values.Length, "values in one push"));

        foreach (HostValue value in values)
        {
            Write(bytes, value);
        }

        return [.. bytes];
    }

    /// <summary>
    /// Serializes an act's outcome: the values it returned, which a Swift
    /// <c>try await</c> resumes with - none for a method that returns
    /// nothing.
    /// </summary>
    internal static byte[] WriteReply(params HostValue[] values)
    {
        var bytes = new List<byte>(16);
        bytes.Add(Version);
        bytes.Add(1);
        bytes.Add(Count8(values.Length, "values in one reply"));

        foreach (HostValue value in values)
        {
            Write(bytes, value);
        }

        return [.. bytes];
    }

    /// <summary>
    /// Serializes an act's failure: why it could not be performed, which the
    /// awaiting Swift handler throws as <c>StateUIError</c>.
    /// </summary>
    internal static byte[] WriteFailure(string reason)
    {
        var bytes = new List<byte>(16);
        bytes.Add(Version);
        bytes.Add(0);
        bytes.Add(1);
        Write(bytes, HostValue.Of(reason));
        return [.. bytes];
    }

    /// <summary>One tagged value, the mirror of <c>Reader.Value</c>.</summary>
    private static void Write(List<byte> bytes, HostValue value)
    {
        switch (value.Tag)
        {
            case HostValue.TagFalse:
            case HostValue.TagTrue:
                bytes.Add(value.Tag);
                break;

            case HostValue.TagNumber:
                bytes.Add(value.Tag);
                Write(bytes, value.Number);
                break;

            case HostValue.TagString:
                bytes.Add(value.Tag);
                Write(bytes, value.Text ?? "");
                break;

            case HostValue.TagColor:
                // Four channels, one byte each, so there is no word to agree
                // an endianness for - the shape the tree carries a colour in.
                bytes.Add(value.Tag);
                bytes.Add(value.Red);
                bytes.Add(value.Green);
                bytes.Add(value.Blue);
                bytes.Add(value.Alpha);
                break;

            case HostValue.TagNumbers:
            {
                double[] numbers = value.Numbers ?? [];
                bytes.Add(value.Tag);
                Write(bytes, Count16(numbers.Length, "numbers in one value"));
                foreach (double number in numbers)
                {
                    Write(bytes, number);
                }
                break;
            }

            case HostValue.TagStrings:
            {
                string[] strings = value.Strings ?? [];
                bytes.Add(value.Tag);
                Write(bytes, Count16(strings.Length, "strings in one value"));
                foreach (string text in strings)
                {
                    Write(bytes, text);
                }
                break;
            }

            case HostValue.TagEnumeration:
                // A member of a closed vocabulary the HOST reports - a gesture's
                // status, a battery state, why a navigation happened. Written
                // as OUR number for it, never MAUI's: the caller has already
                // translated MAUI's member onto the mirror, which is the same
                // rule the tree travels by, read backwards. See
                // HostEnums.cs.
                bytes.Add(value.Tag);
                Write(bytes, value.Member);
                break;

            case HostValue.TagValues:
            {
                // A list of them - the connection profiles are the one payload
                // that carries several members at once, and a run of doubles
                // could not say they were members.
                HostValue[] values = value.Values ?? [];
                bytes.Add(value.Tag);
                Write(bytes, Count16(values.Length, "members in one list"));
                foreach (HostValue each in values)
                {
                    Write(bytes, each);
                }
                break;
            }

            case HostValue.TagNothing:
                // No payload: the tag IS the value. A dialog the reader
                // dismissed answers with it, so "no choice" travels in the
                // value rather than in the shape of the reply.
                bytes.Add(value.Tag);
                break;

            default:
                // A name is read here and never written: its number belongs
                // to the session's dictionary, which only Swift assigns, and
                // nothing this side writes carries one.
                throw new InvalidOperationException(
                    $"a value with tag {value.Tag} is not one this side ever writes");
        }
    }

    private static void Write(List<byte> bytes, ushort value)
    {
        Span<byte> scratch = stackalloc byte[2];
        BinaryPrimitives.WriteUInt16LittleEndian(scratch, value);
        bytes.AddRange(scratch);
    }

    /// <summary>
    /// A member's number, four bytes and signed - what an enumeration carries,
    /// and its own overload so that an <c>int</c> can never widen into the
    /// eight bytes of <see cref="Write(List{byte}, double)"/> unnoticed.
    /// </summary>
    private static void Write(List<byte> bytes, int value)
    {
        Span<byte> scratch = stackalloc byte[4];
        BinaryPrimitives.WriteInt32LittleEndian(scratch, value);
        bytes.AddRange(scratch);
    }

    private static void Write(List<byte> bytes, double value)
    {
        Span<byte> scratch = stackalloc byte[8];
        BinaryPrimitives.WriteDoubleLittleEndian(scratch, value);
        bytes.AddRange(scratch);
    }

    /// <summary>A length-prefixed UTF-8 string - nothing escaped.</summary>
    private static void Write(List<byte> bytes, string value)
    {
        byte[] utf8 = Encoding.UTF8.GetBytes(value);
        Span<byte> scratch = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(scratch, (uint)utf8.Length);
        bytes.AddRange(scratch);
        bytes.AddRange(utf8);
    }

    /// <summary>
    /// The walk itself: little-endian, fixed width, every read bounds-checked
    /// so a truncated buffer is a sentence rather than a wrong value.
    /// </summary>
    private ref struct Reader(ReadOnlySpan<byte> bytes)
    {
        private readonly ReadOnlySpan<byte> _bytes = bytes;
        private int _at;

        internal readonly bool AtEnd => _at == _bytes.Length;

        /// <summary>
        /// Refuses unless <paramref name="count"/> more bytes are really
        /// there. Counted as a <see cref="long"/> because the only width the
        /// wire states outright is a string's, and it states it UNSIGNED: a
        /// length that does not fit an int must reach this check as the large
        /// number it is, rather than as the negative one it would become, and
        /// the sum must not be able to wrap either.
        /// </summary>
        private readonly void Need(long count)
        {
            if (count < 0 || _at + count > _bytes.Length)
            {
                throw new InvalidDataException("the batch ends in the middle of a value");
            }
        }

        internal byte U8()
        {
            Need(1);
            return _bytes[_at++];
        }

        internal ushort U16()
        {
            Need(2);
            ushort value = BinaryPrimitives.ReadUInt16LittleEndian(_bytes.Slice(_at, 2));
            _at += 2;
            return value;
        }

        internal int I32()
        {
            Need(4);
            int value = BinaryPrimitives.ReadInt32LittleEndian(_bytes.Slice(_at, 4));
            _at += 4;
            return value;
        }

        internal uint U32()
        {
            Need(4);
            uint value = BinaryPrimitives.ReadUInt32LittleEndian(_bytes.Slice(_at, 4));
            _at += 4;
            return value;
        }

        internal ulong U64()
        {
            Need(8);
            ulong value = BinaryPrimitives.ReadUInt64LittleEndian(_bytes.Slice(_at, 8));
            _at += 8;
            return value;
        }

        internal double F64()
        {
            Need(8);
            double value = BinaryPrimitives.ReadDoubleLittleEndian(_bytes.Slice(_at, 8));
            _at += 8;
            return value;
        }

        internal string Str()
        {
            Need(4);
            uint length = BinaryPrimitives.ReadUInt32LittleEndian(_bytes.Slice(_at, 4));
            _at += 4;

            // Unsigned until it has been bounds-checked. Past this line the
            // length is known to be no larger than what is left of the buffer,
            // so it fits an int and the slice is safe.
            Need(length);

            string value = Encoding.UTF8.GetString(_bytes.Slice(_at, (int)length));
            _at += (int)length;
            return value;
        }

        internal HostValue Value(WireDictionary names, int depth = 0)
        {
            byte tag = U8();
            switch (tag)
            {
                case HostValue.TagFalse:
                case HostValue.TagTrue:
                    return new HostValue(tag);

                case HostValue.TagNumber:
                    return new HostValue(F64());

                case HostValue.TagString:
                    return new HostValue(Str());

                case HostValue.TagNumbers:
                {
                    int count = U16();
                    var numbers = new double[count];
                    for (int i = 0; i < count; i++)
                    {
                        numbers[i] = F64();
                    }
                    return new HostValue(numbers);
                }

                case HostValue.TagStrings:
                {
                    int count = U16();
                    var strings = new string[count];
                    for (int i = 0; i < count; i++)
                    {
                        strings[i] = Str();
                    }
                    return new HostValue(strings);
                }

                case HostValue.TagColor:
                {
                    // Four channels, written out one byte each - so there is
                    // no word to agree an endianness for. Read into locals
                    // rather than into an argument list, where the order
                    // would be the language's promise rather than this
                    // file's.
                    byte red = U8();
                    byte green = U8();
                    byte blue = U8();
                    byte alpha = U8();
                    return new HostValue(red, green, blue, alpha);
                }

                case HostValue.TagValues:
                {
                    if (depth >= MostNesting)
                    {
                        throw new InvalidDataException(
                            $"a value nests deeper than {MostNesting} levels");
                    }

                    int count = U16();
                    var values = new HostValue[count];
                    for (int i = 0; i < count; i++)
                    {
                        values[i] = Value(names, depth + 1);
                    }
                    return new HostValue(values);
                }

                case HostValue.TagNothing:
                    // No payload: the tag IS the value. Every typed accessor
                    // answers null for it, so an absent argument reads exactly
                    // as one that was never sent.
                    return new HostValue(HostValue.TagNothing);

                case HostValue.TagEnumeration:
                    // A member of a closed vocabulary, as THIS REPOSITORY's
                    // number for it. Signed and four bytes wide: room for a
                    // bit set of any width, and for the negative number a
                    // translation answers to say a member is one it cannot
                    // read.
                    return new HostValue(HostValue.TagEnumeration, I32());

                case HostValue.TagName:
                {
                    // A NAME from an open vocabulary - a visual state, a font
                    // family, a radio group - riding the session's dictionary
                    // the way a property key does. Resolved here, so everything
                    // downstream reads the spelling.
                    ushort id = U16();
                    string name = names.Resolve(id)
                        ?? throw new InvalidDataException(
                            $"a value names #{id}, never announced");
                    return new HostValue(HostValue.TagName, name);
                }

                default:
                    throw new InvalidDataException($"unknown value tag {tag}");
            }
        }
    }
}
