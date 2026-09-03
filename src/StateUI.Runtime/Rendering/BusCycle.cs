// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;
using StateUI.Runtime.Interop;
using StateUI.Runtime.Protocol;

/// <summary>Why a cycle is being run.</summary>
internal enum BusReason : byte
{
    /// <summary>The display is about to draw. Every tick, and the ordinary case.</summary>
    Frame = 0,

    /// <summary>
    /// Something was drained - a report landed, a handler wrote a value - and
    /// there may be nothing else about to make a frame.
    /// </summary>
    Drained = 1,

    /// <summary>
    /// A message registered or replaced a bus, so the engines it armed have a
    /// picture to work out before anything is drawn.
    /// </summary>
    Registered = 2,

    /// <summary>A value the platform reports has moved.</summary>
    Told = 3,
}

/// <summary>
/// The far end of the Swift side's image: one call in, one cycle, one call
/// out.
/// </summary>
/// <remarks>
/// A seam rather than a set of P/Invokes so that the tests can wind the whole
/// thing by hand - the cycle is a pure function over there, and a stub that
/// records what crossed is what makes it one over here too.
/// </remarks>
internal interface IBusCrossing
{
    /// <summary>Takes a batch of writes into the image.</summary>
    /// <param name="batch">The bytes, in the layout NativeMethods describes.</param>
    /// <returns>How many buses were written, or -1 for bytes that could not be read.</returns>
    int Write(ReadOnlySpan<byte> batch);

    /// <summary>Runs one cycle.</summary>
    /// <param name="sync">Which board.</param>
    /// <param name="now">The instant, in milliseconds.</param>
    /// <param name="reducesMotion">Whether the reader asked for less movement.</param>
    /// <returns>
    /// How many buses have lanes waiting, with <c>0x4000_0000</c> set while
    /// any engine says it has more to do.
    /// </returns>
    int Cycle(int sync, double now, bool reducesMotion);

    /// <summary>Reads out what a cycle wrote.</summary>
    /// <param name="bus">Which bus, or 0 for every one with lanes waiting.</param>
    /// <param name="into">Where to write.</param>
    /// <returns>How many bytes were written, 0 for a bus that has gone, -1 for no room.</returns>
    int Read(int bus, Span<byte> into);

    /// <summary>Whether anything at all is waiting for a cycle.</summary>
    /// <returns>How many boards have something waiting.</returns>
    int Awake();

    /// <summary>The last cycle, as one line, or null where nothing answers.</summary>
    /// <returns>The line.</returns>
    string? Trace();
}

/// <summary>The crossing itself, over the Swift exports.</summary>
/// <remarks>
/// EVERY CALL IS BEHIND THE SAME QUESTION the rest of this runtime asks before
/// it enters Swift: whether there is a Swift half at all. A build with no
/// module - the tests, and a host that never registered an application -
/// answers as an empty image does, which is what "nothing is moving" means.
/// </remarks>
internal sealed class NativeBusCrossing : IBusCrossing
{
    /// <summary>Whether there is a Swift half to talk to.</summary>
    private static bool Live => StateUISession.RegisterApp is not null;

    /// <inheritdoc/>
    public unsafe int Write(ReadOnlySpan<byte> batch)
    {
        if (!Live)
        {
            return 0;
        }

        fixed (byte* bytes = batch)
        {
            return NativeMethods.BusWrite(bytes, batch.Length);
        }
    }

    /// <inheritdoc/>
    public int Cycle(int sync, double now, bool reducesMotion) =>
        Live ? NativeMethods.BusCycleRun(sync, now, reducesMotion ? 1 : 0) : 0;

    /// <inheritdoc/>
    public unsafe int Read(int bus, Span<byte> into)
    {
        if (!Live)
        {
            return 0;
        }

        fixed (byte* bytes = into)
        {
            return NativeMethods.BusRead(bus, bytes, into.Length);
        }
    }

    /// <inheritdoc/>
    public int Awake() => Live ? NativeMethods.BusAwake() : 0;

