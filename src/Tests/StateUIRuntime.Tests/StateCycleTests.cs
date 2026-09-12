// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host's half of the image: what a REGISTRATION lands on a control, and
// what a cycle's answer is worn by.
//
// The cycle itself is a pure function on the Swift side and is asserted there.
// What these hold up is this side: that a registration reaches the right
// property of the right control, that the value on the number is landed before
// anything is drawn, and that what a cycle answers is applied in the one order
// the mask means.

using Microsoft.Maui.Controls;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class StateCycleTests
{
    private static byte[] Read(string name) => Fixtures.ReadBytes(name);

    /// <summary>
    /// The bytes a number answers with: an animated value's lanes, in the one
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

    /// <summary>One number, as a batch of one - what a read answers.</summary>
    private static byte[] Batch(int number, ulong mask, byte[] bytes)
    {
        List<byte> batch = [.. BitConverter.GetBytes((ushort)1)];

        batch.AddRange(BitConverter.GetBytes(number));
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
    /// A property with a stated value AND a number carries both: the value lands
    /// as it always did, and the registration says the host also reads that
    /// property off a number.
    /// </summary>
    [Fact]
    public void ADrivenPropertyBesideAStatedValueLandsBoth()
    {
        var host = new Host();
        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        Assert.Equal(0.5, border.Opacity);

        StateTie tie = Assert.Single(host.Renderer.Cycle.Registered(border).Values);

        Assert.Equal(1, tie.Number);
        Assert.Equal(SwiftStateMode.InOut, tie.Mode);
        Assert.Equal(SwiftStateKind.Property, tie.Kind);
        Assert.Equal(VisualElement.OpacityProperty, tie.Property);
    }

    /// <summary>
    /// Every one of the thirty twins reaches a real property of the control it
    /// was written on - which is what says a modifier does not merely compile.
    /// </summary>
    [Fact]
    public void EveryDrivenModifierReachesItsProperty()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-modifiers.bin"));

        Assert.Equal(
            [StackBase.SpacingProperty],
            host.Renderer.Cycle.Registered(stack).Values.Select(tie => tie.Property));

        var border = (Border)stack.Children[0];
        var label = (Label)border.Content!;
        BindableObject shape = (View)stack.Children[1];
        var button = (Button)stack.Children[2];
        var entry = (Entry)stack.Children[3];
        var box = (BoxView)stack.Children[4];

        Assert.Equal(20, host.Renderer.Cycle.Registered(border).Count);
        Assert.Equal(3, host.Renderer.Cycle.Registered(label).Count);
        Assert.Equal(3, host.Renderer.Cycle.Registered(shape).Count);
        Assert.Equal(2, host.Renderer.Cycle.Registered(button).Count);
        Assert.Single(host.Renderer.Cycle.Registered(entry));
        Assert.Equal(
            [BoxView.ColorProperty],
            host.Renderer.Cycle.Registered(box).Values.Select(tie => tie.Property));

        // And every one of them resolved to a property rather than to nothing:
        // a token this side cannot resolve is a tie that is never made.
        foreach (BindableObject view in new BindableObject[]
                 { stack, border, label, shape, button, entry, box })
        {
            Assert.All(
                host.Renderer.Cycle.Registered(view).Values,
                tie => Assert.NotNull(tie.Property));
        }
    }

    /// <summary>Text, which is out only and has no lanes at all.</summary>
    [Fact]
    public void ADrivenTextIsRegisteredOnBothControls()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-text.bin"));

        foreach (BindableObject view in new BindableObject[]
                 { (View)stack.Children[0], (View)stack.Children[1] })
        {
            StateTie tie = Assert.Single(host.Renderer.Cycle.Registered(view).Values);

            Assert.Equal(SwiftStateKind.Text, tie.Kind);
            Assert.Equal(SwiftStateMode.Out, tie.Mode);
            Assert.Equal(1, tie.Number);
        }
    }

    /// <summary>
    /// The two-way inputs, and they are both carried BOTH ways.
    /// </summary>
    /// <remarks>
    /// Neither the author nor the modifier chooses that, and there is no
    /// argument to choose it with: an <c>AnimatedValue</c>'s <c>value</c> MEANS
    /// where the value is, so a property this side drives has to be told where
    /// the platform got it to - and these two are the ones a reader can drag as
    /// well, which is a second reason for the same answer.
    /// </remarks>
    [Fact]
    public void ADrivenInputIsCarriedBothWays()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-input.bin"));

        StateTie slider = Assert.Single(
            host.Renderer.Cycle.Registered((View)stack.Children[0]).Values);
        StateTie stepper = Assert.Single(
            host.Renderer.Cycle.Registered((View)stack.Children[1]).Values);

        Assert.Equal(SwiftStateMode.InOut, slider.Mode);
        Assert.Equal(Slider.ValueProperty, slider.Property);
        Assert.Equal(SwiftStateMode.InOut, stepper.Mode);
        Assert.Equal(Stepper.ValueProperty, stepper.Property);
    }

    /// <summary>
    /// A value the READER moves reaches every control the state drives, not
    /// only the one they touched.
    /// </summary>
    /// <remarks>
    /// A report clears the state's dirty lanes, because a lane the host wrote
    /// is a lane the host already has. The lanes belong to the STATE, though,
    /// while "already has it" is only true of the control that REPORTED - so
    /// without this a panel whose width rides the same value as a slider's
    /// thumb hears nothing and stands still under the finger. Measured on the
    /// gallery, byte for byte: the state reached 267 and the panel was drawn
    /// at the width it started with.
    /// </remarks>
    [Fact]
    public void AValueTheReaderMovesReachesEveryControlTheStateDrives()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-shared.bin"));

        var slider = (Slider)stack.Children[0];
        var box = (BoxView)stack.Children[1];

        // Both ride ONE number, which is the whole point of the fixture.
        Assert.Equal(
            host.Renderer.Cycle.Registered(slider).Values.Single().Number,
            host.Renderer.Cycle.Registered(box).Values.Single().Number);

        // What a finger looks like from here: the platform assigning the value
        // and raising its own change for it.
        slider.Value = 0.8;

        Assert.Equal(0.8, box.WidthRequest, 3);
    }

    // ---- What a cycle's answer is worn by ------------------------------------

    /// <summary>
    /// A registration LANDS the value the number stands at, before anything is
    /// drawn - so a control born under a number shows what the number says rather
    /// than what its own default was.
    /// </summary>
    [Fact]
    public void ARegisteredStateLandsItsCurrentValue()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.25, setPoint: 0.25));

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        Assert.Equal(0.25, border.Opacity, 6);
    }

    /// <summary>
    /// A PLAIN value lands as it stands, boxed to the property's own type: a flag
    /// from one lane, a choice from a whole number, a MEMBER through the very
    /// table a described property goes through, words from text - and a journey
    /// from a plain number. The bound fixture is one of each.
    /// </summary>
    [Fact]
    public void APlainStateLandsOnItsPropertyAsItsOwnType()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 22, setPoint: 22));   // a journey: a font size
        crossing.Whole[2] = Batch(2, ~0UL, BitConverter.GetBytes(2.0));       // a member: LayoutOptions.end
        crossing.Whole[3] = Batch(3, ~0UL, BitConverter.GetBytes(0.0));       // a flag: hidden
        crossing.Whole[5] = Batch(5, ~0UL, BitConverter.GetBytes(2.0));       // a choice: the third item
        crossing.Whole[6] = Batch(6, ~0UL, BitConverter.GetBytes(1.0));       // a flag the reader can move

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("bound.bin"));
        var label = Assert.IsType<Label>(stack.Children[0]);
        var picker = Assert.IsType<Picker>(stack.Children[2]);
        var toggle = Assert.IsType<Switch>(stack.Children[3]);

        Assert.Equal(22, label.FontSize, 6);
        Assert.False(label.IsVisible);
        Assert.True(toggle.IsToggled);
        Assert.Equal(2, picker.SelectedIndex);

        // A MEMBER: the number this library gives `LayoutOptions.end`, resolved
        // through the very table a described property goes through - so a
        // channel understands every member the tree can describe.
        Assert.Equal(LayoutOptions.End, label.HorizontalOptions);
    }

    /// <summary>
    /// A PLAIN value the reader moved - a switch flipped - crosses as the host's
    /// own write, one lane under the tie's number, and every other control the
    /// same state drives is set beside it; the tie remembers the value, so the
    /// state's echo of it is not set on the control again.
    /// </summary>
    [Fact]
    public void AFlippedSwitchIsToldToItsPlainState()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("bound.bin"));
        var toggle = Assert.IsType<Switch>(stack.Children[3]);

        Assert.True(host.Renderer.Cycle.Reported(toggle, Switch.IsToggledProperty, 1));

        (int number, ulong mask, double[] lanes) = Told(crossing)!.Value;

        Assert.Equal(6, number);
        Assert.Equal(1UL, mask);
        Assert.Equal([1.0], lanes);

        // A property nobody drives is nobody's report.
        Assert.False(host.Renderer.Cycle.Reported(toggle, Switch.IsEnabledProperty, 0));
    }

    /// <summary>
    /// A VALUE WRITTEN ON A DRIVEN STATE SNAPS: whatever was carrying the property lets
    /// go without a word, because the author has just written it.
    /// </summary>
    [Fact]
    public void AValueWrittenOnADrivenStateSnapsAndEndsTheWalk()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        // Sent somewhere over a fifth of a second, and half way there.
        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0.5, setPoint: 0, law: 2, a: 200, b: (int)SwiftEasing.Linear));

        host.Renderer.Cycle.Run(CycleReason.Told);
        clock.Tick(100);

        Assert.Equal(0.25, border.Opacity, 2);

        // And then written, which is a snap: the walk lets go and the value is
        // what was written, not what the curve was drawing.
        crossing.Dirty = Batch(1, Value, Lanes(value: 0.9, setPoint: 0));
        host.Renderer.Cycle.Run(CycleReason.Told);

        Assert.Equal(0.9, border.Opacity, 6);

        clock.Tick(100);
        Assert.Equal(0.9, border.Opacity, 6);
    }

    /// <summary>
    /// A SETPOINT IS A JOURNEY, under the law its own lanes name - and the
    /// waiter named beside it hears when it arrives.
    /// </summary>
    [Fact]
    public void ASetPointTravelsUnderTheStatedLawAndAnswersItsWaiter()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint | (1UL << 6), Lanes(
            value: 1, setPoint: 0, law: 2, a: 200, b: (int)SwiftEasing.Linear, completion: -3));

        host.Renderer.Cycle.Run(CycleReason.Told);

        // FROM WHERE THE PLATFORM HAS IT, which is the stated 0.5 - the value
        // lane says where the number thinks it is, and a journey that is starting
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
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint | (1UL << 6), Lanes(
            value: 1, setPoint: 0, law: 2, a: 400, b: (int)SwiftEasing.Linear, completion: -4));

        host.Renderer.Cycle.Run(CycleReason.Told);
        clock.Tick(100);

        double reached = border.Opacity;

        crossing.Dirty = Batch(1, Stopped, Lanes(
            value: reached, setPoint: 0, completion: -4, stopped: 1));

        host.Renderer.Cycle.Run(CycleReason.Told);

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
    public void ADrivenTextWritesOnlyWhenTheWordsChange()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-text.bin"));
        var label = (Label)stack.Children[0];

        static byte[] Words(string text)
        {
            List<byte> bytes = [.. BitConverter.GetBytes(text.Length)];

            bytes.AddRange(System.Text.Encoding.UTF8.GetBytes(text));
            return [.. bytes];
        }

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, 1, Words("60%"));
        host.Renderer.Cycle.Run(CycleReason.Told);

        Assert.Equal("60%", label.Text);

        int measures = 0;
        label.MeasureInvalidated += (_, _) => measures++;

        crossing.Dirty = Batch(1, 1, Words("60%"));
        host.Renderer.Cycle.Run(CycleReason.Told);

        // The same words are not written again, so nothing is re-measured.
        Assert.Equal(0, measures);

        crossing.Dirty = Batch(1, 1, Words("61%"));
        host.Renderer.Cycle.Run(CycleReason.Told);

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
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;
        host.ApplyMessage(Read("state-sink.bin"));

        crossing.Cycles.Clear();
        host.Renderer.Cycle.Frame();

        Assert.Single(crossing.Cycles);

        host.Renderer.Cycle.Run(CycleReason.Drained);

        Assert.Equal(2, crossing.Cycles.Count);
    }

    // ---- The mirror ---------------------------------------------------------

    /// <summary>What the host last told a number - the batch, decoded.</summary>
    /// <summary>
    /// A FIELD THE READER TYPES INTO REPORTS THE WORDS WHOLE. The text state
    /// hears a keystroke as the host's own write - length and letters, every
    /// lane named - and every other field the same state drives wears the
    /// words at once; a text nobody types into (a label's caption) is no
    /// report at all.
    /// </summary>
    [Fact]
    public void ATypedTextIsToldToItsStateWhole()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-text-two-way.bin"));
        var entry = Assert.IsType<Entry>(stack.Children[0]);
        var editor = Assert.IsType<Editor>(stack.Children[1]);
        var search = Assert.IsType<SearchBar>(stack.Children[2]);

        Assert.True(host.Renderer.Cycle.Typed(entry, InputView.TextProperty, "Ada"));

        byte[] last = crossing.Written[^1];
        var written = Assert.Single(StateBatch.Read(last.AsSpan()));

        Assert.Equal(1, written.Number);
        Assert.Equal(~0UL, written.Mask);
        Assert.Equal("Ada", StateBatch.Text(written.Bytes));

        // The two other fields on the same state wear the words at once.
        Assert.Equal("Ada", editor.Text);
        Assert.Equal("Ada", search.Text);

        // And a caption is written out, never reported.
        var labels = (VerticalStackLayout)host.ApplyMessage(Read("state-text.bin"));

        Assert.False(host.Renderer.Cycle.Typed((Label)labels.Children[0], Label.TextProperty, "x"));
    }

    /// <summary>
    /// A WRITE MADE ON THIS SIDE NEVER COMES BACK AS AN EVENT OR AS A REPORT.
    /// The state's own words land on the field under the writing marker, so
    /// the platform's TextChanged is refused as an event and as a report - and
    /// the marker is back to nought the moment the write is over.
    /// </summary>
    [Fact]
    public void AStatesOwnTextRaisesNoEventAndReportsNothing()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-text-two-way.bin"));
        var entry = Assert.IsType<Entry>(stack.Children[0]);

        host.Dispatched.Clear();
        int reports = crossing.Written.Count;

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, ~0UL, StateBatch.Words("xyz"));
        host.Renderer.Cycle.Run(CycleReason.Told);

        Assert.Equal("xyz", entry.Text);
        Assert.Empty(host.Dispatched);
        Assert.Equal(reports, crossing.Written.Count);
        Assert.Equal(0, MotionEngine.Writing);
    }

    /// <summary>
    /// THREE LANES MAKE A DAY AND A TIME. A plain state on a DateTime property
    /// lands as year, month and day, on a TimeSpan one as hour, minute and
    /// second - and a day that does not exist sets nothing, so the picker goes
    /// on showing the one it had.
    /// </summary>
    [Fact]
    public void AThreeLanePlainStateLandsADayAndATime()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Plain(2026, 8, 2));
        crossing.Whole[2] = Batch(2, ~0UL, Plain(9, 30, 5));

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-picked.bin"));
        var picker = Assert.IsType<DatePicker>(stack.Children[0]);
        var time = Assert.IsType<TimePicker>(stack.Children[1]);

        Assert.Equal(new DateTime(2026, 8, 2), picker.Date);
        Assert.Equal(new TimeSpan(9, 30, 5), time.Time);

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, ~0UL, Plain(2026, 2, 31));
        host.Renderer.Cycle.Run(CycleReason.Told);

        Assert.Equal(new DateTime(2026, 8, 2), picker.Date);
    }

    /// <summary>
    /// A CHOSEN DAY IS TOLD AS THREE LANES, a chosen time likewise - the way a
    /// flipped switch is told as one - and the state's own day landing on the
    /// picker raises no event and reports nothing back.
    /// </summary>
    [Fact]
    public void AChosenDayIsToldAsThreeLanesAndTheStatesOwnDayIsNoEvent()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-picked.bin"));
        var picker = Assert.IsType<DatePicker>(stack.Children[0]);
        var time = Assert.IsType<TimePicker>(stack.Children[1]);

        Assert.True(host.Renderer.Cycle.Reported(picker, DatePicker.DateProperty, [2026, 9, 15]));

        (int number, ulong mask, double[] lanes) = Told(crossing)!.Value;

        Assert.Equal(1, number);
        Assert.Equal(0b111UL, mask);
        Assert.Equal([2026.0, 9, 15], lanes);

        Assert.True(host.Renderer.Cycle.Reported(time, TimePicker.TimeProperty, [7, 45, 0]));
        Assert.Equal(2, Told(crossing)!.Value.Number);

        host.Dispatched.Clear();
        int reports = crossing.Written.Count;

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, ~0UL, Plain(2027, 1, 1));
        host.Renderer.Cycle.Run(CycleReason.Told);

        Assert.Equal(new DateTime(2027, 1, 1), picker.Date);
        Assert.Empty(host.Dispatched);
        Assert.Equal(reports, crossing.Written.Count);
        Assert.Equal(0, MotionEngine.Writing);
    }

    /// <summary>
    /// The three fields redeclare InputView's TextProperty as the SAME
    /// instance, which is what lets the renderer report a keystroke under one
    /// property name and the tie made from the field's own resolve it.
    /// </summary>
    [Fact]
    public void TheTextPropertyIsOneInstanceAcrossTheFields()
    {
        Assert.Same(InputView.TextProperty, Entry.TextProperty);
        Assert.Same(InputView.TextProperty, Editor.TextProperty);
        Assert.Same(InputView.TextProperty, SearchBar.TextProperty);
    }

    /// <summary>Plain lanes, as the image holds them: eight bytes a lane.</summary>
    private static byte[] Plain(params double[] lanes)
    {
        byte[] bytes = new byte[lanes.Length * 8];

        for (int lane = 0; lane < lanes.Length; lane++)
        {
            BitConverter.TryWriteBytes(bytes.AsSpan(lane * 8, 8), lanes[lane]);
        }

        return bytes;
    }

    private static (int Number, ulong Mask, double[] Lanes)? Told(HandCrossing crossing)
    {
        if (crossing.Written.Count == 0)
        {
            return null;
        }

        byte[] last = crossing.Written[^1];

        return StateBatch.Read(last.AsSpan()) is [(int number, ulong mask, byte[] bytes)]
            ? (number, mask, StateBatch.Lanes(bytes))
            : null;
    }

    /// <summary>
    /// A CHANNEL OF ONE CONTROL'S OWN IS NOT THE STATE'S NEWS. A visual state
    /// dimming a button, or the tree stating a value beside the registration,
    /// aims that control's own channel - and the value on the number is
    /// unchanged by it: a button disabled to grey is a button that looks grey,
    /// not a colour that turned grey, and every other control on the number
    /// goes on showing the state.
    /// </summary>
    [Fact]
    public void AnOutsideAimOnOneControlIsNotTheStatesNews()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        crossing.Written.Clear();

        host.Renderer.Motion.Aim(
            new MotionProperty(border, VisualElement.OpacityProperty, MotionValue.Number, true),
            [0.1],
            MotionSpec.Eased(200, (int)SwiftEasing.Linear));

        // The control travels, on a channel of its own.
        Assert.NotNull(host.Renderer.Motion.Moving(border, VisualElement.OpacityProperty));

        clock.Tick(100);

        Assert.Equal(0.3, border.Opacity, 2);
        Assert.Empty(crossing.Written);
    }

    /// <summary>
    /// A STOP OF THE STATE'S OWN CHANNEL IS TOLD - the half no poll can see:
    /// the channel is taken out of the table as it lands, so nothing is left
    /// to read the value it finished at. Where it stopped is where it is going
    /// and the speed is nought, which together are what an engine reads as
    /// arrived.
    /// </summary>
    [Fact]
    public void AStopOfTheStatesChannelTellsTheStateWhereTheValueStopped()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0.5, setPoint: 0, law: 2, a: 200, b: (int)SwiftEasing.Linear));

        host.Renderer.Cycle.Run(CycleReason.Told);
        clock.Tick(100);
        crossing.Written.Clear();

        StateFan fan = Assert.Single(host.Renderer.Cycle.Registered(border).Values).Fan!;

        host.Renderer.Motion.Halt(fan, StateFan.Slot, MotionEnd.Here);

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
    public void AMotionAbandonedWithoutAWriteTellsTheStateNothing()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0.5, setPoint: 0, law: 2, a: 200, b: (int)SwiftEasing.Linear));

        host.Renderer.Cycle.Run(CycleReason.Told);
        clock.Tick(100);
        crossing.Written.Clear();

        StateFan fan = Assert.Single(host.Renderer.Cycle.Registered(border).Values).Fan!;

        host.Renderer.Motion.Halt(fan, StateFan.Slot, MotionEnd.Nothing);

        Assert.Empty(crossing.Written);
    }

    // ---- The doors the host's own writers go through ------------------------

    /// <summary>
    /// A VISUAL STATE LEAVING LANDS THE STATE, NOT THE TREE. What the tree last
    /// described is the resting value only where nothing else is carrying the
    /// property; where a number is, the resting value is the number's and this side
    /// cannot work it out for itself.
    /// </summary>
    [Fact]
    public void AVisualStateLeavingLandsTheStateRatherThanTheTree()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.8, setPoint: 0.8));

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        // Into the state, which is an author's instruction and wins.
        Assert.True(VisualStateManager.GoToState(border, "Disabled"));
        Assert.Equal(0.1, border.Opacity, 6);

        // And out of it again: the tree says 0.5 and the number says 0.8.
        Assert.True(VisualStateManager.GoToState(border, "Normal"));
        Assert.Equal(0.8, border.Opacity, 6);
    }

    /// <summary>
    /// AND IT BENDS A JOURNEY RATHER THAN STARTING IT OVER. A state that came
    /// and went while the number was carrying the value settles it at the state's
    /// destination, from wherever the value had got to - so nothing jumps back
    /// to the value the tree describes and nothing restarts.
    /// </summary>
    [Fact]
    public void AStateLeavingSendsTheValueWhereItIsGoing()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        // The law the application would have stated, which a harness handed
        // the view alone never sees.
        host.Renderer.Motion.Travel = MotionSpec.Eased(200, (int)SwiftEasing.Linear);
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.5, setPoint: 0.5));

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        // The number sends it down to nothing over 400 ms, and the image it would
        // now answer with says so.
        byte[] going = Lanes(
            value: 0.5, setPoint: 0, law: 2, a: 400, b: (int)SwiftEasing.Linear);

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, going);
        host.Renderer.Cycle.Run(CycleReason.Told);
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
    /// AN ASSIGNMENT DOES NOT STOP WHAT A DRIVEN STATE IS CARRYING. A value the message
    /// states rather than walks to ends every motion of that property - which
    /// is the author writing over their own animation - but a number's journey is
    /// the one the tree is describing, not one it is interrupting.
    /// </summary>
    [Fact]
    public void AnAssignmentDoesNotStopWhatAStateIsCarrying()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0.5, setPoint: 0, law: 2, a: 400, b: (int)SwiftEasing.Linear));

        host.Renderer.Cycle.Run(CycleReason.Told);
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

        // The number's channel is still carrying it.
        StateFan fan = Assert.Single(host.Renderer.Cycle.Registered(border).Values).Fan!;

        Assert.NotNull(host.Renderer.Motion.Moving(fan, StateFan.Slot));

        clock.Tick(100);
        Assert.True(
            border.Opacity < 0.4, $"still going where the number sent it, at {border.Opacity}");
    }

    /// <summary>
    /// A PROPERTY THE TREE STOPS DESCRIBING GOES BACK TO WHOEVER ELSE HAS IT.
    /// A modifier written conditionally is the tree letting go of a value,
    /// never the number beside it letting go too - so the value lands where the
    /// number says rather than at MAUI's own default.
    /// </summary>
    [Fact]
    public void AClearedPropertyBesideADrivenOneLandsTheState()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.3, setPoint: 0.3));

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

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
    /// A DRIVEN OPACITY IS NOT CROSSED. Showing and hiding is a fade of
    /// this one value, so a view whose opacity somebody else carries appears
    /// and goes at once - and wears the number's opacity the whole time rather
    /// than the one the tree remembers for it.
    /// </summary>
    [Fact]
    public void AShownViewOnADrivenOpacityIsInstant()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0.4, setPoint: 0.4));

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        Assert.True(border.IsVisible);
        Assert.Equal(0.4, border.Opacity, 6);

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(3),
            Type = SwiftNodeType.Border,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.IsVisible] = SwiftWireValue.Of(false),
            },
        });

        // Gone at once, with no fade to run and the opacity still the number's.
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
        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        Assert.Single(host.Renderer.Cycle.Registered(border));

        host.Renderer.Cycle.Detach(border);

        Assert.Empty(host.Renderer.Cycle.Registered(border));
    }

    /// <summary>
    /// A control the tree has stopped describing is COLLECTABLE - the cycle
    /// holds it weakly and nothing else here holds it at all.
    /// </summary>
    /// <remarks>
    /// `Detach` is called only
    /// where a control REGISTERS again, never where one leaves, so a tie holding
    /// its view strongly kept every driven control ever built alive for the life
    /// of the process - measured on Mac, Android and an iPad as two or three
    /// controls per page visited, and every page is rebuilt on every visit.
    /// A weak reference is the fix, and this is what says so: drop every
    /// reference this test holds, collect, and the control must be gone.
    /// </remarks>
    [Fact]
    public void AViewTheTreeHasDroppedIsCollectable()
    {
        var host = new Host();

        WeakReference Driven()
        {
            var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

            Assert.Single(host.Renderer.Cycle.Registered(border));

            return new WeakReference(border);
        }

        WeakReference gone = Driven();

        // The tree stops describing it: another control takes its place, so
        // nothing in the test or the host holds the old one any more.
        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(4),
            Type = SwiftNodeType.Label,
            Replace = true,
        });

        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();

        Assert.False(gone.IsAlive, "the cycle is holding a control the tree has let go of");
    }

    /// <summary>
    /// NOTHING A FEED KEEPS MAY HOLD THE CONTROL.
    /// </summary>
    /// <remarks>
    /// A feed subscribes to the control's own PropertyChanged and keeps the
    /// unsubscription on the TIE, which the cycle keeps by number - so a
    /// handler or an unsubscription that closes over the control roots it for
    /// the life of the process, and the tie's weak reference can never go null,
    /// which means <c>Prune</c> never drops it either. Measured on the gallery
    /// as 76 controls left behind on every visit to <c>PlacedLayout</c>
    /// and 59 to <c>GalleryView</c>, <c>tracked</c> climbing for ever while
    /// <c>alive</c> came back to its baseline every time.
    ///
    /// Asked of the CLOSURES rather than of the collector: a heap that has just
    /// run twenty other tests collects when it pleases, and what this is about
    /// is a reference that must not be written in the first place.
    /// </remarks>
    [Fact]
    public void NothingAFeedKeepsHoldsItsControl()
    {
        var host = new Host();

        var layout = (VerticalStackLayout)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(4),
            Type = SwiftNodeType.VerticalStackLayout,
            States =
            [
                new SwiftStateEntry(SwiftProp.Frame, "frame", 7, SwiftStateMode.In, SwiftStateKind.Feed),
            ],
        });

        StateTie tie = Assert.Single(host.Renderer.Cycle.Registered(layout)).Value;

        Assert.NotNull(tie.Released);
        Assert.Empty(Holds(tie.Released, 3));
    }

    /// <summary>
    /// Every control a delegate's captured state holds, following the
    /// delegates it captured too - the closure walk the guard above reads.
    /// </summary>
    /// <param name="what">The delegate to look inside.</param>
    /// <param name="depth">How many delegates deep to follow.</param>
    /// <returns>The controls it holds, by the field that holds each.</returns>
    private static List<string> Holds(Delegate what, int depth)
    {
        List<string> found = [];

        if (depth <= 0 || what.Target is not object captured)
        {
            return found;
        }

        foreach (System.Reflection.FieldInfo field in captured.GetType()
            .GetFields(System.Reflection.BindingFlags.Instance
                | System.Reflection.BindingFlags.Public
                | System.Reflection.BindingFlags.NonPublic))
        {
            object? held = field.GetValue(captured);

            if (held is VisualElement view)
            {
                found.Add($"{captured.GetType().Name}.{field.Name} holds {view.GetType().Name}");
            }
            else if (held is Delegate deeper)
            {
                found.AddRange(Holds(deeper, depth - 1));
            }
        }

        return found;
    }

    // ---- The reader --------------------------------------------------------

    /// <summary>
    /// A REPORT RAISED INSIDE THE ENGINE'S OWN WRITE IS THE ENGINE HEARING
    /// ITSELF, and reaches the state as nothing at all.
    /// </summary>
    /// <remarks>
    /// Every platform raises its change notification synchronously as the value
    /// is assigned, so a walk of sixty frames is sixty reports. Believed, each
    /// one would write the value the engine had just written back over where it
    /// was GOING, and the walk would end on its own first frame.
    /// </remarks>
    [Fact]
    public void AReportRaisedInsideTheEnginesOwnWriteIsDropped()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-input.bin"));
        var slider = (Slider)stack.Children[0];

        crossing.Written.Clear();

        MotionEngine.Writing++;

        try
        {
            Assert.True(host.Renderer.Cycle.Reader(slider, Slider.ValueProperty, 0.75));
        }
        finally
        {
            MotionEngine.Writing--;
        }

        Assert.Empty(crossing.Written);
    }

    /// <summary>
    /// A REPORT RAISED OUTSIDE IT IS A FINGER, and the finger's number is where
    /// the value is AND where it is going.
    /// </summary>
    /// <remarks>
    /// Both lanes, because a setpoint left where the state last sent it is a
    /// destination the next cycle would drag the thumb back to - out from under
    /// the reader holding it.
    /// </remarks>
    [Fact]
    public void AReportRaisedOutsideTheWriteIsTheReaders()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-input.bin"));
        var slider = (Slider)stack.Children[0];

        crossing.Written.Clear();

        Assert.True(host.Renderer.Cycle.Reader(slider, Slider.ValueProperty, 0.75));

        (int number, ulong mask, double[] lanes) = Assert.NotNull(Told(crossing));

        Assert.Equal(1, number);
        Assert.Equal(Value | SetPoint | Velocity, mask);
        Assert.Equal(0.75, lanes[0], 6);
        Assert.Equal(0.75, lanes[1], 6);
        Assert.Equal(0, lanes[2], 6);
    }

    /// <summary>
    /// And it is written into an array of the value's WHOLE shape, three lanes
    /// of which it speaks about.
    /// </summary>
    /// <remarks>
    /// A report is about LANES and never about shape: the other side lays the
    /// named lanes into the image it holds, and one of a different length is a
    /// value of a different shape. Sent short, this reading replaced a
    /// journey's image with its own three lanes - law, waiter and stop counter
    /// gone - and every write after it crossed as a whole new value, which the
    /// write path reads as a snap. Measured on the gallery: a slider travelled
    /// to every value it was sent until a finger touched it once, and jumped
    /// for the rest of the session.
    /// </remarks>
    [Fact]
    public void AReadersReportIsTheWholeShapeOfTheValueItIsAbout()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-input.bin"));
        var slider = (Slider)stack.Children[0];

        crossing.Written.Clear();

        Assert.True(host.Renderer.Cycle.Reader(slider, Slider.ValueProperty, 0.75));

        (_, _, double[] lanes) = Assert.NotNull(Told(crossing));

        // One lane wide: value, setpoint and velocity, the three law lanes,
        // the waiter and the stop counter.
        Assert.Equal((1 * 3) + 5, lanes.Length);
    }

    /// <summary>
    /// A FINGER ON A MOVING CONTROL TAKES IT: whatever was carrying the value
    /// ends where it stands, and the value is the reader's from that moment.
    /// </summary>
    [Fact]
    public void AFingerTakesAValueTheEngineWasCarrying()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-input.bin"));
        var slider = (Slider)stack.Children[0];

        // Sent to 1 over a fifth of a second, and half way there.
        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0, setPoint: 1, law: 2, a: 200, b: (int)SwiftEasing.Linear));

        host.Renderer.Cycle.Run(CycleReason.Told);
        clock.Tick(100);

        Assert.Equal(0.5, slider.Value, 2);

        // The reader puts the thumb somewhere else. On a device the platform
        // has already written that number onto the control by the time it
        // reports; here the assignment stands in for it, and what is being
        // asserted is the frame AFTER - which would have carried the value on
        // to 1 had the finger not ended the walk.
        Assert.True(host.Renderer.Cycle.Reader(slider, Slider.ValueProperty, 0.2));

        slider.Value = 0.2;
        clock.Tick(100);

        Assert.Equal(0.2, slider.Value, 6);
    }

    /// <summary>
    /// A LANDING'S OWN WRITE IS NOT A FINGER. Ending a journey assigns the
    /// control, the platform raises its change for that assignment, and a
    /// report believed there would re-enter as a reader and halt the landing
    /// making it - leaving the value where the curve happened to be rather
    /// than at the target.
    /// </summary>
    /// <remarks>
    /// What tells state about the arrival is the engine's own mirror, not a
    /// platform report, so nothing is lost by dropping it.
    /// </remarks>
    [Fact]
    public void ALandingsOwnWriteIsNotReadAsAFinger()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-input.bin"));
        var slider = (Slider)stack.Children[0];

        int reads = 0;

        slider.ValueChanged += (sender, e) =>
        {
            if (MotionEngine.Writing == 0)
            {
                reads++;
            }
        };

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0, setPoint: 1, law: 2, a: 200, b: (int)SwiftEasing.Linear));

        host.Renderer.Cycle.Run(CycleReason.Told);

        clock.Tick(100);
        clock.Tick(150);

        Assert.Equal(1, slider.Value, 6);
        Assert.Equal(0, reads);
    }

    /// <summary>
    /// A MOTION'S OWN FRAME IS NOT AN EVENT EITHER. A two-way control writes
    /// every report it makes back into the state it was described from, so a
    /// report raised by the motion's own write would overwrite the value the
    /// motion is carrying - and an assignment over a moving value SNAPS it.
    /// </summary>
    /// <remarks>
    /// Measured on Mac Catalyst before this guard existed: a Slider bound to
    /// state and sent from 0.2 to 1 arrived at 0.39 with no movement to see,
    /// its own first frame having ended the journey and snapped it there. The
    /// number was different every press, which is what the report happening to
    /// land on a different frame looks like.
    /// </remarks>
    [Fact]
    public void AMotionsOwnFrameRaisesNoEvent()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-input.bin"));
        var slider = (Slider)stack.Children[0];

        host.Dispatched.Clear();

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0, setPoint: 1, law: 2, a: 200, b: (int)SwiftEasing.Linear));

        host.Renderer.Cycle.Run(CycleReason.Told);

        clock.Tick(100);
        clock.Tick(150);

        // It arrived, and nothing about the journey reached the tree - the
        // 25 frames it took raised 25 platform changes and not one event.
        Assert.Equal(1, slider.Value, 6);
        Assert.Empty(host.Dispatched);

        // And the marker is a guard rather than a wall: it is back to nought
        // the moment the journey is over, so the next report is the reader's.
        Assert.Equal(0, MotionEngine.Writing);
    }

    /// <summary>
    /// A control NOTHING drives hears nothing about it - the state path is not
    /// entered at all, and the tree's own binding goes on as it always did.
    /// </summary>
    [Fact]
    public void AReportOnAnUndrivenControlReachesNoState()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-input.bin"));

        crossing.Written.Clear();

        Assert.False(host.Renderer.Cycle.Reader(
            new Slider(), Slider.ValueProperty, 0.75));
        Assert.Empty(crossing.Written);
    }

    /// <summary>
    /// Where a value stands is kept whether or not anything follows it: a drag
    /// MOVES a value rather than setting it, so where it began has to be known,
    /// and a render that happens later describes the views where the reader
    /// left them.
    /// </summary>
    [Fact]
    public void AValueThatMovedIsWhereItWasLastSaidToBe()
    {
        StateCycle states = new Host().Renderer.Cycle;

        Assert.Equal(0, states.Standing(7));

        states.Moved(7, 12.5);
        Assert.Equal(12.5, states.Standing(7));

        states.Moved(7, -3);
        Assert.Equal(-3, states.Standing(7));

        Assert.Equal(0, states.Standing(8));
    }

    // ---- One state, one channel ---------------------------------------------

    /// <summary>
    /// ONE STATE IS ONE CHANNEL, however many controls wear it. A state is one
    /// value, and a control handed it holds a handle on that value rather than
    /// a value of its own - so the physics is worked out once, every control is
    /// written from the same lanes on the same frame, and the image hears ONE
    /// reading of the number per cycle rather than one per control.
    /// </summary>
    /// <remarks>
    /// Before this, two controls on one number were two channels: two curves,
    /// two positions, and two writers of the image's value lane, with which of
    /// them the state quoted decided by an unstable sort.
    /// </remarks>
    [Fact]
    public void OneStateOnTwoControlsIsOneChannel()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;
        crossing.Whole[1] = Batch(1, ~0UL, Lanes(value: 0, setPoint: 0));

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("state-shared.bin"));
        var slider = (Slider)stack.Children[0];
        var box = (BoxView)stack.Children[1];

        // Sent from 0 to 1 over a fifth of a second.
        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, Lanes(
            value: 0, setPoint: 1, law: 2, a: 200, b: (int)SwiftEasing.Linear));

        host.Renderer.Cycle.Run(CycleReason.Told);

        // ONE motion carries both.
        Assert.Equal(1, host.Renderer.Motion.Carrying);

        crossing.Written.Clear();
        clock.Tick(100);

        Assert.Equal(0.5, slider.Value, 2);
        Assert.Equal(0.5, box.WidthRequest, 2);

        // And the frame's own cycle told the image the number ONCE - a batch
        // of one entry, where a reading per control would have been two.
        (int number, _, double[] lanes) = Assert.NotNull(Told(crossing));

        Assert.Equal(1, number);
        Assert.Equal(0.5, lanes[0], 2);
    }

    /// <summary>
    /// A CONTROL TIED WHILE THE VALUE IS ON ITS WAY JOINS IT WHERE IT IS - the
    /// same number, the same frame, the same landing - rather than starting a
    /// curve of its own from wherever the image said the value stood.
    /// </summary>
    [Fact]
    public void AControlJoiningMidFlightRidesTheValueWhereItIs()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var border = (Border)host.ApplyMessage(Read("state-sink.bin"));

        // Sent from 0.5 down to nothing over 400 ms, and a quarter of the way.
        byte[] going = Lanes(value: 0.5, setPoint: 0, law: 2, a: 400, b: (int)SwiftEasing.Linear);

        crossing.Answers = 1;
        crossing.Dirty = Batch(1, SetPoint, going);
        host.Renderer.Cycle.Run(CycleReason.Told);
        crossing.Whole[1] = Batch(1, ~0UL, going);

        clock.Tick(100);
        Assert.Equal(0.375, border.Opacity, 3);

        // A label is described with its opacity on the same number, while the
        // value is still travelling.
        var label = (Label)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(9),
            Type = SwiftNodeType.Label,
            States =
            [
                new SwiftStateEntry(
                    SwiftProp.Opacity, "opacity", 1, SwiftStateMode.InOut, SwiftStateKind.Property),
            ],
        });

        // Where the value IS, at once, and one channel for the two of them.
        Assert.Equal(border.Opacity, label.Opacity, 3);
        Assert.Equal(1, host.Renderer.Motion.Carrying);

        clock.Tick(100);

        Assert.Equal(0.25, border.Opacity, 3);
        Assert.Equal(0.25, label.Opacity, 3);
    }

    /// <summary>
    /// A DRIVEN SCROLLER'S OWN MOVEMENT IS THE STATE'S. A settle onto the grid
    /// and an asked-for glide are decisions this side makes about the offset,
    /// and an offset on a state moves on the state's channel - so every scroller
    /// on the number moves with it, and the state is told where it is going.
    /// </summary>
    [Fact]
    public void ADrivenScrollersOwnMovementMovesTheState()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        var scroll = (ScrollView)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.ScrollView,
            Arranged = true,
            Children =
            [
                new SwiftNode
                {
                    Id = new SwiftId(2),
                    Type = SwiftNodeType.BoxView,
                    Props = new Dictionary<SwiftProp, SwiftWireValue>
                    {
                        [SwiftProp.WidthRequest] = SwiftWireValue.Of(100),
                        [SwiftProp.HeightRequest] = SwiftWireValue.Of(900),
                    },
                },
            ],
            States =
            [
                new SwiftStateEntry(
                    SwiftProp.Scroll, "scroll", 3, SwiftStateMode.InOut, SwiftStateKind.Property),
            ],
        });

        // Laid out with a run three viewports tall, so there is somewhere to go.
        ((IView)scroll).Arrange(new Rect(0, 0, 100, 300));

        Assert.Single(host.Renderer.Cycle.Registered(scroll));
        crossing.Written.Clear();

        _ = host.Renderer.SettleOf(scroll).GlideTo(0, 300);

        // Told where the offset is going - which only the state's own channel
        // says, a movement of the scroller's own being nobody's news.
        (int number, ulong mask, double[] lanes) = Assert.NotNull(Told(crossing));

        Assert.Equal(3, number);
        Assert.NotEqual(0UL, mask & (1UL << 3));
        Assert.Equal(300, lanes[3], 6);
        Assert.Equal(1, host.Renderer.Motion.Carrying);
    }
}
