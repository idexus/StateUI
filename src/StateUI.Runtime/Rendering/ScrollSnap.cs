using System.Diagnostics;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Settles a scroller the reader let go of: rounds where the release was going
/// to the grid the tree described, and makes the movement itself where the
/// platform's own would not look right.
/// </summary>
/// <remarks>
/// <para>
/// THE AIM IS TAKEN WHERE THE PLATFORM DECIDES, never afterwards. UIKit asks
/// its delegate where the deceleration should end and takes the answer by
/// reference; Android's fling is predicted with an <c>OverScroller</c> of this
/// side's own before the platform starts one; WinUI hands over the end of its
/// inertia as that inertia begins. Rounding after the event instead would be a
/// second movement - the platform brakes to its own stop, and only then does
/// the scroller set off again - which is what a carousel must not do. Nothing
/// waits for the Swift side: the grid is a described property, so the answer is
/// already here.
/// </para>
/// <para>
/// WHOSE MOVEMENT IT IS then follows from how far that prediction was going,
/// counted in points of the grid - see <see cref="ScrollGlide"/>. A release
/// going no further than one point is settled HERE, at a stated speed, because
/// a platform sent somewhere its own throw was not going stretches its curve to
/// reach it and a gentle release then crawls. A release going further keeps the
/// platform's own curve and is simply sent to the rounded point.
/// </para>
/// <para>
/// A scroller the tree asked nothing of - no grid, no shortened throw - is left
/// entirely alone, and is hooked only to be heard stopping. A platform that
/// will not be told, or a scroll no gesture started - a wheel, a key - leaves
/// the offset wherever it stops, and that is where this puts it right, once.
/// Every movement is CLAMPED to what the scroller can actually reach, so a grid
/// whose next point lies past the end asks for nothing rather than asking
/// forever.
/// </para>
/// <para>
/// It reports ONE thing: <see cref="Rested"/>, the moment the scroller stops -
/// which is where the aiming already had to know it was, and where work that
/// would be seen as a hitch costs nothing. Which point of the grid the scroller
/// is nearest is a property report like any other - see
/// <c>StateUIRenderer.WatchSnapItem</c> - so a scroller that snaps and one that
/// only listens are the same mechanism.
/// </para>
/// </remarks>
internal sealed class ScrollSnap
{
    /// <summary>The scroller this keeps on its grid.</summary>
    private readonly ScrollView _scroll;

    /// <summary>Whether a finger is on it, so nothing is moved under one.</summary>
    /// <remarks>
    /// Written only inside a platform's own hooks, so the build with no
    /// platform at all - which is the one the tests run against - reads the
    /// false it is given here.
    /// </remarks>
    private bool _down = false;

    /// <summary>
    /// Whether the offset has changed since the last rest was reported, so a
    /// scroller asked twice whether it has stopped answers once.
    /// </summary>
    private bool _moved;

    /// <summary>Whether the scroller's own offset reports are watched.</summary>
    private bool _watching;

    /// <summary>Whether a movement of this side's own is under way.</summary>
    private bool _gliding;

    /// <summary>
    /// Whether a correction onto the grid is being made, so the movement it
    /// makes cannot ask for another one. A movement short enough to be PUT
    /// finishes inside the call that started it, and the offset it wrote is
    /// not always readable yet when it does.
    /// </summary>
    private bool _settling;

    /// <summary>
    /// Where the offset was when the finger landed - what a limit on how far one
    /// release may go is measured from, so a drag and the throw that ends it
    /// cannot add up to more than the limit between them.
    ///
    /// Written only inside a platform's own hooks - see <see cref="_down"/>.
    /// </summary>
    private Point _grip = default;

    /// <summary>
    /// Who is waiting for the movement under way to finish - an act that asked
    /// for it, there being nothing else that can await one.
    /// </summary>
    private TaskCompletionSource<bool>? _arrival;

    /// <summary>
    /// The scroller has come to rest: nothing is moving, no finger is on it,
    /// and it is where it is going to stay - the settle, where one was needed,
    /// having already run.
    /// </summary>
    internal event Action? Rested;

    /// <summary>The hooks for one scroller, not yet attached to anything.</summary>
    internal ScrollSnap(ScrollView scroll)
    {
        _scroll = scroll;
    }

    /// <summary>
    /// How far off a grid point an offset may rest and still count as on it,
    /// in device units - a pixel's worth of rounding either way.
    /// </summary>
    private const double Slack = 1.5;

    /// <summary>
    /// The furthest a movement is simply PUT rather than flown, in device
    /// units.
    /// </summary>
    /// <remarks>
    /// Every flight keeps a landing of its own however short it is, which is
    /// what stops a settle arriving with a snap - and is exactly wrong for a
    /// movement of two or three units, where a fifth of a second of easing is
    /// the only thing anybody sees. Measured on a carousel whose cards stand
    /// 766 apart: a late dribble of the touchpad's tail moved the content 2.3
    /// units and was given 201 ms to do it, and that is what a reader reads as
    /// one tug too many. Under this, the offset is written and the movement is
    /// over.
    /// </remarks>
    private const double Nudge = 8;

    /// <summary>How often a movement of this side's own is stepped, in ms.</summary>
    private const uint Rate = 16;

    /// <summary>The name the movement runs under, so it can be stopped by it.</summary>
    private const string Gliding = "StateUIScrollGlide";

    /// <summary>
    /// Where a release is going, and whose movement takes it there.
    /// </summary>
    /// <param name="Landing">The point it comes to rest on.</param>
    /// <param name="Ours">
    /// Whether this side makes the movement. False leaves the platform its own
    /// curve, which is then sent to <paramref name="Landing"/> instead of where
    /// it was going.
    /// </param>
    private readonly record struct Release(Point Landing, bool Ours);

    /// <summary>
    /// Attaches to the platform view the scroller has now, where it has one and
    /// this has not attached to it already.
    /// </summary>
    internal void Hook()
    {
        Watch();

#if IOS || MACCATALYST
        HookApple();
#elif ANDROID
        HookAndroid();
#elif WINDOWS
        HookWindows();
#endif
    }

    /// <summary>Where the scroller is now, in device units.</summary>
    private Point Offset => new(_scroll.ScrollX, _scroll.ScrollY);

    /// <summary>How far apart the offsets it may rest on are. Zero is anywhere.</summary>
    private double Interval => (double)_scroll.GetValue(StateUIRenderer.SnapIntervalProperty);

    /// <summary>
    /// What fraction of a released throw this scroller keeps. One is the whole
    /// of what the platform would carry it.
    /// </summary>
    private double Momentum => (double)_scroll.GetValue(StateUIRenderer.ScrollMomentumProperty);

    /// <summary>Where the grid starts.</summary>
    private double From => (double)_scroll.GetValue(StateUIRenderer.SnapFromProperty);

    /// <summary>
    /// The most points of the grid one release may cross. Zero is no limit.
    /// </summary>
    private int Most => (int)(double)_scroll.GetValue(StateUIRenderer.SnapsAtMostProperty);

    /// <summary>
    /// The nearest point of the grid, both axes rounded and each held inside
    /// what the scroller can reach. The same point back where there is no grid.
    /// </summary>
    private Point Snapped(Point offset)
    {
        double interval = Interval;

        return Reachable(new Point(
            StateUIRenderer.SnapPoint(offset.X, interval, From),
            StateUIRenderer.SnapPoint(offset.Y, interval, From)));
    }

    /// <summary>
    /// An offset the scroller can actually be at, both axes - see
    /// <see cref="StateUIRenderer.Reachable"/> for why nothing may be aimed
    /// anywhere else.
    /// </summary>
    private Point Reachable(Point offset) => new(
        StateUIRenderer.Reachable(offset.X, _scroll.ContentSize.Width, _scroll.Width),
        StateUIRenderer.Reachable(offset.Y, _scroll.ContentSize.Height, _scroll.Height));

    /// <summary>
    /// Whether the tree asked for a release to be aimed at all - a grid to land
    /// on, or a throw to shorten. A scroller that asked for neither keeps the
    /// platform's own physics untouched, and is hooked only to be heard
    /// stopping.
    /// </summary>
    private bool Aims => Interval > 0 || Momentum < 1;

