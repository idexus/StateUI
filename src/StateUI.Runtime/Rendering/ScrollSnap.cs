namespace StateUI.Runtime.Rendering;

/// <summary>
/// Aims a scroller's own deceleration: SHORTER than the platform would throw
/// it where the tree asked for that, and at a point of the GRID where the tree
/// gave it one - both before the braking begins. A scroller left to rest
/// between two points anyway is taken to the nearest one.
/// </summary>
/// <remarks>
/// <para>
/// THE AIM IS TAKEN WHERE THE PLATFORM DECIDES, never afterwards. UIKit asks
/// its delegate where the deceleration should end and takes the answer by
/// reference; Android is told to scroll smoothly to the rounded point, which
/// replaces the fling it was about to run; WinUI is sent to it with ChangeView
/// as the inertia starts. Rounding after the event instead would be a second
/// movement - the platform brakes to its own stop, and only then does the
/// scroller set off again - which is what a carousel must not do. Nothing waits
/// for the Swift side: the grid is a described property, so the answer is
/// already here.
/// </para>
/// <para>
/// The rest is the guarantee behind it. A platform that will not be told - or
/// a scroll no gesture started, a wheel, a key - leaves the offset wherever it
/// stops, and that is where this puts it right, once, with an animated scroll.
/// The correction is CLAMPED to what the scroller can actually reach, so a
/// grid whose next point lies past the end asks for nothing rather than asking
/// forever.
/// </para>
/// <para>
/// It reports ONE thing: <see cref="Rested"/>, the moment the scroller stops -
/// which is where the aiming already had to know it was, and where work that
/// would be seen as a hitch costs nothing. Which point of the grid the
/// scroller is nearest is a property report like any other - see
/// <c>StateUIRenderer.WatchSnapItem</c> - so a scroller that snaps and one
/// that only listens are the same mechanism.
/// </para>
/// </remarks>
internal sealed class ScrollSnap
{
    /// <summary>The scroller this keeps on its grid.</summary>
    private readonly ScrollView _scroll;

    /// <summary>Whether a finger is on it, so nothing is corrected under one.</summary>
    private bool _down;

    /// <summary>
    /// Whether the offset has changed since the last rest was reported, so a
    /// scroller asked twice whether it has stopped answers once.
    /// </summary>
    private bool _moved;

    /// <summary>Whether the scroller's own offset reports are watched.</summary>
    private bool _watching;

    /// <summary>
    /// The scroller has come to rest: nothing is moving, no finger is on it,
    /// and it is where it is going to stay - the grid correction, where one was
    /// needed, having already run.
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
    /// How much of the platform's own throw to keep. One is all of it.
    /// </summary>
    private double Momentum => (double)_scroll.GetValue(StateUIRenderer.ScrollMomentumProperty);

    /// <summary>Where the grid starts.</summary>
    private double From => (double)_scroll.GetValue(StateUIRenderer.SnapFromProperty);

    /// <summary>
    /// The nearest point of the grid, both axes rounded and each held inside
    /// what the scroller can reach. The same point back where there is no grid.
    /// </summary>
    private Point Snapped(Point predicted) => Snapped(predicted, Offset);

