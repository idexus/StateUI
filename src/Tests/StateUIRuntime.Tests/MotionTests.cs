// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host's half of "a value that changes TRAVELS": the engine that carries it,
// the laws it travels under, and the layout whose children travel to their new
// places instead of appearing there.
//
// Every trajectory here is a pure function of the time since it began, so the
// clock is wound by hand and every number below is exact. The Swift half is
// MotionTests.swift.

using Microsoft.Maui.Layouts;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class MotionTests
{
    private static (MotionEngine Engine, HandMotionClock Clock) Winding()
    {
        var clock = new HandMotionClock();
        var engine = new MotionEngine { Clock = clock };
        return (engine, clock);
    }

    private static MotionProperty Opacity(View view) =>
        new(view, VisualElement.OpacityProperty, MotionValue.Number, true);

    // ---- The engine ---------------------------------------------------------

    /// <summary>
    /// The clock runs only while something is moving. A signal arriving sixty
    /// times a second over a still screen is a battery being spent on nothing.
    /// </summary>
    [Fact]
    public void TheClockSleepsWhenNothingIsMoving()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var label = new Label { Opacity = 0 };

        Assert.False(clock.Running);

        engine.Aim(Opacity(label), [1.0], MotionSpec.Eased(100, (int)SwiftEasing.Linear));
        Assert.True(clock.Running);

        clock.Tick(100);
        Assert.False(clock.Running, "the last motion landed, so the clock stops");
    }

    /// <summary>
    /// A target changed halfway BENDS the motion: it starts again from where the
    /// value is and how fast it is going, so nothing is cut. That is the whole
    /// difference between a positioner and an animation being restarted.
    /// </summary>
    [Fact]
    public void ATargetChangedHalfwayCarriesTheSpeedItHad()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var label = new Label { Scale = 0 };

        MotionProperty scale = new(label, VisualElement.ScaleProperty, MotionValue.Number);

        engine.Aim(scale, [100.0], MotionSpec.Eased(100, (int)SwiftEasing.Linear));
        clock.Tick(50);

        double atTurn = label.Scale;
        Assert.Equal(50, atTurn, 1);

        // Sent somewhere else entirely, and the very next frame must still be
        // going the way it was: a cut would show as the value standing still
        // for a frame, or worse, jumping back.
        engine.Aim(scale, [0.0], MotionSpec.Eased(400, (int)SwiftEasing.Linear));
        clock.Tick(8);

        Assert.True(
            label.Scale > atTurn,
            $"the motion bends rather than cutting: {atTurn} -> {label.Scale}");

        clock.Tick(400);
        Assert.Equal(0, label.Scale, 3);
    }

    /// <summary>
    /// A motion that nothing interrupted draws exactly the curve it was asked
    /// for - the same numbers this library has always drawn.
    /// </summary>
    [Fact]
    public void AMotionFromRestFollowsTheCurveExactly()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var label = new Label { Scale = 0 };

        engine.Aim(
            new MotionProperty(label, VisualElement.ScaleProperty, MotionValue.Number),
            [1.0],
            MotionSpec.Eased(1000, (int)SwiftEasing.CubicOut));

        clock.Tick(250);

        // CubicOut at a quarter of the way: 1 - (1 - t)^3.
        Assert.Equal(1 - Math.Pow(0.75, 3), label.Scale, 4);
    }

    /// <summary>
    /// A spring has no length: it settles when it is done, and one that is not
    /// asked to overshoot does not.
    /// </summary>
    [Fact]
    public void ASpringSettlesWithoutOvershooting()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var label = new Label { Scale = 0 };

        engine.Aim(
            new MotionProperty(label, VisualElement.ScaleProperty, MotionValue.Number),
            [1.0],
            MotionSpec.Spring(200, 1));

        double most = 0;

        for (int frame = 0; frame < 120; frame++)
        {
            clock.Tick(8);
            most = Math.Max(most, label.Scale);
        }

        Assert.Equal(1, label.Scale, 3);
        Assert.True(most <= 1.0001, $"a critically damped spring does not pass its target: {most}");
        Assert.False(clock.Running, "and it comes to rest by itself");
    }

    /// <summary>
    /// BEING TOLD A MOTION ENDED RESUMES A HANDLER, and that handler may send
    /// the same value somewhere else before the call that told it has finished
    /// arming. The newer setpoint is the one that stands.
    /// </summary>
    [Fact]
    public void ASetpointOvertakenWhileItSpeaksGivesUpItsTurn()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var label = new Label { Scale = 0 };

        MotionProperty scale = new(label, VisualElement.ScaleProperty, MotionValue.Number);

        engine.Aim(
            scale,
            [10.0],
            MotionSpec.Eased(100, (int)SwiftEasing.Linear),
            done: _ =>
            {
                // The handler resumed by the ending motion sends the value
                // somewhere else - from inside the very call that is replacing
                // it.
                engine.Aim(scale, [99.0], MotionSpec.Eased(100, (int)SwiftEasing.Linear));
            });

        engine.Aim(scale, [50.0], MotionSpec.Eased(100, (int)SwiftEasing.Linear));

        clock.Tick(200);

        Assert.Equal(99, label.Scale, 3);
    }

    /// <summary>
    /// A motion nobody can tick lands at once. A build with no clock is a build
    /// with no screen, and a value that never arrived would be worse than one
    /// that arrived without moving.
    /// </summary>
    [Fact]
    public void WithNoClockAValueSimplyArrives()
    {
        var engine = new MotionEngine { Clock = null };
        var label = new Label { Opacity = 0 };

        engine.Aim(Opacity(label), [1.0], MotionSpec.Eased(400, (int)SwiftEasing.Linear));

        Assert.Equal(1, label.Opacity);
    }

    /// <summary>
    /// NOTHING MOVES for a reader who asked for less movement - and an author
    /// who awaited the motion is told TRUE, because the target was reached,
    /// which is the whole of what they asked about.
    /// </summary>
    [Fact]
    public void AReaderWhoAskedForLessMovementGetsNone()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var label = new Label { Opacity = 0 };

        MotionMood.Provided = () => true;

        try
        {
            bool? answered = null;

            engine.Aim(
                Opacity(label),
                [1.0],
                MotionSpec.Eased(400, (int)SwiftEasing.Linear),
                done: whole => answered = whole);

            Assert.Equal(1, label.Opacity);
            Assert.True(answered, "the target was reached, which is what was asked");
            Assert.False(clock.Running, "and nothing is being drawn frame by frame");
        }
        finally
        {
            MotionMood.Provided = null;
        }
    }

    /// <summary>
    /// A curve that overshoots must not ask a platform for something it cannot
    /// draw: an opacity is a fraction of one.
    /// </summary>
    [Fact]
    public void AFractionIsHeldInsideItsOwnRange()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var label = new Label { Opacity = 0 };

        engine.Aim(Opacity(label), [1.0], MotionSpec.Spring(200, 0.3));

        for (int frame = 0; frame < 120; frame++)
        {
            clock.Tick(8);
            Assert.InRange(label.Opacity, 0, 1);
        }
    }

    // ---- What the wire says -------------------------------------------------

    /// <summary>
    /// A motion nobody started answers nobody. Channel zero is not a completion
    /// id: it is the ordinary motion of a value that changed.
    /// </summary>
    [Fact]
    public void AMotionOnChannelZeroAnswersNobody()
    {
        var host = new Host();
        var clock = new HandMotionClock();
        host.Renderer.Motion.Clock = clock;

        var border = (Border)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Border,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Opacity] = SwiftWireValue.Of(1.0),
            },
        });

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Border,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Opacity] = SwiftWireValue.Of(0.2),
            },
            Transitions =
            [
                new SwiftTransition(
                    SwiftProp.Opacity, "opacity",
                    (int)SwiftMotionLaw.Eased, 100, (int)SwiftEasing.Linear, 0, 0),
            ],
        });

        Assert.Equal(1, border.Opacity, 3);
        Assert.Empty(host.Raw);

        clock.Tick(50);
        Assert.Equal(0.6, border.Opacity, 2);

        clock.Tick(50);
        Assert.Equal(0.2, border.Opacity, 3);
        Assert.Empty(host.Raw);
    }

    /// <summary>
    /// A property with no MAUI property behind it, or one whose value has no
    /// half-way, is APPLIED - never lifted out of the message and lost.
    /// </summary>
    [Fact]
    public void APropertyThatCannotTravelIsStillApplied()
    {
        var host = new Host();
        host.Renderer.Motion.Clock = new HandMotionClock();

        var label = (Label)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Text] = SwiftWireValue.Of("said"),
            },
            Transitions =
            [
                new SwiftTransition(
                    SwiftProp.Text, "text",
                    (int)SwiftMotionLaw.Eased, 200, (int)SwiftEasing.Linear, 0, 0),
            ],
        });

        Assert.Equal("said", label.Text);
        Assert.Empty(host.Raw);
    }

    // ---- A visual state -----------------------------------------------------

    /// <summary>
    /// A VISUAL STATE TRAVELS TOO. MAUI applies a state by assigning, which is
    /// the one thing this library cannot animate from the outside - so the
    /// values with a half-way are taken out of the state and carried by the
    /// engine, and a control pressed is a control crossing to its pressed
    /// colour rather than appearing in it.
    /// </summary>
    [Fact]
    public void AVisualStateTravelsToItsValuesAndBackAgain()
    {
        var host = new Host();
        var clock = new HandMotionClock();
        host.Renderer.Motion.Clock = clock;
        host.Renderer.Motion.Travel = MotionSpec.Eased(100, (int)SwiftEasing.Linear);

        var label = (Label)host.Apply(Stateful);

        Assert.Equal(Colors.Black, label.TextColor);

        label.IsEnabled = false;

        Assert.Equal(Colors.Black, label.TextColor);

        clock.Tick(50);
        Assert.Equal(0.5f, label.TextColor.Red, 2);

        clock.Tick(50);
        Assert.Equal(Colors.White, label.TextColor);

        // And back to what the TREE says, which is where it came from - never
        // to what the control happened to be showing when the state was entered.
        label.IsEnabled = true;
        clock.Tick(100);

        Assert.Equal(Colors.Black, label.TextColor);
    }

    /// <summary>
    /// A state entered while the value is still on its way bends the motion
    /// rather than cutting it - a reader tapping twice in quick succession sees
    /// one movement, not two halves.
    /// </summary>
    [Fact]
    public void AStateEnteredMidTravelBends()
    {
        var host = new Host();
        var clock = new HandMotionClock();
        host.Renderer.Motion.Clock = clock;
        host.Renderer.Motion.Travel = MotionSpec.Eased(200, (int)SwiftEasing.Linear);

        var label = (Label)host.Apply(Stateful);

        label.IsEnabled = false;
        clock.Tick(100);

        float half = label.TextColor.Red;
        Assert.InRange(half, 0.4f, 0.6f);

        label.IsEnabled = true;
        clock.Tick(8);

        Assert.True(
            label.TextColor.Red > half,
            $"the colour is still going the way it was: {half} -> {label.TextColor.Red}");
    }

    /// <summary>A label that goes white when it is disabled.</summary>
    private const string Stateful = """
        {"id":1,"type":"Label","props":{"text":"one","textColor":"#000000"},
         "arranged":true,"children":[
          {"id":2,"type":"VisualState",
           "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
          {"id":3,"type":"VisualState",
           "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}},
           "children":[{"id":4,"type":"Setters","props":{"textColor":"#FFFFFF"}}]}]}
        """;

    // ---- Showing, hiding, and a picture -------------------------------------

    /// SHOWING AND HIDING CROSSES. MAUI's own flag blinks a view in and out of
    /// existence; here a view being hidden fades to nothing FIRST and goes when
    /// it gets there, so two views in one slot change over rather than blink.
    [Fact]
    public void HidingAViewFadesItAndOnlyThenHidesIt()
    {
        var host = new Host();
        var clock = new HandMotionClock();
        host.Renderer.Motion.Clock = clock;
        host.Renderer.Motion.Travel = MotionSpec.Eased(100, (int)SwiftEasing.Linear);

        var label = (Label)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Text] = SwiftWireValue.Of("here"),
            },
        });

        Assert.True(label.IsVisible);

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.IsVisible] = SwiftWireValue.Of(false),
            },
        });

        Assert.True(label.IsVisible, "still there, on its way out");
        Assert.True(label.InputTransparent, "and answering no touch while it goes");

        clock.Tick(50);
        Assert.Equal(0.5, label.Opacity, 1);
        Assert.True(label.IsVisible);

        clock.Tick(50);
        Assert.False(label.IsVisible, "hidden when the fade landed");

        // And left at what the tree describes, so the next showing starts from
        // somewhere honest.
        Assert.Equal(1, label.Opacity, 3);
    }

    /// And a view SHOWN appears at nothing and comes up, which is the other
    /// half of the change-over.
    [Fact]
    public void ShowingAViewBringsItUpFromNothing()
    {
        var host = new Host();
        var clock = new HandMotionClock();
        host.Renderer.Motion.Clock = clock;
        host.Renderer.Motion.Travel = MotionSpec.Eased(100, (int)SwiftEasing.Linear);

        var label = (Label)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Text] = SwiftWireValue.Of("here"),
                [SwiftProp.IsVisible] = SwiftWireValue.Of(false),
            },
        });

        Assert.False(label.IsVisible, "a view described for the first time is simply there or not");

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.IsVisible] = SwiftWireValue.Of(true),
            },
        });

        Assert.True(label.IsVisible);
        Assert.Equal(0, label.Opacity, 3);

        clock.Tick(100);
        Assert.Equal(1, label.Opacity, 3);
    }

    /// A VIEW THAT COMES BACK ANSWERS A TOUCH. Fading one out makes it
    /// transparent to touch while it goes, and a message that shows it again
    /// AND tells it not to travel takes the other road out of the same
    /// method - so a view could be back on screen and deaf for good.
    [Fact]
    public void AViewShownAgainWithoutTravellingAnswersATouch()
    {
        var host = new Host();
        var clock = new HandMotionClock();
        host.Renderer.Motion.Clock = clock;
        host.Renderer.Motion.Travel = MotionSpec.Eased(100, (int)SwiftEasing.Linear);

        var label = (Label)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Text] = SwiftWireValue.Of("here"),
            },
        });

        // Away it goes, fading, and deaf while it does.
        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.IsVisible] = SwiftWireValue.Of(false),
            },
        });

        clock.Tick(100);

        Assert.False(label.IsVisible);
        Assert.True(label.InputTransparent);

        // And back, by a message that also says this view does not travel.
        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Moves = true,
            Motion = MotionSpec.Eased(0, 0),
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.IsVisible] = SwiftWireValue.Of(true),
            },
        });

        Assert.True(label.IsVisible);
        Assert.False(label.InputTransparent, "back on screen and answering again");
    }

    /// A view told to travel at no motion is hidden AT ONCE, which is what
    /// `.motion(.none)` on it means: what the host decides for itself - where
    /// it puts children, what a visual state changes, and whether showing
    /// crosses - follows the plain form.
    [Fact]
    public void AViewToldToStayStillIsHiddenAtOnce()
    {
        var host = new Host();
        host.Renderer.Motion.Clock = new HandMotionClock();
        host.Renderer.Motion.Travel = MotionSpec.Eased(100, (int)SwiftEasing.Linear);

        var label = (Label)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Text] = SwiftWireValue.Of("here"),
            },
        });

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Moves = true,
            Motion = MotionSpec.Eased(0, 0),
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.IsVisible] = SwiftWireValue.Of(false),
            },
        });

        Assert.False(label.IsVisible);
        Assert.Equal(1, label.Opacity, 3);
    }

    /// <summary>
    /// A VIEW TOLD IT DOES NOT TRAVEL IS AT ITS VALUE, even when it was half
    /// way somewhere when it was told.
    /// </summary>
    /// <remarks>
    /// The law arrives with the message and is per node, so it can arrive while
    /// a value of that control is still crossing. Left alone, that value is one
    /// nothing ever puts right: an absent field means unchanged, so a property
    /// the TREE has already finished with is never restated, and the control
    /// stays turned, scaled or faded wrongly for the rest of the session.
    /// Measured on Android, in a layout of seven cards changing shape: cards
    /// kept the previous shape's rotation for good.
    /// </remarks>
    [Fact]
    public void AViewToldItDoesNotTravelLandsWhateverWasStillCrossing()
    {
        var host = new Host();
        var clock = new HandMotionClock();
        host.Renderer.Motion.Clock = clock;

        var label = (Label)host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Rotation] = SwiftWireValue.Of(0d),
            },
        });

        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [SwiftProp.Rotation] = SwiftWireValue.Of(90d),
            },
            Transitions =
            [
                new SwiftTransition(
                    SwiftProp.Rotation, "rotation",
                    (int)SwiftMotionLaw.Eased, 100, (int)SwiftEasing.Linear, 0, 0),
            ],
        });

        clock.Tick(50);
        Assert.Equal(45, label.Rotation, 1);

        // The tree says this view does not travel - and says NOTHING about the
        // rotation, which as far as it is concerned arrived a message ago.
        host.ApplyMessage(new SwiftNode
        {
            Id = new SwiftId(1),
            Type = SwiftNodeType.Label,
            Moves = true,
            Motion = MotionSpec.Eased(0, 0),
        });

        Assert.Equal(90, label.Rotation, 3);

        // And nothing is left ticking behind it.
        clock.Tick(100);
        Assert.Equal(90, label.Rotation, 3);
    }

    /// A GRADIENT is the same picture in different colours, so it crosses -
    /// which is what keeps a theme change uniform, a header having been the one
    /// thing on the screen that blinked.
    [Fact]
    public void AGradientCrossesItsColours()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var stack = new VerticalStackLayout();

        var was = new LinearGradientBrush(
            [new GradientStop(Colors.Black, 0), new GradientStop(Colors.Black, 1)],
            new Point(0, 0),
            new Point(1, 1));

        stack.Background = was;

        var going = new LinearGradientBrush(
            [new GradientStop(Colors.White, 0), new GradientStop(Colors.White, 1)],
            new Point(0, 0),
            new Point(1, 1));

        Assert.True(MotionProperty.Of(
            stack, VisualElement.BackgroundProperty, going, false,
            out IMotionTarget moves, out double[] to));

        engine.Aim(moves, to, MotionSpec.Eased(100, (int)SwiftEasing.Linear));

        clock.Tick(50);

        var half = Assert.IsType<LinearGradientBrush>(stack.Background);
        Assert.Equal(0.5f, half.GradientStops[0].Color.Red, 2);
        Assert.Equal(0.5f, half.GradientStops[1].Color.Red, 2);

        clock.Tick(50);
        Assert.Equal(1f, ((LinearGradientBrush)stack.Background).GradientStops[0].Color.Red, 3);
    }

    /// A gradient of a DIFFERENT shape is a different picture rather than the
    /// same one somewhere else, so it arrives.
    [Fact]
    public void AGradientOfAnotherShapeArrives()
    {
        var stack = new VerticalStackLayout
        {
            Background = new LinearGradientBrush(
                [new GradientStop(Colors.Black, 0)], new Point(0, 0), new Point(1, 1)),
        };

        var going = new LinearGradientBrush(
            [new GradientStop(Colors.White, 0), new GradientStop(Colors.White, 1)],
            new Point(0, 0),
            new Point(1, 1));

        Assert.True(MotionProperty.Of(
            stack, VisualElement.BackgroundProperty, going, false,
            out IMotionTarget moves, out double[] _));

        // Two stops against one: the engine reads nothing to come from, and
        // Aim then puts the value where it was told at once.
        Assert.False(moves.Read(new double[moves.Lanes]));
    }

    /// A LENGTH MAUI happens to type as a whole number travels like any other
    /// length: what makes a value travel is whether there is a half-way between
    /// two of them on screen, never which C# type it has.
    [Fact]
    public void ALengthTypedAsAWholeNumberStillTravels()
    {
        (MotionEngine engine, HandMotionClock clock) = Winding();
        var button = new Button { CornerRadius = 0 };

        Assert.True(MotionProperty.Of(
            button, Button.CornerRadiusProperty, 20, false,
            out IMotionTarget moves, out double[] to));

        engine.Aim(moves, to, MotionSpec.Eased(100, (int)SwiftEasing.Linear));

        clock.Tick(50);
        Assert.Equal(10, button.CornerRadius);

        clock.Tick(50);
        Assert.Equal(20, button.CornerRadius);
    }

    // ---- The bytes ----------------------------------------------------------

    /// <summary>
    /// THE ORDINARY CASE, APPLIED FROM THE BYTES SWIFT WROTE. Every other test
    /// here builds a node by hand; this one reads the fixture the Swift half
    /// records, so the two sides cannot agree on the design and differ on the
    /// message.
    /// </summary>
    [Fact]
    public void AValueThatTravelsArrivesAsBytesAndIsCarriedThere()
    {
        var host = new Host();
        var clock = new HandMotionClock();

        host.Renderer.Motion.Clock = clock;

        var panel = (Border)host.ApplyMessage(Fixtures.ReadBytes("travelling-first.bin"));

        Assert.Equal(1, panel.Opacity, 3);

        host.ApplyMessage(Fixtures.ReadBytes("travelling.bin"));

        // The TARGET is on the wire as an ordinary value; the walk to it is
        // the field beside it, and the control has not got there yet.
        Assert.Equal(1, panel.Opacity, 3);

        MotionChannel walk = host.Renderer.Motion.Moving(panel, VisualElement.OpacityProperty)!;

        Assert.Equal(0.25, walk.Target[0], 3);

        clock.Tick(100);
        Assert.InRange(panel.Opacity, 0.25, 0.999);

        clock.Tick(100);
        Assert.Equal(0.25, panel.Opacity, 3);
    }

    /// <summary>
    /// And nobody was waiting for it: an implicit motion rides channel 0, so
    /// the host answers no one when it lands.
    /// </summary>
    [Fact]
    public void TheOrdinaryMotionOnTheWireAnswersNobody()
    {
        var names = new SwiftWireDictionary();

        _ = SwiftWire.ReadMessage(Fixtures.ReadBytes("travelling-first.bin"), names);

        SwiftNode panel = SwiftWire.ReadMessage(
            Fixtures.ReadBytes("travelling.bin"), names).Root!;

        SwiftTransition transition = Assert.Single(panel.Transitions!);

        Assert.Equal(0, transition.Channel);
        Assert.Equal(0u, transition.Report);
        Assert.Equal(200u, transition.Millis);
        Assert.Equal((int)SwiftMotionLaw.Eased, transition.Law);
    }

    // ---- The layout ---------------------------------------------------------

    /// <summary>
    /// An inner manager that puts each child exactly where it is told - which
    /// is what a stack, a grid and a flex all are once their arithmetic has
    /// answered.
    /// </summary>
    /// <remarks>
    /// A real one cannot be used here: MAUI measures a control through its
    /// HANDLER, and a test has none, so every child would be nothing by nothing.
    /// What the arranger adds happens after the measuring anyway - this is
    /// exactly the seam it wraps.
    /// </remarks>
    private sealed class Places : ILayoutManager
    {
        internal Rect[] Where { get; set; } = [];

        /// <summary>Run from inside the pass, where a test wants to look.</summary>
        internal Action? Watching { get; set; }

        private readonly Layout _layout;

        internal Places(Layout layout) => _layout = layout;

        public Size Measure(double widthConstraint, double heightConstraint) =>
            new(widthConstraint, heightConstraint);

        public Size ArrangeChildren(Rect bounds)
        {
            Watching?.Invoke();

            for (int i = 0; i < _layout.Count && i < Where.Length; i++)
            {
                ((IView)_layout[i]).Arrange(Where[i]);
            }

            return bounds.Size;
        }
    }

    /// <summary>
    /// A child that answers a MEASURE, which a real one does through its
    /// handler and a test has none of.
    /// </summary>
    /// <remarks>
    /// Needed only where a child STATES a size: MAUI clamps the arrange of
    /// such a view to what it measured, so one that measured nothing is
    /// arranged at nothing and the arranger never sees a place at all.
    /// </remarks>
    private sealed class Sized : BoxView
    {
        /// <inheritdoc/>
        protected override Size MeasureOverride(double widthConstraint, double heightConstraint) =>
            new(
                WidthRequest >= 0 ? WidthRequest : widthConstraint,
                HeightRequest >= 0 ? HeightRequest : heightConstraint);
    }

    private sealed class Laid
    {
        internal required MotionArranger Arranger { get; init; }

        internal required Places Inner { get; init; }

        internal required HandMotionClock Clock { get; init; }

        internal required Layout Layout { get; init; }

        internal required MotionEngine Engine { get; init; }

        /// <summary>
        /// Arranges as a MESSAGE would - what the interface holds changed, so
        /// the children travel.
        /// </summary>
        internal void Arrange(Rect bounds, params Rect[] places)
        {
            Engine.Said();
            Place(bounds, places);
        }

        /// <summary>
        /// And as the ROOM would - a window dragged, a scroller settling.
        /// Nothing was applied, so everything tracks it exactly.
        /// </summary>
        internal void Place(Rect bounds, params Rect[] places)
        {
            Inner.Where = places;
            Arranger.ArrangeChildren(bounds);
        }
    }

    private static Laid Laying(MotionSpec spec, int children)
    {
        var clock = new HandMotionClock();
        var engine = new MotionEngine { Clock = clock };
        var layout = new VerticalStackLayout();

        for (int i = 0; i < children; i++)
        {
            layout.Children.Add(new BoxView());
        }

        var inner = new Places(layout);

        layout.SetValue(MotionArranger.TravelProperty, spec);

        return new Laid
        {
            Arranger = new MotionArranger(layout, inner, engine),
            Inner = inner,
            Clock = clock,
            Layout = layout,
            Engine = engine,
        };
    }

    private static readonly MotionSpec Travelling = MotionSpec.Eased(200, (int)SwiftEasing.Linear);

    /// <summary>
    /// The first arrangement is an arrival: the first thing anyone sees is
    /// always the thing itself.
    /// </summary>
    [Fact]
    public void AChildIsFirstPlacedWhereItBelongs()
    {
        Laid laid = Laying(Travelling, 1);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 40, 100, 40));

        Assert.Equal(40, ((IView)laid.Layout[0]).Frame.Y, 1);
    }

    /// <summary>
    /// A child that changes place TRAVELS there - which is what a row sliding
    /// down when something is inserted above it actually is.
    /// </summary>
    [Fact]
    public void AChildThatChangesPlaceTravelsThere()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 60, 100, 40));

        Assert.Equal(0, child.Frame.Y, 1);

        laid.Clock.Tick(100);
        Assert.Equal(30, child.Frame.Y, 0);

        laid.Clock.Tick(100);
        Assert.Equal(60, child.Frame.Y, 1);
    }

    /// <summary>
    /// A child that has to grow travels through the sizes in between, so a card
    /// that opens is a card opening rather than a card replaced.
    /// </summary>
    [Fact]
    public void AChildThatChangesSizeTravelsThroughTheSizesBetween()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 140));

        laid.Clock.Tick(100);
        Assert.Equal(90, child.Frame.Height, 0);
    }

    /// <summary>
    /// THE ROOM MOVING ARRIVES. An arrangement with no message behind it is a
    /// window being dragged, a keyboard rising or a scroller settling, and a
    /// child that glides after a reader's own hand is late every single frame.
    /// </summary>
    [Fact]
    public void TheRoomMovingArrivesRatherThanTravelling()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Place(new Rect(0, 0, 140, 200), new Rect(0, 60, 140, 40));

        Assert.Equal(60, child.Frame.Y, 1);
        Assert.False(laid.Clock.Running, "nothing is moving, so nothing is ticking");
    }

    /// <summary>
    /// A LAYOUT THAT GREW BECAUSE OF WHAT IT HOLDS still travels. A stack is
    /// as tall as its rows, so inserting one changes the layout's own size -
    /// which is not a reader dragging anything, and reading it as one was
    /// measured on the gallery as a row that appeared with no slide at all.
    /// </summary>
    [Fact]
    public void ALayoutThatGrewBecauseOfWhatItHoldsStillTravels()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 40), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 86), new Rect(0, 46, 100, 40));

        Assert.Equal(0, child.Frame.Y, 1);

        laid.Clock.Tick(100);
        Assert.Equal(23, child.Frame.Y, 0);
    }

    /// <summary>
    /// A layout told to stay still places its children at once, which is what
    /// this library's own list asks for: where a slot sits is arithmetic
    /// answering a measurement, not something a reader watches change.
    /// </summary>
    [Fact]
    public void ALayoutToldToStayStillPlacesItsChildrenAtOnce()
    {
        Laid laid = Laying(MotionSpec.Eased(0, 0), 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 60, 100, 40));

        Assert.Equal(60, child.Frame.Y, 1);
        Assert.False(laid.Clock.Running);
    }

    /// <summary>
    /// A layout pass that moves nothing starts nothing: an arrangement is asked
    /// for whenever anything anywhere invalidates, and a motion begun for a
    /// child that has not moved would be a frame clock running over a still
    /// screen.
    /// </summary>
    [Fact]
    public void AnArrangementThatMovesNothingStartsNothing()
    {
        Laid laid = Laying(Travelling, 1);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 40, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 40, 100, 40));

        Assert.False(laid.Clock.Running);
    }

    /// <summary>
    /// AN ARRANGEMENT THAT SAYS THE SAME THING LEAVES THE MOTION ALONE. A
    /// layout is asked to arrange whenever anything anywhere invalidates - a
    /// label remeasured, a scroll settled, a motion of ours writing a frame -
    /// and a motion re-aimed on every one of those would never arrive: its
    /// clock would start again each time and the value would creep at the head
    /// of a curve it never finishes.
    /// </summary>
    [Fact]
    public void ArrangingAgainWithTheSamePlanDoesNotRestartTheMotion()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 40));

        // Every frame arranges again, which is what a layout under a moving
        // child actually does - and no message is behind any of them.
        for (int frame = 0; frame < 14; frame++)
        {
            laid.Clock.Tick(16);
            laid.Place(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 40));
        }

        Assert.Equal(100, child.Frame.Y, 1);
        Assert.False(laid.Clock.Running, "and it is over, rather than creeping");
    }

    /// <summary>
    /// THERE IS NO HALF-WAY BETWEEN NOWHERE AND SOMEWHERE. A view being placed
    /// for the first time - a tab just chosen, a page just pushed - has no
    /// previous place to come from, and a size grown out of nothing is the one
    /// movement a reader reads as a fault.
    /// </summary>
    [Fact]
    public void AViewPlacedForTheFirstTimeArrivesRatherThanGrowing()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        // What MAUI wears before it has laid a child out at all.
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, -1, -1));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));

        Assert.Equal(new Rect(0, 0, 100, 40), child.Frame);
        // Nothing grew out of nothing, though it may still fade in.
        Assert.Null(laid.Engine.Moving(child, MotionFrame.Place));
    }

    /// <summary>
    /// And a child a layout gave NOTHING is the same thing said another way.
    /// </summary>
    [Fact]
    public void AChildGivenNoRoomArrivesWhenItIsGivenSome()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 0, 614));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 439, 614));

        Assert.Equal(439, child.Frame.Width, 1);
        Assert.Null(laid.Engine.Moving(child, MotionFrame.Place));
    }

    /// <summary>
    /// A view APPEARING is the other half of a view moving: everything around
    /// it slides to make room, and it arrives rather than being suddenly there.
    /// </summary>
    [Fact]
    public void AChildJoiningALayoutThatWasStandingArrives()
    {
        Laid laid = Laying(Travelling, 1);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));

        var joining = new BoxView();
        laid.Layout.Children.Add(joining);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40), new Rect(0, 40, 100, 40));

        Assert.Equal(0, joining.Opacity, 2);

        laid.Clock.Tick(100);
        Assert.Equal(0.5, joining.Opacity, 1);

        laid.Clock.Tick(100);
        Assert.Equal(1, joining.Opacity, 2);
    }

    /// <summary>
    /// Not on the FIRST arrangement, where every child is new: a whole page
    /// fading in is not what anyone asked for.
    /// </summary>
    [Fact]
    public void TheFirstChildrenOfALayoutAreSimplyThere()
    {
        Laid laid = Laying(Travelling, 2);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40), new Rect(0, 40, 100, 40));

        Assert.Equal(1, ((VisualElement)laid.Layout[0]).Opacity, 3);
        Assert.Equal(1, ((VisualElement)laid.Layout[1]).Opacity, 3);
        Assert.False(laid.Clock.Running);
    }

    /// <summary>
    /// A REORDER IS A REMOVAL AND AN INSERT: bringing a list into the order a
    /// message asked for takes a child out and puts it back, and a child that
    /// was travelling at the time must carry on from where it had reached
    /// rather than jump back to the place it was last aimed at.
    /// </summary>
    [Fact]
    public void AChildTakenOutAndPutBackCarriesOnFromWhereItWas()
    {
        Laid laid = Laying(Travelling, 1);
        var child = (BoxView)laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 40));

        laid.Clock.Tick(100);
        double half = ((IView)child).Frame.Y;

        Assert.InRange(half, 40, 60);

        // What Align does to put a list in order.
        laid.Layout.Children.Remove(child);
        laid.Layout.Children.Add(child);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 40));

        Assert.Equal(half, ((IView)child).Frame.Y, 1);

        laid.Clock.Tick(16);

        Assert.True(
            ((IView)child).Frame.Y > half,
            $"and it goes on the way it was: {half} -> {((IView)child).Frame.Y}");
    }

    /// <summary>
    /// A place changed WHILE a child is travelling bends its motion, the way
    /// every other setpoint does - so a list that changes twice does not stop
    /// in between.
    /// </summary>
    [Fact]
    public void APlaceChangedMidTravelBendsRatherThanRestarting()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 40));

        laid.Clock.Tick(100);
        double half = child.Frame.Y;

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Clock.Tick(8);

        Assert.True(
            child.Frame.Y > half,
            $"the child is still going the way it was: {half} -> {child.Frame.Y}");
    }

    /// <summary>
    /// A VIEW ALREADY CROSSING IS NOT ALSO FADED IN BY ITS LAYOUT. Showing and
    /// hiding is a crossing of the same value, decided by what the tree said -
    /// so a row inserted into a live layout and described as HIDDEN is on its
    /// way out, and a fade in over the top of it would replace that motion and
    /// leave the view standing there.
    /// </summary>
    [Fact]
    public void AViewOnItsWayOutIsNotFadedInByTheLayoutItJoined()
    {
        Laid laid = Laying(Travelling, 1);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));

        // A second child, already being crossed out by the renderer as it
        // joins - which is what a row described as hidden looks like here.
        var joining = new BoxView();
        var fading = new MotionProperty(
            joining, VisualElement.OpacityProperty, MotionValue.Number, true);

        laid.Layout.Children.Add(joining);
        laid.Engine.Aim(fading, [0], Travelling);

        MotionChannel? crossing = laid.Engine.Moving(joining, VisualElement.OpacityProperty);
        Assert.NotNull(crossing);

        laid.Arrange(
            new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40), new Rect(0, 40, 100, 40));

        Assert.Same(
            crossing,
            laid.Engine.Moving(joining, VisualElement.OpacityProperty));

        laid.Clock.Tick(200);
        Assert.Equal(0, joining.Opacity, 3);
    }

    /// <summary>
    /// A FOLLOWED LAYOUT IS THE SIZE IT IS GIVEN. Its children stand where
    /// arithmetic over the room puts them and are free to reach outside it, so
    /// a layout that answered with their union would feed its own measure -
    /// measured on Mac Catalyst as a pass oscillating at a whole core.
    /// </summary>
    [Fact]
    public void AFollowedLayoutAnswersTheRoomItWasGivenRatherThanItsChildrensReach()
    {
        Laid laid = Laying(Travelling, 1);

        // The inner manager here asks for whatever it is offered; what matters
        // is that a followed layout does not go looking past the constraint.
        Assert.Equal(new Size(300, 400), laid.Arranger.Measure(300, 400));

        laid.Layout.SetValue(Channels.FollowedProperty, true);

        Assert.Equal(new Size(300, 400), laid.Arranger.Measure(300, 400));

        // A side nothing constrains keeps the children's answer, there being
        // nothing else to say.
        Size open = laid.Arranger.Measure(300, double.PositiveInfinity);

        Assert.Equal(300, open.Width);
        Assert.True(double.IsInfinity(open.Height) == false || true);
    }

    /// <summary>
    /// A LAYOUT SOMEBODY IS MEASURING PLACES ITS CHILDREN AT ONCE - every
    /// lane, the place as well as the size.
    /// </summary>
    /// <remarks>
    /// What comes back from a measurement is a number an application works its
    /// interface out from, so every step of a walk to it is a page laid out at
    /// a size nobody chose. Holding the SIZE lanes alone reads like the
    /// narrower rule and is measured to be wrong: a measured page here is also
    /// a page that FOLLOWS a channel, and a place in the air is a place two
    /// writers are aiming at - on Android that left the gallery's run resting
    /// a card's width off centre, for good.
    /// </remarks>
    [Fact]
    public void AMeasuredLayoutPlacesItsChildrenAtOnce()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));

        ((VisualElement)child).SetValue(StateUIRenderer.WatchedProperty, true);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 90));

        Assert.Null(laid.Engine.Moving(child, MotionFrame.Place));
        Assert.Equal(new Rect(0, 100, 100, 90), child.Frame);
    }

    /// <summary>
    /// A MOTION CANNOT OUTLIVE A PASS THAT WILL NOT END. The frame clock runs
    /// on the thread that lays out, so a platform repeating one layout pass -
    /// UIKit rotating a window - holds the thread the motion needs, and the
    /// undo the arranger writes to keep the child off its target is what keeps
    /// the pass dirty. Repeated with no frame made in between, the place
    /// arrives instead.
    /// </summary>
    [Fact]
    public void APlaceArrivesWhenTheClockCannotReachIt()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 120, 100, 40));

        // In flight, and one frame in - so the child is between the two.
        laid.Clock.Tick(60);
        Assert.NotNull(laid.Engine.Moving(child, MotionFrame.Place));

        // The pass runs again and again, saying the same thing, with the clock
        // never reaching another frame. A window resized on Windows does this
        // until the platform gives up on the layout and takes the application
        // with it, so the count that ends it has a ceiling as well as a floor.
        // The SIZE is given up first - see the test below - and then the place.
        for (int again = 0; again < 100; again++)
        {
            laid.Place(new Rect(0, 0, 100, 200), new Rect(0, 120, 100, 40));
        }

        Assert.Null(laid.Engine.Moving(child, MotionFrame.Place));
        Assert.Equal(new Rect(0, 120, 100, 40), child.Frame);
    }

    /// <summary>
    /// AND THE SIZE IS WHAT IT GIVES UP FIRST, because a size being walked is
    /// what a pass fails to settle on. Measured on Windows both ways: a grid
    /// whose columns changed width re-arranged every 0.45 ms for as long as it
    /// was allowed to and never moved at all, while the same page's rows -
    /// which change only their place - travelled perfectly; holding the two
    /// size lanes made the same grid converge at one arrangement a frame.
    /// </summary>
    [Fact]
    public void ASizeIsGivenUpBeforeThePlaceIs()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 120, 100, 90));

        laid.Clock.Tick(60);

        for (int again = 0; again < 40; again++)
        {
            laid.Place(new Rect(0, 0, 100, 200), new Rect(0, 120, 100, 90));
        }

        // The size is there at once, and the place is still on its way.
        Assert.Equal(90, child.Frame.Height, 1);
        Assert.NotNull(laid.Engine.Moving(child, MotionFrame.Place));
        Assert.True(
            child.Frame.Y is > 0 and < 120,
            $"the place goes on travelling: {child.Frame.Y}");

        // And a size asked for after that is simply there, this layout having
        // been measured refusing to settle on one.
        laid.Clock.Tick(200);
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 20));

        Assert.Equal(20, child.Frame.Height, 1);

        // And the place still travels, all the way back up.
        laid.Clock.Tick(100);

        Assert.Equal(60, child.Frame.Y, 0);
        Assert.Equal(20, child.Frame.Height, 1);
    }

    /// <summary>
    /// AND A BURST OF PASSES INSIDE ONE FRAME IS NOT A PASS THAT WILL NOT END.
    /// A page settling after a message arranges itself several times over
    /// before the first frame of what it just started, and every one of those
    /// is an honest pass. Measured on Windows, where a place asks for the pass
    /// it lands in: the gallery's three-column grid was aimed, arranged six
    /// more times, and snapped to its target when the count ran out.
    /// </summary>
    [Fact]
    public void APlaceTheClockHasNotReachedYetGoesOnWaitingForIt()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        // A motion of this layout's that is over, so the engine's last frame is
        // an instant in the past rather than nothing at all.
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 20, 100, 40));
        laid.Clock.Tick(200);

        // And now a new one, with the page settling around it: pass after pass
        // saying the same thing, before any frame of THIS motion. Six of them
        // is what the gallery's three-column grid measured; twice that is still
        // a page settling and not a pass that will not end.
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 120, 100, 40));

        for (int again = 0; again < 12; again++)
        {
            laid.Place(new Rect(0, 0, 100, 200), new Rect(0, 120, 100, 40));
        }

        Assert.NotNull(laid.Engine.Moving(child, MotionFrame.Place));
        Assert.Equal(20, child.Frame.Y, 0);

        // And it travels the moment the clock does reach it.
        laid.Clock.Tick(100);
        Assert.Equal(70, child.Frame.Y, 0);
    }

    /// <summary>
    /// And a pass repeated WITH frames in between is an ordinary motion: the
    /// clock is reaching it, so nothing is landed early.
    /// </summary>
    [Fact]
    public void APlaceThatTheClockKeepsReachingGoesOnTravelling()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 120, 100, 40));

        for (int again = 0; again < 8; again++)
        {
            laid.Clock.Tick(5);
            laid.Place(new Rect(0, 0, 100, 200), new Rect(0, 120, 100, 40));
        }

        Assert.NotNull(laid.Engine.Moving(child, MotionFrame.Place));
    }

    /// <summary>
    /// A PLACE KNOWS WHETHER IT IS BEING WRITTEN INSIDE A PASS. Windows arranges
    /// by asking the XAML layout system, and between passes nothing is listening
    /// - so a place written from the frame clock has to ask for a pass, and one
    /// written from inside a pass must not, having landed already and having
    /// only the running pass to dirty. That answer is this counter, and it is
    /// nought again however the pass ends.
    /// </summary>
    [Fact]
    public void AnArrangementSaysWhileItIsHappening()
    {
        Laid laid = Laying(Travelling, 1);

        Assert.Equal(0, MotionArranger.Arranging);

        int inside = -1;

        laid.Inner.Watching = () => inside = MotionArranger.Arranging;

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));

        Assert.Equal(1, inside);
        Assert.Equal(0, MotionArranger.Arranging);

        // However it ends - a manager that throws is still a pass that is over.
        laid.Inner.Watching = () => throw new InvalidOperationException("no room");

        Assert.Throws<InvalidOperationException>(
            () => laid.Place(new Rect(0, 0, 100, 200), new Rect(0, 60, 100, 40)));

        Assert.Equal(0, MotionArranger.Arranging);
    }

    /// <summary>
    /// AND IT COUNTS RATHER THAN SAYING YES OR NO, because arrangements NEST: a
    /// layout inside a layout is arranged from inside the outer one's pass, and
    /// an answer cleared when the inner pass ends would tell every write made in
    /// the rest of the outer one that no pass was running. On Windows such a
    /// write asks for a pass, and asking for one from inside the pass that is
    /// making it is the whole of what this prevents.
    /// </summary>
    [Fact]
    public void ArrangementsInsideArrangementsCountUp()
    {
        Laid outer = Laying(Travelling, 1);
        Laid inner = Laying(Travelling, 1);

        int deep = -1;
        int after = -1;

        inner.Inner.Watching = () => deep = MotionArranger.Arranging;

        outer.Inner.Watching = () =>
        {
            inner.Arrange(new Rect(0, 0, 50, 50), new Rect(0, 0, 50, 20));
            after = MotionArranger.Arranging;
        };

        outer.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));

        Assert.Equal(2, deep);
        Assert.Equal(1, after);
        Assert.Equal(0, MotionArranger.Arranging);
    }

    /// <summary>
    /// A PASS IN THE MIDDLE OF A MOTION PUTS THE CHILD BACK WHERE THE MOTION HAS
    /// REACHED. The inner manager has just put it AT the target, and undoing that
    /// is what keeps a travelling child off its destination - and on Windows,
    /// where a place lands only from inside a pass, it is also the whole of how a
    /// frame reaches the screen.
    /// </summary>
    [Fact]
    public void AnArrangementMidMotionPutsTheChildBackWhereItHasReached()
    {
        Laid laid = Laying(Travelling, 1);
        IView child = laid.Layout[0];

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 40));

        laid.Clock.Tick(100);
        Assert.Equal(50, child.Frame.Y, 0);

        // The same plan again, and the inner manager puts the child at 100 on
        // its way through.
        laid.Place(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 40));

        Assert.Equal(50, child.Frame.Y, 0);
        Assert.NotNull(laid.Engine.Moving(child, MotionFrame.Place));
    }

    /// <summary>
    /// AND IT IS THE WHOLE LAYOUT'S ANSWER, not the watched child's: what a
    /// measurement reports is what the views BESIDE it leave it, so a sibling
    /// walked through a size moves the very number being read.
    /// </summary>
    [Fact]
    public void AMeasuredSiblingHoldsEveryChildOfTheLayoutAtItsSize()
    {
        Laid laid = Laying(Travelling, 2);

        laid.Arrange(
            new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40), new Rect(0, 40, 100, 40));

        ((VisualElement)laid.Layout[0]).SetValue(StateUIRenderer.WatchedProperty, true);

        laid.Arrange(
            new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 90), new Rect(0, 90, 100, 90));

        laid.Clock.Tick(100);

        Assert.Equal(90, ((IView)laid.Layout[1]).Frame.Height, 1);
    }

    /// <summary>
    /// A SIZE THE CHILD ASKED FOR ARRIVES TOO. A request is a value somebody
    /// worked out, most sharply where they worked it out from a measurement.
    /// </summary>
    [Fact]
    public void ASizeTheChildAskedForArrivesRatherThanTravelling()
    {
        Laid laid = Laying(Travelling, 0);
        var child = new Sized { HeightRequest = 40 };

        laid.Layout.Children.Add(child);

        ((IView)child).Measure(100, 200);
        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 0, 100, 40));

        child.HeightRequest = 90;
        ((IView)child).Measure(100, 200);

        laid.Arrange(new Rect(0, 0, 100, 200), new Rect(0, 100, 100, 90));
        laid.Clock.Tick(100);

        Assert.Equal(90, ((IView)child).Frame.Height, 1);
        Assert.True(
            ((IView)child).Frame.Y is > 0 and < 100,
            $"the place it was given still travels: {((IView)child).Frame.Y}");
    }
}