    /// <summary>
    /// What a release comes to: the platform's predicted stop, SHORTENED
    /// towards where the finger left it by whatever momentum the tree asked
    /// for, rounded to the grid, held inside what the scroller can reach - and
    /// whose movement takes it there.
    /// </summary>
    /// <remarks>
    /// The shortening is a fraction of the platform's OWN prediction rather
    /// than a distance of this side's own, so a hard throw still goes further
    /// than a gentle one and every platform keeps its own physics where its own
    /// physics is what runs.
    /// </remarks>
    /// <param name="predicted">Where the platform says the movement would end.</param>
    private Release Aimed(Point predicted)
    {
        Point here = Offset;
        double momentum = Math.Max(0, Momentum);

        var shortened = new Point(
            here.X + ((predicted.X - here.X) * momentum),
            here.Y + ((predicted.Y - here.Y) * momentum));

        double interval = Interval;

        // With no grid there is nothing to count in and no speed to make a
        // movement at, so a scroller that only asked for a shorter throw gets
        // the platform's curve, cut short.
        if (interval <= 0)
        {
            return new Release(Reachable(shortened), Ours: false);
        }

        Point landing = Held(Snapped(shortened), interval);

        int cells = Math.Max(
            ScrollGlide.Cells(here.X, landing.X, interval, From),
            ScrollGlide.Cells(here.Y, landing.Y, interval, From));

        return new Release(landing, Ours: cells <= ScrollGlide.Reach);
    }

    /// <summary>
    /// Where a wheel notch takes this scroller: the platform's own destination
    /// rounded to the grid, both axes, and never less than one point of it -
    /// see <see cref="ScrollGlide.Step"/> for why a notch is not a throw.
    /// </summary>
    /// <param name="going">Where the platform was taking it.</param>
    /// <param name="aim">Where it is going already.</param>
    private Point Wheeled(Point going, Point aim)
    {
        double interval = Interval;
        double origin = From;
        Point at = Offset;

        return Reachable(new Point(
            ScrollGlide.Step(going.X, aim.X, at.X, interval, origin, 1),
            ScrollGlide.Step(going.Y, aim.Y, at.Y, interval, origin, 1)));
    }

    /// <summary>
    /// Brings a landing back to the furthest point this scroller is allowed to
    /// cross in one release, where the tree asked for a limit at all.
    /// </summary>
    /// <remarks>
    /// Measured from where the FINGER LANDED, not from where it let go: a reader
    /// who drags most of the way to the next point and then throws has already
    /// spent the movement, and counting only the throw would let the two add up
    /// to two points. So a limit of one means one, whatever the gesture was.
    /// </remarks>
    /// <param name="landing">Where the release was going to end.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    private Point Held(Point landing, double interval)
    {
        int most = Most;

        if (most <= 0)
        {
            return landing;
        }

        double origin = From;

        return Reachable(new Point(
            ScrollGlide.Held(landing.X, _grip.X, interval, origin, most),
            ScrollGlide.Held(landing.Y, _grip.Y, interval, origin, most)));
    }

    /// <summary>
    /// The scroller's own offset reports, which say two things: that something
    /// has MOVED, so the rest that follows is worth reporting; and, where the
    /// platform announces no end of its own, that the movement is still going.
    /// </summary>
    private void Watch()
    {
        if (_watching)
        {
            return;
        }

        _watching = true;

        _scroll.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName != ScrollView.ScrollXProperty.PropertyName
                && e.PropertyName != ScrollView.ScrollYProperty.PropertyName)
            {
                return;
            }

            _moved = true;

#if ANDROID
            // Every report puts the rest off again, so the quiet after the last
            // one is where a movement nobody announced comes to an end.
            ArmRest();
#endif
        };
    }

    /// <summary>
    /// Takes the scroller to a point at the stated speed - the ONE movement a
    /// short settle, a correction and an asked-for scroll all are.
    /// </summary>
    /// <remarks>
    /// A movement short enough to be already there is not made: the scroller is
    /// at rest, and says so. Anything else replaces whatever was under way,
    /// which is what makes a second flick during the first one carry on rather
    /// than fight.
    /// </remarks>
    /// <param name="landing">Where it is going, in device units.</param>
    private void Glide(Point landing)
    {
        Stop(arrived: false);

        Point here = Offset;
        double dx = landing.X - here.X;
        double dy = landing.Y - here.Y;
        double distance = Math.Sqrt((dx * dx) + (dy * dy));

        if (distance <= Nudge)
        {
            // Already there, or near enough that flying is all anyone would
            // see. The offset still has to arrive, so it is written.
            if (distance > Slack)
            {
                Put(landing);
            }

            Arrive();
            Rest();
            return;
        }

        Trace($"glide to={landing.X:F1},{landing.Y:F1} from={here.X:F1},{here.Y:F1} "
            + $"ms={ScrollGlide.Length(distance, Interval):F0}");

        _gliding = true;

#if ANDROID
        // STEPPED ON THE PLATFORM'S OWN FRAME CLOCK, the same one a ride uses.
        // MAUI's animation ticks a movement of this length visibly unevenly here
        // - measured as a settle of one card juddering while a ride across three
        // stayed smooth - and the two movements have to be told apart by their
        // length, not by how well they run.
        Walk(here, landing, ScrollGlide.Length(distance, Interval));
        return;
#else
        try
        {
            _scroll.Animate(
                Gliding,
                t => t,
                // HELD INSIDE WHAT THE SCROLLER CAN REACH, every step, for the
                // same reason the landing is.
                t => Put(Reachable(new Point(here.X + (dx * t), here.Y + (dy * t)))),
                rate: Rate,
                length: (uint)Math.Round(ScrollGlide.Length(distance, Interval)),
                easing: Easing.CubicOut,
                finished: (_, cancelled) =>
                {
                    _gliding = false;

                    if (cancelled)
                    {
                        return;
                    }

                    Put(landing);
                    Arrive();
                    Rest();
                });
        }
        catch (ArgumentException)
        {
            // MAUI could find nothing to tick this with - a scroller that is
            // not in a window yet, which is a real state and not a mistake. The
            // offset still has to end up where it was going, and whoever is
            // waiting for it still has to be answered.
            _gliding = false;
            Put(landing);
            Arrive();
            Rest();
        }
#endif
    }

    /// <summary>
    /// Ends the movement under way where it stands - what a finger landing on
    /// the scroller does, and what an asked-for scroll does to a settle.
    /// </summary>
    /// <param name="arrived">
    /// Whether whoever is waiting for it should be told it finished. False
    /// where the movement is being cut short, so an act that asked for one
    /// answers the moment its movement stops rather than at the end of the next.
    /// </param>
    private void Stop(bool arrived)
    {
#if ANDROID
        // A ride is stepped from the platform's own frame callback rather than
        // by MAUI, so it is ended by its ticket going stale.
        _rides++;
#endif

        if (_gliding)
        {
            _gliding = false;
            _scroll.AbortAnimation(Gliding);
        }

        if (!arrived)
        {
            Arrive();
        }
    }

    /// <summary>Answers whoever asked for the movement, once.</summary>
    private void Arrive()
    {
        TaskCompletionSource<bool>? arrival = _arrival;

        _arrival = null;
        arrival?.TrySetResult(true);
    }

    /// <summary>Puts the offset where the movement has reached, at once.</summary>
    /// <remarks>
    /// The platform view directly where there is one, which is the one thing
    /// each platform is asked for besides a predicted stop. MAUI's own request
    /// otherwise, which is what a scroller with no handler yet can still be
    /// moved by.
    /// </remarks>
    private void Put(Point offset)
    {
#if IOS || MACCATALYST
        if (_scroll.Handler?.PlatformView is UIKit.UIScrollView native)
        {
            native.SetContentOffset(new CoreGraphics.CGPoint(offset.X, offset.Y), false);
            return;
        }
#elif ANDROID
        if (Surface is { } surface && surface.Context is Android.Content.Context context)
        {
            surface.ScrollTo(
                (int)Microsoft.Maui.Platform.ContextExtensions.ToPixels(context, offset.X),
                (int)Microsoft.Maui.Platform.ContextExtensions.ToPixels(context, offset.Y));

            return;
        }
#elif WINDOWS
        if (_scroll.Handler?.PlatformView is Microsoft.UI.Xaml.Controls.ScrollViewer viewer)
        {
            viewer.ChangeView(offset.X, offset.Y, null, true);
            return;
        }
#endif
        _ = _scroll.ScrollToAsync(offset.X, offset.Y, false);
    }

    /// <summary>
    /// Moves the scroller to a point at the stated speed, and answers when it
    /// gets there - what an animated scroll act is.
    /// </summary>
    /// <remarks>
    /// A movement nobody threw, so it is this side's own like any other, and it
    /// lands where it was ASKED to rather than on the grid: an author who names
    /// an offset means that offset. One point of the grid therefore takes the
    /// same time however it was asked for, which is why assigning a position
    /// looks like settling onto one.
    /// </remarks>
    /// <param name="x">Where it is going across.</param>
    /// <param name="y">And down.</param>
    /// <returns>A task that finishes when the movement does.</returns>
    internal Task GlideTo(double x, double y)
    {
        var arrival = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

        Stop(arrived: false);

#if WINDOWS
        // An asked-for movement replaces whatever a wheel was doing, so the
        // next turn of one starts a burst of its own from wherever this lands.
        _turned = null;
        _aim = null;
        _least = null;
        _latched = null;
        _falls = 0;
        _rises = 0;
#endif

        _arrival = arrival;
        Glide(Reachable(new Point(x, y)));

        return arrival.Task;
    }

    /// <summary>
    /// The scroller has stopped moving: puts an offset that came to rest
    /// between two points of the grid onto the nearest one, and where nothing
    /// is left to move, says so. Nothing happens under a finger, or while a
    /// movement is still running.
    /// </summary>
    /// <remarks>
    /// The correction is a MOVEMENT, so it is not the rest - its own end runs
    /// this again, finds the offset already on the grid, and reports from
    /// there. Which is what makes the report worth having: where it says the
    /// scroller is, it is.
    /// </remarks>
    private void Rest()
    {
        if (_down || _gliding || _settling)
        {
            return;
        }

#if WINDOWS
        // A WHEEL STILL TURNING IS A FINGER STILL DOWN: nothing rests, and
        // nothing is put right, until the burst's quiet has run out - which is
        // what runs this again, through Ended.
        if (_turned is not null)
        {
            return;
        }
#endif

        Point here = Offset;

        // PAST ITS OWN END the scroller is bouncing, and the platform is
        // already carrying it back. A movement aimed at the same place fights
        // that one and arrives as a jump - measured as a scroller that would
        // not start when a fling to the beginning was answered by a swipe the
        // other way. The end of the bounce reports again, and this runs then.
        if (here != Reachable(here))
        {
            return;
        }

        if (Interval > 0)
        {
            Point there = Snapped(here);

            // NUDGE, NOT SLACK, and the two must be the same number here as in
            // Glide. An offset written by Put is not read back at once on every
            // platform, so a correction that fires for a distance Glide answers
            // by putting asks for the same put again, for ever.
            if (Math.Abs(there.X - here.X) > Nudge || Math.Abs(there.Y - here.Y) > Nudge)
            {
                Trace($"correcting from={here.X:F1},{here.Y:F1} to={there.X:F1},{there.Y:F1}");

                _settling = true;

                try
                {
                    Glide(there);
                }
                finally
                {
                    _settling = false;
                }

                return;
            }
        }

        if (!_moved)
        {
            return;
        }

        _moved = false;
        Rested?.Invoke();
    }

    /// <summary>Where the trace is written, once <c>STATEUI_SCROLL</c> asks for one.</summary>
    private static readonly string? TracePath =
        Environment.GetEnvironmentVariable("STATEUI_SCROLL") is not null
            ? Path.Combine(Path.GetTempPath(), "stateui-scroll.log")
            : null;

    /// <summary>When this scroller's trace started, so the lines carry a clock.</summary>
    private readonly System.Diagnostics.Stopwatch _clock = System.Diagnostics.Stopwatch.StartNew();

    /// <summary>Writes one line of what the platform did, where one is asked for.</summary>
    /// <param name="line">What happened.</param>
    private void Trace(string line)
    {
        Debug.WriteLine($"{_clock.ElapsedMilliseconds,7} {line}\n");
        if (TracePath is null)
        {
            return;
        }

        try
        {
            File.AppendAllText(TracePath, $"{_clock.ElapsedMilliseconds,7} {line}\n");
        }
        catch (IOException)
        {
        }
    }
