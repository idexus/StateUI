// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;
using StateUI.Runtime.Protocol;

/// <summary>
/// The properties a message says to WALK to rather than assign, and the
/// answers they owe when they get there.
/// </summary>
/// <remarks>
/// <para>
/// A flight arrives as an ordinary property change with a
/// <see cref="SwiftTransition"/> beside it. This takes those properties out of
/// the node before the renderer applies it - so the assignment that would have
/// snapped never happens - and starts one MAUI animation per property, from
/// wherever the control is now to the value that arrived.
/// </para>
/// <para>
/// One flight is one CHANNEL, and a channel may cover several properties on
/// several controls: a piece of state armed on three views arrives as three
/// transitions carrying the same number. The Swift handler is resumed once,
/// when the last of them is done, and the answer is true only if all of them
/// ran to the end. Counting works without any "the message is over" moment
/// because every member of a channel is started inside one synchronous apply,
/// and no animation can tick before that apply returns.
/// </para>
/// <para>
/// A property that arrives with NO transition while a walk is under way on it
/// is a plain assignment, and it ENDS the walk: the author wrote the value
/// rather than flying it, and a motion left running would go on writing over
/// what they wrote. That is the one place this class acts on a property nobody
/// said anything about.
/// </para>
/// <para>
/// What actually MOVES is <see cref="MotionEngine"/>; this is the wire's face
/// on it - which properties a message says to walk, which channel is waiting
/// for each, and what the answer is when they land.
/// </para>
/// </remarks>
internal sealed class SwiftFlights
{
    /// <summary>One property of one control, being walked.</summary>
    /// <remarks>
    /// Held under the property's SPELLING, which is the one form both
    /// vocabularies have: the library's own properties have a member name, and
    /// a registered control's own property has nothing else to be called.
    /// </remarks>
    private sealed record Member(
        View View, BindableProperty Property, SwiftKey Key, string Spelling, IMotionTarget Moves);

    /// <summary>How a channel is getting on.</summary>
    private sealed class Channel
    {
        /// <summary>Everything this flight is moving.</summary>
        internal readonly List<Member> Members = [];

        /// <summary>Members started and not yet finished.</summary>
        internal int Pending;

        /// <summary>Whether every member so far ran to the end.</summary>
        internal bool Whole = true;

        /// <summary>
        /// Whether the answer has gone. A guard rather than a nicety: a ticker
        /// that finishes an animation synchronously - which a test's can -
        /// could drop the count to zero between two members starting.
        /// </summary>
        internal bool Answered;
    }

    private readonly Dictionary<int, Channel> _channels = [];

    /// <summary>
    /// What each control is having walked: the property's spelling, and the
    /// key that finds it in whichever bag a message carries it in. A weak table
    /// because a control that has left the tree must not be held by the fact
    /// that something was once animating it.
    /// </summary>
    private readonly ConditionalWeakTable<View, Dictionary<string, SwiftKey>> _walking = new();

    /// <summary>
    /// Whether anything in this subtree is being walked to a value.
    /// </summary>
    /// <remarks>
    /// Asked before a row goes into a pool: a control under an animation the
    /// author started must not change hands, because the walk would go on and
    /// move whichever row adopted it instead. The whole subtree, because the
    /// row that leaves is a subtree and the flight may be on any part of it.
    /// </remarks>
    /// <param name="view">the root of the subtree</param>
    internal bool Walking(View view)
    {
        // Nothing anywhere is flying, which is the answer almost every time
        // this is asked: a channel lives exactly as long as the walk it is
        // answering, so an empty map spares the subtree walk below.
        if (_channels.Count == 0)
        {
            return false;
        }

        if (_walking.TryGetValue(view, out Dictionary<string, SwiftKey>? properties)
            && properties.Count > 0)
        {
            return true;
        }

        foreach (IVisualTreeElement child in ((IVisualTreeElement)view).GetVisualChildren())
        {
            if (child is View below && Walking(below))
            {
                return true;
            }
        }

        return false;
    }

    private readonly Action<int, bool> _land;

    /// <summary>Where a sample of a walk in the air goes.</summary>
    private readonly Action<int, SwiftWireValue> _report;

    /// <summary>What actually moves the values.</summary>
    private readonly MotionEngine _engine;