    /// <inheritdoc/>
    public string? Trace() => Live ? NativeMethods.TakeString(NativeMethods.CycleTrace()) : null;
}

/// <summary>
/// A crossing a test winds by hand: it records every call and answers scripted
/// bytes.
/// </summary>
/// <remarks>
/// It reimplements NOTHING - there is no image here, no engine order and no
/// arithmetic, because all of that is asserted on the Swift side where it
/// lives. What this holds up is the HOST's half: that a report is written
/// before the cycle runs, that what a cycle answers is worn by the right
/// property, and that one frame is one cycle.
/// </remarks>
internal sealed class HandBusCrossing : IBusCrossing
{
    /// <summary>Every batch this side wrote, in the order it wrote them.</summary>
    internal List<byte[]> Written { get; } = [];

    /// <summary>Every cycle asked for: which board, when, and whether reduced.</summary>
    internal List<(int Sync, double Now, bool Reduced)> Cycles { get; } = [];

    /// <summary>What the next cycle answers.</summary>
    internal int Answers { get; set; }

    /// <summary>
    /// What the next read of every dirty bus answers, as a batch.
    /// </summary>
    /// <remarks>
    /// TAKEN, not kept: a read clears the lanes it answered over there, so a
    /// stub that went on answering the same bytes would have every frame
    /// re-aim a journey the last one started - which is not a thing the real
    /// crossing can do.
    /// </remarks>
    internal byte[] Dirty { get; set; } = [];

    /// <summary>What a read of one bus answers, by number.</summary>
    internal Dictionary<int, byte[]> Whole { get; } = [];

    /// <summary>What <see cref="Awake"/> answers.</summary>
    internal int Waiting { get; set; }

    /// <inheritdoc/>
    public int Write(ReadOnlySpan<byte> batch)
    {
        Written.Add(batch.ToArray());
        return 1;
    }

    /// <inheritdoc/>
    public int Cycle(int sync, double now, bool reducesMotion)
    {
        Cycles.Add((sync, now, reducesMotion));
        return Answers;
    }

    /// <inheritdoc/>
    public int Read(int bus, Span<byte> into)
    {
        byte[] answer = bus == 0 ? Dirty : Whole.GetValueOrDefault(bus, []);

        if (answer.Length == 0)
        {
            return 0;
        }

        if (answer.Length > into.Length)
        {
            return -1;
        }

        answer.CopyTo(into);

        if (bus == 0)
        {
            Dirty = [];
        }

        return answer.Length;
    }

    /// <inheritdoc/>
    public int Awake() => Waiting;

    /// <inheritdoc/>
    public string? Trace() => null;
}

/// <summary>
/// One sync's cycle, as this side runs it: what the platform has to say, then
/// the arithmetic, then what to write onto the controls.
/// </summary>
/// <remarks>
/// <para>
/// THREE PHASES, ONE ORDER, ONCE A FRAME. Everything the platform reported
/// goes in first, in the order it arrived; the Swift side then runs every
/// engine that has a reason to; and what those engines wrote comes back and is
/// written onto the controls. Nothing in the middle can see a value change
/// under it, which is what makes a run of frames reproducible.
/// </para>
/// <para>
/// A property with a bus behind it is moved by the SAME engine that moves
/// everything else here - the channel is the ordinary (control, property) one
/// - so every guard the motion engine already has sees a bus-driven motion
/// exactly as it sees a state-driven one.
/// </para>
/// </remarks>
internal sealed class BusCycle
{
    /// <summary>How much room a read is given before it asks for more.</summary>
    private const int Room = 4096;

    private readonly MotionEngine _engine;
    private readonly Action<int, bool> _land;
    private readonly int _sync;

    /// <summary>Every tie, by the bus it rides on - one bus may drive several.</summary>
    private readonly Dictionary<int, List<BusTie>> _byBus = [];

