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
    private bool _down;

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
    /// Where the offset was when the finger landed - what a limit on how far one
    /// release may go is measured from, so a drag and the throw that ends it
    /// cannot add up to more than the limit between them.
    /// </summary>
    private Point _grip;

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

        if (distance <= Slack)
        {
            Arrive();
            Rest();
            return;
        }

        Trace($"glide to={landing.X:F1},{landing.Y:F1} from={here.X:F1},{here.Y:F1} ms={ScrollGlide.Length(distance, Interval):F0}");

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
        if (_down || _gliding)
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

            if (Math.Abs(there.X - here.X) > Slack || Math.Abs(there.Y - here.Y) > Slack)
            {
                Trace($"correcting from={here.X:F1},{here.Y:F1} to={there.X:F1},{there.Y:F1}");
                Glide(there);
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

    /// <summary>The view the wheel is heard on, which is the scroller's content.</summary>
    private Microsoft.UI.Xaml.UIElement? _content;

    /// <summary>What one whole notch of the wheel reports.</summary>
    private const double Whole = 120;

    /// <summary>
    /// How far one notch of the wheel carries a scroller, in device units -
    /// WinUI's own, measured at 139. It is what makes a touchpad's stream move
    /// the content as far as the fingers asked, so the number matters only in
    /// that it is the platform's rather than one of ours.
    /// </summary>
    private const double Notch = 140;

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
    private const double Least = Notch * 0.6;

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

    /// <summary>How far the last message carried, unsigned, in device units.</summary>
    private double _lastSize;

    /// <summary>The furthest any one message of this burst carried, unsigned.</summary>
    private double _peak;

    /// <summary>
    /// Whether this burst has entered its DECAY - the shrinking tail the
    /// platform synthesizes after the fingers leave. What a fresh gesture is
    /// told against: speed where the tail was dying is a reader, not inertia.
    /// </summary>
    private bool _decayed;

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

        HookWheel(viewer);

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
    /// Hears the wheel on the scroller's CONTENT, where a snapping scroller
    /// takes it over.
    /// </summary>
    /// <remarks>
    /// <para>
    /// ON THE CONTENT, because a routed event reaches a child before its
    /// parent and the ScrollViewer's own handling is the parent's: marked
    /// handled here, the platform never scrolls and the movement is entirely
    /// this side's. Marking it on the ScrollViewer would be too late - by then
    /// it has already answered the notch.
    /// </para>
    /// <para>
    /// A TOUCHPAD IS WHAT THIS IS FOR. A desktop's scroll is a wheel message
    /// either way, but a precision touchpad and an Apple mouse send a stream of
    /// FRACTIONS of a notch as the fingers move, and the platform answers each
    /// one by re-aiming at its own accumulated destination - so an aim of ours
    /// taken from that stream is overwritten by the next fraction, the content
    /// follows the fingers to wherever they stopped, and the grid is reached by
    /// a second movement afterwards. Which is the very thing a snapping
    /// scroller exists not to do.
    /// </para>
    /// </remarks>
    /// <param name="viewer">The scroller's platform view.</param>
    private void HookWheel(Microsoft.UI.Xaml.Controls.ScrollViewer viewer)
    {
        if (viewer.Content is not Microsoft.UI.Xaml.UIElement content
            || ReferenceEquals(_content, content))
        {
            return;
        }

        _content = content;

        content.AddHandler(
            Microsoft.UI.Xaml.UIElement.PointerWheelChangedEvent,
            new Microsoft.UI.Xaml.Input.PointerEventHandler((_, e) => Turned(viewer, e)),
            handledEventsToo: false);
    }

    /// <summary>
    /// The wheel turned over a scroller that has a grid: the burst it belongs
    /// to grows by what the message carried, and the scroller GLIDES to the
    /// point of the grid the burst has earned - retargeted only when that
    /// point changes, so the motion is one movement however many messages fed
    /// it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// THE OFFSET IS NEVER WRITTEN FROM HERE. It moves only by gliding to a
    /// point of the grid, so the scroller is always either resting on the grid
    /// or making one eased movement towards it - which is what makes a wheel
    /// deterministic: no follow to teleport, no correction to fight, nothing
    /// to oscillate around the landing.
    /// </para>
    /// <para>
    /// ONE GESTURE IS ONE BURST, AND THE TAIL BELONGS TO IT. A precision
    /// touchpad - an Apple mouse too - keeps sending after the fingers leave, a
    /// decaying tail of fractions the platform synthesizes; cutting the burst
    /// on a short quiet split that tail into a second gesture and a second
    /// card. So the quiet is long, and a NEW gesture inside it is told by its
    /// shape instead: a direction change, or speed where the tail was dying.
    /// Either one commits the burst where it was going and starts the next
    /// from there - which is what makes forward, back, forward land where it
    /// started, one card per gesture.
    /// </para>
    /// <para>
    /// HOW FAR A BURST REACHES: its whole sweep at the platform's own
    /// <see cref="Notch"/> per notch, rounded to the grid, at least one point
    /// once it clears <see cref="Least"/> - and a mouse's CLICKS, whole
    /// notches slower than <see cref="Click"/> apart, are a point each, so
    /// three deliberate clicks are three rows however little distance they
    /// add up to. <c>snapsAtMost</c> then caps the whole burst from where it
    /// began, tail included, which is what "one card a swipe" means.
    /// </para>
    /// </remarks>
    /// <param name="viewer">The scroller's platform view.</param>
    /// <param name="e">The wheel message.</param>
    private void Turned(
        Microsoft.UI.Xaml.Controls.ScrollViewer viewer,
        Microsoft.UI.Xaml.Input.PointerRoutedEventArgs e)
    {
        _wheeled = true;

        double interval = Interval;

        if (interval <= 0)
        {
            return;
        }

        Microsoft.UI.Input.PointerPointProperties turn = e.GetCurrentPoint(viewer).Properties;
        bool across = turn.IsHorizontalMouseWheel;

        // A wheel this scroller cannot answer belongs to whatever is above it,
        // which is how a page goes on scrolling under the pointer.
        if (across ? viewer.ScrollableWidth <= 0 : viewer.ScrollableHeight <= 0)
        {
            return;
        }

        e.Handled = true;

        int delta = turn.MouseWheelDelta;

        // Turned away from the reader - a positive delta - is UP and BACK, so
        // the offset falls; a horizontal wheel is the other way round, its
        // positive being to the right.
        double step = delta / Whole * Notch * (across ? 1 : -1);
        double size = Math.Abs(step);
        double now = _clock.ElapsedMilliseconds;
        double gap = now - _lastTurn;

        _lastTurn = now;

        bool fresh = _turned is null;

        if (_turned is { } sofar)
        {
            double swept = across ? sofar.X : sofar.Y;

            // A direction change is a new gesture however soon it comes - and
            // so is speed where the tail was dying, which is the one thing a
            // reader's fingers do that inertia cannot.
            fresh = (swept != 0 && Math.Sign(step) != Math.Sign(swept) && size >= Notch / 6)
                || (_decayed && size >= Math.Max(_lastSize * 2, Notch / 2));
        }

        if (fresh)
        {
            // FROM THE POINT THE LAST MOVEMENT WAS GOING TO, not from wherever
            // the glide has reached: a gesture during a glide means "the next
            // card after that one", and counting from mid-flight is what made
            // one gesture read as two.
            _grip = _gliding && _aim is { } aimed ? aimed : Offset;
            _turned = new Point(0, 0);
            _peak = 0;
            _decayed = false;
            _clicks = 0;
            _lastSize = 0;
            _fractional = false;
        }

        _fractional |= Math.Abs(delta) % (int)Whole != 0;

        if (!_fractional && gap >= Click)
        {
            _clicks++;
        }

        Point was = _turned ?? _grip;
        Point turned = across
            ? new Point(was.X + step, was.Y)
            : new Point(was.X, was.Y + step);

        _turned = turned;
        _peak = Math.Max(_peak, size);
        _decayed |= _peak >= Notch / 3 && size <= _peak * 0.25;
        _lastSize = size;

        Aim(turned, across, interval, fresh);

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
    private void Ended()
    {
        if (_turned is null)
        {
            return;
        }

        _turned = null;

        Trace("burst over");

        Rest();
    }
#endif
}
