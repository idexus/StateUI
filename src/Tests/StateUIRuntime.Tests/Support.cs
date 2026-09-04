// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What every test here needs: a renderer, a message to give it, and a way to
// look at what came out.
using System.Globalization;
using System.Numerics;
using System.Runtime.CompilerServices;
using System.Text.Json;
using Microsoft.Maui.Dispatching;
using Microsoft.Maui.Graphics.Text;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

// ONE CLASS AT A TIME, because these tests drive real MAUI objects and MAUI
// keeps the application in a process-wide static.
//
// xUnit runs test CLASSES in parallel by default. Constructing a MAUI
// `Application` plants it in `Application.Current`, which is exactly where the
// host looks when it opens or closes a window - so a class that constructs one
// has taken the seat from whichever other class was using it, and the failure
// reads as a window opening on the wrong application rather than as a race.
// MultiWindowTests builds a `Platform : Application` in most of its tests and
// ContentPageTests builds another; serializing the classes is what keeps the
// two out of each other's way, and it costs a fraction of a second over the
// whole suite.
//
// Anything else this file reaches that is static per process belongs here too -
// a hazard of this shape is invisible in a green run and only shows up under
// load.
[assembly: CollectionBehavior(DisableTestParallelization = true)]

namespace StateUI.Runtime.Tests;

/// <summary>
/// A dispatcher, because a few MAUI types ask for one the moment they are used.
/// </summary>
/// <remarks>
/// <para>
/// Most of MAUI's controls are ordinary objects that need nothing underneath
/// them, which is what makes these tests possible at all. A handful are not:
/// <c>SearchHandler.ItemsSource</c> reaches for the dispatcher of the thread it
/// is on, and without an application there is none.
/// </para>
/// <para>
/// So one is provided, and it runs everything inline - which is what a test
/// wants anyway: no thread to wait for, no timer to fire.
/// </para>
/// </remarks>
internal static class TestDispatcher
{
    [ModuleInitializer]
    internal static void Install()
    {
        DispatcherProvider.SetCurrent(new Provider());
    }

    private sealed class Provider : IDispatcherProvider
    {
        private readonly Dispatcher _dispatcher = new();

        public IDispatcher? GetForCurrentThread() => _dispatcher;
    }

    /// <summary>
    /// Holds dispatched jobs instead of running them, so a test can see a
    /// DEFERRED report land after the render that caused it.
    /// </summary>
    /// <remarks>
    /// Inline is what every other test wants - a job that runs where it is
    /// dispatched is one less thing to drive. But a report deferred a turn is
    /// the whole point in one place: a control enters Disabled inside a render,
    /// where the renderer answers no events at all, so running the job inline
    /// would drop it exactly as it did before it was deferred. Test classes do
    /// not run in parallel here, so one static is enough.
    /// </remarks>
    internal static Queue<Action>? Held { get; private set; }

    /// <summary>Holds what is dispatched from here on.</summary>
    internal static void Hold() => Held = new Queue<Action>();

    /// <summary>
    /// Runs jobs inline again, dropping anything held.
    /// </summary>
    /// <remarks>
    /// Every test builds a <see cref="Host"/>, and that is where this is
    /// called: a hold is per test, and an assertion failing between
    /// <see cref="Hold"/> and <see cref="Drain"/> would otherwise leave the
    /// static set for every test after it - one real failure, and the ones
    /// behind it fail for a reason that is not theirs.
    /// </remarks>
    internal static void Forget() => Held = null;

    /// <summary>Runs what was held, and goes back to running jobs inline.</summary>
    internal static void Drain()
    {
        Queue<Action> held = Held ?? new Queue<Action>();

        Held = null;

        while (held.Count > 0)
        {
            held.Dequeue()();
        }
    }

    private sealed class Dispatcher : IDispatcher
    {
        public bool IsDispatchRequired => false;

        public bool Dispatch(Action action)
        {
            if (Held is Queue<Action> held)
            {
                held.Enqueue(action);
                return true;
            }

            action();
            return true;
        }

