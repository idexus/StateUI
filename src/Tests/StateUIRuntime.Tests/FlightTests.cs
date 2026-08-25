// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host's half of a flight: a property that arrives with a walk beside it
// is NOT assigned, it is animated - and the channel it named is answered.
//
// The Swift half is FlightTests.swift, and `fixtures/flying.bin` is where the
// two meet: Swift wrote it, this reads it.

using Microsoft.Maui.Animations;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class FlightTests
{
    /// <summary>
    /// A ticker nobody drives. MAUI needs an <c>IAnimationManager</c> to start
    /// an animation at all, and it finds one through the control's window -
    /// which a test has none of.
    /// </summary>
    /// <remarks>
    /// <c>SystemEnabled</c> is TRUE deliberately. With it false MAUI's Tweener
    /// finishes the animation SYNCHRONOUSLY inside <c>Start</c>, applying the
    /// final value and then reporting cancelled=true - the right value with the
    /// wrong answer, which is exactly the confusion the finished-flag inversion
    /// already cost this project one round.
    /// </remarks>
    private sealed class StillTicker : ITicker
    {
        public int MaxFps { get; set; } = 60;

        public bool IsRunning { get; private set; }

        public bool SystemEnabled => true;

        public Action? Fire { get; set; }

        public void Start() => IsRunning = true;

        public void Stop() => IsRunning = false;
    }

    /// <summary>
    /// The flight message, read the way a session reads it: the opening
    /// message first, through the SAME dictionary, because that is where the
    /// names it uses were announced.
    /// </summary>
    private static SwiftNode Flight()
    {
        var names = new SwiftWireDictionary();
        _ = SwiftWire.ReadMessage(Fixtures.ReadBytes("flying-first.bin"), names);
        return SwiftWire.ReadMessage(Fixtures.ReadBytes("flying.bin"), names).Root!;
    }

    private static Host Flying()
    {
        var host = new Host();
        host.Renderer.Flights.Manager = new AnimationManager(new StillTicker());
        return host;
    }

    /// <summary>
    /// The wire's side of it: a transition decodes as a property, a length, a
    /// curve and a channel, and the property it names is in the props beside
    /// it, carrying the TARGET.
    /// </summary>
    [Fact]
    public void AFlightArrivesAsAWalkBesideTheValueItIsAbout()
    {
        SwiftNode border = Flight();

        SwiftTransition transition = Assert.Single(border.Transitions!);
        Assert.Equal(SwiftProp.Opacity, transition.Property);
        Assert.Equal("opacity", transition.PropertyName);
        Assert.Equal(400u, transition.Length);
        Assert.Equal((int)SwiftEasing.CubicOut, transition.Easing);
        Assert.Equal(-1, transition.Channel);

        Assert.Equal(0.25, border.GetNumber(SwiftProp.Opacity));
    }

    /// <summary>
    /// The interception: what is being walked to is lifted out of the node
    /// before it is applied, so the renderer cannot assign it. Without this the
    /// control would jump to the target and then animate from it to itself.
    /// </summary>
    [Fact]
    public void AWalkedPropertyIsLiftedOutOfTheNodeSoNothingAssignsIt()
    {
        SwiftNode border = Flight();
        Assert.True(border.Props!.ContainsKey(SwiftProp.Opacity));

        var taken = SwiftFlights.Take(border);

        Assert.Single(taken);
        Assert.False(border.Props.ContainsKey(SwiftProp.Opacity), "the walk's property does not stay");
        Assert.Equal(0.25, taken[0].Target.Number);
    }

    /// <summary>
    /// Applied for real: the border keeps the opacity it had, because the
    /// target is where it is GOING. A snap here would be the whole round
    /// failing quietly.
    /// </summary>
    [Fact]
    public void ApplyingAFlightWalksTheControlRatherThanSettingIt()
    {
        Host host = Flying();

        // The first message builds the border at the opacity it starts from.
        var border = (Border)host.ApplyMessage(Fixtures.ReadBytes("flying-first.bin"));
        Assert.Equal(1, border.Opacity);

        host.ApplyMessage(Fixtures.ReadBytes("flying.bin"));

        Assert.Equal(1, border.Opacity, 3);
        Assert.Empty(host.Raw);

        // Whoever the walk belongs to hears the moment it is stopped, and hears
        // that it did NOT run to the end.
        border.AbortAnimation("StateUI.opacity");

        (int Id, byte[]? Bytes) answer = Assert.Single(host.Raw);
        Assert.Equal(-1, answer.Id);
        Assert.False(Answer(answer.Bytes), "an aborted walk did not run to the end");
    }

    /// <summary>
    /// A property no walk exists for is ASSIGNED and answered false: the value
    /// still arrives, only the glide does not - and the handler waiting on it
    /// is never left suspended.
    /// </summary>
    [Fact]
    public void APropertyThatCannotBeWalkedIsSetAndSaysSo()
    {
        Host host = Flying();

        var label = (Label)host.ApplyMessage(
            (new SwiftNode
            {
                Id = new SwiftId(1),
                Type = SwiftNodeType.Label,
                Props = new Dictionary<SwiftProp, SwiftWireValue>
                {
                    [SwiftProp.Text] = SwiftWireValue.Of("walked"),
                },
                Transitions =
                [
                    new SwiftTransition(SwiftProp.Text, "text", 200, (int)SwiftEasing.Linear, -7),
                ],
            }));

        Assert.Equal("walked", label.Text);

        (int Id, byte[]? Bytes) answer = Assert.Single(host.Raw);
        Assert.Equal(-7, answer.Id);
        Assert.False(Answer(answer.Bytes), "nothing was walked, so nothing ran to the end");
    }

    /// <summary>
    /// A plain assignment to a property that is being walked ENDS the walk.
    /// The author wrote the value rather than flying it, and an animation left
    /// ticking would write over what they wrote a frame later.
    /// </summary>
    [Fact]
    public void AssigningAPropertyThatIsBeingWalkedStopsTheWalk()
    {
        Host host = Flying();

        var border = (Border)host.ApplyMessage(Fixtures.ReadBytes("flying-first.bin"));
        host.ApplyMessage(Fixtures.ReadBytes("flying.bin"));
        Assert.Empty(host.Raw);

        // The same property again, this time with nothing beside it.
        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Border,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Opacity] = SwiftWireValue.Of(0.5),
            },
        });

        Assert.Equal(0.5, border.Opacity);

        (int Id, byte[]? Bytes) answer = Assert.Single(host.Raw);
        Assert.Equal(-1, answer.Id);
        Assert.False(Answer(answer.Bytes), "the walk was ended, not finished");
    }

    /// <summary>
    /// Stopping a flight answers where the control had got to, so the Swift
    /// side can put the tree and the control back on speaking terms.
    /// </summary>
    [Fact]
    public void StoppingAFlightAnswersWhereItHadGotTo()
    {
        Host host = Flying();

        var border = (Border)host.ApplyMessage(Fixtures.ReadBytes("flying-first.bin"));
        host.ApplyMessage(Fixtures.ReadBytes("flying.bin"));

        // Nothing has ticked, so it is still where it started - which is what
        // this answers, and what the state is then written with.
        SwiftWireValue[] reached = host.Renderer.Flights.Stop(-1);

        Assert.Equal(1.0, Assert.Single(reached).Number);
        Assert.False(border.AnimationIsRunning("StateUI.opacity"));

        (int Id, byte[]? Bytes) answer = Assert.Single(host.Raw);
        Assert.Equal(-1, answer.Id);
        Assert.False(Answer(answer.Bytes), "a stopped walk did not run to the end");
    }

    // ---- Being watched: the cadence, and what crosses -----------------------

    /// <summary>
    /// A watched walk says so on the wire, in one field of the transition and
    /// nowhere else - everything about it is a walk like any other.
    /// </summary>
    [Fact]
    public void AWatchedWalkCarriesTheCadenceTheAuthorStated()
    {
        var names = new SwiftWireDictionary();
        _ = SwiftWire.ReadMessage(Fixtures.ReadBytes("flying-first.bin"), names);
        SwiftNode border = SwiftWire.ReadMessage(
            Fixtures.ReadBytes("flying-watched.bin"), names).Root!;

        SwiftTransition transition = Assert.Single(border.Transitions!);

        Assert.Equal(100u, transition.Report);
        Assert.Equal(400u, transition.Length);
        Assert.Equal(-1, transition.Channel);
    }

    /// <summary>
    /// A walk nobody is watching says 0, which is what keeps an unwatched
    /// flight two crossings and not sixty.
    /// </summary>
    [Fact]
    public void AWalkNobodyWatchesReportsNothing()
    {
        Assert.Equal(0u, Assert.Single(Flight().Transitions!).Report);
        Assert.False(SwiftFlights.Due(400, double.NegativeInfinity, 0));
    }

    /// <summary>
    /// The cadence is measured on the WALK's clock: a report is due when the
    /// animation has run another interval, whatever the frames did. The first
    /// step is always due, because where a walk BEGAN is something the Swift
    /// side may not know - the control could have been anywhere.
    /// </summary>
    [Fact]
    public void AReportIsDueEveryIntervalOfTheWalkAndAtItsStart()
    {
        Assert.True(SwiftFlights.Due(0, double.NegativeInfinity, 100), "the first step");
        Assert.False(SwiftFlights.Due(50, 0, 100), "not yet halfway to the next");
        Assert.True(SwiftFlights.Due(100, 0, 100), "exactly an interval on");
        Assert.True(SwiftFlights.Due(260, 100, 100), "a long frame does not lose one");
    }

    /// <summary>
    /// A watched walk samples: where the control has got to goes out the REPORT
    /// door under the channel that asked, and a colour goes as a COLOUR - four
    /// channels under their own tag, not as four numbers.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The shape matters as much as the value. A thickness is four numbers on
    /// this wire, so a colour sent as four numbers would be read back into the
    /// wrong kind of state by whichever binding happened to be watching, and
    /// nothing would fail: the count is the same.
    /// </para>
    /// <para>
    /// A sample says where the walk IS and nothing about its being over, so it
    /// goes out a different door: <see cref="Host.Reported"/> rather than
    /// <see cref="Host.Dispatched"/>, which is the door an event and a landing
    /// share.
    /// </para>
    /// <para>
    /// The FIRST step of a walk runs the moment MAUI commits it, before any
    /// frame falls, which is what makes the opening sample something a test can
    /// assert exactly. A frame after that carries wherever the wall clock had
    /// got to by then, so only its shape is pinned here; the cadence itself is
    /// arithmetic and is pinned by
    /// <see cref="AReportIsDueEveryIntervalOfTheWalkAndAtItsStart"/>.
    /// </para>
    /// <para>
    /// That there is a walk at all is the other half: the target is turned into
    /// a MAUI <c>Color</c> by <c>SwiftStyles</c>, the same table a style setter
    /// is resolved through, which is what keeps a property animatable the
    /// moment it becomes styleable. A target the table could not read would be
    /// assigned instead, and this would see a landing rather than a sample.
    /// </para>
    /// </remarks>
    [Fact]
    public void AWatchedColourWalkReportsWhereItHasGotToAsAColour()
    {
        var ticker = new StillTicker();
        var host = new Host();
        host.Renderer.Flights.Manager = new AnimationManager(ticker);

        // Black to white, so the value the first sample carries is one no other
        // channel of the record could be mistaken for.
        var border = (Border)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Border,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.BackgroundColor] = new SwiftWireValue(0, 0, 0, 255),
            },
        });

        Assert.Equal(Colors.Black, border.BackgroundColor);

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Border,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.BackgroundColor] = new SwiftWireValue(255, 255, 255, 255),
            },
            Transitions =
            [
                new SwiftTransition(
                    SwiftProp.BackgroundColor,
                    "backgroundColor",
                    400,
                    (int)SwiftEasing.Linear,
                    -4,
                    Report: 100),
            ],
        });

        // Where the walk BEGAN, which the Swift side may not know - the control
        // could have been anywhere - and the reason the first step is always
        // due. Opaque black, so alpha leading is unmistakable.
        (int Channel, string? Sample) opening = host.Reported[0];
        Assert.Equal(-4, opening.Channel);
        Assert.Equal("color FF000000", opening.Sample);

        // One frame on. Whatever it reached, it is still a colour and still on
        // the channel that asked for it.
        ticker.Fire!();

        Assert.All(host.Reported, sample =>
        {
            Assert.Equal(-4, sample.Channel);
            Assert.StartsWith("color ", sample.Sample);
        });

        // A sample is not a landing, and it is not an event either.
        Assert.Empty(host.Dispatched);
    }

    // ---- What walking from one value to another means ----------------------

    [Fact]
    public void ANumberIsWalkedInAStraightLine()
    {
        Func<double, object> walk = SwiftFlights.Transform(10.0, 20.0)!;

        Assert.Equal(10.0, walk(0));
        Assert.Equal(15.0, walk(0.5));
        Assert.Equal(20.0, walk(1));
    }

    [Fact]
    public void AColourIsWalkedChannelByChannel()
    {
        Func<double, object> walk = SwiftFlights.Transform(Colors.Black, Colors.White)!;

        var half = (Color)walk(0.5);

        Assert.Equal(0.5f, half.Red, 3);
        Assert.Equal(0.5f, half.Green, 3);
        Assert.Equal(0.5f, half.Blue, 3);
        Assert.Equal(1f, half.Alpha, 3);
    }

    /// <summary>
    /// Alpha is a channel like any other, which is what makes a colour fade to
    /// nothing rather than to black.
    /// </summary>
    [Fact]
    public void AColourWalksItsAlphaAsWell()
    {
        Func<double, object> walk = SwiftFlights.Transform(Colors.Red, Colors.Transparent)!;

        Assert.Equal(0.5f, ((Color)walk(0.5)).Alpha, 3);
        Assert.Equal(0f, ((Color)walk(1)).Alpha, 3);
    }

    [Fact]
    public void FourEdgesAreWalkedOneByOne()
    {
        Func<double, object> walk =
            SwiftFlights.Transform(new Thickness(0), new Thickness(4, 8, 12, 16))!;

        var half = (Thickness)walk(0.5);

        Assert.Equal(new Thickness(2, 4, 6, 8), half);
    }

    /// <summary>
    /// A property that has never been set reads as MAUI's default, which for a
    /// colour is null - so the walk starts from transparent rather than
    /// refusing.
    /// </summary>
    [Fact]
    public void AColourThatWasNeverSetIsWalkedFromTransparent()
    {
        Func<double, object> walk = SwiftFlights.Transform(null, Colors.Red)!;

        Assert.Equal(0f, ((Color)walk(0)).Alpha, 3);
        Assert.Equal(1f, ((Color)walk(1)).Alpha, 3);
    }

    [Fact]
    public void AValueOfNoWalkableTypeHasNoTransform()
    {
        Assert.Null(SwiftFlights.Transform("one", "two"));
        Assert.Null(SwiftFlights.Transform(FontAttributes.None, FontAttributes.Bold));
    }

    // ---- The easing table ---------------------------------------------------

    /// <summary>
    /// Every member of the easing vocabulary, so a case added to the mirror
    /// without an arm behind it fails here rather than animating linearly.
    /// </summary>
    /// <remarks>
    /// The members as plain numbers, because <c>SwiftEasing</c> is internal
    /// and a theory's data has to be public - which is honest enough here:
    /// what crosses the wire IS the number.
    /// </remarks>
    public static TheoryData<int> Easings =>
        [.. Enum.GetValues<SwiftEasing>().Select(kind => (int)kind)];

    [Theory]
    [MemberData(nameof(Easings))]
    public void EveryEasingSwiftCanWriteHasAMauiOneBehindIt(int member)
    {
        Easing easing = SwiftFlights.Read(member);

        // Named rather than merely non-null: every arm but linear has to be a
        // DIFFERENT curve, or a missing case would read as a pass.
        Assert.Equal(member == (int)SwiftEasing.Linear, ReferenceEquals(easing, Easing.Linear));
    }

    /// <summary>
    /// An easing member from a newer Swift side than this runtime is linear,
    /// which is what MAUI does with a null one. The curve is a closed
    /// vocabulary, so what arrives is the number both sides give the member.
    /// </summary>
    [Fact]
    public void AnEasingThisSideDoesNotKnowIsLinear()
    {
        // 9999 rather than a null: an easing is a slot in the transition
        // record, always present, so the only way to be handed one this side
        // does not know is a Swift side that has grown a curve.
        Assert.Same(Easing.Linear, SwiftFlights.Read(9999));
        Assert.Same(Easing.Linear, SwiftFlights.Read(-1));
    }

    /// <summary>
    /// The one bool in a reply - <c>[version][ok][count][tag]</c>, read by hand
    /// the way the tests read a payload rather than through the writer.
    /// </summary>
    private static bool Answer(byte[]? reply)
    {
        Assert.NotNull(reply);
        Assert.Equal(4, reply.Length);
        Assert.Equal(SwiftWire.Version, reply[0]);
        Assert.Equal(1, reply[1]);
        Assert.Equal(1, reply[2]);
        return reply[3] == 2;
    }
}
