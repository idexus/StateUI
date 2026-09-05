// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;
using StateUI.Runtime.Interop;
using StateUI.Runtime.Protocol;

/// <summary>Why a cycle is being run.</summary>
internal enum CycleReason : byte
{
    /// <summary>The display is about to draw. Every tick, and the ordinary case.</summary>
    Frame = 0,

    /// <summary>
    /// Something was drained - a report landed, a handler wrote a value - and
    /// there may be nothing else about to make a frame.
    /// </summary>
    Drained = 1,

    /// <summary>
    /// A message registered or replaced a state, so the engines it armed have a
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
internal interface ICycleCrossing
{
    /// <summary>Takes a batch of writes into the image.</summary>
    /// <param name="batch">The bytes, in the layout NativeMethods describes.</param>
    /// <returns>How many states were written, or -1 for bytes that could not be read.</returns>
    int Write(ReadOnlySpan<byte> batch);

    /// <summary>Runs one cycle.</summary>
    /// <param name="sync">Which board.</param>
    /// <param name="now">The instant, in milliseconds.</param>
    /// <param name="reducesMotion">Whether the reader asked for less movement.</param>
    /// <returns>
    /// How many states have lanes waiting, with <c>0x4000_0000</c> set while
    /// any engine says it has more to do.
    /// </returns>
    int Cycle(int sync, double now, bool reducesMotion);

    /// <summary>Reads out what a cycle wrote.</summary>
    /// <param name="number">Which number, or 0 for every one with lanes waiting.</param>
    /// <param name="into">Where to write.</param>
    /// <returns>How many bytes were written, 0 for a state that has gone, -1 for no room.</returns>
    int Read(int number, Span<byte> into);

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
internal sealed class NativeCycleCrossing : ICycleCrossing
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
            return NativeMethods.CycleWrite(bytes, batch.Length);
        }
    }

    /// <inheritdoc/>
    public int Cycle(int sync, double now, bool reducesMotion) =>
        Live ? NativeMethods.CycleRun(sync, now, reducesMotion ? 1 : 0) : 0;

    /// <inheritdoc/>
    public unsafe int Read(int number, Span<byte> into)
    {
        if (!Live)
        {
            return 0;
        }

        fixed (byte* bytes = into)
        {
            return NativeMethods.CycleRead(number, bytes, into.Length);
        }
    }

    /// <inheritdoc/>
    public int Awake() => Live ? NativeMethods.CycleAwake() : 0;

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
internal sealed class HandCrossing : ICycleCrossing
{
    /// <summary>Every batch this side wrote, in the order it wrote them.</summary>
    internal List<byte[]> Written { get; } = [];

    /// <summary>Every cycle asked for: which board, when, and whether reduced.</summary>
    internal List<(int Sync, double Now, bool Reduced)> Cycles { get; } = [];

    /// <summary>What the next cycle answers.</summary>
    internal int Answers { get; set; }

    /// <summary>
    /// What the next read of every dirty number answers, as a batch.
    /// </summary>
    /// <remarks>
    /// TAKEN, not kept: a read clears the lanes it answered over there, so a
    /// stub that went on answering the same bytes would have every frame
    /// re-aim a journey the last one started - which is not a thing the real
    /// crossing can do.
    /// </remarks>
    internal byte[] Dirty { get; set; } = [];

