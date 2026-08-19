using System.Buffers.Binary;
using System.Text;

namespace StateUI.Runtime.Protocol;

/// <summary>
/// The binary wire format, mirroring <c>Core/Wire.swift</c> byte for byte:
/// this side READS the tree and the acts, and WRITES the other two channels -
/// an act's reply and an event's payload.
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
/// <see cref="SwiftWireDictionary"/>. There is no static table, so there is
/// nothing to be out of step with, and an application's own names ride
/// numbers exactly as the library's do.
/// </para>
/// <para>
/// Anything malformed - a truncated value, a tag this version does not know,
/// an id no message announced - throws <see cref="InvalidDataException"/>,
/// and the caller cashes the receipt so every act in the unreadable batch
/// fails back to its awaiting handler. See
/// <c>StateUISession.PerformCommands</c>.
/// </para>
/// </remarks>
/// 
/// 
internal static partial class SwiftWire
{
    /// <summary>
    /// The format version this runtime reads and writes. Checked against
    /// <c>stateui_wire_version</c> before the first render, and against the
    /// first byte of every message. 2: replies and event payloads became
    /// typed values instead of text. 3: names are numbered per session and
    /// announced by the message that first uses them - the static ledger and
    /// its by-name escape died. 4: the arrangement became the children list
    /// itself - see <see cref="SwiftNode.Arranged"/> - and order, childCount,
    /// removed and the style version died with it. 5: a colour is four bytes
    /// rather than a hex string, a brush is a list of typed values rather
    /// than a list of records, and the theme is resolved before anything is
    /// written - so no value here ever means two colours again. 6: an element
    /// may say that some of its properties are to be WALKED to rather than
    /// assigned - see <see cref="SwiftNode.Transitions"/>. 7: a walk may be
    /// REPORTED as it goes, every entry saying how many milliseconds apart -
    /// see <see cref="SwiftTransition.Report"/>. 8: A STRING IS TEXT SOMEONE
    /// WROTE, and nothing else is one. Every closed vocabulary rides its
    /// member's NUMBER - <see cref="SwiftWireValue.TagEnumeration"/>, this
    /// repository's own number for it, translated onto the MAUI member by name
    /// - every open-vocabulary NAME rides the session's
    /// dictionary like a property key - <see cref="SwiftWireValue.TagName"/> -
    /// and every value with parts rides as its parts. A walk's easing became a
    /// number with them, and NOTHING got a tag of its own -
    /// <see cref="SwiftWireValue.TagNothing"/> - so that an absent argument
    /// stops borrowing an empty string or a -1 to say so. Every one of those
    /// numbers is THIS REPOSITORY's, never MAUI's: see
    /// <see cref="Rendering.SwiftValues"/> for why, and for the mirrors that
    /// translate them.
    /// </summary>
    internal const byte Version = 8;

    /// <summary>Reads a whole render message: the envelope, the names the
    /// message is the first to use, then the tree.</summary>
    internal static SwiftMessage ReadMessage(ReadOnlySpan<byte> bytes, SwiftWireDictionary names)
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
        SwiftNode root = ReadNode(ref reader, names);

        if (!reader.AtEnd)
        {
            throw new InvalidDataException("the message carries bytes past its root");
        }

