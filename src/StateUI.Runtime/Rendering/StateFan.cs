// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Controls;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// One state's value on this side: the one channel every control tied to the
/// number is written from.
/// </summary>
/// <remarks>
/// <para>
/// ONE STATE, ONE CHANNEL, HOWEVER MANY CONTROLS WEAR IT. A state is one
/// value, and a control handed it holds a HANDLE on that value rather than a
/// value of its own: where it is, how fast it is going and where it is bound
/// are worked out once per state, on this channel, and every tie is written
/// from the same lanes on the same frame. So two controls on one number can
/// never stand in two places, a control tied while the value is on its way
/// joins it where it IS, and the image hears one reading of the number per
/// cycle rather than one per control - which, with a reading per control,
/// left which of two positions the state quoted to an unstable sort.
/// </para>
/// <para>
/// A REPORT FROM ANY ONE OF THEM IS THE VALUE MOVING: the channel lets go
/// where the reader put it and every other tie is written that number at once.
/// They ARRIVE rather than travel - the reader has the thumb under their
/// finger, and a value gliding after it would be late every frame.
/// </para>
/// <para>
/// WHAT STAYS PER CONTROL is a decision somebody else makes about ONE
/// control's property - a visual state, a value the tree states beside the
/// registration - which rides that control's own (control, property) channel
/// exactly as it does on a control no state drives. While such a channel is
/// moving this one leaves that control alone, and the moment it lands the
/// control takes the state's writes again. The state is not told about it: a
/// button disabled to grey is a button that looks grey, not a colour that
/// turned grey, and the other controls on the number stay the colour.
/// </para>
/// <para>
/// It is the ENGINE's target, and owns its channel the way a control owns
/// one - the table is weak in the owner, and this object lives exactly as long
/// as the cycle keeps the number. A channel still moving when the last tie
/// goes runs to its landing and tells the state where it got to; nothing is
/// there to be written, and the waiter hears the truth about the value.
/// </para>
/// </remarks>
internal sealed class StateFan : IMotionTarget
{
    /// <summary>The one key a state's channel is filed under.</summary>
    internal static readonly object Slot = new();

    private readonly MotionEngine _engine;
    private readonly List<StateTie> _ties = [];
    private int _lanes = 1;
    private bool _shaped;

    /// <summary>The fan of one number, with nothing tied to it yet.</summary>
    /// <param name="number">The number the value rides on.</param>
    /// <param name="engine">What moves the values.</param>
    internal StateFan(int number, MotionEngine engine)
    {
        Number = number;
        _engine = engine;
    }

    /// <summary>The number the value rides on.</summary>
    internal int Number { get; }

    /// <summary>Every tie on the number, in the order they registered.</summary>
    internal IReadOnlyList<StateTie> Ties => _ties;

    /// <summary>Whether nothing is tied to the number any more.</summary>
    internal bool Empty => _ties.Count == 0;

    /// <summary>The channel carrying the value, or null while it stands still.</summary>
    internal MotionChannel? Moving => _engine.Moving(this, Slot);

    /// <summary>What to call the value in a trace.</summary>
    internal string Name
    {
        get
        {
            foreach (StateTie tie in _ties)
            {
                if (tie.Kind == SwiftStateKind.Property)
                {
                    return $"state{Number}.{tie.Property?.PropertyName ?? "scroll"}";
                }
            }

            return $"state{Number}";
        }
    }

    /// <summary>
    /// Whether the number wants to hear where the value got to - any journey
    /// that crosses back, or a channel nothing wears any more, whose landing
    /// is still the value's.
    /// </summary>
    internal bool Reports
    {
        get
        {
            bool journey = false;

            foreach (StateTie tie in _ties)
            {
                if (tie.Kind != SwiftStateKind.Property)
                {
                    continue;
                }

                if (tie.Mode != SwiftStateMode.Out)
                {
                    return true;
                }

                journey = true;
            }

            return !journey;
        }
    }

    /// <summary>Whether any journey on the number is worn by a control still there.</summary>
    internal bool Wears
    {
        get
        {
            foreach (StateTie tie in _ties)
            {
                if (tie.Kind == SwiftStateKind.Property
                    && tie.Mode != SwiftStateMode.In
                    && tie.View is not null)
                {
                    return true;
                }
            }

            return false;
        }
    }

    /// <summary>Whether a journey rides the number at all.</summary>
    internal bool Journeys
    {
        get
        {
            foreach (StateTie tie in _ties)
            {
                if (tie.Kind == SwiftStateKind.Property)
                {
                    return true;
                }
            }

            return false;
        }
    }

    /// <inheritdoc/>
    public object Owner => this;

    /// <inheritdoc/>
    public object Key => Slot;