    /// <summary>And by the control, which is how a host writer asks about one.</summary>
    private readonly ConditionalWeakTable<BindableObject, Dictionary<SwiftKey, BusTie>> _byView = new();

    /// <summary>What a cycle reads into, kept rather than made per frame.</summary>
    private byte[] _buffer = new byte[Room];

    private bool _cycling;
    private bool _inFrame;

    /// <summary>Whether a message is being applied, which defers every cycle.</summary>
    internal Func<bool>? Held { get; set; }

    /// <summary>
    /// One cycle over one board.
    /// </summary>
    /// <param name="engine">What moves the values.</param>
    /// <param name="crossing">The far end of the image.</param>
    /// <param name="land">Told a completion is done, and whether it finished.</param>
    /// <param name="sync">Which board.</param>
    internal BusCycle(
        MotionEngine engine,
        IBusCrossing crossing,
        Action<int, bool> land,
        int sync = 0)
    {
        _engine = engine;
        Crossing = crossing;
        _land = land;
        _sync = sync;
    }

    /// <summary>
    /// The far end of the image. Settable so a test can wind the whole cycle
    /// by hand, which an application never needs to.
    /// </summary>
    internal IBusCrossing Crossing { get; set; }

    /// <summary>
    /// Ties this control's properties to their buses, forgetting whatever it
    /// was tied to before.
    /// </summary>
    /// <remarks>
    /// THE VALUE IS LANDED AT ONCE, before anything is drawn: the bus is read
    /// whole - where the value is AND where it is going - and the property
    /// snapped to where the value stands, so a control born under a bus is
    /// already showing what the bus says rather than what its default was.
    /// A setpoint that differs is then aimed at in the ordinary way.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="node">
    /// The element as the message describes it - its registrations, and the
    /// type that resolves each property the way a style setter is resolved.
    /// </param>
    internal void Register(BindableObject view, SwiftNode node)
    {
        Detach(view);

        if (node.Buses is not { Count: > 0 } entries)
        {
            return;
        }

        Dictionary<SwiftKey, BusTie> tied = [];

        foreach (SwiftBusEntry entry in entries)
        {
            if (BusTie.Of(view, entry, node.Type, node.TypeName) is not BusTie tie)
            {
                continue;
            }

            tied[entry.Key] = tie;

            if (!_byBus.TryGetValue(entry.Bus, out List<BusTie>? riding))
            {
                _byBus[entry.Bus] = riding = [];
            }

            riding.Add(tie);

            // READ WHOLE, and landed before anything is drawn: the value AND
            // where it is going, so a control born under a bus shows what the
            // bus says rather than what its own default was.
            int read = Crossing.Read(entry.Bus, _buffer);

            if (read > 0 && BusBatch.Read(_buffer.AsSpan(0, read)) is [(_, _, byte[] bytes)])
            {
                tie.Landed(bytes, _engine);
            }
        }

        if (tied.Count > 0)
        {
            _byView.AddOrUpdate(view, tied);
        }
    }

    /// <summary>What this control's properties are tied to, if anything.</summary>
    /// <param name="view">The control.</param>
    /// <returns>The ties, by property.</returns>
    internal IReadOnlyDictionary<SwiftKey, BusTie> Registered(BindableObject view) =>
        _byView.TryGetValue(view, out Dictionary<SwiftKey, BusTie>? tied)
            ? tied
            : new Dictionary<SwiftKey, BusTie>();

    /// <summary>
    /// The tie one property of one control has, or null where it has none.
    /// </summary>
    /// <remarks>
    /// The one question every host writer asks before it decides a resting
    /// value for itself: a property a bus is driving has its resting value on
    /// the bus, and a visual state leaving, a hidden view coming back or a
    /// cleared property must land THAT rather than what the tree last said.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <returns>The tie, or null.</returns>
    internal BusTie? Sink(BindableObject view, BindableProperty property)
    {
        if (!_byView.TryGetValue(view, out Dictionary<SwiftKey, BusTie>? tied))
        {
            return null;
        }

        foreach (BusTie tie in tied.Values)
        {
            if (tie.Property == property)
            {
                return tie;
            }
        }

        return null;
    }