        public bool DispatchDelayed(TimeSpan delay, Action action)
        {
            action();
            return true;
        }

        public IDispatcherTimer CreateTimer() => new Timer();
    }

    /// <summary>A timer that never fires: nothing here waits for one.</summary>
    private sealed class Timer : IDispatcherTimer
    {
        public TimeSpan Interval { get; set; }

        public bool IsRepeating { get; set; }

        public bool IsRunning { get; private set; }

        public event EventHandler? Tick;

        public void Start() => IsRunning = true;

        public void Stop()
        {
            IsRunning = false;
            Tick?.Invoke(this, EventArgs.Empty);
        }
    }
}

/// <summary>
/// A renderer and the events it reported, so a test can apply a message and
/// then ask what the tree became.
/// </summary>
internal sealed class Host
{
    public Host()
    {
        // A hold belongs to the test that took it. Anything still held here is
        // a test that failed before its Drain, and inheriting it would hide
        // every deferral this one means to see.
        TestDispatcher.Forget();

        Renderer = new StateUIRenderer((id, payload, _) =>
        {
            Raw.Add((id, payload));

            // A NEGATIVE id carries a reply rather than an event payload -
            // an awaited movement landing - and the two have different
            // layouts, so only the events are described here. `Raw` is what a
            // reply is read from.
            if (id >= 0)
            {
                Dispatched.Add((id, Describe(payload)));
            }
        });
    }

    public StateUIRenderer Renderer { get; }

    /// <summary>
    /// Every event the tree reported, in order - the payload rendered by
    /// <see cref="Describe"/> so an assert stays one readable tuple.
    /// </summary>
    public List<(int Id, string? Payload)> Dispatched { get; } = [];

    /// <summary>
    /// Every crossing, events and replies alike, with its bytes unread - what
    /// a test asks when the layout is not an event payload's.
    /// </summary>
    public List<(int Id, byte[]? Bytes)> Raw { get; } = [];

    /// <summary>
    /// A payload's bytes, rendered for an assert: null for no payload, and
    /// otherwise one value per property, joined with commas - <c>true</c>,
    /// <c>12.5</c>, <c>"typed"</c> (text quoted, so a bool is never mistaken
    /// for the word), <c>enum 4</c> for a member of a closed vocabulary,
    /// <c>color FF3366CC</c> for four channels alpha-first, and
    /// <c>[2026, 9, 15]</c> for a list of any of them.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Deliberately the TESTS' own reading of the payload channel, decoded by
    /// hand the way the Swift probe decodes what Swift writes: the runtime
    /// only writes payloads, so a second spelling of the layout is what makes
    /// a writer bug a failed assert instead of two halves agreeing on the
    /// same mistake.
    /// </para>
    /// <para>
    /// A member is spelled <c>enum 4</c> rather than <c>4</c> so that a member
    /// and a number are never the same string here. They are different values
    /// on the wire, a handler reads them through different accessors, and a
    /// report that quietly sent one where the other was meant would otherwise
    /// pass every assertion in the suite.
    /// </para>
    /// <para>
    /// A colour is spelled the way the Swift probe spells one in a sidecar -
    /// <c>color</c> and the four channels in hex, alpha first - so the two
    /// readings of one payload can be held side by side, and so a colour is
    /// never the same string as the text <c>"#FF3366CC"</c>.
    /// </para>
    /// <para>
    /// The arms are exactly what <c>SwiftWire.Write</c> can produce: a property
    /// token, a name and a nothing are read by this side and never written by
    /// it, so a tag carrying one is a writer bug and says so.
    /// </para>
    /// </remarks>
    private static string? Describe(byte[]? payload)
    {
        if (payload is null)
        {
            return null;
        }

        int at = 0;
        byte U8() => payload[at++];
        ushort U16() => (ushort)(U8() | U8() << 8);
        int I32() => U16() | U16() << 16;
        double F64()
        {
            double value = BitConverter.ToDouble(payload, at);
            at += 8;
            return value;
        }
        string Str()
        {
            int length = (int)(uint)(U16() | U16() << 16);
            string value = System.Text.Encoding.UTF8.GetString(payload, at, length);
            at += length;
            return value;
        }
        string Number(double value) => value.ToString("R", CultureInfo.InvariantCulture);

        // Four channels in the order they were written - red, green, blue,
        // alpha - spelled alpha first, which is the order a colour is written
        // in everywhere it is read by a person.
        string Colour()
        {
            byte red = U8();
            byte green = U8();
            byte blue = U8();
            byte alpha = U8();
            return $"color {alpha:X2}{red:X2}{green:X2}{blue:X2}";
        }

        // Recursive, because a value list holds values of any kind - the shape
        // several members at once arrive in.
        string One()
        {
            byte tag = U8();

            return tag switch
            {
                1 => "false",
                2 => "true",
                3 => Number(F64()),
                4 => $"\"{Str()}\"",
                5 => "[" + string.Join(", ", Enumerable.Range(0, U16()).Select(_ => Number(F64()))) + "]",
                6 => "[" + string.Join(", ", Enumerable.Range(0, U16()).Select(_ => $"\"{Str()}\"")) + "]",
                8 => Colour(),
                9 => "[" + string.Join(", ", Enumerable.Range(0, U16()).Select(_ => One())) + "]",
                10 => "enum " + I32().ToString(CultureInfo.InvariantCulture),
                _ => throw new InvalidDataException($"unknown payload value tag {tag}"),
            };
        }

        byte version = U8();
        Assert.Equal(SwiftWire.Version, version);

        int count = U8();
        var values = new List<string>(count);

        for (int i = 0; i < count; i++)
        {
            values.Add(One());
        }

        Assert.Equal(payload.Length, at);
        return string.Join(", ", values);
    }