    /// <inheritdoc/>
    public int Lanes => _lanes;

    /// <summary>Ties a control's property to the number.</summary>
    /// <remarks>
    /// The value's shape is the first journey's: every tie on one number
    /// carries the same state, so they cannot disagree about its width.
    /// </remarks>
    /// <param name="tie">The tie.</param>
    internal void Add(StateTie tie)
    {
        tie.Fan = this;

        if (!_shaped && tie.Kind == SwiftStateKind.Property)
        {
            _lanes = tie.Lanes;
            _shaped = true;
        }

        _ties.Add(tie);
    }

    /// <summary>Unties a control's property from the number.</summary>
    /// <param name="tie">The tie.</param>
    internal void Remove(StateTie tie) => _ties.Remove(tie);

    /// <summary>Drops every tie whose control has been collected.</summary>
    /// <returns>How many ties are left.</returns>
    internal int Prune()
    {
        _ties.RemoveAll(static tie => tie.View is null);
        return _ties.Count;
    }

    /// <summary>Stops the channel, leaving the value where the end says.</summary>
    /// <param name="end">Where to leave it.</param>
    /// <returns>Whether anything was moving.</returns>
    internal bool Halt(MotionEnd end) => _engine.Halt(this, Slot, end);

    /// <inheritdoc/>
    public bool Read(double[] into)
    {
        foreach (StateTie tie in _ties)
        {
            if (tie.Kind == SwiftStateKind.Property && tie.Read(into))
            {
                return true;
            }
        }

        return false;
    }

    /// <inheritdoc/>
    public void Write(double[] from)
    {
        foreach (StateTie tie in _ties)
        {
            if (tie.Kind != SwiftStateKind.Property || tie.Mode == SwiftStateMode.In)
            {
                continue;
            }

            // SOMEBODY ELSE'S DECISION ABOUT THIS ONE CONTROL, until it lands.
            if (tie.Property is BindableProperty own
                && tie.View is BindableObject held
                && _engine.Moving(held, own) is not null)
            {
                continue;
            }

            tie.Write(from);
        }
    }

    /// <inheritdoc/>
    public object Compose(double[] from)
    {
        foreach (StateTie tie in _ties)
        {
            if (tie.Kind == SwiftStateKind.Property && tie.Compose(from) is object value)
            {
                return value;
            }
        }

        return (double[])from.Clone();
    }

    /// <summary>
    /// Writes every tie, as this side's own write.
    /// </summary>
    /// <remarks>
    /// Under <see cref="MotionEngine.Writing"/>, for the reason
    /// <see cref="StateTie.Set(double[])"/> gives: the platform raises each
    /// property's changed notification synchronously inside the assignment,
    /// and that notification is this side's own value coming round.
    /// </remarks>
    /// <param name="lanes">The value, lane by lane.</param>
    private void Written(double[] lanes)
    {
        MotionEngine.Writing++;

        try
        {
            Write(lanes);
        }
        finally
        {
            MotionEngine.Writing--;
        }
    }

    /// <summary>
    /// A control joining the number: written where the value is, and no more
    /// than that.
    /// </summary>
    /// <remarks>
    /// A value on its way is joined where it has GOT to - the channel's own
    /// lanes, which the next frame carries on from, so the newcomer and the
    /// controls already riding are one picture from the first frame. A value
    /// standing still is landed as the image says it, and aimed at where the
    /// image says it is going if that is somewhere else, which is what a
    /// control born under a setpoint nobody was walking needs.
    /// </remarks>
    /// <param name="tie">The tie joining.</param>
    /// <param name="bytes">The state, whole.</param>
    internal void Join(StateTie tie, byte[] bytes)
    {
        if (Moving is MotionChannel carrying)
        {
            MotionEngine.Writing++;

            try
            {
                tie.Write(carrying.P);
            }
            finally
            {
                MotionEngine.Writing--;
            }

            return;
        }

        double[] lanes = StateBatch.Lanes(bytes);
        int width = _lanes;

        if (lanes.Length < (width * 3) + 5)
        {
            return;
        }

        MotionEngine.Writing++;

        try
        {
            tie.Write(lanes[..width]);
        }
        finally
        {
            MotionEngine.Writing--;
        }

        double[] setPoint = lanes[width..(width * 2)];

        if (!StateTie.Same(lanes[..width], setPoint))
        {
            _engine.Aim(this, setPoint, StateTie.Law(lanes, width, _engine));
        }
    }

