// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using System.Runtime.CompilerServices;
using Microsoft.Maui.Animations;
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
/// rather than flying it, and an animation left ticking would go on writing
/// over what they wrote. That is the one place this class acts on a property
/// nobody said anything about.
/// </para>
/// </remarks>
internal sealed class SwiftFlights
{
    /// <summary>One property of one control, being walked.</summary>
    /// <remarks>
    /// Held under the property's SPELLING, which is the one form both
    /// vocabularies have: MAUI names an animation with a string, and a
    /// registered control's own property has nothing else to be called.
    /// </remarks>
    private sealed record Member(View View, BindableProperty Property, SwiftKey Key, string Spelling)
    {
        /// <summary>MAUI's name for the animation, which is also its identity:
        /// starting a second one of the same name replaces the first.</summary>
        internal string Name => "StateUI." + Spelling;
    }

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

    /// <summary>
    /// Who ticks the walks, when it is not MAUI's own answer.
    /// </summary>
    /// <remarks>
    /// Null in an application, which is what makes MAUI resolve one from the
    /// control's own window - the manager is a per-window service, and asking
    /// the control is how the right window is found. A test has no window and
    /// no handler, so it sets one here; without it MAUI throws rather than
    /// animating, and no walk can be driven past its first tick.
    /// </remarks>
    internal IAnimationManager? Manager { get; set; }

    /// <summary>
    /// Takes the answer path a completion uses: the channel, and whether it
    /// ran to the end.
    /// </summary>
    internal SwiftFlights(Action<int, bool> land, Action<int, SwiftWireValue> report)
    {
        _land = land;
        _report = report;
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
    internal static List<(SwiftTransition Transition, SwiftWireValue Target)> Take(SwiftNode node)
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

            bool lifted = transition.Property != SwiftProp.None
                ? node.Props.Remove(transition.Property, out target)
                : node.OwnProps is not null
                    && node.OwnProps.Remove(transition.PropertyName, out target);

            if (!lifted)
            {
                // A transition names a property the patch is also sending; one
                // without is a message that contradicts itself, and the answer
                // still has to go or the handler waits for ever.
                continue;
            }

            taken.Add((transition, target));
        }

        return taken;
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
        Interrupt(view, node);

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
        SwiftWireValue[] reached = Reached(first.View.GetValue(first.Property));

        foreach (Member member in flight.Members.ToArray())
        {
            member.View.AbortAnimation(member.Name);
        }