    public View? Current { get; private set; }

    /// <summary>Applies one message, the way StateUIHost does.</summary>
    public View Apply(string json)
    {
        SwiftNode root = Parse(json);
        Current = Renderer.Render(Current, root);
        return Current;
    }

    /// <summary>
    /// This host's wire dictionary, learned from the announcements of every
    /// binary message applied to it - one per host, exactly as the session
    /// keeps one. A SEQUENCE of fixtures teaches it message by message.
    /// </summary>
    internal SwiftWireDictionary Names { get; } = new();

    /// <summary>Applies a whole binary fixture, envelope and all.</summary>
    public View ApplyMessage(byte[] bytes) =>
        ApplyMessage(SwiftWire.ReadMessage(bytes, Names).Root!);

    /// <summary>Applies a whole message written as inline JSON - see <see cref="Parse"/>.</summary>
    public View ApplyMessage(string json) => ApplyMessage(Parse(json));

    internal View ApplyMessage(SwiftNode root)
    {
        // A fixture describes an Application, a Window and a Page above the view
        // tree, the way the real one does; the renderer is given the view.
        SwiftNode node = root;

        while (IsChrome(node))
        {
            node = node.Children is { Count: > 0 } children ? children[0] : node;

            if (!IsChrome(node))
            {
                break;
            }
        }

        Current = Renderer.Render(Current, node);
        return Current;
    }

    /// <summary>The three the renderer is never handed: it is given the view.</summary>
    private static bool IsChrome(SwiftNode node) =>
        node.Type is SwiftNodeType.Application or SwiftNodeType.Window or SwiftNodeType.ContentPage;

    /// <summary>
    /// A window with a Swift application behind it, the way the platform makes
    /// one - and its OWN application, never the process-wide
    /// <c>StateUIApplication.Current</c>: one test's windows have no business
    /// in the next test's list.
    /// </summary>
    public static StateUIWindow Window() => new(new StateUIApplication());

    /// <summary>
    /// An application node around one window's JSON - what a message is rooted
    /// in, so that a test can hand a window's description to a target that
    /// takes the root.
    /// </summary>
    public static string Application(string window) =>
        $$"""{"id":9,"type":"Application","arranged":true,"children":[{{window}}]}""";

