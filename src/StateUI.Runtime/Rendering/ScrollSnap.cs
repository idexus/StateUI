namespace StateUI.Runtime.Rendering;

/// <summary>
/// Settles a scroller the reader let go of: where it lands, how long it takes
/// getting there, and the one movement that carries it - none of which is the
/// platform's to decide.
/// </summary>
/// <remarks>
/// <para>
/// THE PLATFORM IS ASKED FOR ONE NUMBER AND NOTHING ELSE: how fast the scroller
/// was going as the finger left it. Its own inertia is stopped at that moment,
/// and what follows is a single movement of this side's own - the distance from
/// <see cref="ScrollGlide.Thrown"/>, rounded to the grid the tree described, and
/// the time and the curve from <see cref="ScrollGlide.Movement"/>. So a card
/// settles the same way on every platform, and a settle looks like the move an
/// author asks for with a position, because they are the same movement.
/// </para>
/// <para>
/// This is also what stops a gentle release from crawling. A platform asked to
/// decelerate somewhere its own throw was not going stretches its curve to
/// reach it, and how long that takes then depends on how slowly the reader
/// happened to let go - which is a settle whose LOOK is decided by something
/// that should not decide it. Here the speed a movement sets off at has a
/// floor.
/// </para>
/// <para>
/// A scroller the tree asked nothing of - no grid, no shortened throw - is left
/// entirely alone with its own physics, and is hooked only to be heard
/// stopping. Ordinary scrolling is the platform's.
/// </para>
/// <para>
/// It reports ONE thing: <see cref="Rested"/>, the moment the scroller stops -
/// which is where the movement already had to know it was, and where work that
/// would be seen as a hitch costs nothing. Which point of the grid the scroller
/// is nearest is a property report like any other - see
/// <c>StateUIRenderer.WatchSnapItem</c> - so a scroller that snaps and one that
/// only listens are the same mechanism.
/// </para>
/// </remarks>
internal sealed class ScrollSnap
{
    /// <summary>The scroller this settles.</summary>
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
    /// What fraction of a throw this scroller keeps. One is the whole of it.
    /// </summary>
    private double Momentum => (double)_scroll.GetValue(StateUIRenderer.ScrollMomentumProperty);