#if IOS || MACCATALYST
    /// <summary>The UIScrollView the hooks are on.</summary>
    private UIKit.UIScrollView? _native;

    /// <summary>
    /// What the release under way comes to, worked out where UIKit states its
    /// own prediction and acted on the moment the drag ends.
    /// </summary>
    private Release? _release;

    /// <summary>
    /// UIScrollView says every moment itself, but for the finger coming DOWN:
    /// <c>DraggingStarted</c> fires once the finger has moved far enough to be
    /// a drag, and a tap that stops a movement never gets that far. A press
    /// recognizer with no minimum duration fires the instant the finger lands,
    /// recognizes beside the scroller's own pan, and cancels nothing.
    /// </summary>
    private void HookApple()
    {
        if (_scroll.Handler?.PlatformView is not UIKit.UIScrollView native || ReferenceEquals(_native, native))
        {
            return;
        }

        _native = native;

        var press = new UIKit.UILongPressGestureRecognizer(Pressed)
        {
            MinimumPressDuration = 0,
            CancelsTouchesInView = false,
            DelaysTouchesBegan = false,
            DelaysTouchesEnded = false,
        };

        press.ShouldRecognizeSimultaneously = (_, _) => true;
        native.AddGestureRecognizer(press);

        // The predicted stop is UIKit's own: where its deceleration would end,
        // handed over BEFORE it begins and taken back by reference. A landing
        // written here is where that deceleration goes, in one movement, with
        // UIKit's own curve; the CURRENT offset written instead is what stops
        // the deceleration from happening at all, leaving the movement to this
        // side.
        native.WillEndDragging += (_, e) =>
        {
            if (!Aims)
            {
                _release = null;
                return;
            }

            Release release = Aimed(new Point(e.TargetContentOffset.X, e.TargetContentOffset.Y));

            _release = release;

            e.TargetContentOffset = release.Ours
                ? native.ContentOffset
                : new CoreGraphics.CGPoint(release.Landing.X, release.Landing.Y);
        };

        // A gesture that never touched anything - a trackpad, a wheel - has no
        // finger to have landed, so this is where a limit on how far one release
        // may go gets something to measure from. A real touch has already set it
        // from where the finger came down, which is earlier and truer, so this
        // does not overwrite that.
        native.DraggingStarted += (_, _) =>
        {
            if (!_down)
            {
                _grip = Offset;
            }
        };

        // Every way a movement can end, which is where the guarantee is kept:
        // a drag let go of, a deceleration that ran out, and an animated
        // scroll - a wheel among them, which no drag precedes.
        native.DraggingEnded += (_, e) =>
        {
            _down = false;

            if (_release is { Ours: true } ours)
            {
                _release = null;
                Glide(ours.Landing);
                return;
            }

            _release = null;

            if (!e.Decelerate)
            {
                Rest();
            }
        };

        native.DecelerationEnded += (_, _) => Rest();
        native.ScrollAnimationEnded += (_, _) => Rest();
    }

    /// <summary>The finger landed, or left without ever dragging.</summary>
    private void Pressed(UIKit.UILongPressGestureRecognizer press)
    {
        if (_native is not UIKit.UIScrollView native)
        {
            return;
        }

        switch (press.State)
        {
            case UIKit.UIGestureRecognizerState.Began:
                _down = true;
                _grip = Offset;

                // A movement of this side's own is stepped frame by frame, so
                // stopping it is stopping the stepping - there is nothing to
                // read out of a presentation layer and nothing to put back.
                Stop(arrived: false);

                // UIKit stops its OWN deceleration when a finger lands, so the
                // only thing left to stop is a scroll MAUI animated - and that
                // one is a CAAnimation. It is stopped where it is SEEN to be:
                // the model offset already holds the animation's target and the
                // presentation layer holds where it has got to.
                //
                // CLAMPED, and that is not a nicety: a scroller bouncing past
                // its start is showing a NEGATIVE offset, and writing that back
                // as the model would hold it there - the finger would then drag
                // the overshoot back before anything moved. Measured as a
                // scroller that refused to start when a throw to the beginning
                // was answered by a swipe the other way.
                if (native.Layer.AnimationKeys is { Length: > 0 }
                    && native.Layer.PresentationLayer is CoreAnimation.CALayer shown)
                {
                    Point seen = Reachable(new Point(shown.Bounds.Location.X, shown.Bounds.Location.Y));

                    native.SetContentOffset(new CoreGraphics.CGPoint(seen.X, seen.Y), false);

                    // MAUI's request, waiting on an animation that will now
                    // never end, is completed by hand so an awaiting handler
                    // resumes.
                    ((IScrollViewController)_scroll).SendScrollFinished();
                }

                break;

            case UIKit.UIGestureRecognizerState.Ended:
            case UIKit.UIGestureRecognizerState.Cancelled:
            case UIKit.UIGestureRecognizerState.Failed:
                if (!_down)
                {
                    break;
                }

                _down = false;

                // A drag hands its own end to DraggingEnded, with the
                // prediction already taken. A touch that never became one ends
                // here, and what it interrupted has to be put back.
                if (!native.Dragging && !native.Decelerating)
                {
                    Rest();
                }

                break;
        }
    }