    /// <summary>
    /// The value the READER moved on one control, onto every other.
    /// </summary>
    /// <remarks>
    /// The channel lets go without a write - the platform has just written
    /// the control the reader touched, and the others are written here - and
    /// whoever was waiting on it hears that it did not arrive. Whatever else
    /// was carrying one of the other controls' property lets go too: the
    /// reader's number is the value now, on every control that shows it.
    /// </remarks>
    /// <param name="by">The tie the report came through.</param>
    /// <param name="lanes">Where the reader left the value, lane by lane.</param>
    internal void Taken(StateTie by, double[] lanes)
    {
        Halt(MotionEnd.Nothing);

        MotionEngine.Writing++;

        try
        {
            foreach (StateTie tie in _ties)
            {
                if (ReferenceEquals(tie, by)
                    || tie.Kind != SwiftStateKind.Property
                    || tie.Mode == SwiftStateMode.In
                    || tie.Lanes != lanes.Length)
                {
                    continue;
                }

                if (tie.Property is BindableProperty own && tie.View is BindableObject held)
                {
                    _engine.Halt(held, own, MotionEnd.Nothing);
                }

                tie.Write(lanes);
            }
        }
        finally
        {
            MotionEngine.Writing--;
        }
    }

    /// <summary>
    /// What a cycle wrote onto the number, onto the channel.
    /// </summary>
    /// <remarks>
    /// THE BITS OF ONE MASK APPLY IN ONE ORDER: stop, then the value, then
    /// where it is going, then how fast, then the law. So a handler that stops
    /// a movement and starts another in the same breath ends the first and
    /// gets a fresh one, rather than the other way round.
    /// </remarks>
    /// <param name="bytes">The state, whole.</param>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="land">Told a completion is done, and whether it finished.</param>
    internal void Wear(byte[] bytes, ulong mask, Action<int, bool> land)
    {
        double[] lanes = StateBatch.Lanes(bytes);
        int width = _lanes;

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
            if (Halt(MotionEnd.Here) && waiter != 0)
            {
                land(waiter, false);
            }
        }

        if ((mask & values) != 0)
        {
            // A VALUE WRITTEN IS A SNAP: whatever was carrying it lets go
            // without a word, because the author has just written it.
            Halt(MotionEnd.Nothing);
            Written(lanes[..width]);
        }

        if ((mask & setPoints) != 0)
        {
            double[] speed = lanes[(width * 2)..(width * 3)];
            bool kicked = (mask & speeds) != 0;

            if (Wears)
            {
                _engine.Aim(
                    this,
                    lanes[width..(width * 2)],
                    StateTie.Law(lanes, width, _engine),
                    done: waiter == 0 ? null : whole => land(waiter, whole),
                    velocity: kicked ? StateTie.PerFrame(speed) : null);
            }
            else if (waiter != 0)
            {
                // NOTHING WEARS THIS VALUE, so there is nobody to walk it: it
                // is already where it was sent, and whoever awaited it hears
                // that it arrived rather than waiting for a walk that no
                // control will ever make.
                land(waiter, true);
            }

            return;
        }

        if ((mask & speeds) != 0 && Wears)
        {
            // A SPEED ON ITS OWN is a kick: what is moving bends, and what is
            // still leaves and comes back.
            double[] going = lanes[(width * 2)..(width * 3)];
            double[] target = Moving is MotionChannel channel
                ? channel.Target
                : lanes[width..(width * 2)];

            _engine.Aim(this, target, StateTie.Law(lanes, width, _engine), velocity: StateTie.PerFrame(going));
        }
    }

    /// <summary>
    /// Where the value stands, for the image - or null where nothing has
    /// written it since the last cycle.
    /// </summary>
    /// <remarks>
    /// The channel's own P and V, so what the image says is where the value
    /// actually got to. The speed crosses per SECOND, which is what an author
    /// writes and reads; the engine keeps it per millisecond.
    /// </remarks>
    /// <returns>Which lanes are being reported and the whole value.</returns>
    internal (ulong Mask, double[] Lanes)? Reading()
    {
        if (Moving is not MotionChannel channel || !channel.Observed)
        {
            return null;
        }

        channel.Observed = false;

        int width = _lanes;
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
    /// Where the value is and where it is going, for the image - what a
    /// decision made on the channel by somebody other than the state looks
    /// like from the state's side.
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
        int width = _lanes;

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
    /// Asks every control whose size the value is to measure again - what a
    /// size that lands inside a frame owes on Android, where a measure asked
    /// for during the platform's own layout or draw phase is served on a frame
    /// that never comes. See <see cref="MotionEngine"/>'s landing.
    /// </summary>
    internal void Remeasure()
    {
        foreach (StateTie tie in _ties)
        {
            if ((tie.Property == VisualElement.WidthRequestProperty
                    || tie.Property == VisualElement.HeightRequestProperty)
                && tie.View is VisualElement sized)
            {
                sized.Dispatcher.Dispatch(sized.InvalidateMeasure);
            }
        }
    }
}