    /// <summary>
    /// Forgets everything this control was tied to, and ends whatever was
    /// moving one of its bus-driven properties.
    /// </summary>
    /// <param name="view">The control.</param>
    internal void Detach(BindableObject view)
    {
        if (!_byView.TryGetValue(view, out Dictionary<SwiftKey, BusTie>? tied))
        {
            return;
        }

        foreach (BusTie tie in tied.Values)
        {
            if (_byBus.TryGetValue(tie.Bus, out List<BusTie>? riding))
            {
                riding.Remove(tie);

                if (riding.Count == 0)
                {
                    _byBus.Remove(tie.Bus);
                }
            }

            // A motion on a property nothing reads any more is a motion whose
            // waiter would never hear: halted, so the answer goes out false.
            if (tie.Property is not null)
            {
                _engine.Halt(view, tie.Property, MotionEnd.Nothing);
            }
        }

        _byView.Remove(view);
    }

    /// <summary>
    /// Whether nothing is waiting for a frame - what the engine asks before it
    /// stops the clock.
    /// </summary>
    /// <returns>True when the clock may stop.</returns>
    internal bool Idle() => Crossing.Awake() == 0;

    /// <summary>
    /// One cycle: in, work out, out.
    /// </summary>
    /// <remarks>
    /// ONE PER FRAME, whatever else asks. A drained run is skipped inside a
    /// frame, because the frame's own cycle is about to catch whatever the
    /// drain wrote; and every run is skipped while a message is being applied,
    /// for the reason the engine skips a frame there - a value written inside
    /// an apply is a render inside an apply.
    /// </remarks>
    /// <param name="reason">Why.</param>
    internal void Run(BusReason reason)
    {
        if (_cycling || Held?.Invoke() == true)
        {
            return;
        }

        if (reason == BusReason.Drained && _inFrame)
        {
            return;
        }

        _cycling = true;

        try
        {
            Told();

            int answer = Crossing.Cycle(_sync, _engine.Clock?.Now is long now
                ? now * 1000.0 / System.Diagnostics.Stopwatch.Frequency
                : 0, MotionMood.Reduced);

            if (answer > 0)
            {
                Wear();
            }
        }
        finally
        {
            _cycling = false;
        }
    }

    /// <summary>Runs a cycle as the frame's own, which is what a tick is.</summary>
    internal void Frame()
    {
        _inFrame = true;

        try
        {
            Run(BusReason.Frame);
        }
        finally
        {
            _inFrame = false;
        }
    }

    /// <summary>
    /// PHASE ONE: what the platform has to say, written into the image before
    /// any arithmetic runs.
    /// </summary>
    /// <remarks>
    /// Where a value is and how fast it is going, for every bus-driven
    /// property the engine has written since the last cycle - so an engine
    /// steering by a value the host is carrying is reading where it actually
    /// got to rather than where it was sent.
    /// </remarks>
    private void Told()
    {
        List<(int Bus, ulong Mask, double[] Lanes)> batch = [];

        foreach ((int bus, List<BusTie> riding) in _byBus)
        {
            foreach (BusTie tie in riding)
            {
                if (tie.Kind != SwiftBusKind.Property || tie.Mode == SwiftBusMode.Out)
                {
                    continue;
                }

                if (tie.Reading(_engine) is not (ulong mask, double[] lanes))
                {
                    continue;
                }

                batch.Add((bus, mask, lanes));
            }
        }

        if (batch.Count == 0)
        {
            return;
        }

        batch.Sort((left, right) => left.Bus.CompareTo(right.Bus));
        Crossing.Write(BusBatch.Bytes(batch));
    }