    /// <summary>
    /// How deep the message being applied is - answers wait for the outermost
    /// one to finish.
    /// </summary>
    /// <remarks>
    /// A channel may cover several controls in one message, and its answer is
    /// owed exactly once, when the last of them is done. That counting needs a
    /// moment where the whole message is known to have been read: a walk that
    /// lands the instant it starts - one of no length, or one on a build with
    /// no frame clock at all - would otherwise drop the count to zero between
    /// two controls and answer twice.
    /// </remarks>
    private int _holding;

    /// <summary>Answers owed once the message being applied is over.</summary>
    private readonly List<(int Channel, bool Whole)> _owed = [];

    /// <summary>
    /// Takes the answer path a completion uses: the channel, and whether it
    /// ran to the end.
    /// </summary>
    /// <param name="engine">What moves the values.</param>
    /// <param name="land">Told a channel is done, and whether it finished.</param>
    /// <param name="report">Told where a watched walk has got to.</param>
    internal SwiftFlights(
        MotionEngine engine, Action<int, bool> land, Action<int, SwiftWireValue> report)
    {
        _engine = engine;
        _land = land;
        _report = report;
    }

    /// <summary>Holds the answers back while a message is being applied.</summary>
    internal void Hold() => _holding++;

    /// <summary>Lets them go, once the outermost message is over.</summary>
    internal void Release()
    {
        if (--_holding > 0 || _owed.Count == 0)
        {
            return;
        }

        (int Channel, bool Whole)[] owed = [.. _owed];
        _owed.Clear();

        foreach ((int channel, bool whole) in owed)
        {
            _land(channel, whole);
        }
    }

    /// <summary>
    /// The properties this node says to walk, lifted OUT of it so the
    /// renderer's ordinary apply cannot assign them.
    /// </summary>
    /// <remarks>
    /// Called before the node is applied and answered after the control is in
    /// hand - which is the only order available, since a flight needs the
    /// control it is about and the control may not exist until the node is
    /// applied.
    /// </remarks>
    /// <param name="node">The node about to be applied.</param>
    /// <returns>What was lifted, empty when nothing was.</returns>
    internal List<(SwiftTransition Transition, SwiftWireValue Target)> Take(SwiftNode node)
    {
        if (node.Transitions is not { Count: > 0 } transitions || node.Props is null)
        {
            return [];
        }

        var taken = new List<(SwiftTransition, SwiftWireValue)>(transitions.Count);

        foreach (SwiftTransition transition in transitions)
        {
            // Out of the bag the property arrived in - the library's by
            // member, an application's own by the name it declared it under.
            SwiftWireValue target = default;

            bool named = transition.Property != SwiftProp.None
                ? node.Props.TryGetValue(transition.Property, out target)
                : node.OwnProps is not null
                    && node.OwnProps.TryGetValue(transition.PropertyName, out target);

            if (!named)
            {
                // A transition names a property the patch is also sending; one
                // without is a message that contradicts itself, and the answer
                // still has to go or the handler waits for ever.
                Refuse(transition);
                continue;
            }

            // NOTHING IS LIFTED THAT CANNOT BE WALKED. A property with no
            // MAUI property behind it, or one whose value has no half-way,
            // is left exactly where it is and applied the ordinary way - so
            // the worst a motion nobody can make costs is that it does not
            // happen, never that the value goes missing.
            if (!Walkable(node, transition, target))
            {
                Refuse(transition);
                continue;
            }

            if (transition.Property != SwiftProp.None)
            {
                node.Props.Remove(transition.Property);
            }
            else
            {
                node.OwnProps!.Remove(transition.PropertyName);
            }

            taken.Add((transition, target));
        }

        return taken;
    }

    /// <summary>
    /// Whether this property is one the engine can carry a control through -
    /// it has a MAUI property behind it, and its value has a half-way.
    /// </summary>
    private static bool Walkable(SwiftNode node, SwiftTransition transition, SwiftWireValue target)
    {
        SwiftKey key = transition.Key;

        if (SwiftStyles.Property(node.Type, node.TypeName, key) is not BindableProperty property)
        {
            return false;
        }

        var carrier = new SwiftNode();

        if (transition.Property != SwiftProp.None)
        {
            carrier.Props = new Dictionary<SwiftProp, SwiftWireValue> { [transition.Property] = target };
        }
        else
        {
            carrier.OwnProps = new Dictionary<string, SwiftWireValue> { [transition.PropertyName] = target };
        }

        return SwiftStyles.Value(property, carrier, key) is object value
            && MotionProperty.Of(
                new Label(), property, value, false, out IMotionTarget _, out double[] _);
    }