    /// <summary>
    /// Every word of text under an element, joined - how a test reads the
    /// diagnostic shown in place of an interface.
    /// </summary>
    public static string TextOf(Element? element)
    {
        if (element is null)
        {
            return "";
        }

        var text = new List<string>();

        void Walk(Element node)
        {
            if (node is Label label && label.Text is string words)
            {
                text.Add(words);
            }

            foreach (Element child in ((IElementController)node).LogicalChildren)
            {
                Walk(child);
            }
        }

        Walk(element);
        return string.Join("\n", text);
    }

    /// <summary>
    /// The root of a SELF-CONTAINED binary fixture - one that announces every
    /// name it uses, which is what a fresh dictionary per file checks. A
    /// fixture from a sequence goes through a host's <see cref="ApplyMessage(byte[])"/>.
    /// </summary>
    public static SwiftNode Parse(byte[] bytes) =>
        SwiftWire.ReadMessage(bytes, new SwiftWireDictionary()).Root!;

    /// <summary>
    /// A node written as JSON - the AUTHORING notation the tests keep, because
    /// an inline tree is worth reading. The wire itself is binary; this bridge
    /// exists on the test side only, translating the notation into the same
    /// <see cref="SwiftNode"/> the reader produces.
    /// </summary>
    public static SwiftNode Parse(string json)
    {
        using JsonDocument document = JsonDocument.Parse(json);
        JsonElement root = document.RootElement;

        if (root.TryGetProperty("root", out JsonElement wrapped))
        {
            root = wrapped;
        }

        return NodeFrom(root);
    }

    private static SwiftNode NodeFrom(JsonElement element)
    {
        var node = new SwiftNode();

        if (element.TryGetProperty("id", out JsonElement id))
        {
            node.Id = IdFrom(id);
        }

        // The notation writes NAMES, as the wire's announcements do - so this is
        // where they meet their members, the one place a test side has to and
        // the reason the ~147 call sites go on reading as they always did. A
        // name with no member is an application's own and lands in the string
        // bag, exactly as the reader puts it there.
        if (element.TryGetProperty("type", out JsonElement type))
        {
            node.TypeName = type.GetString() ?? "";
            node.Type = SwiftTokenNames<SwiftNodeType>.Parse(node.TypeName);
        }

        if (element.TryGetProperty("replace", out JsonElement replace))
        {
            node.Replace = replace.ValueKind == JsonValueKind.True;
        }

        if (element.TryGetProperty("props", out JsonElement props))
        {
            node.Props = [];
            foreach (JsonProperty property in props.EnumerateObject())
            {
                SwiftProp key = SwiftTokenNames<SwiftProp>.Parse(property.Name);

                if (key != SwiftProp.None)
                {
                    node.Props[key] = ValueFrom(property.Value);
                }
                else
                {
                    (node.OwnProps ??= [])[property.Name] = ValueFrom(property.Value);
                }
            }
        }

        // The keys the element has STOPPED describing, written as the names
        // they are - `"cleared":["fontSize"]` - since there is no value to
        // give one.
        if (element.TryGetProperty("cleared", out JsonElement cleared))
        {
            node.Cleared =
            [
                .. cleared.EnumerateArray().Select(key => SwiftKey.Own(key.GetString() ?? "")),
            ];
        }

        if (element.TryGetProperty("events", out JsonElement events))
        {
            node.Events = [];
            foreach (JsonProperty handler in events.EnumerateObject())
            {
                SwiftEvent raised = SwiftTokenNames<SwiftEvent>.Parse(handler.Name);

                if (raised != SwiftEvent.None)
                {
                    node.Events[raised] = handler.Value.GetInt32();
                }
                else
                {
                    (node.OwnEvents ??= [])[handler.Name] = handler.Value.GetInt32();
                }
            }
        }

        // Whether this element's children are rows a pool is kept for, and -
        // one level down - what one row LOOKS like, as the number the Swift
        // side works out. Written here as a plain number, since these tests
        // care only that two rows carry the same one or different ones.
        if (element.TryGetProperty("recycles", out JsonElement recycles))
        {
            node.Recycles = recycles.ValueKind == JsonValueKind.True;
        }

        if (element.TryGetProperty("shape", out JsonElement shape))
        {
            node.Shape = shape.GetUInt64();
        }

        if (element.TryGetProperty("arranged", out JsonElement arranged))
        {
            // The arranged form: children is the COMPLETE list, in order -
            // possibly empty, which is how an element that lost its last
            // child says so.
            node.Arranged = arranged.ValueKind == JsonValueKind.True;
            node.Children ??= [];
        }

        if (element.TryGetProperty("children", out JsonElement children))
        {
            node.Children = [.. children.EnumerateArray().Select(NodeFrom)];
        }

        return node;
    }