    /// <summary>
    /// PHASE THREE: what the cycle wrote, onto the controls.
    /// </summary>
    private void Wear()
    {
        int written = Crossing.Read(0, _buffer);

        if (written < 0)
        {
            // Too small - and nothing was cleared over there, so asking again
            // with room answers the same bytes.
            _buffer = new byte[_buffer.Length * 2];
            written = Crossing.Read(0, _buffer);
        }

        if (written <= 0)
        {
            return;
        }

        foreach ((int bus, ulong mask, byte[] bytes) in BusBatch.Read(_buffer.AsSpan(0, written)))
        {
            if (!_byBus.TryGetValue(bus, out List<BusTie>? riding))
            {
                continue;
            }

            foreach (BusTie tie in riding.ToArray())
            {
                tie.Wear(bytes, mask, _engine, _land);
            }
        }
    }

    /// <summary>Where a value the platform reports goes.</summary>
    /// <remarks>
    /// Written straight into the image and the clock STARTED if it was
    /// stopped: a report on a still page has to reach whatever follows it
    /// within a frame, and nothing else is about to ask for one.
    /// </remarks>
    /// <param name="bus">Which bus.</param>
    /// <param name="lanes">The value, lane by lane.</param>
    /// <param name="mask">Which lanes are being reported.</param>
    internal void Told(int bus, double[] lanes, ulong mask)
    {
        Crossing.Write(BusBatch.Bytes([(bus, mask, lanes)]));
        _engine.Clock?.Start();
    }
}

/// <summary>
/// One property of one control, tied to a bus - and the whole of what the
/// lanes of an animated value mean.
/// </summary>
/// <remarks>
/// THE LANE LAYOUT IS HERE AND NOWHERE ELSE on this side: where the value is,
/// where it is going, how fast, under what law, who is waiting and how many
/// times it has been stopped. The Swift half writes the same order in
/// <c>Core/Bus.swift</c>, and a fixture's sidecar is what holds the two
/// together.
/// </remarks>
internal sealed class BusTie
{
    private readonly BindableObject _view;
    private readonly MotionValue _shape;
    private readonly bool _fraction;

    /// <summary>What the last text written onto the control was.</summary>
    /// <remarks>
    /// So a text bus that was dirtied without its words changing writes
    /// nothing at all: a label re-measures whenever its text is set, whether
    /// or not the letters differ.
    /// </remarks>
    private string? _wrote;

    private BusTie(
        BindableObject view,
        SwiftBusEntry entry,
        BindableProperty? property,
        MotionValue shape)
    {
        _view = view;
        _shape = shape;
        _fraction = property == VisualElement.OpacityProperty;
        Key = entry.Key;
        Bus = entry.Bus;
        Mode = entry.Mode;
        Kind = entry.Kind;
        Property = property;
    }

    /// <summary>Which property, as a key that reads either bag.</summary>
    internal SwiftKey Key { get; }

    /// <summary>The number the value rides on.</summary>
    internal int Bus { get; }

    /// <summary>Which way it crosses.</summary>
    internal SwiftBusMode Mode { get; }

    /// <summary>Which of this side's doors the value goes through.</summary>
    internal SwiftBusKind Kind { get; }

    /// <summary>The property itself, or null for a kind that is not one.</summary>
    internal BindableProperty? Property { get; }

    /// <summary>How many lanes the value takes.</summary>
    internal int Lanes => _shape is MotionValue.Number or MotionValue.Whole or MotionValue.Single
        ? 1
        : 4;

    /// <summary>
    /// The tie a registration asks for, or null where this side cannot make
    /// one.
    /// </summary>
    /// <remarks>
    /// A property nothing declares, or one of a value nothing can carry, is
    /// not tied at all - and says so by being absent rather than by throwing:
    /// a message from a newer Swift half is a message this one reads as far as
    /// it can.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="entry">What the message said.</param>
    /// <param name="type">The element's type, which resolves a shared property.</param>
    /// <param name="typeName">
    /// Its name, which resolves a property of a control an application
    /// registered.
    /// </param>
    /// <returns>The tie, or null.</returns>
    internal static BusTie? Of(
        BindableObject view,
        SwiftBusEntry entry,
        SwiftNodeType type,
        string typeName)
    {
        if (SwiftStyles.Property(type, typeName, entry.Key) is not BindableProperty property)
        {
            return null;
        }

        // TEXT HAS NO LANES: it is dirty or it is not, and nothing walks it.
        if (entry.Kind == SwiftBusKind.Text)
        {
            return new BusTie(view, entry, property, MotionValue.Number);
        }

        if (Shape(property) is not MotionValue shape)
        {
            return null;
        }

        return new BusTie(view, entry, property, shape);
    }