    /// <summary>
    /// Where a movement should end: the platform's predicted stop, SHORTENED
    /// towards where the finger left it by whatever momentum the tree asked
    /// for, then rounded to the grid and held inside what the scroller can
    /// reach.
    /// </summary>
    /// <remarks>
    /// The shortening is a fraction of the platform's OWN prediction rather
    /// than a distance of this side's own, so a hard throw still goes further
    /// than a gentle one and every platform keeps its own physics - which is
    /// the point: a touch platform throws a scroller a long way, and a strip of
    /// cards wants the same flick to mean the next card.
    /// </remarks>
    /// <param name="predicted">Where the platform says the movement would end.</param>
    /// <param name="from">Where the movement is being let go of.</param>
    private Point Snapped(Point predicted, Point from)
    {
        double momentum = Momentum;

        if (momentum is > 0 and not 1)
        {
            predicted = new Point(
                from.X + (predicted.X - from.X) * momentum,
                from.Y + (predicted.Y - from.Y) * momentum);
        }
        else if (momentum <= 0)
        {
            predicted = from;
        }

        double interval = Interval;

        return Reachable(new Point(
            StateUIRenderer.SnapPoint(predicted.X, interval, From),
            StateUIRenderer.SnapPoint(predicted.Y, interval, From)));
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
    /// Whether the tree asked for a movement to be AIMED at all - a grid to
    /// land on, or a throw to shorten. A scroller that asked for neither is
    /// hooked only to be heard stopping, and its movements are left alone.
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
    /// The scroller has stopped moving: puts an offset that came to rest
    /// between two points of the grid onto the nearest one, and where nothing
    /// is left to move, says so. Nothing happens under a finger.
    /// </summary>
    /// <remarks>
    /// The correction is a MOVEMENT, so it is not the rest - its own end runs
    /// this again, finds the offset already on the grid, and reports from
    /// there. Which is what makes the report worth having: where it says the
    /// scroller is, it is.
    /// </remarks>
    private void Rest()
    {
        if (_down)
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
                _scroll.ScrollToAsync(there.X, there.Y, true);
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
    /// UIScrollView says every moment itself, but for the finger coming DOWN:
    /// <c>DraggingStarted</c> fires once the finger has moved far enough to be
    /// a drag, and a tap that stops a glide never gets that far. A press
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
        // handed over BEFORE it begins and taken back by reference - so the
        // rounded point written here is where the deceleration goes, in one
        // movement, with UIKit's own curve.
        native.WillEndDragging += (_, e) =>
        {
            if (!Aims)
            {
                return;
            }

            Point landing = Snapped(new Point(e.TargetContentOffset.X, e.TargetContentOffset.Y));

            e.TargetContentOffset = new CoreGraphics.CGPoint(landing.X, landing.Y);
        };

        // Every way a movement can end, which is where the guarantee is kept:
        // a drag let go of with nothing to shed, a deceleration that ran out,
        // and an animated scroll - a wheel among them, which no drag precedes.
        native.DraggingEnded += (_, e) =>
        {
            _down = false;

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

                // UIKit stops its OWN deceleration when a finger lands, so the
                // only thing to stop here is a scroll THIS side animated - and
                // that is a CAAnimation on the layer, which a deceleration is
                // not. It is stopped where it is SEEN to be: the model offset
                // already holds the animation's target and the presentation
                // layer holds where it has got to.
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
                // prediction already rounded. A touch that never became one
                // ends here, and what it interrupted has to be put back.
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

    /// <summary>The velocity of the touch under way.</summary>
    private Android.Views.VelocityTracker? _tracker;

    /// <summary>Which quiet after a movement is the current one.</summary>
    private int _quiet;

    /// <summary>And which posted landing is, so an older one drops.</summary>
    private int _landings;

    /// <summary>
    /// How long the offset must stay unchanged before it counts as at rest, in
    /// milliseconds. Android's plain scrollers say nothing when a fling or a
    /// smooth scroll ends, so the rest is read off the scroll reports stopping -
    /// two frames and a little.
    /// </summary>
    private const int RestAfterMs = 50;

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

        if (outer.ChildCount > 0 && outer.GetChildAt(0) is Android.Widget.HorizontalScrollView across)
        {
            Listen(across);
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
        // and - on a touch landing mid-glide - aborts its scroller.
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

                    Land(touched, Snapped(
                        Predicted(touched, motion.ActionMasked == Android.Views.MotionEventActions.Up)));

                    _tracker?.Recycle();
                    _tracker = null;
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

        using var scroller = new Android.Widget.OverScroller(context);

        scroller.Fling(
            group.ScrollX, group.ScrollY,
            across ? -velocity : 0, across ? 0 : -velocity,
            0, rangeX, 0, rangeY);

        double x = across ? Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, scroller.FinalX) : here.X;
        double y = across ? here.Y : Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, scroller.FinalY);

        return new Point(x, y);
    }

    /// <summary>
    /// Sends the scroller to the rounded point, replacing the fling it is about
    /// to run.
    /// </summary>
    /// <remarks>
    /// POSTED rather than called: the fling has not started yet - the platform
    /// starts it from the same UP event, after this listener has returned - and
    /// a smooth scroll asked for first would be the thing that got replaced.
    /// Android takes pixels here, where everything else on this side is in
    /// device units.
    /// </remarks>
    private void Land(Android.Views.View touched, Point landing)
    {
        if (!Aims || touched.Context is not Android.Content.Context context)
        {
            return;
        }

        int x = (int)Microsoft.Maui.Platform.ContextExtensions.ToPixels(context, landing.X);
        int y = (int)Microsoft.Maui.Platform.ContextExtensions.ToPixels(context, landing.Y);

        int ticket = ++_landings;

        touched.Post(() =>
        {
            // POSTED means a frame later, and a frame is long enough for the
            // reader to put a finger back down. Landing then would take the
            // offset out from under them and arrive as a jump.
            if (_down || ticket != _landings)
            {
                return;
            }

            switch (touched)
            {
                case Android.Widget.HorizontalScrollView across:
                    across.SmoothScrollTo(x, 0);
                    break;

                case AndroidX.Core.Widget.NestedScrollView down:
                    down.SmoothScrollTo(0, y);
                    break;

                case Android.Widget.ScrollView plain:
                    plain.SmoothScrollTo(0, y);
                    break;
            }
        });
    }

    /// <summary>
    /// Puts the rest off by <see cref="RestAfterMs"/>: the offset is at rest
    /// when that long has passed with no report and no finger, which is where
    /// anything the landing did not reach is put right.
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
    /// WinUI's ScrollViewer hands over the end of its inertia before it gets
    /// there - <c>ViewChanging.FinalView</c> - which is where the aim is taken.
    /// A wheel or a key makes no manipulation and no inertia, so those are put
    /// right at the rest instead.
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
        };

        viewer.ViewChanging += (_, e) =>
        {
            if (!e.IsInertial || _inertial || !Aims)
            {
                return;
            }

            _inertial = true;
            _down = false;

            Point landing = Snapped(
                new Point(e.FinalView.HorizontalOffset, e.FinalView.VerticalOffset), Offset);

            viewer.ChangeView(landing.X, landing.Y, null);
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