    private static SwiftId IdFrom(JsonElement id) =>
        id.ValueKind == JsonValueKind.String
            ? new SwiftId(id.GetString() ?? "")
            : new SwiftId(id.GetInt32());

    /// <summary>
    /// One member of a closed vocabulary, written the way the notation spells
    /// one: <c>{"enum":4}</c>.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Takes the MIRROR MEMBER rather than a number, so a test reads
    /// <c>Member(SwiftLineBreakMode.TailTruncation)</c> and never a bare 4 -
    /// which in a JSON blob says nothing about which member it is, or even
    /// which vocabulary. A bit set is the members ORed, since that is one
    /// number too.
    /// </para>
    /// <para>
    /// Built by hand rather than in a raw interpolated string of its own: the
    /// spelling ends in a brace, and an interpolation hole ending in one more
    /// than the delimiter takes is where the compiler stops being able to tell
    /// them apart.
    /// </para>
    /// <para>
    /// The trap for a caller: JSON's own <c>}}</c> is a run of two, so a blob
    /// holding one of these is written <c>$$$"""…{{{Member(…)}}}…"""</c> - three
    /// dollars, so that a run of two braces is content and only three close a
    /// hole.
    /// </para>
    /// </remarks>
    /// <typeparam name="T">The mirror enum in <c>Protocol/SwiftWireEnums.cs</c>.</typeparam>
    /// <param name="member">The member, or the OR of several for a bit set.</param>
    /// <returns>The notation's spelling of that member.</returns>
    public static string Member<T>(T member)
        where T : struct, Enum =>
        "{\"enum\":" +
        Convert.ToInt32(member, CultureInfo.InvariantCulture)
            .ToString(CultureInfo.InvariantCulture) +
        "}";

    /// <summary>
    /// One VALUE written as JSON - the same authoring notation
    /// <see cref="Parse(string)"/> reads, for a test that builds a value alone.
    /// </summary>
    public static SwiftWireValue Value(string json)
    {
        using JsonDocument document = JsonDocument.Parse(json);
        return ValueFrom(document.RootElement);
    }