    /// <summary>What a property's value is made of, or null for one nothing carries.</summary>
    private static MotionValue? Shape(BindableProperty property) =>
        property.ReturnType == typeof(double) ? MotionValue.Number
        : property.ReturnType == typeof(Color) ? MotionValue.Colour
        : property.ReturnType == typeof(Thickness) ? MotionValue.Edges
        : property.ReturnType == typeof(Rect) ? MotionValue.Bounds
        : property.ReturnType == typeof(CornerRadius) ? MotionValue.Corners
        : property.ReturnType == typeof(int) ? MotionValue.Whole
        : property.ReturnType == typeof(float) ? MotionValue.Single
        : null;

    /// <summary>
    /// Where the value stands, for the image - or null where nothing has
    /// written it since the last cycle.
    /// </summary>
    /// <remarks>
    /// The channel's own P and V, so what the image says is where the value
    /// actually got to. The speed crosses per SECOND, which is what an author
    /// writes and reads; the engine keeps it per millisecond.
    /// </remarks>
    /// <param name="engine">What moves the values.</param>
    /// <returns>Which lanes are being reported and the whole value.</returns>
    internal (ulong Mask, double[] Lanes)? Reading(MotionEngine engine)
    {
        if (Property is null || engine.Moving(_view, Property) is not MotionChannel channel)
        {
            return null;
        }

        if (!channel.Observed)
        {
            return null;
        }

        channel.Observed = false;

        int width = Lanes;
        double[] lanes = new double[(width * 3) + 5];
        ulong mask = 0;

        for (int lane = 0; lane < width; lane++)
        {
            lanes[lane] = channel.P[lane];
            lanes[(width * 2) + lane] = channel.V[lane] * 1000;
            mask |= 1UL << lane;
            mask |= 1UL << ((width * 2) + lane);
        }

        return (mask, lanes);
    }

    /// <summary>
    /// The value the bus stands at, written onto the control at once - what a
    /// registration owes before anything is drawn.
    /// </summary>
    /// <param name="bytes">The bus, whole.</param>
    /// <param name="engine">What moves the values.</param>
    internal void Landed(byte[] bytes, MotionEngine engine)
    {
        if (Kind == SwiftBusKind.Text)
        {
            Wear(bytes, 1, engine, static (_, _) => { });
            return;
        }

        if (Property is null || Mode == SwiftBusMode.In)
        {
            return;
        }

        double[] lanes = BusBatch.Lanes(bytes);
        int width = Lanes;

        if (lanes.Length < (width * 3) + 5)
        {
            return;
        }

        engine.Halt(_view, Property, MotionEnd.Nothing);
        Target().Write(lanes[..width]);

        // And aimed where it is going, if that is somewhere else - which is
        // what a control built while a motion was already under way needs.
        double[] setPoint = lanes[width..(width * 2)];

        if (!Same(lanes[..width], setPoint))
        {
            engine.Aim(Target(), setPoint, Law(lanes, width, engine));
        }
    }

