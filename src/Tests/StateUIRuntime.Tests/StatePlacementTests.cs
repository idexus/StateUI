// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHERE A RUN OF VIEWS GOES, worn on the host's own frames.
//
// The arithmetic that works the run out is the Swift side's and is asserted
// there. What these hold up is this side: that the twelve numbers reach the
// container the library wrapped each face in, that a run written with no law
// lands at once while one written with a law travels, that the two lanes with
// no half-way - a size and a drawing order - are taken at once either way, and
// that a room the platform reports reaches the number that asked for it.

using Microsoft.Maui.Controls;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class StatePlacementTests
{
    private static byte[] Read(string name) => Fixtures.ReadBytes(name);

    /// <summary>How many numbers one view's placement takes.</summary>
    private const int Fields = 12;

    /// <summary>
    /// A run of placements as its lanes: twelve a view, then the law's three.
    /// </summary>
    /// <param name="law">Which law - 0 for none, 2 for a stated length.</param>
    /// <param name="millis">How long, for a stated length.</param>
    /// <param name="places">One array of twelve per view.</param>
    private static byte[] Run(double law, double millis, params double[][] places)
    {
        List<double> lanes = [];

        foreach (double[] place in places)
        {
            lanes.AddRange(place);
        }

        lanes.AddRange([law, millis, (int)SwiftEasing.Linear]);

        byte[] bytes = new byte[lanes.Count * 8];

        for (int lane = 0; lane < lanes.Count; lane++)
        {
            BitConverter.GetBytes(lanes[lane]).CopyTo(bytes, lane * 8);
        }

        return bytes;
    }

    /// <summary>One view's twelve, in the order both sides write them.</summary>
    private static double[] Place(
        double x,
        double y,
        double width = 100,
        double height = 100,
        double opacity = 1,
        double rank = 0,
        double shade = 0) =>
        [x, y, width, height, 0, 0, 0, 1, 1, opacity, rank, shade];

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

    /// <summary>The layout the fixture describes, and the two wrappers in it.</summary>
    private static (AbsoluteLayout Layout, View First, View Second) Placed(Host host)
    {
        var layout = (AbsoluteLayout)host.ApplyMessage(Read("state-placed.bin"));

        return (layout, (View)layout.Children[0], (View)layout.Children[1]);
    }

    /// <summary>
    /// The registration is on the LAYOUT and names no property: a placement is
    /// about the layout's children rather than about a value of its own.
    /// </summary>
    [Fact]
    public void APlacedRunIsRegisteredOnTheLayoutAndNamesNoProperty()
    {
        var host = new Host();
        (AbsoluteLayout layout, View first, _) = Placed(host);

        StateTie run = host.Renderer.Cycle.Registered(layout).Values
            .Single(tie => tie.Kind == SwiftStateKind.Placement);

        Assert.Equal(SwiftStateMode.Out, run.Mode);
        Assert.Null(run.Property);

        // And not one of the twelve is on a child: where the views go is the
        // number's to say, from the registration on.
        Assert.Empty(host.Renderer.Cycle.Registered(first));
    }

    /// <summary>
    /// A ROOM IS A FEED THE HOST WRITES, and it holds all four lanes - where
    /// the view sits as well as how big it is.
    /// </summary>
    [Fact]
    public void AFrameStateHoldsAllFourLanes()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Cycle.Crossing = crossing;

        (AbsoluteLayout layout, _, _) = Placed(host);

        StateTie room = host.Renderer.Cycle.Registered(layout).Values
            .Single(tie => tie.Kind == SwiftStateKind.Feed);

        Assert.Equal(SwiftStateMode.In, room.Mode);

        crossing.Written.Clear();
        ((IView)layout).Arrange(new Rect(4, 8, 320, 240));

        byte[] told = Assert.Single(crossing.Written);
        (int number, ulong mask, byte[] bytes) = Assert.Single(StateBatch.Read(told));

        Assert.Equal(room.Number, number);
        Assert.Equal(0b1111UL, mask);
        Assert.Equal([4, 8, 320, 240], StateBatch.Lanes(bytes));
    }

    /// <summary>
    /// A PLACEMENT UNDER NO LAW IS WORN AT ONCE - what arithmetic re-run on
    /// every frame of a drag means, there being no destination the next frame
    /// will not replace.
    /// </summary>
    [Fact]
    public void APlacementUnderNoneWearsAtOnce()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Motion.Clock = new HandMotionClock();
        host.Renderer.Cycle.Crossing = crossing;

        (AbsoluteLayout layout, View first, View second) = Placed(host);

        int number = host.Renderer.Cycle.Registered(layout).Values
            .Single(tie => tie.Kind == SwiftStateKind.Placement).Number;

        crossing.Answers = 1;
        crossing.Dirty = Batch(number, ~0UL, Run(
            0, 0, Place(10, 20, opacity: 0.5), Place(30, 40, rank: 1)));

        host.Renderer.Cycle.Run(CycleReason.Told);

        Assert.Equal(new Rect(10, 20, 100, 100), AbsoluteLayout.GetLayoutBounds(first));
        Assert.Equal(0.5, first.Opacity, 6);
        Assert.Equal(new Rect(30, 40, 100, 100), AbsoluteLayout.GetLayoutBounds(second));
        Assert.Equal(1, second.ZIndex);
    }

    /// <summary>
    /// A MOVE IS A TRANSLATION over the rectangle already written, never a new
    /// rectangle - which on Android is a whole-hierarchy relayout a frame.
    /// </summary>
    [Fact]
    public void AMoveIsWrittenAsATranslation()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Motion.Clock = new HandMotionClock();
        host.Renderer.Cycle.Crossing = crossing;

        (AbsoluteLayout layout, View first, _) = Placed(host);

        int number = host.Renderer.Cycle.Registered(layout).Values
            .Single(tie => tie.Kind == SwiftStateKind.Placement).Number;

        void Wear(double x)
        {
            crossing.Answers = 1;
            crossing.Dirty = Batch(number, ~0UL, Run(0, 0, Place(x, 0), Place(0, 0)));
            host.Renderer.Cycle.Run(CycleReason.Told);
        }

        Wear(10);
        Assert.Equal(new Rect(10, 0, 100, 100), AbsoluteLayout.GetLayoutBounds(first));
        Assert.Equal(0, first.TranslationX, 6);

        Wear(60);
        Assert.Equal(
            new Rect(10, 0, 100, 100),
            AbsoluteLayout.GetLayoutBounds(first));
        Assert.Equal(50, first.TranslationX, 6);
    }

    /// <summary>
    /// A RUN WRITTEN WITH A LAW TRAVELS, and the two lanes with no half-way go
    /// at once: a size in the air is what a layout pass will not settle on, and
    /// a rank between two ranks is not a picture.
    /// </summary>
    [Fact]
    public void ASizeAndARankNeverTravelInAPlacement()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        (AbsoluteLayout layout, View first, _) = Placed(host);

        int number = host.Renderer.Cycle.Registered(layout).Values
            .Single(tie => tie.Kind == SwiftStateKind.Placement).Number;

        void Wear(ulong mask, byte[] bytes)
        {
            crossing.Answers = 1;
            crossing.Dirty = Batch(number, mask, bytes);
            host.Renderer.Cycle.Run(CycleReason.Told);
        }

        // Placed first, so there is somewhere to travel FROM.
        Wear(~0UL, Run(0, 0, Place(0, 0, 100, 100), Place(0, 0)));

        Wear(~0UL, Run(2, 200, Place(200, 0, 40, 40, rank: 3), Place(0, 0)));

        // The size and the rank are the journey's end from the first frame;
        // the place is a fifth of the way there.
        clock.Tick(100);

        Assert.Equal(new Rect(0, 0, 40, 40), AbsoluteLayout.GetLayoutBounds(first));
        Assert.Equal(3, first.ZIndex);
        Assert.Equal(100, first.TranslationX, 1);

        clock.Tick(100);
        Assert.Equal(200, first.TranslationX, 1);
    }

    /// <summary>
    /// A RUN WRITTEN DURING A JOURNEY BENDS IT rather than starting it again -
    /// which is what lets a finger go on moving cards that are crossing.
    /// </summary>
    [Fact]
    public void AShapeChangeTravelsAndAFingerBendsIt()
    {
        var host = new Host();
        var crossing = new HandCrossing();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;
        host.Renderer.Cycle.Crossing = crossing;

        (AbsoluteLayout layout, View first, _) = Placed(host);

        int number = host.Renderer.Cycle.Registered(layout).Values
            .Single(tie => tie.Kind == SwiftStateKind.Placement).Number;

        void Wear(double law, double millis, double x)
        {
            crossing.Answers = 1;
            crossing.Dirty = Batch(number, ~0UL, Run(law, millis, Place(x, 0), Place(0, 0)));
            host.Renderer.Cycle.Run(CycleReason.Told);
        }

        Wear(0, 0, 0);
        Wear(2, 200, 200);

        clock.Tick(100);
        Assert.Equal(100, first.TranslationX, 1);

        // And bent half way. It is not a fresh curve from 100 to 0, which
        // would read 50 here: the view was going the other way at speed, and a
        // journey that starts from where the value IS and how fast it is going
        // carries that speed on before it turns round.
        Wear(2, 200, 0);

        clock.Tick(100);
        Assert.InRange(first.TranslationX, 51, 100);

        clock.Tick(100);
        Assert.Equal(0, first.TranslationX, 1);
    }

    /// <summary>
    /// A view given the place it is already wearing is skipped before anything
    /// is written - the cache a run of cards is worth 59% of its writes.
    /// </summary>
    [Fact]
    public void APlaceAViewIsAlreadyWearingIsNotWrittenAgain()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Motion.Clock = new HandMotionClock();
        host.Renderer.Cycle.Crossing = crossing;

        (AbsoluteLayout layout, View first, _) = Placed(host);

        int number = host.Renderer.Cycle.Registered(layout).Values
            .Single(tie => tie.Kind == SwiftStateKind.Placement).Number;

        void Wear()
        {
            crossing.Answers = 1;
            crossing.Dirty = Batch(number, ~0UL, Run(0, 0, Place(10, 0), Place(0, 0)));
            host.Renderer.Cycle.Run(CycleReason.Told);
        }

        Wear();

        int written = 0;
        first.PropertyChanged += (_, _) => written++;

        Wear();

        Assert.Equal(0, written);
    }

    /// <summary>
    /// The SHADE is the wrapper's second child and nothing else - a view's own
    /// fade is lane 9, and the darkening drawn over it is lane 11.
    /// </summary>
    [Fact]
    public void AShadeIsWornByTheSecondChildOfTheWrapper()
    {
        var host = new Host();
        var crossing = new HandCrossing();

        host.Renderer.Motion.Clock = new HandMotionClock();
        host.Renderer.Cycle.Crossing = crossing;

        (AbsoluteLayout layout, View first, _) = Placed(host);

        int number = host.Renderer.Cycle.Registered(layout).Values
            .Single(tie => tie.Kind == SwiftStateKind.Placement).Number;

        crossing.Answers = 1;
        crossing.Dirty = Batch(number, ~0UL, Run(
            0, 0, Place(0, 0, opacity: 0.8, shade: 0.6), Place(0, 0)));

        host.Renderer.Cycle.Run(CycleReason.Told);

        var wrapper = (Microsoft.Maui.Controls.Layout)first;

        Assert.Equal(0.8, wrapper.Opacity, 6);
        Assert.Equal(0.6, ((View)wrapper[1]).Opacity, 6);
        Assert.Equal(1, ((View)wrapper[0]).Opacity, 6);
    }

    /// <summary>
    /// A SHADE TELLS THE FOCUS SYSTEM NOTHING ON APPLE: how dark it stands is
    /// the layer's opacity there, and <c>Opacity</c> - which is what the test
    /// above reads - is the other platforms' spelling.
    /// </summary>
    /// <remarks>
    /// <para>
    /// UIKit's alpha setter reports a view coming into sight or going out of
    /// it, and a shade of nothing is a view out of sight - so a gallery whose
    /// card in front wears none takes one shade out and brings one in at every
    /// card crossed. On a Mac each report is a search of the whole window for
    /// something to focus: measured on the gallery's home page as ~100 ms of
    /// main thread in the middle of every crossing, caught with a breakpoint
    /// naming the shade's <c>MauiShapeView</c> at alpha 0 and at 0.0287.
    /// </para>
    /// <para>
    /// Read off the SOURCE because that is the level the defect lives at: the
    /// branch is compiled for Apple alone, and no headless renderer has a focus
    /// system to stall.
    /// </para>
    /// </remarks>
    [Fact]
    public void AShadeTellsTheFocusSystemNothingOnApple()
    {
        string wear = MotionTargetsBody("internal static bool Wear(");
        string shade = MotionTargetsBody("private static void Shade(");

        Assert.DoesNotContain("shade.Opacity", wear);
        Assert.Contains("Shade(shade,", wear);

        int apple = shade.IndexOf("#if IOS || MACCATALYST", StringComparison.Ordinal);
        int layer = shade.IndexOf("Layer.Opacity = ", StringComparison.Ordinal);
        int otherwise = shade.IndexOf("#endif", StringComparison.Ordinal);

        Assert.True(
            apple >= 0 && apple < layer && layer < otherwise,
            "on Apple a shade must be written as the layer's opacity");
    }

    /// <summary>One method of <c>MotionTargets.cs</c>, brace to brace.</summary>
    /// <param name="signature">How the method's declaration begins.</param>
    /// <returns>Everything the method says.</returns>
    private static string MotionTargetsBody(string signature)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        string? file = null;

        while (directory is not null && file is null)
        {
            string candidate = Path.Combine(
                directory.FullName, "src", "StateUI.Runtime", "Rendering", "MotionTargets.cs");

            file = File.Exists(candidate) ? candidate : null;
            directory = directory.Parent;
        }

        Assert.NotNull(file);

        string source = File.ReadAllText(file);
        int begins = source.IndexOf(signature, StringComparison.Ordinal);

        Assert.True(begins > 0, $"{signature} was not found in MotionTargets.cs");

        int depth = 0;
        int at = source.IndexOf('{', begins);

        for (int step = at; step < source.Length; step++)
        {
            if (source[step] == '{') { depth++; }
            else if (source[step] == '}' && --depth == 0) { return source[at..step]; }
        }

        throw new InvalidOperationException($"{signature} has no end");
    }
}