    /// <summary>Where the grid starts.</summary>
    private double From => (double)_scroll.GetValue(StateUIRenderer.SnapFromProperty);

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
    /// Where a release at this speed ends: as far as the throw carries, rounded
    /// to the grid, held inside what the scroller can reach.
    /// </summary>
    /// <param name="from">Where the finger let go.</param>
    /// <param name="velocity">How fast it was going, in device units a second.</param>
    private Point Landing(Point from, Point velocity)
    {
        double momentum = Momentum;

        return Snapped(new Point(
            ScrollGlide.Thrown(from.X, velocity.X, momentum),
            ScrollGlide.Thrown(from.Y, velocity.Y, momentum)));
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
    /// Whether the tree asked for a release to be SETTLED at all - a grid to
    /// land on, or a throw to shorten. A scroller that asked for neither keeps
    /// the platform's own physics, and is hooked only to be heard stopping.
    /// </summary>
    private bool Aims => Interval > 0 || Momentum < 1;

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
    /// The finger has left the scroller, at this speed in device units a
    /// second, with the platform's own inertia already stopped. What follows is
    /// one movement of this side's own.
    /// </summary>
    private void Released(Point velocity)
    {
        if (!Aims)
        {
            return;
        }

        Point here = Offset;

        Glide(Landing(here, velocity), Math.Sqrt((velocity.X * velocity.X) + (velocity.Y * velocity.Y)));
    }

    /// <summary>
    /// Takes the scroller to a point, setting off at a stated speed - the ONE
    /// movement a settle, a correction and an asked-for scroll all are.
    /// </summary>
    /// <remarks>
    /// A movement short enough to be already there is not made: the scroller is
    /// at rest, and says so. Anything else replaces whatever was under way,
    /// which is what makes a second flick during the first one carry on rather
    /// than fight.
    /// </remarks>
    /// <param name="landing">Where it is going, in device units.</param>
    /// <param name="speed">
    /// How fast it is going as it sets off. Zero for a movement no throw is
    /// behind, which is then made at <see cref="ScrollGlide.Slowest"/>.
    /// </param>
    private void Glide(Point landing, double speed)
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

        _gliding = true;

        (double length, bool springs) = ScrollGlide.Movement(distance, speed, Interval);

        try
        {
            _scroll.Animate(
                Gliding,
                t => t,
                // HELD INSIDE WHAT THE SCROLLER CAN REACH, every step: a spring
                // overshoots its landing, and at the last card there is nothing
                // past it to overshoot into. Clamping here rather than leaving
                // it to the platform is what keeps the ends alike - one would
                // show the overshoot as a bounce and another would flatten it.
                t => Put(Reachable(new Point(here.X + (dx * t), here.Y + (dy * t)))),
                rate: Rate,
                length: (uint)Math.Round(length),
                easing: springs ? Easing.SpringOut : Easing.CubicOut,
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
    /// each platform is asked for besides a speed. MAUI's own request otherwise,
    /// which is what a scroller with no handler yet can still be moved by.
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
    /// Moves the scroller to a point over this side's own curve, and answers
    /// when it gets there - what an animated scroll act is.
    /// </summary>
    /// <remarks>
    /// A movement nobody threw, so it sets off at the floor speed like any
    /// other, and lands where it was ASKED to rather than on the grid: an
    /// author who names an offset means that offset.
    /// </remarks>
    /// <param name="x">Where it is going across.</param>
    /// <param name="y">And down.</param>
    /// <returns>A task that finishes when the movement does.</returns>
    internal Task GlideTo(double x, double y)
    {
        var arrival = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

        Stop(arrived: false);
        _arrival = arrival;
        Glide(Reachable(new Point(x, y)), speed: 0);

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
                Glide(there, speed: 0);
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

#if IOS || MACCATALYST
    /// <summary>The UIScrollView the hooks are on.</summary>
    private UIKit.UIScrollView? _native;

    /// <summary>
    /// How fast the finger was going as it left, in device units a second -
    /// read where UIKit states it, and used the moment the drag ends.
    /// </summary>
    private Point _thrown;

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

        // UIKit states the speed the finger is leaving at, and takes the end of
        // its own deceleration by reference. Sending it where it already is is
        // what stops that deceleration from happening at all: the movement that
        // follows is this side's own, and there are never two.
        native.WillEndDragging += (_, e) =>
        {
            if (!Aims)
            {
                return;
            }

            // Points per MILLISECOND, which is UIKit's own unit here.
            _thrown = new Point(e.Velocity.X * 1000, e.Velocity.Y * 1000);

            e.TargetContentOffset = native.ContentOffset;
        };

        // Every way a movement can end, which is where the guarantee is kept:
        // a drag let go of, a deceleration that ran out where the tree asked
        // for none of this, and an animated scroll - a wheel among them, which
        // no drag precedes.
        native.DraggingEnded += (_, _) =>
        {
            _down = false;

            if (Aims)
            {
                Released(_thrown);
                return;
            }

            Rest();
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

                // A movement of this side's own is stopped where it stands,
                // which is where the offset already is - it is stepped frame by
                // frame rather than handed to the platform, so there is nothing
                // to read out of a presentation layer and nothing to put back.
                Stop(arrived: false);

                // MAUI's own animated scroll IS handed over, and that one is a
                // CAAnimation: it is stopped where it is SEEN to be, the model
                // offset already holding the target.
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

                // A drag hands its own end to DraggingEnded, where the speed it
                // carried is already known. A touch that never became one ends
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

    /// <summary>Which quiet after a movement is the current one.</summary>
    private int _quiet;

    /// <summary>And which posted release is, so an older one drops.</summary>
    private int _releases;

    /// <summary>
    /// How long the offset must stay unchanged before it counts as at rest, in
    /// milliseconds. Android's plain scrollers say nothing when a fling ends,
    /// so the rest is read off the scroll reports stopping - two frames and a
    /// little.
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

        // Never consumed: the platform's own handling is what drags the
        // scroller, and - on a touch landing mid-movement - aborts its scroller.
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

                    Point thrown = Thrown(touched, motion.ActionMasked == Android.Views.MotionEventActions.Up);

                    _tracker?.Recycle();
                    _tracker = null;

                    Take(touched, thrown);
                    ArmRest();
                    break;
            }
        };
    }

    /// <summary>
    /// How fast the scroller is going as the finger leaves, in device units a
    /// second.
    /// </summary>
    /// <remarks>
    /// The tracker states the FINGER's speed, and an offset runs the other way
    /// to it. Below the platform's own minimum fling velocity there is no throw
    /// at all, which is the platform's judgement about what counts as a flick
    /// and the one part of this worth keeping - a drag that ends still is not a
    /// throw of two pixels a second.
    /// </remarks>
    private Point Thrown(Android.Views.View touched, bool lifted)
    {
        if (!lifted || _tracker is null || touched.Context is not Android.Content.Context context)
        {
            return Point.Zero;
        }

        var configuration = Android.Views.ViewConfiguration.Get(context);
        int least = configuration?.ScaledMinimumFlingVelocity ?? 0;
        int most = configuration?.ScaledMaximumFlingVelocity ?? int.MaxValue;

        _tracker.ComputeCurrentVelocity(1000, most);

        bool across = touched is Android.Widget.HorizontalScrollView;
        float velocity = across ? _tracker.XVelocity : _tracker.YVelocity;

        if (Math.Abs(velocity) <= least)
        {
            return Point.Zero;
        }

        double units = -Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, velocity);

        return across ? new Point(units, 0) : new Point(0, units);
    }

    /// <summary>
    /// Takes the movement off the platform and settles it here instead.
    /// </summary>
    /// <remarks>
    /// POSTED, because the fling has not started yet - the platform starts it
    /// from the same UP event, after this listener has returned - so there
    /// would be nothing to replace. A fling of NO speed is what replaces it,
    /// that being the one way in to a scroller's own <c>Scroller</c> from
    /// outside: it finishes at once, and the frames after it are this side's.
    /// </remarks>
    private void Take(Android.Views.View touched, Point thrown)
    {
        if (!Aims)
        {
            return;
        }

        int ticket = ++_releases;

        touched.Post(() =>
        {
            // POSTED means a frame later, and a frame is long enough for the
            // reader to put a finger back down. Moving then would take the
            // offset out from under them and arrive as a jump.
            if (_down || ticket != _releases)
            {
                return;
            }

            switch (touched)
            {
                case Android.Widget.HorizontalScrollView across:
                    across.Fling(0);
                    break;

                case AndroidX.Core.Widget.NestedScrollView down:
                    down.Fling(0);
                    break;

                case Android.Widget.ScrollView plain:
                    plain.Fling(0);
                    break;
            }

            Released(thrown);
        });
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

    /// <summary>Where the scroller was a moment ago, and when.</summary>
    private (Point Offset, long At) _was;

    /// <summary>
    /// WinUI states no speed of its own, so it is read off the last moments of
    /// the manipulation - which is the same quantity by the same definition,
    /// measured rather than asked for. The first INERTIAL change is the moment
    /// the finger left, and the inertia is ended there by being sent where it
    /// already is.
    /// </summary>
    private void HookWindows()
    {
        if (_scroll.Handler?.PlatformView is not Microsoft.UI.Xaml.Controls.ScrollViewer viewer
            || ReferenceEquals(_viewer, viewer))
        {
            return;
        }

        _viewer = viewer;

        viewer.DirectManipulationStarted += (_, _) =>
        {
            _inertial = false;
            _down = true;
            _was = (Offset, System.Diagnostics.Stopwatch.GetTimestamp());
            Stop(arrived: false);
        };

        viewer.ViewChanging += (_, e) =>
        {
            if (!e.IsInertial)
            {
                // Under the finger, and this is what the speed is read from.
                _was = (new Point(e.NextView.HorizontalOffset, e.NextView.VerticalOffset),
                    System.Diagnostics.Stopwatch.GetTimestamp());

                return;
            }

            if (_inertial || !Aims)
            {
                return;
            }

            _inertial = true;
            _down = false;

            Point here = Offset;
            double seconds =
                (System.Diagnostics.Stopwatch.GetTimestamp() - _was.At)
                / (double)System.Diagnostics.Stopwatch.Frequency;

            var thrown = seconds > 0
                ? new Point((here.X - _was.Offset.X) / seconds, (here.Y - _was.Offset.Y) / seconds)
                : Point.Zero;

            viewer.ChangeView(here.X, here.Y, null, true);
            Released(thrown);
        };

        viewer.DirectManipulationCompleted += (_, _) => _down = false;

        viewer.ViewChanged += (_, e) =>
        {
            if (!e.IsIntermediate)
            {
                _inertial = false;
                Rest();
            }
        };
    }
#endif
}