    /// <summary>
    /// Says a transition will not be made, once, to whoever is waiting for it.
    /// </summary>
    private void Refuse(SwiftTransition transition)
    {
        if (transition.Channel == 0)
        {
            return;
        }

        Book(transition.Channel);
        Landed(transition.Channel, whole: false);
    }

    /// <summary>
    /// Ends the walks this message overwrote, and starts the ones it asked for.
    /// </summary>
    /// <param name="view">The control the node was applied to.</param>
    /// <param name="node">The node, with the walked properties already lifted.</param>
    /// <param name="taken">What <see cref="Take"/> answered.</param>
    internal void Apply(
        View view,
        SwiftNode node,
        List<(SwiftTransition Transition, SwiftWireValue Target)> taken)
    {
        Interrupt(view, node, taken);

        foreach ((SwiftTransition transition, SwiftWireValue target) in taken)
        {
            Start(view, node.Type, node.TypeName, transition, target);
        }
    }

    /// <summary>
    /// Stops every walk on a channel where it stands, and answers with the
    /// value the FIRST of them had reached.
    /// </summary>
    /// <remarks>
    /// The read comes before the abort, because aborting is what tells the
    /// handler waiting on the flight that it did not run to the end - and that
    /// answer must not overtake this one. One value for a flight that may have
    /// several members: there is one piece of state behind it, so there is one
    /// value to give it back.
    /// </remarks>
    /// <param name="channel">Which flight.</param>
    /// <returns>Where it had got to, or nothing when there was no such flight.</returns>
    internal SwiftWireValue[] Stop(int channel)
    {
        if (!_channels.TryGetValue(channel, out Channel? flight) || flight.Members.Count == 0)
        {
            return [];
        }

        Member first = flight.Members[0];
        SwiftWireValue[] reached = Reached(Showing(first));

        Hold();

        try
        {
            foreach (Member member in flight.Members.ToArray())
            {
                _engine.Halt(member.View, member.Property);
            }
        }
        finally
        {
            Release();
        }

        return reached;
    }

    /// <summary>What a walked property is showing right now.</summary>
    /// <remarks>
    /// From the CHANNEL rather than from the control, because a motion writes
    /// only what a screen could show: a value that has moved less than a
    /// thousandth of a unit since the last frame is not written at all, so the
    /// control can be a frame behind where the walk actually is.
    /// </remarks>
    private object? Showing(Member member) =>
        _engine.Moving(member.View, member.Property) is MotionChannel channel
            ? member.Moves.Compose(channel.P)
            : member.View.GetValue(member.Property);

    /// <summary>
    /// Whether a walk that has run <paramref name="at"/> milliseconds is due to
    /// be reported, given where it was <paramref name="reported"/> last and how
    /// many milliseconds apart the author asked for.
    /// </summary>
    /// <remarks>
    /// On the WALK's clock, not the wall's: the frames are the platform's and
    /// vary with it, while "every 100ms" is a promise about the animation. A
    /// walk starts unreported at negative infinity, so its first step always
    /// says where it began - which the Swift side may not know, the control
    /// having been anywhere at all.
    /// </remarks>
    internal static bool Due(double at, double reported, uint interval) =>
        interval != 0 && at - reported >= interval;

    /// <summary>
    /// Where a walk had got to, as the value the Swift side reads it back as.
    /// </summary>
    /// <remarks>
    /// A colour crosses as a COLOUR - four bytes under its own tag - rather
    /// than as four numbers. A thickness is four numbers, and two values of
    /// one shape would be told apart only by which binding happened to ask.
    /// </remarks>
    private static SwiftWireValue[] Reached(object? value) => value switch
    {
        double number => [SwiftWireValue.Of(number)],
        Color colour =>
        [
            new SwiftWireValue(
                ChannelByte(colour.Red),
                ChannelByte(colour.Green),
                ChannelByte(colour.Blue),
                ChannelByte(colour.Alpha)),
        ],
        Thickness edges =>
            [SwiftWireValue.Of([edges.Left, edges.Top, edges.Right, edges.Bottom])],
        _ => [],
    };

    /// <summary>
    /// One channel, from MAUI's 0-1 float to the byte that crosses. Named for
    /// what it answers rather than what it takes, since <c>Channel</c> here is
    /// a flight in the air.
    /// </summary>
    private static byte ChannelByte(float value) =>
        (byte)Math.Clamp(Math.Round(value * 255), 0, 255);