        return new SwiftMessage { Generation = generation, Complete = complete, Root = root };
    }

    /// <summary>
    /// The head's dictionary section: the names this message is the first in
    /// its session to use. At the head, BEFORE anything that could refer to
    /// them, so a batch that fails later in its bytes has still taught this
    /// side its names.
    /// </summary>
    private static void ReadAnnouncements(ref Reader reader, SwiftWireDictionary names)
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
    /// change", exactly as the JSON wire had it.
    /// </summary>
    private static SwiftNode ReadNode(ref Reader reader, SwiftWireDictionary names)
    {
        // The identity, then the type - this file's promise about the bytes,
        // which an argument list would leave to the language.
        SwiftId id = ReadId(ref reader);
        SwiftWireDictionary.Entry type = ReadName(ref reader, names);

        var node = new SwiftNode
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
                    node.Props = new Dictionary<SwiftProp, SwiftWireValue>(count);

                    for (int i = 0; i < count; i++)
                    {
                        SwiftWireDictionary.Entry key = ReadName(ref reader, names);
                        SwiftWireValue value = reader.Value(names);

                        if (key.Prop != SwiftProp.None)
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
                    node.Events = new Dictionary<SwiftEvent, int>(count);

                    for (int i = 0; i < count; i++)
                    {
                        SwiftWireDictionary.Entry name = ReadName(ref reader, names);
                        int handler = reader.I32();

                        if (name.Event != SwiftEvent.None)
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

                case 6:
                {
                    int count = reader.U16();
                    node.Transitions = new List<SwiftTransition>(count);
                    for (int i = 0; i < count; i++)
                    {
                        // Read into locals rather than into an argument list:
                        // the order of these five is this file's promise about
                        // the bytes, not the language's about its arguments.
                        SwiftWireDictionary.Entry property = ReadName(ref reader, names);
                        uint length = reader.U32();
                        int easing = reader.I32();
                        int channel = reader.I32();
                        uint report = reader.U32();
                        node.Transitions.Add(new SwiftTransition(
                            property.Prop, property.Name, length, easing, channel, report));
                    }
                    break;
                }

                case 4:
                case 5:
                {
                    int count = reader.U16();
                    node.Arranged = field == 5;
                    node.Children = new List<SwiftNode>(count);
                    for (int i = 0; i < count; i++)
                    {
                        node.Children.Add(ReadNode(ref reader, names));
                    }
                    break;
                }

                default:
                    throw new InvalidDataException($"unknown node field {field}");
            }
        }
    }

    /// <summary>An identity, in whichever namespace its tag says.</summary>
    private static SwiftId ReadId(ref Reader reader) => reader.U8() switch
    {
        1 => new SwiftId(reader.I32()),
        2 => new SwiftId(reader.Str()),
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
    private static SwiftWireDictionary.Entry ReadName(ref Reader reader, SwiftWireDictionary names)
    {
        ushort id = reader.U16();

        return names.At(id)
            ?? throw new InvalidDataException($"the message uses name #{id}, never announced");
    }

    /// <summary>Reads a whole batch of acts, announcements first.</summary>
    internal static List<SwiftCommand> ReadCommands(ReadOnlySpan<byte> bytes, SwiftWireDictionary names)
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
        var commands = new List<SwiftCommand>(count);

        for (int i = 0; i < count; i++)
        {
            string name = ReadName(ref reader, names).Name;

            // The name decides the arm ONCE, here - Perform still switches on
            // the enum, and a name it maps to nothing fails in the default
            // arm, or runs what the application registered for it.
            SwiftAct act = SwiftTokenNames<SwiftAct>.Parse(name);

            int completion = reader.I32();
            int argCount = reader.U8();

            var arguments = new List<SwiftWireValue>(argCount);
            for (int a = 0; a < argCount; a++)
            {
                arguments.Add(reader.Value(names));
            }

            commands.Add(new SwiftCommand(act, name, arguments, completion == 0 ? null : completion));
        }

        if (!reader.AtEnd)
        {
            throw new InvalidDataException("the batch carries bytes past its last command");
        }

        return commands;
    }

    // ---- Writing the host's two channels --------------------------------

    /// <summary>
    /// Serializes an event's payload: one typed value per property of the
    /// MAUI EventArgs, in the order MAUI declares them. Answers null for no
    /// values - an event with nothing to say crosses no bytes at all, which
    /// is the common case and allocates nothing.
    /// </summary>
    internal static byte[]? WritePayload(params SwiftWireValue[] values)
    {
        if (values.Length == 0)
        {
            return null;
        }

        var bytes = new List<byte>(16);
        bytes.Add(Version);
        bytes.Add((byte)values.Length);

        foreach (SwiftWireValue value in values)
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
    internal static byte[] WriteHostEvent(string eventName, params SwiftWireValue[] values)
    {
        var bytes = new List<byte>(32);
        bytes.Add(Version);
        Write(bytes, eventName);
        bytes.Add((byte)values.Length);

        foreach (SwiftWireValue value in values)
        {
            Write(bytes, value);
        }

        return [.. bytes];
    }

    /// <summary>
    /// Serializes a standard-environment push: which provider the values are
    /// for - one byte, the closed vocabulary both sides of the repository
    /// spell, see <see cref="Rendering.StateUIEnvironment"/> - then the
    /// same counted value list every channel shares, one value per property
    /// in the order the Swift provider declares them.
    /// </summary>
    internal static byte[] WriteEnvironment(byte domain, params SwiftWireValue[] values)
    {
        var bytes = new List<byte>(32);
        bytes.Add(Version);
        bytes.Add(domain);
        bytes.Add((byte)values.Length);

        foreach (SwiftWireValue value in values)
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
    internal static byte[] WriteReply(params SwiftWireValue[] values)
    {
        var bytes = new List<byte>(16);
        bytes.Add(Version);
        bytes.Add(1);
        bytes.Add((byte)values.Length);

        foreach (SwiftWireValue value in values)
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
        Write(bytes, SwiftWireValue.Of(reason));
        return [.. bytes];
    }

    /// <summary>One tagged value, the mirror of <c>Reader.Value</c>.</summary>
    private static void Write(List<byte> bytes, SwiftWireValue value)
    {
        switch (value.Tag)
        {
            case SwiftWireValue.TagFalse:
            case SwiftWireValue.TagTrue:
                bytes.Add(value.Tag);
                break;

            case SwiftWireValue.TagNumber:
                bytes.Add(value.Tag);
                Write(bytes, value.Number);
                break;

            case SwiftWireValue.TagString:
                bytes.Add(value.Tag);
                Write(bytes, value.Text ?? "");
                break;

            case SwiftWireValue.TagColor:
                // Four channels, one byte each, so there is no word to agree
                // an endianness for - the same shape the tree carries a colour
                // in, which is what lets a stopped flight answer with one.
                bytes.Add(value.Tag);
                bytes.Add(value.Red);
                bytes.Add(value.Green);
                bytes.Add(value.Blue);
                bytes.Add(value.Alpha);
                break;

            case SwiftWireValue.TagNumbers:
            {
                double[] numbers = value.Numbers ?? [];
                bytes.Add(value.Tag);
                Write(bytes, (ushort)numbers.Length);
                foreach (double number in numbers)
                {
                    Write(bytes, number);
                }
                break;
            }

            case SwiftWireValue.TagStrings:
            {
                string[] strings = value.Strings ?? [];
                bytes.Add(value.Tag);
                Write(bytes, (ushort)strings.Length);
                foreach (string text in strings)
                {
                    Write(bytes, text);
                }
                break;
            }

            case SwiftWireValue.TagEnumeration:
                // A member of a closed vocabulary the HOST reports - a gesture's
                // status, a battery state, why a navigation happened. Written
                // as OUR number for it, never MAUI's: the caller has already
                // translated MAUI's member onto the mirror, which is the same
                // rule the tree travels by, read backwards. See
                // SwiftWireEnums.cs.
                bytes.Add(value.Tag);
                Write(bytes, value.Member);
                break;

            case SwiftWireValue.TagValues:
            {
                // A list of them - the connection profiles are the one payload
                // that carries several members at once, and a run of doubles
                // could not say they were members.
                SwiftWireValue[] values = value.Values ?? [];
                bytes.Add(value.Tag);
                Write(bytes, (ushort)values.Length);
                foreach (SwiftWireValue each in values)
                {
                    Write(bytes, each);
                }
                break;
            }

            default:
                // A property token, a name and a nothing are read here and
                // never written: this side answers acts and raises events, and
                // neither carries one.
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

        private readonly void Need(int count)
        {
            if (_at + count > _bytes.Length)
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
            int length = (int)BinaryPrimitives.ReadUInt32LittleEndian(_bytes.Slice(_at, 4));
            _at += 4;
            Need(length);
            string value = Encoding.UTF8.GetString(_bytes.Slice(_at, length));
            _at += length;
            return value;
        }

        internal SwiftWireValue Value(SwiftWireDictionary names)
        {
            byte tag = U8();
            switch (tag)
            {
                case SwiftWireValue.TagFalse:
                case SwiftWireValue.TagTrue:
                    return new SwiftWireValue(tag);

                case SwiftWireValue.TagNumber:
                    return new SwiftWireValue(F64());

                case SwiftWireValue.TagString:
                    return new SwiftWireValue(Str());

                case SwiftWireValue.TagNumbers:
                {
                    int count = U16();
                    var numbers = new double[count];
                    for (int i = 0; i < count; i++)
                    {
                        numbers[i] = F64();
                    }
                    return new SwiftWireValue(numbers);
                }

                case SwiftWireValue.TagStrings:
                {
                    int count = U16();
                    var strings = new string[count];
                    for (int i = 0; i < count; i++)
                    {
                        strings[i] = Str();
                    }
                    return new SwiftWireValue(strings);
                }

                case SwiftWireValue.TagColor:
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
                    return new SwiftWireValue(red, green, blue, alpha);
                }

                case SwiftWireValue.TagValues:
                {
                    int count = U16();
                    var values = new SwiftWireValue[count];
                    for (int i = 0; i < count; i++)
                    {
                        values[i] = Value(names);
                    }
                    return new SwiftWireValue(values);
                }

                case SwiftWireValue.TagNothing:
                    // No payload: the tag IS the value. Every typed accessor
                    // answers null for it, so an absent argument reads exactly
                    // as one that was never sent.
                    return new SwiftWireValue(SwiftWireValue.TagNothing);

                case SwiftWireValue.TagEnumeration:
                    // A member of a closed vocabulary, as its own number.
                    // Signed and four bytes wide because MAUI numbers some of
                    // them negatively - AbsoluteLayoutFlags.All is -1 - and
                    // one of them past a UInt16: SafeAreaRegions.All is 32768.
                    return new SwiftWireValue(SwiftWireValue.TagEnumeration, I32());

                case SwiftWireValue.TagName:
                {
                    // A NAME from an open vocabulary - a style key, a visual
                    // state, a font family - riding the session's dictionary
                    // the way a property key does. Resolved here, so everything
                    // downstream reads the spelling.
                    ushort id = U16();
                    string name = names.Resolve(id)
                        ?? throw new InvalidDataException(
                            $"a value names #{id}, never announced");
                    return new SwiftWireValue(SwiftWireValue.TagName, name);
                }

                default:
                    throw new InvalidDataException($"unknown value tag {tag}");
            }
        }
    }
}

/// <summary>
/// One value as it crossed the wire: a tag and the payload the tag says is
/// there. What a command's argument is made of - see <c>Core/Wire.swift</c>
/// for the tags.
/// </summary>
public readonly struct SwiftWireValue
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
    /// A list of values of any kind - what a structured value travels as when
    /// its parts are not all the same shape. A Brush is the one that needs
    /// it.
    /// </summary>
    internal const byte TagValues = 9;

    /// <summary>
    /// One member of a CLOSED vocabulary, as its own number.
    /// </summary>
    /// <remarks>
    /// The number is THIS REPOSITORY's, declaration order from 0, in BOTH
    /// directions: an <c>internal enum</c> in <c>Protocol/SwiftWireEnums.cs</c>
    /// mirrors every Swift vocabulary member for member, and the translation
    /// onto MAUI's own member is a switch naming it literally. A bit set is one
    /// of these too, carrying our bits from 1&lt;&lt;0. Signed and four bytes
    /// wide: room enough for a bit set of any width, and for the negative
    /// number a translation answers to say a member is one it cannot read.
    /// </remarks>
    internal const byte TagEnumeration = 10;

    /// <summary>
    /// A NAME from an OPEN vocabulary - a style key, a visual state and its
    /// group, a radio group, a font family.
    /// </summary>
    /// <remarks>
    /// Text an author wrote, but a name rather than prose: it repeats across a
    /// tree and means the same thing every time, so it rides the session's
    /// dictionary as its number exactly as a property key does - announced
    /// once, two bytes thereafter - and is resolved back here. Reads as a
    /// string through <see cref="SwiftNode.GetName(string)"/>, which is deliberately
    /// NOT <see cref="SwiftNode.GetString(string)"/>: a name and a piece of text are
    /// different things and this wire keeps them apart.
    /// </remarks>
    internal const byte TagName = 11;

    /// <summary>
    /// NOTHING - a value that is not there, carrying no payload at all.
    /// </summary>
    /// <remarks>
    /// An argument list has no such thing as a field left out, and a value list
    /// no such thing as a gap, so absence needs saying. It replaces three
    /// sentinels that each read as a value someone meant: the empty string for
    /// a dialog's missing cancel, destruction or placeholder caption, the -1
    /// for a missing maximum length, and the empty list for "no day" in
    /// <c>getUtcOffset</c> and "no base url" in a WebView's HTML source. Every
    /// typed accessor answers null for one, which is what makes an absent
    /// argument indistinguishable from a caller that never sent it.
    /// </remarks>
    internal const byte TagNothing = 12;

    internal readonly byte Tag;
    internal readonly double Number;
    internal readonly int Member;
    internal readonly string? Text;
    internal readonly double[]? Numbers;
    internal readonly string[]? Strings;
    internal readonly SwiftWireValue[]? Values;
    internal readonly byte Red;
    internal readonly byte Green;
    internal readonly byte Blue;
    internal readonly byte Alpha;

    internal SwiftWireValue(byte tag) => Tag = tag;

    internal SwiftWireValue(byte red, byte green, byte blue, byte alpha)
    {
        Tag = TagColor;
        Red = red;
        Green = green;
        Blue = blue;
        Alpha = alpha;
    }

    internal SwiftWireValue(SwiftWireValue[] values)
    {
        Tag = TagValues;
        Values = values;
    }

    internal SwiftWireValue(double number)
    {
        Tag = TagNumber;
        Number = number;
    }

    internal SwiftWireValue(string text)
    {
        Tag = TagString;
        Text = text;
    }

    internal SwiftWireValue(byte tag, string text)
    {
        Tag = tag;
        Text = text;
    }

    /// <summary>
    /// A member of a closed vocabulary - the tag says which kind of number it
    /// is, and the number is kept apart from <see cref="Number"/> so that
    /// nothing can read an alignment as a font size.
    /// </summary>
    internal SwiftWireValue(byte tag, int member)
    {
        Tag = tag;
        Member = member;
    }

    internal SwiftWireValue(double[] numbers)
    {
        Tag = TagNumbers;
        Numbers = numbers;
    }

    internal SwiftWireValue(string[] strings)
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
    public static SwiftWireValue Of(string text) => new(text);

    /// <summary>
    /// A QUANTITY - a slider's value, an index, a count. Never a member of a
    /// vocabulary, however int-shaped it looks: that is
    /// <see cref="OfMember(int)"/>.
    /// </summary>
    public static SwiftWireValue Of(double number) => new(number);

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
    /// <c>Protocol/SwiftWireEnums.cs</c> first - never a cast, which would put
    /// MAUI's own number on the wire and leave a MAUI release free to
    /// reinterpret it.
    /// </remarks>
    /// <param name="member">The mirror's member, cast to its number.</param>
    public static SwiftWireValue OfMember(int member) => new(TagEnumeration, member);

    /// <summary>
    /// A list of values of any kind - what several members travel as, there
    /// being no run of them the way there is a run of numbers.
    /// </summary>
    public static SwiftWireValue OfValues(params SwiftWireValue[] values) => new(values);

    /// <summary>True or false - a switch's state, a focus, a can-go-back.</summary>
    public static SwiftWireValue Of(bool value) => new(value ? TagTrue : TagFalse);

    /// <summary>
    /// A list of numbers - a point's pair, a date's three, a frame report's
    /// eight, a selection's positions.
    /// </summary>
    public static SwiftWireValue Of(params double[] numbers) => new(numbers);
}