    private static SwiftWireValue ValueFrom(JsonElement value) => value.ValueKind switch
    {
        // "#RRGGBB" is a COLOUR in this notation, the way [1,2,3,4] is a
        // Thickness - the wire carries four bytes of its own and has no
        // spelling for one, so the tests need a way to write what they mean.
        JsonValueKind.String when Colour(value.GetString()) is SwiftWireValue colour => colour,

        JsonValueKind.String => new SwiftWireValue(value.GetString() ?? ""),
        JsonValueKind.Number => new SwiftWireValue(value.GetDouble()),
        JsonValueKind.True => new SwiftWireValue(SwiftWireValue.TagTrue),
        JsonValueKind.False => new SwiftWireValue(SwiftWireValue.TagFalse),
        // An EMPTY array reads as strings: the one empty list a test writes
        // is a list of ids, and the binary wire's tag would have said so.
        JsonValueKind.Array when value.GetArrayLength() > 0 && value.EnumerateArray().All(
            item => item.ValueKind == JsonValueKind.Number) =>
            new SwiftWireValue([.. value.EnumerateArray().Select(item => item.GetDouble())]),
        JsonValueKind.Array when value.EnumerateArray().All(
            item => item.ValueKind == JsonValueKind.String) =>
            new SwiftWireValue([.. value.EnumerateArray().Select(item => item.GetString() ?? "")]),

        // Anything else in an array is a list of VALUES of mixed kinds, which
        // is what a brush travels as, and every value made of parts: a grid's
        // lengths, a stroke shape, a WebView's source, a drawing.
        JsonValueKind.Array => new SwiftWireValue(
            [.. value.EnumerateArray().Select(ValueFrom)]),

        // {"enum": 4} is a member of a closed vocabulary and {"name": "Row"} is
        // a name from an open one. Neither has a JSON spelling of its own, and
        // both are DIFFERENT from a number and a string on this wire - so the
        // notation has to be able to say it, or a test could only write values
        // the wire does not carry.
        JsonValueKind.Object when value.TryGetProperty("enum", out JsonElement member) =>
            new SwiftWireValue(SwiftWireValue.TagEnumeration, member.GetInt32()),
        JsonValueKind.Object when value.TryGetProperty("name", out JsonElement name) =>
            new SwiftWireValue(SwiftWireValue.TagName, name.GetString() ?? ""),

        // JSON null is the wire's own NOTHING - an argument or a list element
        // that is not there. It answers null from every accessor, which is what
        // an absent value has to do.
        _ => new SwiftWireValue(SwiftWireValue.TagNothing),
    };

    /// <summary>
    /// A colour value from "#RGB", "#ARGB", "#RRGGBB" or "#AARRGGBB", or null
    /// when the text is not one - the same four lengths Types/Color.swift
    /// reads, since this notation stands in for what Swift would have written.
    /// </summary>
    private static SwiftWireValue? Colour(string? text)
    {
        if (text is null || !text.StartsWith('#'))
        {
            return null;
        }

        string digits = text[1..];
        if (!digits.All(Uri.IsHexDigit))
        {
            return null;
        }

        // The shorthand forms double each digit, exactly as the Swift side
        // reads them.
        string full = digits.Length switch
        {
            3 => "FF" + Doubled(digits),
            4 => Doubled(digits),
            6 => "FF" + digits,
            8 => digits,
            _ => "",
        };

        if (full.Length != 8)
        {
            return null;
        }

        byte Channel(int at) => Convert.ToByte(full.Substring(at, 2), 16);

        return new SwiftWireValue(Channel(2), Channel(4), Channel(6), Channel(0));
    }

    /// <summary>Each digit written twice - the hex shorthand, expanded.</summary>
    private static string Doubled(string digits) =>
        string.Concat(digits.Select(digit => new string(digit, 2)));
}

/// <summary>
/// The files the Swift tests write and these read.
/// </summary>
internal static class Fixtures
{
    /// <summary>`src/Tests/fixtures`, found by walking up from the test assembly.</summary>
    public static string Directory => Found.Value;

    /// <summary>
    /// `src/Tests/StateUIRuntime.Tests`, beside the fixtures - what a guard
    /// that reads the tests THEMSELVES walks.
    /// </summary>
    public static string TestsDirectory =>
        Path.Combine(
            System.IO.Directory.GetParent(Directory)!.FullName, "StateUIRuntime.Tests");

    /// <summary>A fixture, by name - `first-render.bin`, `commands/Focus.bin`.</summary>
    public static byte[] ReadBytes(string name) =>
        File.ReadAllBytes(Path.Combine(Directory, name));

    private static readonly Lazy<string> Found = new(() =>
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);

        while (directory is not null)
        {
            string candidate = Path.Combine(directory.FullName, "fixtures");

            if (System.IO.Directory.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException(
            "src/Tests/fixtures was not found above " + AppContext.BaseDirectory);
    });
}