    /// <summary>
    /// Ends a motion the message assigned over. An author who writes a value
    /// rather than letting it travel means the motion to stop, and one left
    /// running would overwrite what they wrote a frame later.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Every property the node ASSIGNS - one arriving with no transition beside
    /// it - and nothing else. That covers a flight the author interrupted and
    /// the ordinary motion of a value they snapped, which are the same event
    /// seen from two sides. Nothing is written back: the assignment has already
    /// happened.
    /// </para>
    /// <para>
    /// A property a DRIVEN STATE drives is left alone: the value the message states for
    /// one of those is what the tree last heard from the state, and halting the
    /// motion the state started would stop the very journey the message is
    /// describing.
    /// </para>
    /// </remarks>
    private void Interrupt(
        View view,
        SwiftNode node,
        List<(SwiftTransition Transition, SwiftWireValue Target)> taken)
    {
        if (!_engine.Stirring(view))
        {
            return;
        }

        if (node.Props is not null)
        {
            foreach (SwiftProp property in node.Props.Keys)
            {
                if (Walked(taken, property, null))
                {
                    continue;
                }

                if (SwiftStyles.Property(node.Type, node.TypeName, SwiftKey.Of(property, string.Empty))
                    is BindableProperty bindable
                    && _engine.Driven?.Invoke(view, bindable) != true)
                {
                    _engine.Halt(view, bindable, MotionEnd.Nothing);
                }
            }
        }

        if (node.OwnProps is null)
        {
            return;
        }

        foreach (string spelling in node.OwnProps.Keys)
        {
            if (Walked(taken, SwiftProp.None, spelling))
            {
                continue;
            }

            if (SwiftStyles.Property(node.Type, node.TypeName, SwiftKey.Of(SwiftProp.None, spelling))
                is BindableProperty bindable
                && _engine.Driven?.Invoke(view, bindable) != true)
            {
                _engine.Halt(view, bindable, MotionEnd.Nothing);
            }
        }
    }

    /// <summary>Whether this message says to WALK to the named property.</summary>
    private static bool Walked(
        List<(SwiftTransition Transition, SwiftWireValue Target)> taken,
        SwiftProp property,
        string? spelling)
    {
        foreach ((SwiftTransition transition, SwiftWireValue _) in taken)
        {
            if (spelling is null
                ? transition.Property == property
                : transition.Property == SwiftProp.None && transition.PropertyName == spelling)
            {
                return true;
            }
        }

        return false;
    }

    private void Start(
        View view,
        SwiftNodeType type,
        string typeName,
        SwiftTransition transition,
        SwiftWireValue target)
    {
        SwiftKey key = transition.Key;

        // Booked before anything can fail, so a channel whose properties are of
        // no walkable kind is still counted down exactly once. Channel zero is
        // nobody: a value moving because it CHANGED has no handler behind it.
        if (transition.Channel != 0)
        {
            Book(transition.Channel);
        }

        if (SwiftStyles.Property(type, typeName, key) is not BindableProperty property)
        {
            Landed(transition.Channel, whole: false);
            return;
        }

        // The carrier is the shape SwiftValues reads a property off: a node
        // with the one key on it, in the bag that key belongs to. The same
        // conversion a style setter takes, which is what makes a property
        // walkable the moment it is styleable.
        var carrier = new SwiftNode();

        if (transition.Property != SwiftProp.None)
        {
            carrier.Props = new Dictionary<SwiftProp, SwiftWireValue> { [transition.Property] = target };
        }
        else
        {
            carrier.OwnProps = new Dictionary<string, SwiftWireValue> { [transition.PropertyName] = target };
        }

        if (SwiftStyles.Value(property, carrier, key) is not object destination)
        {
            Landed(transition.Channel, whole: false);
            return;
        }

        if (!MotionProperty.Of(
            view, property, destination, Fraction(property),
            out IMotionTarget moves, out double[] to))
        {
            // Not walkable - a string, an enum, a picture. Assign it and say
            // the flight did not run to the end.
            view.SetValue(property, destination);
            Landed(transition.Channel, whole: false);
            return;
        }

        // NOBODY IS WAITING, so there is no member, no channel bookkeeping and
        // nothing to mark this control as being flown - which is what keeps a
        // value's ordinary motion out of the way of the row pool. It is the
        // engine's business alone from here.
        if (transition.Channel == 0)
        {
            _engine.Aim(moves, to, transition.Spec);
            return;
        }

        var member = new Member(view, property, key, transition.PropertyName, moves);
        Enter(transition.Channel, member);

        _engine.Aim(
            moves,
            to,
            transition.Spec,
            done: whole =>
            {
                Left(member);
                Landed(transition.Channel, whole);
            },
            sample: transition.Report == 0 ? null : lanes =>
            {
                if (Reached(moves.Compose(lanes)) is [SwiftWireValue sample])
                {
                    _report(transition.Channel, sample);
                }
            },
            every: transition.Report);
    }