    /// <summary>What a read of one number answers, by number.</summary>
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
    public int Read(int number, Span<byte> into)
    {
        byte[] answer = number == 0 ? Dirty : Whole.GetValueOrDefault(number, []);

        if (answer.Length == 0)
        {
            return 0;
        }

        if (answer.Length > into.Length)
        {
            return -1;
        }

        answer.CopyTo(into);

        if (number == 0)
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
/// <c>STATEUI_FRAMES</c> puts every cycle in the motion log beside the frames
/// it shares a clock with - what was latched in, how many engines ran, how many
/// were skipped, what was written and whether anything says it has more to do.
/// </para>
/// <para>
/// A property with a state behind it is moved by the SAME engine that moves
/// everything else here - the channel is the ordinary (control, property) one
/// - so every guard the motion engine already has sees a driven-state motion
/// exactly as it sees a state-driven one.
/// </para>
/// </remarks>
internal sealed class StateCycle
{
    /// <summary>How much room a read is given before it asks for more.</summary>
    private const int Room = 4096;

    private readonly MotionEngine _engine;
    private readonly Action<int, bool> _land;
    private readonly int _sync;

    /// <summary>Every tie, by the number it rides on - one state may drive several.</summary>
    private readonly Dictionary<int, List<StateTie>> _byNumber = [];

    /// <summary>And by the control, which is how a host writer asks about one.</summary>
    private readonly ConditionalWeakTable<BindableObject, Dictionary<SwiftKey, StateTie>> _byView = new();

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
    internal StateCycle(
        MotionEngine engine,
        ICycleCrossing crossing,
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
    internal ICycleCrossing Crossing { get; set; }

    /// <summary>
    /// Ties this control's properties to their states, forgetting whatever it
    /// was tied to before.
    /// </summary>
    /// <remarks>
    /// THE VALUE IS LANDED AT ONCE, before anything is drawn: the state is read
    /// whole - where the value is AND where it is going - and the property
    /// snapped to where the value stands, so a control born under a state is
    /// already showing what the state says rather than what its default was.
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

        if (node.States is not { Count: > 0 } entries)
        {
            return;
        }

        Dictionary<SwiftKey, StateTie> tied = [];

        foreach (SwiftStateEntry entry in entries)
        {
            if (StateTie.Of(view, entry, node.Type, node.TypeName) is not StateTie tie)
            {
                continue;
            }

            tied[entry.Key] = tie;

            if (!_byNumber.TryGetValue(entry.Number, out List<StateTie>? riding))
            {
                _byNumber[entry.Number] = riding = [];
            }

            riding.Add(tie);

            // AND THE LAYOUT IS TOLD IT IS PLACED, before anything measures
            // it: its children stand where arithmetic over the room puts them,
            // so their reach says nothing about how big it should be.
            if (tie.Kind == SwiftStateKind.Placement)
            {
                view.SetValue(MotionPlacement.PlacedProperty, true);
            }

            if (tie.Kind == SwiftStateKind.Feed
                && entry.Key.Prop == SwiftProp.Frame
                && view is VisualElement reporting)
            {
                Fed(reporting, tie);
                continue;
            }

            // READ WHOLE, and landed before anything is drawn: the value AND
            // where it is going, so a control born under a state shows what the
            // number says rather than what its own default was.
            int read = Crossing.Read(entry.Number, _buffer);

            if (read > 0 && StateBatch.Read(_buffer.AsSpan(0, read)) is [(_, _, byte[] bytes)])
            {
                tie.Landed(bytes, _engine);
            }
        }

        if (tied.Count > 0)
        {
            _byView.AddOrUpdate(view, tied);
        }
    }

    /// <summary>
    /// Puts the room a view is given onto its state, from now on.
    /// </summary>
    /// <remarks>
    /// The frame's own parts rather than <c>SizeChanged</c> alone, because a
    /// view MOVED without being resized has a new room to place things in too -
    /// a run inside a page that scrolled, a pane the reader dragged wider.
    /// </remarks>
    /// <param name="view">The control whose room it is.</param>
    /// <param name="tie">Where the room goes.</param>
    private void Fed(VisualElement view, StateTie tie)
    {
        void Moved(object? sender, PropertyChangedEventArgs args)
        {
            if (args.PropertyName is nameof(VisualElement.X) or nameof(VisualElement.Y)
                or nameof(VisualElement.Width) or nameof(VisualElement.Height)
                or nameof(VisualElement.Frame))
            {
                Reported(view, tie);
            }
        }

        view.PropertyChanged += Moved;
        tie.Released = () => view.PropertyChanged -= Moved;

        // And the room it already stands in, so a layout registered onto a
        // page that has been laid out already is not waiting for a change.
        Reported(view, tie);
    }

    /// <summary>
    /// The room, onto the state, and a cycle at once.
    /// </summary>
    /// <remarks>
    /// <para>
    /// INSIDE THE PLATFORM'S OWN LAYOUT PASS, deliberately. What this room
    /// places has to be where it belongs before the pass paints, and a turn's
    /// wait is a run of cards a frame behind the hand - worse than that on a
    /// Mac, where a window drag is tracked in a run loop mode that drains no
    /// dispatcher at all: measured, a queued turn ran 590 ms after the report
    /// that asked for it, having swallowed eleven reports on the way.
    /// </para>
    /// <para>
    /// What a cycle running there may NOT do is write a rectangle, which
    /// invalidates the very measure being taken. Those are left owing and
    /// written on the turn after - see <see cref="MotionPlacement.Wear"/>.
    /// </para>
    /// </remarks>
    /// <param name="view">The control whose room it is.</param>
    /// <param name="tie">Where the room goes.</param>
    private void Reported(VisualElement view, StateTie tie)
    {
        Rect frame = view.Frame;

        if (tie.Fed == frame)
        {
            return;
        }

        tie.Fed = frame;
        Told(tie.Number, [frame.X, frame.Y, frame.Width, frame.Height], 0b1111);

        MotionPlacement.InPass++;

        try
        {
            Run(CycleReason.Told);
        }
        finally
        {
            MotionPlacement.InPass--;
        }
    }

    /// <summary>What this control's properties are tied to, if anything.</summary>
    /// <param name="view">The control.</param>
    /// <returns>The ties, by property.</returns>
    internal IReadOnlyDictionary<SwiftKey, StateTie> Registered(BindableObject view) =>
        _byView.TryGetValue(view, out Dictionary<SwiftKey, StateTie>? tied)
            ? tied
            : new Dictionary<SwiftKey, StateTie>();

    /// <summary>
    /// The tie one property of one control has, or null where it has none.
    /// </summary>
    /// <remarks>
    /// The one question every host writer asks before it decides a resting
    /// value for itself: a property a state is driving has its resting value on
    /// the state, and a visual state leaving, a hidden view coming back or a
    /// cleared property must land THAT rather than what the tree last said.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <returns>The tie, or null.</returns>
    internal StateTie? Sink(BindableObject view, BindableProperty property)
    {
        if (!_byView.TryGetValue(view, out Dictionary<SwiftKey, StateTie>? tied))
        {
            return null;
        }

        foreach (StateTie tie in tied.Values)
        {
            if (tie.Property == property)
            {
                return tie;
            }
        }

        return null;
    }

    /// <summary>
    /// A value the READER moved, onto the state driving it - and whether there
    /// was a state to move.
    /// </summary>
    /// <remarks>
    /// <para>
    /// THE REPORT THAT IS NOT AN ECHO. Every platform raises its change
    /// notification while the value is being assigned, so the engine's own
    /// frames come back as reports; those are dropped, by
    /// <see cref="MotionEngine.Writing"/>. What is left was made by somebody
    /// else, and on a Slider or a Stepper that is a finger.
    /// </para>
    /// <para>
    /// A FINGER TAKES THE VALUE. Whatever was carrying it ends where it stands
    /// and whoever was waiting hears that it did not arrive - which is the
    /// only honest reading: the reader has just put the thumb somewhere, and a
    /// motion that went on would drag it out from under them. Then the value
    /// AND where it is going are written, so nothing aims it back.
    /// </para>
    /// </remarks>
    /// <param name="view">The control the reader moved.</param>
    /// <param name="property">Which of its properties.</param>
    /// <param name="value">Where they left it.</param>
    /// <returns>Whether a state drives it.</returns>
    internal bool Reader(BindableObject view, BindableProperty property, double value)
    {
        if (_byNumber.Count == 0
            || Sink(view, property) is not StateTie tie
            || tie.Kind != SwiftStateKind.Property
            || tie.Mode == SwiftStateMode.Out
            || tie.Lanes != 1)
        {
            return false;
        }

        if (MotionEngine.Writing > 0)
        {
            return true;
        }

        _engine.Halt(view, property, MotionEnd.Here);

        // Where it is, where it is going, and standing still: three lanes, and
        // the law, the waiter and the stop counter left as they were.
        Told(tie.Number, [value, value, 0], 0b111);

        // BEFORE the cycle, and whether or not there is one: what this writes
        // is the reader's own number onto controls that are not going to hear
        // it any other way, and it needs no arithmetic to do it.
        Beside(tie, value);

        if (StateUISession.RegisterApp is null)
        {
            return true;
        }

        MotionPlacement.InPass++;

        try
        {
            Run(CycleReason.Told);
        }
        finally
        {
            MotionPlacement.InPass--;
        }

        return true;
    }

    /// <summary>
    /// Puts a value the reader moved onto every OTHER control the same state
    /// drives.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A REPORT CLEARS THE STATE'S DIRTY LANES - a lane the host wrote is a
    /// lane the host already has, and reading it back out would be this side
    /// answering the platform with the platform's own news. But the lanes
    /// belong to the STATE while "already has it" is only true of the control
    /// that REPORTED, and one state may drive several: a panel whose width
    /// rides the same value as a slider's thumb then hears nothing at all and
    /// stands still under the finger. Measured on the gallery's Measuring a
    /// frame sample, byte for byte - the state reached 267 and the panel was
    /// drawn at the width it started with.
    /// </para>
    /// <para>
    /// An ENGINE following the same state needs none of this: it reads the
    /// IMAGE rather than the dirty lanes, which is why a driven text beside
    /// the same slider always did keep up.
    /// </para>
    /// <para>
    /// They ARRIVE rather than travel. The reader has the thumb under their
    /// finger, and a value gliding after it would be late every frame - which
    /// is the same answer <see cref="Reader"/> itself gives.
    /// </para>
    /// </remarks>
    /// <param name="moved">The tie the reader's report came through.</param>
    /// <param name="value">Where the reader left it.</param>
    private void Beside(StateTie moved, double value)
    {
        if (!_byNumber.TryGetValue(moved.Number, out List<StateTie>? riding) || riding.Count < 2)
        {
            return;
        }

        foreach (StateTie tie in riding.ToArray())
        {
            if (!ReferenceEquals(tie, moved))
            {
                tie.Moved(value, _engine);
            }
        }
    }

    /// <summary>
    /// Whether a state is driving this value - what every host writer asks
    /// before it decides a resting value of its own.
    /// </summary>
    /// <remarks>
    /// A state whose writes never reach the control drives nothing: an
    /// <c>.in</c> registration is the host TELLING the state where a value got
    /// to, so every writer there goes on as it always did.
    /// </remarks>
    /// <param name="owner">The control.</param>
    /// <param name="key">Which of its values - a property, for a state.</param>
    /// <returns>Whether a state owns it.</returns>
    internal bool Drives(object owner, object key) =>
        owner is BindableObject view
        && key is BindableProperty property
        && Sink(view, property) is StateTie tie
        && tie.Kind is SwiftStateKind.Property or SwiftStateKind.Text
        && tie.Mode != SwiftStateMode.In;

    /// <summary>
    /// Puts a state-driven property back where its state says it belongs, and
    /// answers whether there was a state at all.
    /// </summary>
    /// <remarks>
    /// What the host's own writers do INSTEAD of landing a resting value they
    /// worked out for themselves. The state is read whole, so the property is
    /// snapped to where the value stands and aimed at where it is going -
    /// which is the same landing a registration makes, and the only reading of
    /// "at rest" that a value something else is carrying can have.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <returns>Whether a state drives it.</returns>
    internal bool Reland(BindableObject view, BindableProperty property)
    {
        if (!Drives(view, property) || Sink(view, property) is not StateTie tie)
        {
            return false;
        }

        int read = Crossing.Read(tie.Number, _buffer);

        if (read > 0 && StateBatch.Read(_buffer.AsSpan(0, read)) is [(_, _, byte[] bytes)])
        {
            tie.Landed(bytes, _engine);
        }

        return true;
    }

    /// <summary>
    /// Sends a state-driven property to where its state is going, under the law
    /// the caller was going to use - and answers whether there was a state.
    /// </summary>
    /// <remarks>
    /// The other half of <see cref="Reland"/>, for a writer that was about to
    /// send the value somewhere rather than put it there: a visual state
    /// leaving settles every value it touched, and where a state has one the
    /// destination is the state's rather than the tree's.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <param name="spec">The law the caller was going to use.</param>
    /// <returns>Whether a state drives it.</returns>
    internal bool Restate(BindableObject view, BindableProperty property, in MotionSpec spec)
    {
        if (!Drives(view, property) || Sink(view, property) is not StateTie tie)
        {
            return false;
        }

        int read = Crossing.Read(tie.Number, _buffer);

        if (read > 0 && StateBatch.Read(_buffer.AsSpan(0, read)) is [(_, _, byte[] bytes)])
        {
            tie.Resting(bytes, _engine, spec);
        }

        return true;
    }

    /// <summary>
    /// Tells a state where the value it carries is going, when somebody else
    /// decided that.
    /// </summary>
    /// <remarks>
    /// <para>
    /// WHAT KEEPS A DRIVEN STATE HONEST. The tree, a visual state and a layout all aim
    /// values of their own accord, and the setpoint lane of a state they aimed
    /// would otherwise still name the destination the state itself last chose -
    /// so an engine sending the value where the state already says it is going
    /// would send it nowhere at all, the bytes being equal.
    /// </para>
    /// <para>
    /// A LANDING IS THE OTHER HALF: the channel is taken out of the table as
    /// it lands, so nothing can poll for the value it finished at. Written
    /// here, where the value is and where it is going agree and the speed is
    /// nought, which is what an engine reads as "arrived".
    /// </para>
    /// </remarks>
    /// <param name="channel">The motion.</param>
    /// <param name="going">Whether the value is on its way rather than stopped.</param>
    internal void Mirror(MotionChannel channel, bool going)
    {
        if (_byNumber.Count == 0)
        {
            return;
        }

        if (channel.Moves.Owner is not BindableObject view
            || channel.Moves.Key is not BindableProperty property
            || Sink(view, property) is not StateTie tie
            || tie.Kind != SwiftStateKind.Property
            || tie.Mode == SwiftStateMode.Out)
        {
            return;
        }

        if (tie.Mirror(channel, going) is not (ulong mask, double[] lanes))
        {
            return;
        }

        Crossing.Write(StateBatch.Bytes([(tie.Number, mask, lanes)]));
    }

    /// <summary>
    /// Forgets everything this control was tied to, and ends whatever was
    /// moving one of its state-driven properties.
    /// </summary>
    /// <param name="view">The control.</param>
    internal void Detach(BindableObject view)
    {
        if (!_byView.TryGetValue(view, out Dictionary<SwiftKey, StateTie>? tied))
        {
            return;
        }

        foreach (StateTie tie in tied.Values)
        {
            if (_byNumber.TryGetValue(tie.Number, out List<StateTie>? riding))
            {
                riding.Remove(tie);

                if (riding.Count == 0)
                {
                    _byNumber.Remove(tie.Number);
                }
            }

            // A feed listens to the platform, and a control nothing describes
            // any more is one nothing should hear from.
            tie.Released?.Invoke();
            tie.Released = null;

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
    internal void Run(CycleReason reason)
    {
        if (_cycling || Held?.Invoke() == true)
        {
            return;
        }

        if (reason == CycleReason.Drained && _inFrame)
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

            if (MotionTrace.Watching && Crossing.Trace() is string line)
            {
                MotionTrace.Say($"{reason.ToString().ToLowerInvariant()} {line}");
            }

            // AND THE DISPLAY IS WOKEN WHERE THE CYCLE SAYS THERE IS MORE TO
            // COME. An engine that answers "moving" is asking for the next
            // frame, and one that only ever writes a value it works out itself
            // aims nothing, so nothing else would start the clock for it.
            if (!Idle())
            {
                _engine.Clock?.Start();
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
            Run(CycleReason.Frame);
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
    /// Where a value is and how fast it is going, for every state-driven
    /// property the engine has written since the last cycle - so an engine
    /// steering by a value the host is carrying is reading where it actually
    /// got to rather than where it was sent.
    /// </remarks>
    private void Told()
    {
        List<(int Number, ulong Mask, double[] Lanes)> batch = [];

        foreach ((int number, List<StateTie> riding) in _byNumber)
        {
            foreach (StateTie tie in riding)
            {
                if (tie.Kind != SwiftStateKind.Property || tie.Mode == SwiftStateMode.Out)
                {
                    continue;
                }

                if (tie.Reading(_engine) is not (ulong mask, double[] lanes))
                {
                    continue;
                }

                batch.Add((number, mask, lanes));
            }
        }

        if (batch.Count == 0)
        {
            return;
        }

        batch.Sort((left, right) => left.Number.CompareTo(right.Number));
        Crossing.Write(StateBatch.Bytes(batch));
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

        foreach ((int number, ulong mask, byte[] bytes) in StateBatch.Read(_buffer.AsSpan(0, written)))
        {
            if (!_byNumber.TryGetValue(number, out List<StateTie>? riding))
            {
                continue;
            }

            foreach (StateTie tie in riding.ToArray())
            {
                tie.Wear(bytes, mask, _engine, _land);
            }
        }
    }

    /// <summary>
    /// Where a value the platform reports stands, as far as this side has been
    /// told.
    /// </summary>
    /// <remarks>
    /// Kept here as well as on the state so a gesture can count on from where the
    /// value stood without reading back across the boundary: a drag writes the
    /// base plus its own delta, and it is asked once per report.
    /// </remarks>
    private readonly Dictionary<int, double> _standing = [];

    /// <summary>Where a reported value stands.</summary>
    /// <param name="number">The value being asked about.</param>
    /// <returns>Where it stands, or nought where nothing has said.</returns>
    internal double Standing(int number) =>
        _standing.TryGetValue(number, out double value) ? value : 0;

    /// <summary>Says where a value the platform moves now stands.</summary>
    /// <remarks>
    /// A ONE-LANE WRITE AND A CYCLE, in that order: the arithmetic that follows
    /// this value READS it, so it has to be where the platform says before any
    /// engine runs - and the cycle is run INLINE, on the platform's own report,
    /// because a run of cards that waited for the next frame would be a card
    /// behind the hand. Nothing happens with no Swift side registered: a test
    /// host's controls have no library behind them.
    /// </remarks>
    /// <param name="number">The value that moved.</param>
    /// <param name="value">Where it now stands.</param>
    internal void Moved(int number, double value)
    {
        _standing[number] = value;

        if (StateUISession.RegisterApp is null)
        {
            return;
        }

        Told(number, [value], 1);

        MotionPlacement.InPass++;

        try
        {
            Run(CycleReason.Told);
        }
        finally
        {
            MotionPlacement.InPass--;
        }
    }

    /// <summary>Where a value the platform reports goes.</summary>
    /// <remarks>
    /// Written straight into the image and the clock STARTED if it was
    /// stopped: a report on a still page has to reach whatever follows it
    /// within a frame, and nothing else is about to ask for one.
    /// </remarks>
    /// <param name="number">Which number.</param>
    /// <param name="lanes">The value, lane by lane.</param>
    /// <param name="mask">Which lanes are being reported.</param>
    internal void Told(int number, double[] lanes, ulong mask)
    {
        Crossing.Write(StateBatch.Bytes([(number, mask, lanes)]));
        _engine.Clock?.Start();
    }
}

/// <summary>
/// One property of one control, tied to a state - and the whole of what the
/// lanes of an animated value mean.
/// </summary>
/// <remarks>
/// THE LANE LAYOUT IS HERE AND NOWHERE ELSE on this side: where the value is,
/// where it is going, how fast, under what law, who is waiting and how many
/// times it has been stopped. The Swift half writes the same order in
/// <c>Core/StateValue.swift</c>, and a fixture's sidecar is what holds the two
/// together.
/// </remarks>
internal sealed class StateTie
{
    private readonly BindableObject _view;
    private readonly MotionValue _shape;
    private readonly bool _fraction;

    /// <summary>What the last text written onto the control was.</summary>
    /// <remarks>
    /// So a text state that was dirtied without its words changing writes
    /// nothing at all: a label re-measures whenever its text is set, whether
    /// or not the letters differ.
    /// </remarks>
    private string? _wrote;

    private StateTie(
        BindableObject view,
        SwiftStateEntry entry,
        BindableProperty? property,
        MotionValue shape)
    {
        _view = view;
        _shape = shape;
        _fraction = property == VisualElement.OpacityProperty;
        Key = entry.Key;
        Number = entry.Number;
        Mode = entry.Mode;
        Kind = entry.Kind;
        Property = property;
    }

    /// <summary>Which property, as a key that reads either bag.</summary>
    internal SwiftKey Key { get; }

    /// <summary>The number the value rides on.</summary>
    internal int Number { get; }

    /// <summary>Which way it crosses.</summary>
    internal SwiftStateMode Mode { get; }

    /// <summary>Which of this side's doors the value goes through.</summary>
    internal SwiftStateKind Kind { get; }

    /// <summary>The property itself, or null for a kind that is not one.</summary>
    internal BindableProperty? Property { get; }

    /// <summary>What a feed unsubscribes when the control is described away.</summary>
    internal Action? Released { get; set; }

    /// <summary>The room this feed last put on the state.</summary>
    /// <remarks>
    /// A pass reports each part of a frame separately, so the same room
    /// arrives four times; only a room that actually moved is worth a cycle.
    /// </remarks>
    internal Rect Fed { get; set; } = new(0, 0, -1, -1);

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
    internal static StateTie? Of(
        BindableObject view,
        SwiftStateEntry entry,
        SwiftNodeType type,
        string typeName)
    {
        // A PLACEMENT IS ABOUT THE LAYOUT'S CHILDREN, and a FEED is the
        // platform's own answer about the control - a room, an offset, a drag.
        // Neither is a property of anything, so neither is looked up as one.
        if (entry.Kind == SwiftStateKind.Placement)
        {
            return view is Microsoft.Maui.Controls.Layout
                ? new StateTie(view, entry, null, MotionValue.Number)
                : null;
        }

        if (entry.Kind == SwiftStateKind.Feed)
        {
            return new StateTie(view, entry, null, MotionValue.Number);
        }

        if (SwiftStyles.Property(type, typeName, entry.Key) is not BindableProperty property)
        {
            return null;
        }

        // TEXT HAS NO LANES: it is dirty or it is not, and nothing walks it.
        if (entry.Kind == SwiftStateKind.Text)
        {
            return new StateTie(view, entry, property, MotionValue.Number);
        }

        if (Shape(property) is not MotionValue shape)
        {
            return null;
        }

        return new StateTie(view, entry, property, shape);
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
    /// Where the value is and where it is going, for the image - what somebody
    /// else's decision about this value looks like from the state's side.
    /// </summary>
    /// <remarks>
    /// All three lanes, because a decision made outside the state moves all
    /// three: the value starts where the platform actually had it, the
    /// destination is whatever was asked for, and the speed is what the motion
    /// begins at. A value that has STOPPED is going nowhere - the setpoint is
    /// where it stopped and the speed is nought, which together are what an
    /// engine reads as arrived.
    /// </remarks>
    /// <param name="channel">The motion.</param>
    /// <param name="going">Whether it is on its way rather than stopped.</param>
    /// <returns>Which lanes are being told and the whole value.</returns>
    internal (ulong Mask, double[] Lanes)? Mirror(MotionChannel channel, bool going)
    {
        int width = Lanes;

        if (channel.P.Length < width)
        {
            return null;
        }

        double[] lanes = new double[(width * 3) + 5];
        ulong mask = 0;

        for (int lane = 0; lane < width; lane++)
        {
            lanes[lane] = channel.P[lane];
            lanes[width + lane] = going ? channel.Target[lane] : channel.P[lane];
            lanes[(width * 2) + lane] = going ? channel.V[lane] * 1000 : 0;

            mask |= 1UL << lane;
            mask |= 1UL << (width + lane);
            mask |= 1UL << ((width * 2) + lane);
        }

        // Nothing left for the poll to say: this has just told the state
        // everything a reading would have.
        channel.Observed = false;

        return (mask, lanes);
    }

    /// <summary>
    /// The value the state stands at, written onto the control at once - what a
    /// registration owes before anything is drawn.
    /// </summary>
    /// <param name="bytes">The state, whole.</param>
    /// <param name="engine">What moves the values.</param>
    internal void Landed(byte[] bytes, MotionEngine engine)
    {
        if (Kind == SwiftStateKind.Placement)
        {
            // WHOLE, because nothing has been placed yet - and every one of
            // them arrives rather than travelling, a view nobody has placed
            // having nowhere to travel from.
            Placed(bytes, All, engine);
            return;
        }

        if (Kind == SwiftStateKind.Text)
        {
            Wear(bytes, 1, engine, static (_, _) => { });
            return;
        }

        if (Property is null || Mode == SwiftStateMode.In)
        {
            return;
        }

        double[] lanes = StateBatch.Lanes(bytes);
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
    /// Sends the value where the state is GOING, under a law of somebody else's
    /// - what a host writer settling a resting value does instead of settling
    /// one of its own.
    /// </summary>
    /// <remarks>
    /// An aim rather than a landing, because the value may well be on its way
    /// there already: a setpoint on a value that is moving bends it, one on a
    /// value that is already there and still is an arrival, and neither draws
    /// anything nobody asked for. What it is NOT is the whole state landed
    /// again, which would start the journey over from the beginning.
    /// </remarks>
    /// <param name="bytes">The state, whole.</param>
    /// <param name="engine">What moves the values.</param>
    /// <param name="spec">The law the writer was going to use.</param>
    internal void Resting(byte[] bytes, MotionEngine engine, in MotionSpec spec)
    {
        if (Property is null || Kind != SwiftStateKind.Property || Mode == SwiftStateMode.In)
        {
            return;
        }

        double[] lanes = StateBatch.Lanes(bytes);
        int width = Lanes;

        if (lanes.Length < (width * 3) + 5)
        {
            return;
        }

        engine.Aim(Target(), lanes[width..(width * 2)], spec);
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
    /// <param name="bytes">The state, whole.</param>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="engine">What moves the values.</param>
    /// <param name="land">Told a completion is done, and whether it finished.</param>
    internal void Wear(byte[] bytes, ulong mask, MotionEngine engine, Action<int, bool> land)
    {
        if (Kind == SwiftStateKind.Placement)
        {
            Placed(bytes, mask, engine);
            return;
        }

        if (Property is null)
        {
            return;
        }

        if (Kind == SwiftStateKind.Text)
        {
            string words = StateBatch.Text(bytes);

            if (words == _wrote)
            {
                return;
            }

            _wrote = words;
            _view.SetValue(Property, words);
            return;
        }

        if (Mode == SwiftStateMode.In)
        {
            return;
        }

        double[] lanes = StateBatch.Lanes(bytes);
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

    /// <summary>How many lanes a law takes, at the end of a run.</summary>
    private const int Laws = 3;

    /// <summary>Every lane, for a run nothing has been told about yet.</summary>
    private const ulong All = ~0UL;

    /// <summary>Where each placed view's journey is kept.</summary>
    /// <remarks>
    /// WEAK, because these outlive nothing: a view taken out of the run is a
    /// view this must let go of, and the tie belongs to a layout that belongs
    /// to a page.
    /// </remarks>
    private readonly ConditionalWeakTable<View, MotionPlacement> _seats = new();

    /// <summary>Whether a turn is already booked to write the sizes owing.</summary>
    private bool _settling;

    /// <summary>
    /// A run of placements, worn by the layout's children.
    /// </summary>
    /// <remarks>
    /// <para>
    /// ONE JOURNEY PER VIEW. The law is the RUN's - written by whoever worked
    /// the placements out, so the same arithmetic lands at once while a hand
    /// is moving it and travels when the shape of the layout changes - and a
    /// run written during a journey BENDS it rather than starting it again,
    /// which is what lets a finger go on moving cards that are crossing.
    /// </para>
    /// <para>
    /// A run shorter than the views leaves the rest where they are; one longer
    /// is read as far as there are views to wear it. Neither is a fault: the
    /// tree and the state are written by different halves at different moments,
    /// and the next cycle settles it.
    /// </para>
    /// </remarks>
    /// <param name="bytes">The run, whole.</param>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="engine">What moves the values.</param>
    private void Placed(byte[] bytes, ulong mask, MotionEngine engine)
    {
        if (_view is not Microsoft.Maui.Controls.Layout layout)
        {
            return;
        }

        double[] lanes = StateBatch.Lanes(bytes);
        int width = MotionPlacement.Fields;
        int run = Math.Min((lanes.Length - Laws) / width, layout.Count);

        if (run <= 0)
        {
            return;
        }

        MotionSpec spec = LawAt(lanes, lanes.Length - Laws, engine);
        bool owing = false;

        for (int index = 0; index < run; index++)
        {
            if (layout[index] is not View child || !Moved(mask, index, width))
            {
                continue;
            }

            Array.Copy(lanes, index * width, _place, 0, width);

            MotionPlacement seat = _seats.GetValue(child, static held => new MotionPlacement(held));

            if (seat.Wearing(_place))
            {
                continue;
            }

            seat.Holding(_place);

            if (spec.Instant)
            {
                // AT ONCE, and whatever was carrying this view lets go: the
                // arithmetic has just said where the view is, which is not a
                // destination but a fact.
                engine.Halt(child, MotionPlacement.Seat, MotionEnd.Nothing);
                seat.Write(_place);
            }
            else
            {
                engine.Aim(seat, _place, spec);
            }

            owing |= seat.Owing;
        }

        if (owing)
        {
            Settle(layout);
        }
    }

    /// <summary>One view's twelve lanes, kept rather than made per frame.</summary>
    private readonly double[] _place = new double[MotionPlacement.Fields];

    /// <summary>Whether any of one view's lanes is named by the mask.</summary>
    /// <remarks>
    /// A DIRTY MASK IS A WORD OF BITS and a run is twelve lanes a view, so
    /// past lane 62 there is no bit left to name one: every lane from there on
    /// shares the highest, and the views they belong to are all told together.
    /// Which costs the platform nothing - a view given the place it already
    /// has is skipped here, before any write is made.
    /// </remarks>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="index">Which view.</param>
    /// <param name="width">How many lanes one view takes.</param>
    /// <returns>Whether this view has anything to hear.</returns>
    private static bool Moved(ulong mask, int index, int width)
    {
        for (int lane = index * width; lane < (index + 1) * width; lane++)
        {
            if ((mask & (1UL << Math.Min(lane, 63))) != 0)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Writes the sizes a layout pass would not take, on the turn after it.
    /// </summary>
    /// <remarks>
    /// One turn per layout at a time: every view that could not have its
    /// rectangle written is waiting for the same moment, which is the first
    /// one outside the pass. See <see cref="MotionPlacement.Wear"/>.
    /// </remarks>
    /// <param name="layout">The layout whose children are owed a size.</param>
    private void Settle(Microsoft.Maui.Controls.Layout layout)
    {
        if (_settling)
        {
            return;
        }

        _settling = true;

        layout.Dispatcher.Dispatch(() =>
        {
            _settling = false;

            for (int index = 0; index < layout.Count; index++)
            {
                if (layout[index] is View child && _seats.TryGetValue(child, out MotionPlacement? seat))
                {
                    seat.Settle();
                }
            }
        });
    }

    /// <summary>The channel this property moves on.</summary>
    private MotionProperty Target() => new(_view, Property!, _shape, _fraction);

    /// <summary>
    /// Puts a value the READER moved onto this control, at once.
    /// </summary>
    /// <remarks>
    /// Written straight rather than read back off the state: the reader's own
    /// number is what is wanted and the state has just been told it, so there
    /// is nothing to fetch. Whatever was carrying this property gives up where
    /// it stands, exactly as it does for the control the reader touched -
    /// see <see cref="StateCycle.Reader"/>.
    /// </remarks>
    /// <param name="value">Where the reader left it.</param>
    /// <param name="engine">What moves the values.</param>
    internal void Moved(double value, MotionEngine engine)
    {
        if (Property is null
            || Kind != SwiftStateKind.Property
            || Mode == SwiftStateMode.In
            || Lanes != 1)
        {
            return;
        }

        engine.Halt(_view, Property, MotionEnd.Here);
        Target().Write([value]);
    }

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
    /// Kind 0 is no motion at all, 2 is a stated length on a stated curve, and
    /// 3 is a spring. Kind 1 is a value that asked for the law of whatever
    /// element drives it and is driven by NONE - Swift resolves an element's
    /// own law into these lanes as the value crosses, being the only side that
    /// can read a per-value motion plan - so the application's answer is the
    /// right one for a value no element has claimed.
    /// </remarks>
    private static MotionSpec Law(double[] lanes, int width, MotionEngine engine) =>
        LawAt(lanes, width * 3, engine);

    /// <summary>The law the three lanes at <paramref name="at"/> name.</summary>
    /// <param name="lanes">The whole value.</param>
    /// <param name="at">The first of the law's three lanes.</param>
    /// <param name="engine">What moves the values, for the element's own law.</param>
    /// <returns>The law.</returns>
    private static MotionSpec LawAt(double[] lanes, int at, MotionEngine engine)
    {
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
/// The batch both directions cross in: a count, then a number, a mask, a length
/// and the bytes.
/// </summary>
/// <remarks>
/// Little-endian throughout and written by hand, for the reason the wire is:
/// there is no endianness to agree about and no framework in the way.
/// </remarks>
internal static class StateBatch
{
    /// <summary>The bytes a batch of writes lies as.</summary>
    /// <param name="batch">The states, each with the lanes being written.</param>
    /// <returns>The bytes.</returns>
    internal static byte[] Bytes(IReadOnlyList<(int Number, ulong Mask, double[] Lanes)> batch)
    {
        List<byte> bytes = new(2 + (batch.Count * 32));

        Add(bytes, (ulong)batch.Count, 2);

        foreach ((int number, ulong mask, double[] lanes) in batch)
        {
            Add(bytes, (uint)number, 4);
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
    /// <returns>The states, each with which lanes moved and its own bytes.</returns>
    internal static List<(int Number, ulong Mask, byte[] Bytes)> Read(ReadOnlySpan<byte> bytes)
    {
        List<(int Number, ulong Mask, byte[] Bytes)> read = [];

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

            int number = (int)Number(bytes, at, 4);
            ulong mask = Number(bytes, at + 4, 4) | (Number(bytes, at + 8, 4) << 32);
            int length = (int)Number(bytes, at + 12, 4);

            at += 16;

            if (at + length > bytes.Length)
            {
                return read;
            }

            read.Add((number, mask, bytes.Slice(at, length).ToArray()));
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

    /// <summary>The lanes a number's bytes hold.</summary>
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

    /// <summary>The text a number's bytes hold: its own length, then its own UTF-8.</summary>
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