        return reached;
    }

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
    /// Ends a walk the message assigned over. An author who writes the value
    /// rather than flying it means the walk to stop, and an animation left
    /// ticking would overwrite what they wrote a frame later.
    /// </summary>
    private void Interrupt(View view, SwiftNode node)
    {
        if (node.Props is null || !_walking.TryGetValue(view, out Dictionary<string, SwiftKey>? keys))
        {
            return;
        }

        foreach ((string spelling, SwiftKey key) in keys.ToArray())
        {
            // The same branch Take reads by, and it has to be: a name the
            // library also has arrives in the library's bag, whoever declared
            // it, so the MEMBER is what says where the value is.
            bool assigned = key.Prop != SwiftProp.None
                ? node.Props.ContainsKey(key.Prop)
                : node.OwnProps?.ContainsKey(spelling) == true;

            if (assigned)
            {
                view.AbortAnimation("StateUI." + spelling);
            }
        }
    }

    private void Start(
        View view,
        SwiftNodeType type,
        string typeName,
        SwiftTransition transition,
        SwiftWireValue target)
    {
        SwiftKey key = transition.Key;

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

        Func<double, object>? walk = Transform(view.GetValue(property), destination);

        if (walk is null)
        {
            // Not walkable - a string, an enum, a brush. Assign it and say the
            // flight did not run to the end.
            view.SetValue(property, destination);
            Landed(transition.Channel, whole: false);
            return;
        }

        var member = new Member(view, property, key, transition.PropertyName);
        Enter(transition.Channel, member);

        // How far along the WALK is, kept by the transform for the callback
        // that follows it. MAUI hands the callback the value, not the fraction,
        // and the fraction is what a stated cadence has to be measured on: a
        // report "every 100ms" means 100ms of the walk, however the frames fall.
        double progress = 0;
        double reported = double.NegativeInfinity;

        try
        {
            view.Animate(
                member.Name,
                t =>
                {
                    progress = t;
                    return walk(t);
                },
                step =>
                {
                    view.SetValue(property, step);

                    if (transition.Report == 0)
                    {
                        return;
                    }

                    double at = progress * transition.Length;

                    if (!Due(at, reported, transition.Report))
                    {
                        return;
                    }

                    reported = at;

                    if (Reached(step) is [SwiftWireValue sample])
                    {
                        _report(transition.Channel, sample);
                    }
                },
                rate: Rate,
                length: transition.Length,
                easing: Read(transition.Easing),
                finished: (_, cancelled) =>
                {
                    Left(member);
                    Landed(transition.Channel, whole: !cancelled);
                },
                animationManager: Manager);
        }
        catch (ArgumentException)
        {
            // MAUI could find nothing to tick this with - a control that is not
            // in a window yet, which is a real state and not a mistake. Assign
            // the value and say the walk did not happen, because a flight that
            // silently never answered would leave its handler suspended for the
            // life of the app.
            Left(member);
            view.SetValue(property, destination);
            Landed(transition.Channel, whole: false);
        }
    }


    // ---- The engine: what a value does on the way to another ----------------

    /// <summary>MAUI's own step rate, sixteen milliseconds.</summary>
    internal const uint Rate = 16;

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
    /// A function from "how far through" to the value at that point, or null
    /// when the two values are of a type that cannot be walked between.
    /// </summary>
    /// <remarks>
    /// Three kinds walk: a double, a colour and a Thickness. A Size does not -
    /// it is not a property any MAUI control exposes - while a padding is, which
    /// is why the Thickness is here.
    /// </remarks>
    internal static Func<double, object>? Transform(object? from, object to)
    {
        // A property that has never been set reads as its MAUI default, so
        // `from` is only null where the default is - a colour, most often, which
        // starts the walk from transparent rather than from nothing.
        return (from, to) switch
        {
            (double start, double end) => t => Number(start, end, t),
            (null, double end) => t => Number(0, end, t),

            (Color start, Color end) => t => Blend(start, end, t),
            (null, Color end) => t => Blend(Colors.Transparent, end, t),

            (Thickness start, Thickness end) => t => Between(start, end, t),
            (null, Thickness end) => t => Between(default, end, t),

            _ => null,
        };
    }

    /// <summary>One number on the way to another.</summary>
    /// <remarks>
    /// A width that has never been asked for is <c>-1</c> in MAUI, so animating
    /// one from its default walks up from below zero. That is MAUI's value and
    /// not something to be helpful about: a view whose size is to be animated is
    /// one whose size was set.
    /// </remarks>
    private static double Number(double from, double to, double t) => from + (t * (to - from));

    /// <summary>One colour on the way to another, channel by channel.</summary>
    private static Color Blend(Color from, Color to, double t)
    {
        return new Color(
            (float)Number(from.Red, to.Red, t),
            (float)Number(from.Green, to.Green, t),
            (float)Number(from.Blue, to.Blue, t),
            (float)Number(from.Alpha, to.Alpha, t));
    }

    /// <summary>One set of edges on the way to another, edge by edge.</summary>
    private static Thickness Between(Thickness from, Thickness to, double t)
    {
        return new Thickness(
            Number(from.Left, to.Left, t),
            Number(from.Top, to.Top, t),
            Number(from.Right, to.Right, t),
            Number(from.Bottom, to.Bottom, t));
    }
    /// <summary>Books one more member onto a channel.</summary>
    private void Enter(int number, Member member)
    {
        if (!_channels.TryGetValue(number, out Channel? channel))
        {
            channel = new Channel();
            _channels[number] = channel;
        }

        channel.Members.Add(member);
        channel.Pending++;

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
        if (!_channels.TryGetValue(number, out Channel? channel))
        {
            // Nothing was ever started for this channel: a property that could
            // not be walked, or one the message named and did not send.
            _land(number, whole);
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
        _land(number, channel.Whole);
    }
}