    /// <summary>
    /// Whether a number is a fraction of one, so a curve that overshoots is
    /// held back from asking a platform for something it cannot draw.
    /// </summary>
    private static bool Fraction(BindableProperty property) =>
        property == VisualElement.OpacityProperty;

    // ---- What a walk is made of --------------------------------------------

    /// <summary>
    /// The MAUI easing behind the member Swift sent.
    /// </summary>
    /// <remarks>
    /// A translation by name rather than a cast, for the reason every closed
    /// vocabulary is translated - the wire's numbers are ours, see
    /// <c>Protocol/SwiftWireEnums.cs</c> - and one more besides: MAUI's
    /// <see cref="Easing"/> is a class of STATIC INSTANCES, so there is no enum
    /// on that side to cast to at all. A number this does not know is linear,
    /// which is the same answer MAUI gives for a null easing.
    /// </remarks>
    /// <param name="member">The curve's number, as <see cref="SwiftEasing"/>.</param>
    /// <returns>The easing to walk on.</returns>
    public static Easing Read(int member)
    {
        return (SwiftEasing)member switch
        {
            SwiftEasing.SinOut => Easing.SinOut,
            SwiftEasing.SinIn => Easing.SinIn,
            SwiftEasing.SinInOut => Easing.SinInOut,
            SwiftEasing.CubicIn => Easing.CubicIn,
            SwiftEasing.CubicOut => Easing.CubicOut,
            SwiftEasing.CubicInOut => Easing.CubicInOut,
            SwiftEasing.BounceOut => Easing.BounceOut,
            SwiftEasing.BounceIn => Easing.BounceIn,
            SwiftEasing.SpringIn => Easing.SpringIn,
            SwiftEasing.SpringOut => Easing.SpringOut,
            _ => Easing.Linear,
        };
    }

    /// <summary>
    /// Counts one more property onto a channel, before anything about it is
    /// known.
    /// </summary>
    /// <remarks>
    /// Every transition is booked, walkable or not, which is what makes the
    /// count of what is outstanding the count of what the message named - so a
    /// channel carrying one property that walks and one that cannot is answered
    /// once, at the end, rather than twice.
    /// </remarks>
    private Channel Book(int number)
    {
        if (!_channels.TryGetValue(number, out Channel? channel))
        {
            channel = new Channel();
            _channels[number] = channel;
        }

        channel.Pending++;
        return channel;
    }

    /// <summary>Adds the property a booked transition turned out to be about.</summary>
    private void Enter(int number, Member member)
    {
        Book(number).Members.Add(member);

        // Booked twice - once by Start before anything could fail, once here -
        // so the second is given back at once.
        _channels[number].Pending--;

        _walking.GetValue(member.View, static _ => [])[member.Spelling] = member.Key;
    }

    /// <summary>Forgets a member that has stopped, however it stopped.</summary>
    private void Left(Member member)
    {
        if (_walking.TryGetValue(member.View, out Dictionary<string, SwiftKey>? keys))
        {
            keys.Remove(member.Spelling);
        }
    }

    /// <summary>
    /// One member is done. The Swift handler hears about it when the last of
    /// them is - or at once, when the flight had no member at all.
    /// </summary>
    private void Landed(int number, bool whole)
    {
        if (number == 0)
        {
            // The ordinary motion of a value that changed. Nobody started it
            // and nobody is waiting for it.
            return;
        }

        if (!_channels.TryGetValue(number, out Channel? channel))
        {
            // Nothing was ever booked for this channel: a flight whose property
            // the message named and did not send.
            Answer(number, whole);
            return;
        }

        channel.Whole &= whole;
        channel.Pending--;

        if (channel.Pending > 0 || channel.Answered)
        {
            return;
        }

        channel.Answered = true;
        _channels.Remove(number);
        Answer(number, channel.Whole);
    }

    /// <summary>
    /// Tells whoever is waiting - now, or when the message being applied is
    /// over.
    /// </summary>
    private void Answer(int number, bool whole)
    {
        if (_holding > 0)
        {
            _owed.Add((number, whole));
            return;
        }

        _land(number, whole);
    }
}