    /// <summary>
    /// What a cycle wrote, onto the control.
    /// </summary>
    /// <remarks>
    /// THE BITS OF ONE MASK APPLY IN ONE ORDER: stop, then the value, then
    /// where it is going, then how fast, then the law. So a handler that stops
    /// a movement and starts another in the same breath ends the first and
    /// gets a fresh one, rather than the other way round.
    /// </remarks>
    /// <param name="bytes">The bus, whole.</param>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="engine">What moves the values.</param>
    /// <param name="land">Told a completion is done, and whether it finished.</param>
    internal void Wear(byte[] bytes, ulong mask, MotionEngine engine, Action<int, bool> land)
    {
        if (Property is null)
        {
            return;
        }

        if (Kind == SwiftBusKind.Text)
        {
            string words = BusBatch.Text(bytes);

            if (words == _wrote)
            {
                return;
            }

            _wrote = words;
            _view.SetValue(Property, words);
            return;
        }

        if (Mode == SwiftBusMode.In)
        {
            return;
        }

        double[] lanes = BusBatch.Lanes(bytes);
        int width = Lanes;

        if (lanes.Length < (width * 3) + 5)
        {
            return;
        }

        ulong Bit(int lane) => 1UL << lane;

        ulong values = 0;
        ulong setPoints = 0;
        ulong speeds = 0;

        for (int lane = 0; lane < width; lane++)
        {
            values |= Bit(lane);
            setPoints |= Bit(width + lane);
            speeds |= Bit((width * 2) + lane);
        }

        int waiter = (int)lanes[(width * 3) + 3];

        if ((mask & Bit((width * 3) + 4)) != 0)
        {
            // STOPPED where it stands, and whoever was waiting hears that it
            // did not run to the end.
            if (engine.Halt(_view, Property, MotionEnd.Here) && waiter != 0)
            {
                land(waiter, false);
            }
        }

        if ((mask & values) != 0)
        {
            // A VALUE WRITTEN IS A SNAP: whatever was carrying this property
            // lets go without a word, because the author has just written it.
            engine.Halt(_view, Property, MotionEnd.Nothing);
            Target().Write(lanes[..width]);
        }

        if ((mask & setPoints) != 0)
        {
            double[] speed = lanes[(width * 2)..(width * 3)];
            bool kicked = (mask & speeds) != 0;

            engine.Aim(
                Target(),
                lanes[width..(width * 2)],
                Law(lanes, width, engine),
                done: waiter == 0 ? null : whole => land(waiter, whole),
                velocity: kicked ? PerFrame(speed) : null);

            return;
        }

        if ((mask & speeds) != 0)
        {
            // A SPEED ON ITS OWN is a kick: what is moving bends, and what is
            // still leaves and comes back.
            double[] going = lanes[(width * 2)..(width * 3)];
            double[] target = engine.Moving(_view, Property) is MotionChannel channel
                ? channel.Target
                : lanes[width..(width * 2)];

            engine.Aim(Target(), target, Law(lanes, width, engine), velocity: PerFrame(going));
        }
    }

    /// <summary>The channel this property moves on.</summary>
    private MotionProperty Target() => new(_view, Property!, _shape, _fraction);

    /// <summary>A speed per second, as the engine keeps one.</summary>
    private static double[] PerFrame(double[] lanes)
    {
        double[] perMillisecond = new double[lanes.Length];

        for (int lane = 0; lane < lanes.Length; lane++)
        {
            perMillisecond[lane] = lanes[lane] / 1000;
        }

        return perMillisecond;
    }

    /// <summary>
    /// The law the lanes name.
    /// </summary>
    /// <remarks>
    /// Kind 0 is no motion at all, 1 is the one the element resolves to - the
    /// application's answer, which is what almost every element is - 2 is a
    /// stated length on a stated curve, and 3 is a spring.
    /// </remarks>
    private static MotionSpec Law(double[] lanes, int width, MotionEngine engine)
    {
        int at = width * 3;

        return (int)lanes[at] switch
        {
            1 => engine.Travel,
            2 => MotionSpec.Eased(lanes[at + 1], (int)lanes[at + 2]),
            3 => MotionSpec.Spring(lanes[at + 1], lanes[at + 2]),
            _ => MotionSpec.Eased(0, 0),
        };
    }

