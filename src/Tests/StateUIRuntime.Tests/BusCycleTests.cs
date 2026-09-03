// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host's half of the image: what a REGISTRATION lands on a control, and
// what a cycle's answer is worn by.
//
// The cycle itself is a pure function on the Swift side and is asserted there.
// What these hold up is this side: that a registration reaches the right
// property of the right control, that the value on the bus is landed before
// anything is drawn, and that what a cycle answers is applied in the one order
// the mask means.

using Microsoft.Maui.Controls;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class BusCycleTests
{
    private static byte[] Read(string name) => Fixtures.ReadBytes(name);

    /// <summary>
    /// The bytes a bus answers with: an animated value's lanes, in the one
    /// order both sides write them.
    /// </summary>
    private static byte[] Lanes(
        double value,
        double setPoint,
        double velocity = 0,
        double law = 0,
        double a = 0,
        double b = 0,
        double completion = 0,
        double stopped = 0)
    {
        double[] lanes = [value, setPoint, velocity, law, a, b, completion, stopped];
        byte[] bytes = new byte[lanes.Length * 8];

        for (int lane = 0; lane < lanes.Length; lane++)
        {
            BitConverter.GetBytes(lanes[lane]).CopyTo(bytes, lane * 8);
        }

        return bytes;
    }

    /// <summary>One bus, as a batch of one - what a read answers.</summary>
    private static byte[] Batch(int bus, ulong mask, byte[] bytes)
    {
        List<byte> batch = [.. BitConverter.GetBytes((ushort)1)];

        batch.AddRange(BitConverter.GetBytes(bus));
        batch.AddRange(BitConverter.GetBytes((uint)(mask & 0xFFFF_FFFF)));
        batch.AddRange(BitConverter.GetBytes((uint)(mask >> 32)));
        batch.AddRange(BitConverter.GetBytes(bytes.Length));
        batch.AddRange(bytes);

        return [.. batch];
    }

    /// <summary>Which lanes of a one-lane animated value one part sits in.</summary>
    private const ulong Value = 1UL << 0;
    private const ulong SetPoint = 1UL << 1;
    private const ulong Velocity = 1UL << 2;
    private const ulong Stopped = 1UL << 7;

    // ---- The registrations ---------------------------------------------------

    /// <summary>
    /// A property with a stated value AND a bus carries both: the value lands
    /// as it always did, and the registration says the host also reads that
    /// property off a bus.
    /// </summary>
    [Fact]
    public void ABusBesideAStatedValueLandsBoth()
    {
        var host = new Host();
        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        Assert.Equal(0.5, border.Opacity);

        BusTie tie = Assert.Single(host.Renderer.Buses.Registered(border).Values);

        Assert.Equal(1, tie.Bus);
        Assert.Equal(SwiftBusMode.InOut, tie.Mode);
        Assert.Equal(SwiftBusKind.Property, tie.Kind);
        Assert.Equal(VisualElement.OpacityProperty, tie.Property);
    }

    /// <summary>
    /// Every one of the thirty twins reaches a real property of the control it
    /// was written on - which is what says a modifier does not merely compile.
    /// </summary>
    [Fact]
    public void EveryBusModifierReachesItsProperty()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.ApplyMessage(Read("bus-modifiers.bin"));

        Assert.Equal(
            [StackBase.SpacingProperty],
            host.Renderer.Buses.Registered(stack).Values.Select(tie => tie.Property));

        var border = (Border)stack.Children[0];
        var label = (Label)border.Content;
        BindableObject shape = (View)stack.Children[1];
        var button = (Button)stack.Children[2];
        var entry = (Entry)stack.Children[3];
        var box = (BoxView)stack.Children[4];

        Assert.Equal(20, host.Renderer.Buses.Registered(border).Count);
        Assert.Equal(3, host.Renderer.Buses.Registered(label).Count);
        Assert.Equal(3, host.Renderer.Buses.Registered(shape).Count);
        Assert.Equal(2, host.Renderer.Buses.Registered(button).Count);
        Assert.Single(host.Renderer.Buses.Registered(entry));
        Assert.Equal(
            [BoxView.ColorProperty],
            host.Renderer.Buses.Registered(box).Values.Select(tie => tie.Property));

        // And every one of them resolved to a property rather than to nothing:
        // a token this side cannot resolve is a tie that is never made.
        foreach (BindableObject view in new BindableObject[]
                 { stack, border, label, shape, button, entry, box })
        {
            Assert.All(
                host.Renderer.Buses.Registered(view).Values,
                tie => Assert.NotNull(tie.Property));
        }
    }

    /// <summary>Text, which is out only and has no lanes at all.</summary>
    [Fact]
    public void ATextBusIsRegisteredOnBothControls()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.ApplyMessage(Read("bus-text.bin"));

        foreach (BindableObject view in new BindableObject[]
                 { (View)stack.Children[0], (View)stack.Children[1] })
        {
            BusTie tie = Assert.Single(host.Renderer.Buses.Registered(view).Values);

            Assert.Equal(SwiftBusKind.Text, tie.Kind);
            Assert.Equal(SwiftBusMode.Out, tie.Mode);
            Assert.Equal(1, tie.Bus);
        }
    }

    /// <summary>
    /// The two-way inputs, and the mode each was written with - a slider both
    /// ways, a stepper this side writes and never reads back.
    /// </summary>
    [Fact]
    public void AnInputBusCarriesItsMode()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.ApplyMessage(Read("bus-input.bin"));

        BusTie slider = Assert.Single(
            host.Renderer.Buses.Registered((View)stack.Children[0]).Values);
        BusTie stepper = Assert.Single(
            host.Renderer.Buses.Registered((View)stack.Children[1]).Values);

        Assert.Equal(SwiftBusMode.InOut, slider.Mode);
        Assert.Equal(Slider.ValueProperty, slider.Property);
        Assert.Equal(SwiftBusMode.Out, stepper.Mode);
        Assert.Equal(Stepper.ValueProperty, stepper.Property);
    }

    // ---- What a cycle's answer is worn by ------------------------------------

    /// <summary>
    /// A registration LANDS the value the bus stands at, before anything is
    /// drawn - so a control born under a bus shows what the bus says rather
    /// than what its own default was.
    /// </summary>
    [Fact]
    public void ARegisteredBusLandsItsCurrentValue()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();

        host.Renderer.Buses.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.25, setPoint: 0.25));

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        Assert.Equal(0.25, border.Opacity, 6);
    }

    /// <summary>
    /// A VALUE WRITTEN ON A BUS SNAPS: whatever was carrying the property lets
    /// go without a word, because the author has just written it.
    /// </summary>
    [Fact]
    public void AValueWrittenOnABusSnapsAndEndsTheWalk()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        // Sent somewhere over a fifth of a second, and half way there.
        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0.5, setPoint: 0, law: 2, a: 200, b: (int)SwiftEasing.Linear));

        host.Renderer.Buses.Run(BusReason.Told);
        clock.Tick(100);

        Assert.Equal(0.25, border.Opacity, 2);

        // And then written, which is a snap: the walk lets go and the value is
        // what was written, not what the curve was drawing.
        crossing.Dirty = Batch(1, Value, Lanes(value: 0.9, setPoint: 0));
        host.Renderer.Buses.Run(BusReason.Told);

        Assert.Equal(0.9, border.Opacity, 6);

        clock.Tick(100);
        Assert.Equal(0.9, border.Opacity, 6);
    }

    /// <summary>
    /// A SETPOINT IS A JOURNEY, under the law its own lanes name - and the
    /// waiter named beside it hears when it arrives.
    /// </summary>
    [Fact]
    public void ASetPointTravelsUnderTheBusLawAndAnswersItsWaiter()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint | (1UL << 6), Lanes(
            value: 1, setPoint: 0, law: 2, a: 200, b: (int)SwiftEasing.Linear, completion: -3));

        host.Renderer.Buses.Run(BusReason.Told);

        // FROM WHERE THE PLATFORM HAS IT, which is the stated 0.5 - the value
        // lane says where the bus thinks it is, and a journey that is starting
        // begins wherever the control actually stands, since anything at all
        // may have written it while nothing was moving.
        clock.Tick(100);
        Assert.Equal(0.25, border.Opacity, 2);
        Assert.DoesNotContain(-3, host.Raw.Select(sent => sent.Id));

        clock.Tick(100);
        Assert.Equal(0, border.Opacity, 6);
        Assert.Contains(-3, host.Raw.Select(sent => sent.Id));
    }

    /// <summary>
    /// A STOP ends the journey where it stands, and whoever was waiting hears
    /// that it did not run to the end.
    /// </summary>
    [Fact]
    public void AStopLeavesTheValueWhereItIsAndAnswersFalse()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint | (1UL << 6), Lanes(
            value: 1, setPoint: 0, law: 2, a: 400, b: (int)SwiftEasing.Linear, completion: -4));

        host.Renderer.Buses.Run(BusReason.Told);
        clock.Tick(100);

        double reached = border.Opacity;

        crossing.Dirty = Batch(1, Stopped, Lanes(
            value: reached, setPoint: 0, completion: -4, stopped: 1));

        host.Renderer.Buses.Run(BusReason.Told);

        Assert.Equal(reached, border.Opacity, 6);
        Assert.Contains(-4, host.Raw.Select(sent => sent.Id));

        clock.Tick(200);
        Assert.Equal(reached, border.Opacity, 6);
    }

    /// <summary>
    /// TEXT IS WRITTEN WHEN THE BYTES CHANGE and never otherwise: a label
    /// re-measures whenever its text is set, whether or not the letters
    /// differ.
    /// </summary>
    [Fact]
    public void ATextBusWritesOnlyWhenTheWordsChange()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();

        host.Renderer.Buses.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("bus-text.bin"));
        var label = (Label)stack.Children[0];

        static byte[] Words(string text)
        {
            List<byte> bytes = [.. BitConverter.GetBytes(text.Length)];

            bytes.AddRange(System.Text.Encoding.UTF8.GetBytes(text));
            return [.. bytes];
        }

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, 1, Words("60%"));
        host.Renderer.Buses.Run(BusReason.Told);

        Assert.Equal("60%", label.Text);

        int measures = 0;
        label.MeasureInvalidated += (_, _) => measures++;

        crossing.Dirty = Batch(1, 1, Words("60%"));
        host.Renderer.Buses.Run(BusReason.Told);

        // The same words are not written again, so nothing is re-measured.
        Assert.Equal(0, measures);

        crossing.Dirty = Batch(1, 1, Words("61%"));
        host.Renderer.Buses.Run(BusReason.Told);

        Assert.Equal("61%", label.Text);
    }

    /// <summary>
    /// ONE FRAME IS ONE CYCLE. A drained run inside a frame is skipped,
    /// because the frame's own cycle is about to catch whatever the drain
    /// wrote.
    /// </summary>
    [Fact]
    public void ADrainedCycleInsideAFrameIsSkipped()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;
        host.ApplyMessage(Read("bus-sink.bin"));

        crossing.Cycles.Clear();
        host.Renderer.Buses.Frame();

        Assert.Single(crossing.Cycles);

        host.Renderer.Buses.Run(BusReason.Drained);

        Assert.Equal(2, crossing.Cycles.Count);
    }

    // ---- The mirror ---------------------------------------------------------

    /// <summary>What the host last told a bus - the batch, decoded.</summary>
    private static (int Bus, ulong Mask, double[] Lanes)? Told(HandBusCrossing crossing)
    {
        if (crossing.Written.Count == 0)
        {
            return null;
        }

        byte[] last = crossing.Written[^1];

        return BusBatch.Read(last.AsSpan()) is [(int bus, ulong mask, byte[] bytes)]
            ? (bus, mask, BusBatch.Lanes(bytes))
            : null;
    }

    /// <summary>
    /// SOMEBODY ELSE'S DECISION REACHES THE BUS. A value on a bus that the
    /// tree, a visual state or a layout sends somewhere has all three lanes
    /// told - where it is, where it is now going, and how fast - because a
    /// setpoint left saying the bus's own last destination is one an engine
    /// could never send the value away from: the bytes would be equal and the
    /// write would cross as nothing.
    /// </summary>
    /// <remarks>
    /// Aimed through the engine directly, which is the one door every one of
    /// those writers goes through.
    /// </remarks>
    [Fact]
    public void AnOutsideAimIsToldToTheBus()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        crossing.Written.Clear();

        host.Renderer.Motion.Aim(
            new MotionProperty(border, VisualElement.OpacityProperty, MotionValue.Number, true),
            [0.1],
            MotionSpec.Eased(200, (int)SwiftEasing.Linear));

        (int bus, ulong mask, double[] lanes) = Assert.NotNull(Told(crossing));

        Assert.Equal(1, bus);
        Assert.Equal(Value | SetPoint | Velocity, mask & (Value | SetPoint | Velocity));
        Assert.Equal(0.5, lanes[0], 6);
        Assert.Equal(0.1, lanes[1], 6);
    }

    /// <summary>
    /// AND SO DOES A STOP, which is the half no poll can see: the channel is
    /// taken out of the table as it lands, so nothing is left to read the
    /// value it finished at. Where it stopped is where it is going and the
    /// speed is nought, which together are what an engine reads as arrived.
    /// </summary>
    [Fact]
    public void AStopFromOutsideTellsTheBusWhereTheValueStopped()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        host.Renderer.Motion.Aim(
            new MotionProperty(border, VisualElement.OpacityProperty, MotionValue.Number, true),
            [0.1],
            MotionSpec.Eased(200, (int)SwiftEasing.Linear));

        clock.Tick(100);
        crossing.Written.Clear();

        host.Renderer.Motion.Halt(border, VisualElement.OpacityProperty, MotionEnd.Here);

        (_, _, double[] lanes) = Assert.NotNull(Told(crossing));

        Assert.Equal(border.Opacity, lanes[0], 6);
        Assert.Equal(border.Opacity, lanes[1], 6);
        Assert.Equal(0, lanes[2], 6);
    }

    /// <summary>
    /// A MOTION ABANDONED WITHOUT A WRITE IS NOT NEWS. Where a value is left
    /// exactly as it stood and nothing is written onto the control, there is
    /// nothing to tell - and telling it would put the value the author has
    /// just written back to what it was before they wrote it.
    /// </summary>
    [Fact]
    public void AMotionAbandonedWithoutAWriteTellsTheBusNothing()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        host.Renderer.Motion.Aim(
            new MotionProperty(border, VisualElement.OpacityProperty, MotionValue.Number, true),
            [0.1],
            MotionSpec.Eased(200, (int)SwiftEasing.Linear));

        clock.Tick(100);
        crossing.Written.Clear();

        host.Renderer.Motion.Halt(border, VisualElement.OpacityProperty, MotionEnd.Nothing);

        Assert.Empty(crossing.Written);
    }

    // ---- The doors the host's own writers go through ------------------------

    /// <summary>
    /// A VISUAL STATE LEAVING LANDS THE BUS, NOT THE TREE. What the tree last
    /// described is the resting value only where nothing else is carrying the
    /// property; where a bus is, the resting value is the bus's and this side
    /// cannot work it out for itself.
    /// </summary>
    [Fact]
    public void AVisualStateLeavingLandsTheBusRatherThanTheTree()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();

        host.Renderer.Buses.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.8, setPoint: 0.8));

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        // Into the state, which is an author's instruction and wins.
        Assert.True(VisualStateManager.GoToState(border, "Disabled"));
        Assert.Equal(0.1, border.Opacity, 6);

        // And out of it again: the tree says 0.5 and the bus says 0.8.
        Assert.True(VisualStateManager.GoToState(border, "Normal"));
        Assert.Equal(0.8, border.Opacity, 6);
    }

    /// <summary>
    /// AND IT BENDS A JOURNEY RATHER THAN STARTING IT OVER. A state that came
    /// and went while the bus was carrying the value settles it at the BUS's
    /// destination, from wherever the value had got to - so nothing jumps back
    /// to the value the tree describes and nothing restarts.
    /// </summary>
    [Fact]
    public void AStateLeavingSendsTheValueWhereTheBusIsGoing()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;

        // The law the application would have stated, which a harness handed
        // the view alone never sees.
        host.Renderer.Motion.Travel = MotionSpec.Eased(200, (int)SwiftEasing.Linear);
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.5, setPoint: 0.5));

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        // The bus sends it down to nothing over 400 ms, and the image it would
        // now answer with says so.
        byte[] going = Lanes(
            value: 0.5, setPoint: 0, law: 2, a: 400, b: (int)SwiftEasing.Linear);

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, going);
        host.Renderer.Buses.Run(BusReason.Told);
        crossing.Whole[1] = Batch(1, ~0UL, going);

        clock.Tick(200);
        Assert.Equal(0.25, border.Opacity, 2);

        // A state comes and goes while it travels.
        Assert.True(VisualStateManager.GoToState(border, "Disabled"));
        Assert.True(VisualStateManager.GoToState(border, "Normal"));

        Assert.NotNull(host.Renderer.Motion.Moving(border, VisualElement.OpacityProperty));
        Assert.True(
            border.Opacity is > 0.15 and < 0.3,
            $"carried on from where it was, and it is at {border.Opacity}");

        clock.Tick(400);
        Assert.Equal(0, border.Opacity, 3);
    }

    /// <summary>
    /// AN ASSIGNMENT DOES NOT STOP WHAT A BUS IS CARRYING. A value the message
    /// states rather than walks to ends every motion of that property - which
    /// is the author writing over their own animation - but a bus's journey is
    /// the one the tree is describing, not one it is interrupting.
    /// </summary>
    [Fact]
    public void AnAssignmentDoesNotStopWhatABusIsCarrying()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0.5, setPoint: 0, law: 2, a: 400, b: (int)SwiftEasing.Linear));

        host.Renderer.Buses.Run(BusReason.Told);
        clock.Tick(100);

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(4),
            Type = SwiftNodeType.Border,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Opacity] = SwiftWireValue.Of(0.5),
            },
        });

        Assert.NotNull(host.Renderer.Motion.Moving(border, VisualElement.OpacityProperty));

        clock.Tick(100);
        Assert.True(
            border.Opacity < 0.4, $"still going where the bus sent it, at {border.Opacity}");
    }

    /// <summary>
    /// A PROPERTY THE TREE STOPS DESCRIBING GOES BACK TO WHOEVER ELSE HAS IT.
    /// A modifier written conditionally is the tree letting go of a value,
    /// never the bus beside it letting go too - so the value lands where the
    /// bus says rather than at MAUI's own default.
    /// </summary>
    [Fact]
    public void AClearedPropertyBesideABusLandsTheBus()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();

        host.Renderer.Buses.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.3, setPoint: 0.3));

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        Assert.Equal(0.3, border.Opacity, 6);

        // The same element again, with the opacity STOPPED being described and
        // the registration standing.
        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(4),
            Type = SwiftNodeType.Border,
            Cleared = [SwiftKey.Of(SwiftProp.Opacity, string.Empty)],
        });

        Assert.Equal(0.3, border.Opacity, 6);
    }

    /// <summary>
    /// A BUS-DRIVEN OPACITY IS NOT CROSSED. Showing and hiding is a fade of
    /// this one value, so a view whose opacity somebody else carries appears
    /// and goes at once - and wears the bus's opacity the whole time rather
    /// than the one the tree remembers for it.
    /// </summary>
    [Fact]
    public void AShownViewOnAnOpacityBusIsInstant()
    {
        var host = new Host();
        var crossing = new HandBusCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Buses.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.4, setPoint: 0.4));

        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        Assert.True(border.IsVisible);
        Assert.Equal(0.4, border.Opacity, 6);

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(4),
            Type = SwiftNodeType.Border,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.IsVisible] = SwiftWireValue.Of(false),
            },
        });

        // Gone at once, with no fade to run and the opacity still the bus's.
        Assert.False(border.IsVisible);
        Assert.Equal(0.4, border.Opacity, 6);
        Assert.Null(host.Renderer.Motion.Moving(border, VisualElement.OpacityProperty));
    }

    /// <summary>
    /// A control that leaves the tree takes its ties with it, and whatever was
    /// carrying one of its values is let go of.
    /// </summary>
    [Fact]
    public void ADetachedViewIsTiedToNothing()
    {
        var host = new Host();
        var border = (Border)host.ApplyMessage(Read("bus-sink.bin"));

        Assert.Single(host.Renderer.Buses.Registered(border));

        host.Renderer.Buses.Detach(border);

        Assert.Empty(host.Renderer.Buses.Registered(border));
    }
}