#elif ANDROID
    /// <summary>
    /// The views the touch listener is on - the outer scroller, and the
    /// sideways one inside it where there is one.
    /// </summary>
    private readonly HashSet<Android.Views.View> _hooked = [];

    /// <summary>The view that actually scrolls, which is what is moved.</summary>
    private Android.Views.View? _surface;

    /// <summary>The velocity of the touch under way.</summary>
    private Android.Views.VelocityTracker? _tracker;

    /// <summary>
    /// The platform's own fling, run ahead of the platform in <see cref="Predicted"/>
    /// and then ridden by <see cref="Ride"/> where the movement is left to it.
    /// </summary>
    private Android.Widget.OverScroller? _fling;

    /// <summary>Which ride is the current one, so an older one drops.</summary>
    private int _rides;

    /// <summary>Which quiet after a movement is the current one.</summary>
    private int _quiet;

    /// <summary>And which posted release is, so an older one drops.</summary>
    private int _releases;

    /// <summary>
    /// How long the offset must stay unchanged before it counts as at rest, in
    /// milliseconds. Android's plain scrollers say nothing when a fling or a
    /// smooth scroll ends, so the rest is read off the scroll reports stopping -
    /// two frames and a little.
    /// </summary>
    private const int RestAfterMs = 50;

    /// <summary>Where an offset is put, the sideways scroller where there is one.</summary>
    private Android.Views.View? Surface =>
        _surface ??= _scroll.Handler?.PlatformView as Android.Views.View;

    /// <summary>
    /// MAUI's Android scroller is a vertical scroller holding, when it runs
    /// sideways, a horizontal one - and the touch goes to whichever of them
    /// takes the drag, so both are listened to. The sideways one appears when
    /// the orientation does, which is why this is asked again every render.
    /// </summary>
    private void HookAndroid()
    {
        if (_scroll.Handler?.PlatformView is not Android.Views.ViewGroup outer)
        {
            return;
        }

        Listen(outer);
        _surface = outer;

        if (outer.ChildCount > 0 && outer.GetChildAt(0) is Android.Widget.HorizontalScrollView across)
        {
            Listen(across);
            _surface = across;
        }
    }

    /// <summary>One touch listener on one view, once.</summary>
    private void Listen(Android.Views.View view)
    {
        if (!_hooked.Add(view))
        {
            return;
        }

        // Never consumed: the platform's own handling is what scrolls, flings
        // and - on a touch landing mid-movement - aborts its scroller.
        view.Touch += (sender, e) =>
        {
            e.Handled = false;

            if (e.Event is not Android.Views.MotionEvent motion || sender is not Android.Views.View touched)
            {
                return;
            }

            switch (motion.ActionMasked)
            {
                case Android.Views.MotionEventActions.Down:
                case Android.Views.MotionEventActions.Move:
                    // The first event of a touch is the finger coming down,
                    // whichever it is: a down the content took is seen here
                    // only from the move the scroller intercepted.
                    if (!_down)
                    {
                        _down = true;
                        _grip = Offset;
                        Stop(arrived: false);
                        _tracker?.Recycle();
                        _tracker = Android.Views.VelocityTracker.Obtain();
                        ((IScrollViewController)_scroll).SendScrollFinished();
                    }

                    _tracker?.AddMovement(motion);
                    break;

                case Android.Views.MotionEventActions.Up:
                case Android.Views.MotionEventActions.Cancel:
                    if (!_down)
                    {
                        break;
                    }

                    _down = false;
                    _tracker?.AddMovement(motion);

                    Point predicted = Predicted(
                        touched, motion.ActionMasked == Android.Views.MotionEventActions.Up);

                    _tracker?.Recycle();
                    _tracker = null;

                    Land(touched, predicted);
                    ArmRest();
                    break;
            }
        };
    }

    /// <summary>
    /// Where the fling the platform is about to start would end - its own
    /// physics, run ahead: the velocity the touch carried, over the range the
    /// scroller has, through an <c>OverScroller</c> exactly as the scroller's
    /// own is about to be. Below the platform's minimum fling velocity there is
    /// no fling, and the offset stays where the finger left it.
    /// </summary>
    private Point Predicted(Android.Views.View touched, bool lifted)
    {
        Point here = Offset;

        if (!lifted || _tracker is null || touched.Context is not Android.Content.Context context)
        {
            return here;
        }

        var configuration = Android.Views.ViewConfiguration.Get(context);
        int least = configuration?.ScaledMinimumFlingVelocity ?? 0;
        int most = configuration?.ScaledMaximumFlingVelocity ?? int.MaxValue;

        _tracker.ComputeCurrentVelocity(1000, most);

        bool across = touched is Android.Widget.HorizontalScrollView;
        int velocity = (int)(across ? _tracker.XVelocity : _tracker.YVelocity);

        if (Math.Abs(velocity) <= least || touched is not Android.Views.ViewGroup group || group.ChildCount == 0)
        {
            return here;
        }

        Android.Views.View content = group.GetChildAt(0)!;
        int rangeX = Math.Max(0, content.Width - (group.Width - group.PaddingLeft - group.PaddingRight));
        int rangeY = Math.Max(0, content.Height - (group.Height - group.PaddingTop - group.PaddingBottom));

        // KEPT, not disposed: this scroller has just run the platform's own fling
        // ahead of the platform, and where the movement is left to that fling it
        // is this object that is then ridden - see Ride.
        _fling?.Dispose();
        _fling = new Android.Widget.OverScroller(context);

        _fling.Fling(
            group.ScrollX, group.ScrollY,
            across ? -velocity : 0, across ? 0 : -velocity,
            0, rangeX, 0, rangeY);

        double x = across ? Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, _fling.FinalX) : here.X;
        double y = across ? here.Y : Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, _fling.FinalY);

        return new Point(x, y);
    }

    /// <summary>
    /// Settles the release: a smooth scroll to the rounded point, which
    /// replaces the fling the platform is about to run, or - where the movement
    /// is this side's own - a fling of NO speed to end that scroller and the
    /// stepping this side does instead.
    /// </summary>
    /// <remarks>
    /// POSTED rather than called: the fling has not started yet - the platform
    /// starts it from the same UP event, after this listener has returned - so
    /// there would be nothing to replace. A fling of no speed is the one way in
    /// to a scroller's own <c>Scroller</c> from outside; it finishes at once,
    /// and the frames after it are this side's.
    /// </remarks>
    private void Land(Android.Views.View touched, Point predicted)
    {
        if (!Aims || touched.Context is not Android.Content.Context context)
        {
            return;
        }

        Release release = Aimed(predicted);
        int ticket = ++_releases;

        touched.Post(() =>
        {
            // POSTED means a frame later, and a frame is long enough for the
            // reader to put a finger back down. Landing then would take the
            // offset out from under them and arrive as a jump.
            if (_down || ticket != _releases)
            {
                return;
            }

            // The platform's fling has started by now, and either way it is
            // ended here: what follows is stepped from this side.
            switch (touched)
            {
                case Android.Widget.HorizontalScrollView across: across.Fling(0); break;
                case AndroidX.Core.Widget.NestedScrollView down: down.Fling(0); break;
                case Android.Widget.ScrollView plain: plain.Fling(0); break;
            }

            if (release.Ours)
            {
                Glide(release.Landing);
                return;
            }

            Ride(touched, release.Landing);
        });
    }

    /// <summary>
    /// Rides the platform's own fling to the rounded point.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Android has no way to redirect a fling: <c>fling</c> takes a speed and
    /// works out its own end, and <c>smoothScrollTo</c> - the only thing that
    /// takes an end - covers ANY distance in a flat 250 ms, so a long throw
    /// arrives in a quarter of a second while the same throw on a scroller with
    /// no grid takes as long as it takes. That difference is what this exists to
    /// remove.
    /// </para>
    /// <para>
    /// So the fling that was run ahead in <see cref="Predicted"/> is sampled
    /// here instead, frame by frame on the platform's own animation clock, and
    /// SCALED onto the rounded point: same curve, same duration, same decay,
    /// ending a fraction of a card from where the platform would have ended by
    /// itself. Where the fling was going nowhere there is nothing to scale, and
    /// the movement is this side's own instead.
    /// </para>
    /// </remarks>
    /// <param name="surface">The view being scrolled.</param>
    /// <param name="landing">The rounded point it is to end on.</param>
    private void Ride(Android.Views.View surface, Point landing)
    {
        if (_fling is not { } fling || surface.Context is not Android.Content.Context context)
        {
            Glide(landing);
            return;
        }

        double Units(int pixels) => Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, pixels);

        Point from = Offset;
        double startX = Units(fling.StartX);
        double startY = Units(fling.StartY);
        double spanX = Units(fling.FinalX) - startX;
        double spanY = Units(fling.FinalY) - startY;

        double scaleX = Math.Abs(spanX) > 0.5 ? (landing.X - from.X) / spanX : 0;
        double scaleY = Math.Abs(spanY) > 0.5 ? (landing.Y - from.Y) / spanY : 0;

        if (scaleX == 0 && scaleY == 0)
        {
            Glide(landing);
            return;
        }

        Stop(arrived: false);

        _gliding = true;

        int ticket = ++_rides;

        void Step()
        {
            if (ticket != _rides || _down)
            {
                return;
            }

            bool going = fling.ComputeScrollOffset();

            Put(Reachable(new Point(
                from.X + ((Units(fling.CurrX) - startX) * scaleX),
                from.Y + ((Units(fling.CurrY) - startY) * scaleY))));

            if (going)
            {
                surface.PostOnAnimation(new Java.Lang.Runnable(Step));
                return;
            }

            _gliding = false;
            Put(landing);
            Rest();
        }

        surface.PostOnAnimation(new Java.Lang.Runnable(Step));
    }

    /// <summary>
    /// Steps a movement of this side's own on the platform's own frame clock -
    /// the same clock <see cref="Ride"/> uses, so a settle of one card and a
    /// ride across three are as smooth as each other.
    /// </summary>
    /// <param name="from">Where it starts.</param>
    /// <param name="landing">Where it ends.</param>
    /// <param name="length">How long it takes, in milliseconds.</param>
    private void Walk(Point from, Point landing, double length)
    {
        if (Surface is not { } surface || length <= 0)
        {
            _gliding = false;
            Put(landing);
            Arrive();
            Rest();
            return;
        }

        long began = System.Diagnostics.Stopwatch.GetTimestamp();
        int ticket = ++_rides;

        void Step()
        {
            if (ticket != _rides || _down)
            {
                return;
            }

            double gone = (System.Diagnostics.Stopwatch.GetTimestamp() - began)
                * 1000.0 / System.Diagnostics.Stopwatch.Frequency;

            double t = Math.Clamp(gone / length, 0, 1);

            // Easing.CubicOut, written out because this steps itself.
            double eased = 1 - Math.Pow(1 - t, 3);

            Put(Reachable(new Point(
                from.X + ((landing.X - from.X) * eased),
                from.Y + ((landing.Y - from.Y) * eased))));

            if (t < 1)
            {
                surface.PostOnAnimation(new Java.Lang.Runnable(Step));
                return;
            }

            _gliding = false;
            Put(landing);
            Arrive();
            Rest();
        }

        surface.PostOnAnimation(new Java.Lang.Runnable(Step));
    }

    /// <summary>
    /// Puts the rest off by <see cref="RestAfterMs"/>: the offset is at rest
    /// when that long has passed with no report and no finger, which is where
    /// anything the settle did not reach is put right.
    /// </summary>
    private void ArmRest()
    {
        if (_down || _scroll.Handler?.MauiContext is null)
        {
            return;
        }

        int ticket = ++_quiet;

        _scroll.Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(RestAfterMs), () =>
        {
            if (ticket == _quiet)
            {
                Rest();
            }
        });
    }