internal static class Tree
{
    /// <summary>Every control under one, itself included.</summary>
    public static IEnumerable<Element> All(Element element)
    {
        yield return element;

        IEnumerable<Element> children = element switch
        {
            ContentPage page => page.Content is null ? [] : [page.Content],
            Border border => border.Content is null ? [] : [border.Content],
            ContentView view => view.Content is null ? [] : [view.Content],
            ScrollView scroll => scroll.Content is null ? [] : [scroll.Content],
            Layout layout => layout.Children.OfType<Element>(),
            ItemsView items => (items.ItemsSource as IEnumerable<View>)?.Cast<Element>() ?? [],
            _ => [],
        };

        foreach (Element child in children)
        {
            foreach (Element descendant in All(child))
            {
                yield return descendant;
            }
        }
    }

    public static IEnumerable<T> OfType<T>(Element root) => All(root).OfType<T>();

    public static List<string> Texts(Element root) =>
        All(root).OfType<Label>().Select(l => l.Text ?? "").ToList();

    /// <summary>
    /// The identity a control carries, read from the renderer's one source of
    /// truth - the attached element - in its matched spelling: a
    /// renderer-assigned <c>12</c> reads as <c>12</c>, an author's
    /// <c>.id("12")</c> as <c>"12"</c>.
    /// </summary>
    public static string? Identity(Element element) =>
        StateUIRenderer.KeyOf(element);
}

/// <summary>
/// A canvas that writes down what it was told to draw.
/// </summary>
/// <remarks>
/// <para>
/// The other half of the check a drawing needs. A <c>SwiftDrawable</c> replays
/// the instructions the Swift side sent, and a record it does not recognize is
/// SKIPPED - the same answer an unrecognized property gets, and just as silent.
/// So a test that only compared the strings would prove nothing about the
/// replay; this one draws on a canvas that counts.
/// </para>
/// <para>
/// Every member of ICanvas is here because the interface asks for it. What is
/// not written down is what no drawing produces, and adding a record to
/// <see cref="Calls"/> is all it would take.
/// </para>
/// </remarks>
internal sealed class CountingCanvas : ICanvas
{
    /// <summary>What the drawable asked for, in order.</summary>
    public List<string> Calls { get; } = [];

    private static string N(float value) => value.ToString(CultureInfo.InvariantCulture);

    public float DisplayScale { get; set; } = 1;

    public float StrokeSize { set => Calls.Add($"StrokeSize={N(value)}"); }

    public float MiterLimit { set => Calls.Add($"MiterLimit={N(value)}"); }

    public Color StrokeColor { set => Calls.Add($"StrokeColor={value?.ToHex()}"); }

    public LineCap StrokeLineCap { set => Calls.Add($"StrokeLineCap={value}"); }

    public LineJoin StrokeLineJoin { set => Calls.Add($"StrokeLineJoin={value}"); }

    public float[] StrokeDashPattern { set => Calls.Add("StrokeDashPattern"); }

    public float StrokeDashOffset { set => Calls.Add($"StrokeDashOffset={N(value)}"); }

    public Color FillColor { set => Calls.Add($"FillColor={value?.ToHex()}"); }

    public Color FontColor { set => Calls.Add($"FontColor={value?.ToHex()}"); }

    public IFont Font { set => Calls.Add("Font"); }

    public float FontSize { set => Calls.Add($"FontSize={N(value)}"); }

    public float Alpha { set => Calls.Add($"Alpha={N(value)}"); }

    public bool Antialias { set => Calls.Add($"Antialias={value}"); }

    public BlendMode BlendMode { set => Calls.Add($"BlendMode={value}"); }

    public void DrawPath(PathF path) => Calls.Add("DrawPath");

    public void FillPath(PathF path, WindingMode windingMode) => Calls.Add("FillPath");

    public void SubtractFromClip(float x, float y, float width, float height) => Calls.Add("SubtractFromClip");

    public void ClipPath(PathF path, WindingMode windingMode = WindingMode.NonZero) => Calls.Add("ClipPath");

    public void ClipRectangle(float x, float y, float width, float height) => Calls.Add("ClipRectangle");

    public void DrawLine(float x1, float y1, float x2, float y2) =>
        Calls.Add($"DrawLine({N(x1)},{N(y1)},{N(x2)},{N(y2)})");