    /// <summary>Whether two runs of lanes hold the same numbers.</summary>
    private static bool Same(double[] left, double[] right)
    {
        for (int lane = 0; lane < left.Length; lane++)
        {
            if (Math.Abs(left[lane] - right[lane]) >= MotionCurve.Still)
            {
                return false;
            }
        }

        return true;
    }
}

/// <summary>
/// The batch both directions cross in: a count, then a bus, a mask, a length
/// and the bytes.
/// </summary>
/// <remarks>
/// Little-endian throughout and written by hand, for the reason the wire is:
/// there is no endianness to agree about and no framework in the way.
/// </remarks>
internal static class BusBatch
{
    /// <summary>The bytes a batch of writes lies as.</summary>
    /// <param name="batch">The buses, each with the lanes being written.</param>
    /// <returns>The bytes.</returns>
    internal static byte[] Bytes(IReadOnlyList<(int Bus, ulong Mask, double[] Lanes)> batch)
    {
        List<byte> bytes = new(2 + (batch.Count * 32));

        Add(bytes, (ulong)batch.Count, 2);

        foreach ((int bus, ulong mask, double[] lanes) in batch)
        {
            Add(bytes, (uint)bus, 4);
            Add(bytes, mask & 0xFFFF_FFFF, 4);
            Add(bytes, mask >> 32, 4);
            Add(bytes, (ulong)(lanes.Length * 8), 4);

            foreach (double lane in lanes)
            {
                Add(bytes, BitConverter.DoubleToUInt64Bits(lane), 8);
            }
        }

        return [.. bytes];
    }

    /// <summary>What a batch says.</summary>
    /// <param name="bytes">The batch.</param>
    /// <returns>The buses, each with which lanes moved and its own bytes.</returns>
    internal static List<(int Bus, ulong Mask, byte[] Bytes)> Read(ReadOnlySpan<byte> bytes)
    {
        List<(int Bus, ulong Mask, byte[] Bytes)> read = [];

        if (bytes.Length < 2)
        {
            return read;
        }

        int count = (int)Number(bytes, 0, 2);
        int at = 2;

        for (int entry = 0; entry < count; entry++)
        {
            if (at + 16 > bytes.Length)
            {
                return read;
            }

            int bus = (int)Number(bytes, at, 4);
            ulong mask = Number(bytes, at + 4, 4) | (Number(bytes, at + 8, 4) << 32);
            int length = (int)Number(bytes, at + 12, 4);

            at += 16;

            if (at + length > bytes.Length)
            {
                return read;
            }

            read.Add((bus, mask, bytes.Slice(at, length).ToArray()));
            at += length;
        }

        return read;
    }

    /// <summary>A little-endian number of a stated width.</summary>
    private static ulong Number(ReadOnlySpan<byte> bytes, int at, int width)
    {
        ulong value = 0;

        for (int byteAt = 0; byteAt < width; byteAt++)
        {
            value |= (ulong)bytes[at + byteAt] << (byteAt * 8);
        }

        return value;
    }

    /// <summary>The lanes a bus's bytes hold.</summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>One number per eight bytes.</returns>
    internal static double[] Lanes(byte[] bytes)
    {
        double[] lanes = new double[bytes.Length / 8];

        for (int lane = 0; lane < lanes.Length; lane++)
        {
            lanes[lane] = BitConverter.ToDouble(bytes, lane * 8);
        }

        return lanes;
    }

    /// <summary>The text a bus's bytes hold: its own length, then its own UTF-8.</summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>The words.</returns>
    internal static string Text(byte[] bytes)
    {
        if (bytes.Length < 4)
        {
            return string.Empty;
        }

        int length = BitConverter.ToInt32(bytes, 0);

        return System.Text.Encoding.UTF8.GetString(
            bytes, 4, Math.Min(length, bytes.Length - 4));
    }

    private static void Add(List<byte> bytes, ulong value, int width)
    {
        for (int byteAt = 0; byteAt < width; byteAt++)
        {
            bytes.Add((byte)(value >> (byteAt * 8)));
        }
    }
}