#elif WINDOWS
    /// <summary>The ScrollViewer the hooks are on.</summary>
    private Microsoft.UI.Xaml.Controls.ScrollViewer? _viewer;

    /// <summary>Whether the movement under way is the platform's inertia.</summary>
    private bool _inertial;

    /// <summary>
    /// Whether the movement under way was started by the WHEEL rather than by a
    /// gesture, which WinUI reports as inertia just the same.
    /// </summary>
    private bool _wheeled;

    /// <summary>
    /// Which point of the grid a wheel has already been aimed at, so the notch
    /// after it steps on from there rather than from wherever the scroller has
    /// got to. Nothing while no wheel movement is under way.
    /// </summary>
    private Point? _aim;

    /// <summary>
    /// How long after the last wheel message a burst counts as over, in ms.
    /// </summary>
    /// <remarks>
    /// Long enough that neither a touchpad's stream nor the decaying tail it
    /// ends with is ever cut in half - a cut tail is a second burst, and a
    /// second burst is a second card. What it costs is nothing: a NEW gesture
    /// inside the window is recognized by its own shape - a direction change,
    /// or speed where the tail was dying - rather than by the pause before it.
    /// </remarks>
    private const double Quiet = 150;

    /// <summary>
    /// The least a burst must have swept before it moves the grid at all, in
    /// device units - under one notch, so a mouse's single click clears it and
    /// a jiggle of the touchpad does not.
    /// </summary>
    private const double Least = ScrollTuning.Notch * 0.6;

    /// <summary>
    /// How far a push must have carried at its fastest to count as a swipe
    /// rather than a drift, in device units.
    /// </summary>
    /// <remarks>
    /// The band is wide, which is what makes the number safe to state: a
    /// touchpad drifting under a resting hand carries two to nine device units
    /// a message, where a deliberate push peaks in the seventies. This sits
    /// between them, well clear of the drift.
    /// </remarks>
    private const double Decisive = ScrollTuning.Notch / 6;

    /// <summary>
    /// How much of the way to the card already sent for must be covered before
    /// another swipe is decoded.
    /// </summary>
    /// <remarks>
    /// <para>
    /// THE HOLD IS A DISTANCE, NOT A TIME, and it is what makes one push one
    /// card. A swipe is decoded the moment the fingers pass the threshold, so
    /// everything the same gesture does after that - the rest of the push, the
    /// whole of the tail - has to be shut out, and the card being nearly there
    /// is the thing that says the gesture had time to end.
    /// </para>
    /// <para>
    /// It scales itself, which a stated number of milliseconds cannot: the
    /// movement is the same movement a settle makes, so the hold is always
    /// three quarters of it, and a reader who swipes again the moment the card
    /// arrives is heard rather than held off by a clock that has not run out.
    /// </para>
    /// </remarks>
    private const double Covered = 0.75;

    /// <summary>
    /// How many messages in a row must carry less than the one before them for
    /// the gesture to count as decaying.
    /// </summary>
    /// <remarks>
    /// ONE FALL IS NOISE; THREE IN A ROW IS A GESTURE COMING DOWN. A touchpad
    /// wobbles either way over a single message even while the fingers move
    /// evenly - measured at 68.8, 71.2, 67.7 device units in a row - so a
    /// gesture that is still gathering presents falls of its own, and reading
    /// one of them as the end of a push is what stepped a long gesture two
    /// cards.
    /// </remarks>
    private const int Falls = 3;

    /// <summary>
    /// How long a gap between messages counts as the gesture decaying too, in
    /// ms - a hand off the pad rather than a hand slowing down.
    /// </summary>
    /// <remarks>
    /// A burst of its own would end well inside this (see <see cref="Quiet"/>),
    /// EXCEPT while a card is in flight - a burst outlives its own movement, so
    /// this is the gap that can actually happen there.
    /// </remarks>
    private const double Hush = 300;

    /// <summary>
    /// How many messages in a row must carry MORE than the one before them for
    /// the fingers to have landed on the pad again.
    /// </summary>
    /// <remarks>
    /// THE SAME ARGUMENT AS <see cref="Falls"/>, the other way up: one message
    /// rising is inside the wobble a touchpad has even while the fingers move
    /// evenly, so a lone up-tick is noise and not a hand. Two in a row is a
    /// hand. And a lone one says more than nothing - it says the decay that
    /// earned the reading was not clean - so it CANCELS that reading, and the
    /// gesture has to be seen coming down again before it is read at all.
    /// </remarks>
    private const int Rises = 2;

    /// <summary>How many messages in a row have carried less than the one before.</summary>
    private int _falls;

    /// <summary>And how many in a row have carried more, since the reading was allowed.</summary>
    private int _rises;

    /// <summary>
    /// What a rise has to beat for the fingers to have landed on the pad again.
    /// Nothing until the gesture is allowed to be read again at all.
    /// </summary>
    /// <remarks>
    /// TAKEN WHEN THE READING IS ALLOWED, AND THEN FOLLOWING THE DECAY DOWN, so
    /// what a rise is measured against is always the low the gesture actually
    /// reached rather than wherever it happened to be when the gate opened. It
    /// is a LEVEL over it and not a ratio: a tail carrying 30 and one carrying
    /// 60 both want the same push to be told from them, and a ratio asks twice
    /// as much of the second.
    /// </remarks>
    private double? _latched;

    /// <summary>How far the last message carried, unsigned, in device units.</summary>
    private double _lastSize;



    /// <summary>
    /// The point of the grid the last swipe was answered with, and what the
    /// swipe after it counts from. A <see cref="Swiped"/> scroller only;
    /// nothing before the first push, and nothing again once the gesture is
    /// over.
    /// </summary>
    private Point? _least;

    /// <summary>
    /// The shortest gap before a whole notch counts as a CLICK of a mouse, in
    /// ms. Whole notches packed tighter than a finger can click are a coalesced
    /// touchpad stream, and carry distance rather than a point each.
    /// </summary>
    private const double Click = 50;

    /// <summary>
    /// Whether this burst has carried any FRACTION of a notch - which no mouse
    /// sends, so a burst that has is a touchpad's and none of its messages are
    /// clicks, however far apart the platform coalesces them.
    /// </summary>
    private bool _fractional;

    /// <summary>
    /// Which burst the quiet is being waited for, so a message that arrives
    /// first makes the wait it interrupted stale.
    /// </summary>
    private int _bursts;

    /// <summary>When the last wheel message arrived, by this scroller's clock.</summary>
    private double _lastTurn;

    /// <summary>How many whole notches of this burst arrived as CLICKS.</summary>
    private int _clicks;

    /// <summary>
    /// How far the wheel has swept since the burst began, signed, in device
    /// units - the accumulation the landing is counted from. Nothing between
    /// bursts, which is what says no burst is under way.
    /// </summary>
    private Point? _turned;

    /// <summary>
    /// WinUI's ScrollViewer hands over the end of its inertia before it gets
    /// there - <c>ViewChanging.FinalView</c> - which is where the aim is taken.
    /// A KEY makes no manipulation and no inertia, so that one is put right at
    /// the rest instead.
    /// </summary>
    /// <remarks>
    /// THE WHEEL NEVER GETS THIS FAR on a scroller with a grid - it is taken
    /// over on the scroller's content, in <see cref="Turned"/>, and every
    /// movement it causes is this side's own glide. What still reaches these
    /// hooks from a wheel is a scroller with only a shortened throw, whose
    /// inertia is told from a gesture's by <c>_wheeled</c>: WinUI reports both
    /// as inertial view changes, and only a gesture raises
    /// <c>DirectManipulationStarted</c> first.
    /// </remarks>
    private void HookWindows()
    {
        if (_scroll.Handler?.PlatformView is not Microsoft.UI.Xaml.Controls.ScrollViewer viewer)
        {
            return;
        }

        if (ReferenceEquals(_viewer, viewer))
        {
            return;
        }

        _viewer = viewer;

        // handledEventsToo: where the wheel is NOT this scroller's to take, the
        // ScrollViewer has already marked it handled by the time any handler of
        // ours is called, and knowing a wheel turned at all is what tells the
        // inertia it causes from a released gesture.
        viewer.AddHandler(
            Microsoft.UI.Xaml.UIElement.PointerWheelChangedEvent,
            new Microsoft.UI.Xaml.Input.PointerEventHandler((_, _) => _wheeled = true),
            handledEventsToo: true);

        viewer.DirectManipulationStarted += (_, _) =>
        {
            _inertial = false;
            _wheeled = false;
            _aim = null;
            _turned = null;
            _down = true;
            _grip = Offset;
            Stop(arrived: false);
            Trace($"down at={_grip.X:F1},{_grip.Y:F1}");
        };

        viewer.ViewChanging += (_, e) =>
        {
            Trace($"changing inertial={e.IsInertial} final={e.FinalView.HorizontalOffset:F1},"
                + $"{e.FinalView.VerticalOffset:F1} native={viewer.HorizontalOffset:F1},"
                + $"{viewer.VerticalOffset:F1} maui={_scroll.ScrollX:F1},{_scroll.ScrollY:F1} "
                + $"seen={_inertial} wheeled={_wheeled} aims={Aims}");

            if (!e.IsInertial || !Aims)
            {
                return;
            }

            if (_wheeled)
            {
                // A grid is the whole of what a wheel is aimed by: a scroller
                // that only asked for a shorter throw has nothing to say about
                // a notch, which is a step and not a throw.
                if (Interval <= 0)
                {
                    return;
                }

                Point going = new(e.FinalView.HorizontalOffset, e.FinalView.VerticalOffset);

                // THE MOVEMENT THIS SIDE ASKED FOR IS ANNOUNCED AS INERTIA TOO,
                // and its destination is the one already aimed at. Reading that
                // as a notch is what stepped a carousel to the end of its run
                // on three turns of the wheel.
                if (_aim is { } already
                    && Math.Abs(already.X - going.X) <= Slack
                    && Math.Abs(already.Y - going.Y) <= Slack)
                {
                    return;
                }

                Point step = Wheeled(going, _aim ?? Offset);

                if (_aim is { } standing
                    && Math.Abs(standing.X - step.X) <= Slack
                    && Math.Abs(standing.Y - step.Y) <= Slack)
                {
                    return;
                }

                _aim = step;

                bool turned = viewer.ChangeView(step.X, step.Y, null);

                Trace($"wheel to={step.X:F1},{step.Y:F1} going={going.X:F1},{going.Y:F1} "
                    + $"sent={turned}");

                return;
            }

            if (_inertial)
            {
                return;
            }

            _inertial = true;
            _down = false;

            Release release = Aimed(
                new Point(e.FinalView.HorizontalOffset, e.FinalView.VerticalOffset));

            if (release.Ours)
            {
                // Ends the inertia by sending it where it already is, and the
                // frames after that are this side's.
                Point here = Offset;

                bool killed = viewer.ChangeView(here.X, here.Y, null, true);

                Trace($"ours landing={release.Landing.X:F1},{release.Landing.Y:F1} "
                    + $"kill={killed} from={here.X:F1},{here.Y:F1}");

                Glide(release.Landing);
                return;
            }

            bool sent = viewer.ChangeView(release.Landing.X, release.Landing.Y, null);

            Trace($"theirs landing={release.Landing.X:F1},{release.Landing.Y:F1} sent={sent}");
        };

        viewer.DirectManipulationCompleted += (_, _) =>
        {
            _down = false;
            Trace($"up at={viewer.HorizontalOffset:F1},{viewer.VerticalOffset:F1}");
        };

        viewer.ViewChanged += (_, e) =>
        {
            if (!e.IsIntermediate)
            {
                _inertial = false;

                // Every frame of a glide of ours arrives here too, because it
                // is written through ChangeView - so the wheel's aim survives
                // its own movement, or a burst would re-aim and restart the
                // glide on every message it was fed by.
                if (_turned is null && !_gliding)
                {
                    _aim = null;
                }

                Rest();
            }
        };
    }

    /// <summary>
    /// The wheel turned over a scroller that has a grid, which is answered by
    /// one of three readings: a mouse is STEPPED from point to point, a
    /// touchpad is FOLLOWED and meets the grid when the gesture goes quiet -
    /// and a scroller held to one point a gesture is SWIPED, which follows
    /// nothing and steps on a push.
    /// </summary>
    /// <remarks>
    /// <para>
    /// WHICH ONE IS TOLD BY THE MESSAGE ITSELF. Only a touchpad sends a
    /// FRACTION of a notch, so a gesture that has carried one is a run of the
    /// fingers and every message of it belongs to that run, whole notches
    /// included. A gesture made of nothing but whole notches is a mouse.
    /// </para>
    /// <para>
    /// A MOUSE IS STEPPED. Its sweep at the platform&#39;s own
    /// <see cref="ScrollTuning.Notch"/> per notch, rounded to the grid, at
    /// least one point once it clears <see cref="Least"/> - and its CLICKS,
    /// whole notches further than <see cref="Click"/> apart, are a point each,
    /// so three deliberate clicks are three rows however little distance they
    /// add up to. The scroller glides there, retargeted only when the point
    /// changes, so the motion is one movement however many notches fed it.
    /// </para>
    /// <para>
    /// A TOUCHPAD IS FOLLOWED: the content goes exactly where the fingers took
    /// it, off the grid included, and the grid is met ONCE at the end, on the
    /// nearest point. Which is the same scrolling a list with no grid has, plus
    /// one movement after it.
    /// </para>
    /// <para>
    /// UNLESS THE TREE HELD IT TO ONE POINT A GESTURE - <c>snapsAtMost(1)</c> -
    /// and then it is SWIPED instead: nothing follows the fingers, and a push
    /// steps it one point. See <see cref="Swiped"/> for why that is the more
    /// deterministic of the two here, and <see cref="Covered"/> for what holds
    /// one push to one card.
    /// </para>
    /// <para>
    /// ONE GESTURE IS ONE BURST, AND THE TAIL BELONGS TO IT. A precision
    /// touchpad - an Apple mouse too - keeps sending after the fingers leave, a
    /// decaying tail of fractions the platform synthesizes; cutting the burst
    /// on a short quiet split that tail into a second gesture and a second
    /// card. So the quiet is long, and a NEW gesture inside it is told by the
    /// one thing a tail cannot do: turn round. <c>snapsAtMost</c> then caps the
    /// whole burst from where it began, tail included, which is what "one card
    /// a swipe" means.
    /// </para>
    /// </remarks>
    /// <param name="across">Which axis the message moves this scroller along.</param>
    /// <param name="step">How far it carries, signed, in device units.</param>
    /// <param name="clicked">Whether it was a WHOLE notch, which only a mouse sends.</param>
    /// <returns>
    /// Whether the grid answered it. False where this scroller has no grid, and
    /// the scroller is then slid by <see cref="ScrollTuning"/> instead.
    /// </returns>
    internal bool Turned(bool across, double step, bool clicked)
    {
        _wheeled = true;

        double interval = Interval;

        if (interval <= 0)
        {
            return false;
        }

        double size = Math.Abs(step);
        double now = _clock.ElapsedMilliseconds;
        double gap = now - _lastTurn;

        _lastTurn = now;

        // A FRACTION OF A NOTCH IS A TOUCHPAD, and no mouse sends one - which is
        // what tells a stream to be FOLLOWED from clicks to be STEPPED.
        bool fraction = !clicked;
        bool fresh = _turned is null;

        if (_turned is { } sofar)
        {
            double swept = across ? sofar.X : sofar.Y;

            // A DIRECTION CHANGE IS A NEW GESTURE however soon it comes - a
            // tail cannot turn round. Everything else waits for the QUIET,
            // which is the one thing a reader's pause and a tail running out
            // both look like.
            fresh = swept != 0 && Math.Sign(step) != Math.Sign(swept) && size >= ScrollTuning.Notch / 6;
        }

        if (fresh)
        {
            Trace($"gesture step={step:F1} fraction={fraction}");

            // WHERE THE GESTURE COUNTS FROM, and the two inputs differ. A
            // STEPPED one counts from the point the last movement was going
            // to, so a click during a settle means "the next point after that
            // one" - counting from mid-flight is what made one gesture read as
            // two. A FOLLOWED one counts from where the content actually IS,
            // that being what the reader has hold of, so any settle under way
            // gives way to the fingers instead of being flown from.
            if (fraction && _gliding)
            {
                Stop(arrived: false);
            }

            _grip = !fraction && _gliding && _aim is { } aimed ? aimed : Offset;
            _turned = new Point(0, 0);
            _clicks = 0;
            _fractional = false;
            _lastSize = 0;
            _least = null;
            _latched = null;
            _falls = 0;
            _rises = 0;
        }

        _fractional |= fraction;

        if (!_fractional && gap >= Click)
        {
            _clicks++;
        }

        Point was = _turned ?? _grip;
        Point turned = across
            ? new Point(was.X + step, was.Y)
            : new Point(was.X, was.Y + step);

        _turned = turned;

        // EVERY MESSAGE PUTS THE BURST'S QUIET OFF, so the tail keeps its own
        // burst alive and the message after it cannot start a gesture.
        Await();

        double before = _lastSize;

        _lastSize = size;

        Trace($"turn step={step:F1} before={before:F1} falls={_falls} "
            + $"rises={_rises} latched={_latched?.ToString("F1") ?? "-"} whole={clicked}");

        if (!_fractional)
        {
            Aim(turned, across, interval, fresh);
            return true;
        }

        // A DECK STEPPED ONE POINT AT A TIME IS SWIPED, NOT DRAGGED.
        if (Most == 1)
        {
            Swiped(across, step, size, before, gap, interval);

            return true;
        }

        // EVERYTHING ELSE FOLLOWS THE FINGERS: the content goes where the sweep
        // has reached, tail included, and the grid is met once - at the quiet,
        // through Rest.
        Follow(turned, interval);

        return true;
    }

    /// <summary>
    /// A scroller the tree holds to ONE point of the grid a gesture: the push
    /// is heard and the point is sent for, and nothing else the fingers do
    /// moves anything.
    /// </summary>
    /// <remarks>
    /// <para>
    /// NOTHING FOLLOWS THE FINGERS HERE, AND THAT IS THE POINT. A deck stepped
    /// one card at a time answers a SWIPE - a gesture that either happened or
    /// did not - so there is nothing dragged half way and nothing to decide
    /// about where a drag stopped.
    /// </para>
    /// <para>
    /// IT IS DECODED ON THE WAY UP, at the message that first carries past
    /// <see cref="Decisive"/>, so the card leaves within a message or two of
    /// the fingers moving. What then makes one push one card is that nothing
    /// more is decoded until that card is nearly there - see
    /// <see cref="Covered"/>.
    /// </para>
    /// <para>
    /// A SECOND SWIPE IS ALLOWED, LATCHED, THEN BEATEN TWICE OVER. Allowed once
    /// the card sent for is all but there AND the gesture has been seen to
    /// decay - <see cref="Falls"/> messages down in a row, or a gap; latched at
    /// the low it decays to, see <see cref="_latched"/>; and beaten by
    /// <see cref="Rises"/> messages up in a row, the last of them a push's worth
    /// over that latch. A lone rise cancels the reading rather than merely
    /// failing it. It is heard MID-FLIGHT, so a deck goes
    /// along as fast as the reader can push it, and it counts from the point the
    /// last swipe SENT FOR rather than from where that flight has got to,
    /// because a swipe landing half way across means the point after the one
    /// already on its way.
    /// </para>
    /// </remarks>
    /// <param name="across">Which axis the gesture moves along.</param>
    /// <param name="step">How far this message carried, signed.</param>
    /// <param name="size">How far it carried, unsigned.</param>
    /// <param name="before">How far the message before it carried, unsigned.</param>
    /// <param name="gap">How long since that message arrived, in ms.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    private void Swiped(
        bool across,
        double step,
        double size,
        double before,
        double gap,
        double interval)
    {
        if (_least is { } sent)
        {
            bool falling = size < before;
            bool rising = size > before;

            if (_latched is not { } latched)
            {
                _falls = falling ? _falls + 1 : 0;

                // NOTHING IS READ AT ALL until the card sent for is all but
                // there AND the gesture has been seen to come down. Those two
                // between them cover the whole of the push that was answered:
                // the first its flight, the second the rest of the fingers.
                if (Nearly(sent) && (_falls >= Falls || gap >= Hush))
                {
                    _latched = size;
                    _rises = 0;

                    Trace($"latched {size:F1} falls={_falls} gap={gap:F0}");
                }

                return;
            }

            if (!rising)
            {
                // A LONE RISE WAS NOISE, and it takes the reading down with it:
                // the decay that earned this latch had a wobble in it, so it
                // was not the clean decay it looked like, and the gesture has
                // to be seen coming down all over again.
                if (_rises == 1)
                {
                    _latched = null;
                    _falls = falling ? 1 : 0;
                    _rises = 0;

                    Trace("one rise only, reading cancelled");

                    return;
                }

                _rises = 0;

                // A DECAY THAT GOES ON TAKES THE LATCH WITH IT, so what a rise
                // has to beat is the low the gesture actually reached and not
                // wherever it stood when the reading was allowed.
                if (falling)
                {
                    _latched = size;
                }

                return;
            }

            _rises++;

            // TWO IN A ROW, and the second a push's worth over that low - the
            // same size that tells a push from a drift in the first place,
            // which is what makes it one number rather than two.
            if (_rises < Rises || size < Decisive || size < latched + Decisive)
            {
                return;
            }

            Trace($"landed {size:F1} over {latched:F1} rises={_rises}");

            _grip = sent;
            _least = null;
        }
        else if (size < Decisive)
        {
            return;
        }

        _latched = null;
        _falls = 0;
        _rises = 0;

        Push(across, Math.Sign(step), interval);
    }

    /// <summary>
    /// Whether the card the last swipe sent for is all but there.
    /// </summary>
    /// <param name="sent">The point that swipe was answered with.</param>
    private bool Nearly(Point sent)
    {
        double wx = sent.X - _grip.X;
        double wy = sent.Y - _grip.Y;
        double whole = Math.Sqrt((wx * wx) + (wy * wy));

        // Nowhere to go - the end of the run - so nothing is held off either.
        if (whole <= Slack)
        {
            return true;
        }

        Point here = Offset;
        double gx = here.X - _grip.X;
        double gy = here.Y - _grip.Y;

        return Math.Sqrt((gx * gx) + (gy * gy)) >= whole * Covered;
    }

    /// <summary>
    /// The point of the grid one push is worth, counted from where the gesture
    /// began rather than from where the fingers have got to.
    /// </summary>
    /// <param name="across">Which axis the gesture moves along.</param>
    /// <param name="way">Which way it is going.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    private Point Earned(bool across, int way, double interval)
    {
        double from = StateUIRenderer.SnapPoint(across ? _grip.X : _grip.Y, interval, From);
        double to = from + (way * interval);

        return Reachable(across ? new Point(to, _grip.Y) : new Point(_grip.X, to));
    }

    /// <summary>
    /// Answers the push: takes the scroller to the point of the grid the
    /// gesture earned, AT ONCE.
    /// </summary>
    /// <remarks>
    /// AT THE LIFT, NOT AT THE QUIET. Waiting for the gesture to go quiet - the
    /// tail run out on top of the fingers being gone - puts a third of a second
    /// between the swipe and the card moving, which is longer than the gap a
    /// reader leaves between two of them, so the second swipe lands inside the
    /// first and is never heard.
    /// </remarks>
    /// <param name="across">Which axis the gesture moves along.</param>
    /// <param name="way">Which way it is going.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    private void Push(bool across, int way, double interval)
    {
        Point landing = Held(Earned(across, way, interval), interval);

        _least = landing;

        Trace($"push to={landing.X:F1},{landing.Y:F1} from={_grip.X:F1},{_grip.Y:F1}");

        Glide(landing);
    }

    /// <summary>
    /// Puts the offset where the burst has swept to, straight through - which
    /// is what keeps the content under the fingers.
    /// </summary>
    /// <remarks>
    /// <para>
    /// NOTHING IS ROUNDED HERE, AND THAT IS THE WHOLE OF IT. A reader moving
    /// the content sees it move by exactly what they asked and wherever that
    /// falls, off the grid included - the same scrolling a list with no grid
    /// has. The grid is reached ONCE, when the burst's quiet runs out and
    /// <see cref="Rest"/> settles it, so a swipe is the fingers' movement and
    /// then one movement after them rather than a walk from point to point.
    /// </para>
    /// <para>
    /// <c>snapsAtMost</c> is a WALL here rather than a rounding: the sweep
    /// stops being followed once it reaches the last point this gesture may
    /// have, which is what a limit feels like. Rounding instead would let the
    /// content run past and be pulled back, and a settle that goes backwards
    /// reads as the movement being taken away.
    /// </para>
    /// </remarks>
    /// <param name="turned">How far the burst has swept, signed, both axes.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    private void Follow(Point turned, double interval)
    {
        var swept = new Point(_grip.X + turned.X, _grip.Y + turned.Y);
        int most = Most;

        if (most > 0 && interval > 0)
        {
            double origin = From;

            swept = new Point(
                Walled(swept.X, _grip.X, interval, origin, most),
                Walled(swept.Y, _grip.Y, interval, origin, most));
        }

        Put(Reachable(swept));
    }

    /// <summary>
    /// An offset brought back inside the points of the grid one gesture may
    /// reach, WITHOUT being rounded to one of them.
    /// </summary>
    /// <param name="to">Where the sweep has got to.</param>
    /// <param name="from">Where the gesture began, which need not be on a point.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    /// <param name="origin">Where the grid starts.</param>
    /// <param name="most">The most points it may cross.</param>
    private static double Walled(double to, double from, double interval, double origin, int most)
    {
        double started = Math.Round((from - origin) / interval);

        return Math.Clamp(
            to,
            origin + ((started - most) * interval),
            origin + ((started + most) * interval));
    }

    /// <summary>
    /// Glides to the point of the grid the burst has earned, where that point
    /// is not the one already aimed at.
    /// </summary>
    /// <param name="turned">How far the burst has swept, signed.</param>
    /// <param name="across">Which axis the wheel moves.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    /// <param name="fresh">Whether this message began the burst.</param>
    private void Aim(Point turned, bool across, double interval, bool fresh)
    {
        double swept = across ? turned.X : turned.Y;

        // The sweep in points of the grid, or the clicks that were counted one
        // by one - whichever says more. A sweep under Least says nothing, so a
        // jiggle moves nothing at all.
        int cells = Math.Abs(swept) >= Least
            ? Math.Max(1, (int)Math.Round(Math.Abs(swept) / interval))
            : 0;

        cells = Math.Max(cells, _clicks);

        if (cells == 0)
        {
            Trace($"swept {swept:F1} under the least");
            return;
        }

        double origin = From;
        double held = across ? _grip.X : _grip.Y;
        double from = origin + (Math.Round((held - origin) / interval) * interval);
        double to = from + (Math.Sign(swept) * cells * interval);

        Point landing = Held(
            Reachable(across ? new Point(to, _grip.Y) : new Point(_grip.X, to)),
            interval);

        if (!fresh && _aim is { } aimed
            && Math.Abs(aimed.X - landing.X) <= Slack
            && Math.Abs(aimed.Y - landing.Y) <= Slack)
        {
            return;
        }

        _aim = landing;

        Trace($"aiming {landing.X:F1},{landing.Y:F1} swept={swept:F1} cells={cells} "
            + $"clicks={_clicks} from={_grip.X:F1},{_grip.Y:F1}");

        Glide(landing);
    }

    /// <summary>
    /// The burst is over - its quiet ran out with no message interrupting.
    /// The glide it aimed is already running or already done; what is left is
    /// to say the scroller rested, which the gate in <see cref="Rest"/> was
    /// holding back while the burst lived.
    /// </summary>
    /// <remarks>
    /// A BURST OUTLIVES THE MOVEMENT IT AIMED. The quiet is shorter than a
    /// settle - 150 ms against a flight of two to four hundred - so ending the
    /// burst on the quiet alone lets a late message of the tail begin a fresh
    /// gesture WHILE the settle is still in the air: it takes hold of the
    /// content half way, kills the flight, and sweeps on past the card the
    /// flight was landing on, which is then flown back. Measured as a carousel
    /// thrown to 3828.8, taken over at 3769.8, carried to 3877.2 and pulled
    /// back twice over - the overshoot at the end of a swipe. So the burst
    /// waits for its own movement, and every message until then belongs to it.
    /// </remarks>
    private void Ended()
    {
        if (_turned is null)
        {
            return;
        }

        if (_gliding)
        {
            Await();
            return;
        }

        _turned = null;
        _least = null;

        Trace("burst over");

        Rest();
    }

    /// <summary>Waits another quiet before asking whether the burst is over.</summary>
    private void Await()
    {
        int ticket = ++_bursts;

        _scroll.Dispatcher.DispatchDelayed(
            TimeSpan.FromMilliseconds(Quiet),
            () =>
            {
                if (ticket == _bursts)
                {
                    Ended();
                }
            });
    }
#endif
}