    public void DrawArc(float x, float y, float width, float height,
        float startAngle, float endAngle, bool clockwise, bool closed) =>
        Calls.Add($"DrawArc({N(x)},{N(y)},{N(width)},{N(height)},{N(startAngle)},{N(endAngle)},{clockwise},{closed})");

    public void FillArc(float x, float y, float width, float height,
        float startAngle, float endAngle, bool clockwise) =>
        Calls.Add($"FillArc({N(x)},{N(y)},{N(width)},{N(height)},{N(startAngle)},{N(endAngle)},{clockwise})");

    public void DrawRectangle(float x, float y, float width, float height) =>
        Calls.Add($"DrawRectangle({N(x)},{N(y)},{N(width)},{N(height)})");

    public void FillRectangle(float x, float y, float width, float height) =>
        Calls.Add($"FillRectangle({N(x)},{N(y)},{N(width)},{N(height)})");

    public void DrawRoundedRectangle(float x, float y, float width, float height, float cornerRadius) =>
        Calls.Add($"DrawRoundedRectangle({N(x)},{N(y)},{N(width)},{N(height)},{N(cornerRadius)})");

    public void FillRoundedRectangle(float x, float y, float width, float height, float cornerRadius) =>
        Calls.Add($"FillRoundedRectangle({N(x)},{N(y)},{N(width)},{N(height)},{N(cornerRadius)})");

    public void DrawEllipse(float x, float y, float width, float height) =>
        Calls.Add($"DrawEllipse({N(x)},{N(y)},{N(width)},{N(height)})");

    public void FillEllipse(float x, float y, float width, float height) =>
        Calls.Add($"FillEllipse({N(x)},{N(y)},{N(width)},{N(height)})");

    public void DrawString(string value, float x, float y, HorizontalAlignment horizontalAlignment) =>
        Calls.Add($"DrawString({value},{N(x)},{N(y)},{horizontalAlignment})");

    public void DrawString(string value, float x, float y, float width, float height,
        HorizontalAlignment horizontalAlignment, VerticalAlignment verticalAlignment,
        TextFlow textFlow = TextFlow.ClipBounds, float lineSpacingAdjustment = 0) =>
        Calls.Add($"DrawString({value},{N(x)},{N(y)},{N(width)},{N(height)}," +
            $"{horizontalAlignment},{verticalAlignment})");

    public void DrawText(IAttributedText value, float x, float y, float width, float height) =>
        Calls.Add("DrawText");

    public void Rotate(float degrees, float x, float y) => Calls.Add($"Rotate({N(degrees)},{N(x)},{N(y)})");

    public void Rotate(float degrees) => Calls.Add($"Rotate({N(degrees)})");

    public void Scale(float sx, float sy) => Calls.Add($"Scale({N(sx)},{N(sy)})");

    public void Translate(float tx, float ty) => Calls.Add($"Translate({N(tx)},{N(ty)})");

    public void ConcatenateTransform(Matrix3x2 transform) => Calls.Add("ConcatenateTransform");

    public void SaveState() => Calls.Add("SaveState");

    public bool RestoreState()
    {
        Calls.Add("RestoreState");
        return true;
    }

    public void ResetState() => Calls.Add("ResetState");

    public void SetShadow(SizeF offset, float blur, Color color) => Calls.Add("SetShadow");

    public void SetFillPaint(Paint paint, RectF rectangle) => Calls.Add("SetFillPaint");

    // The graphics one, not MAUI's own IImage: both are in scope and only one
    // of them is what a canvas draws.
    public void DrawImage(Microsoft.Maui.Graphics.IImage image, float x, float y, float width, float height) =>
        Calls.Add("DrawImage");

    public SizeF GetStringSize(string value, IFont font, float fontSize) => SizeF.Zero;

    public SizeF GetStringSize(string value, IFont font, float fontSize,
        HorizontalAlignment horizontalAlignment, VerticalAlignment verticalAlignment) => SizeF.Zero;
}
