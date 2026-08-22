using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Reports what the reader's touch is doing to a scroller - down, up with
/// where the platform would let the offset come to rest, and the offset at
/// rest - and, where the tree asked for a snap interval, sends the platform's
/// own deceleration to a multiple of it instead.
/// </summary>
/// <remarks>
/// <para>
/// Three moments and nothing in between. While the finger moves, the offset is
/// the platform's to move and nothing crosses; the decision a carousel makes
/// needs only the lift and the predicted stop, and an answer to it is an
/// ordinary <c>scrollTo</c>, which replaces the platform's own deceleration.
/// </para>
/// <para>
/// Each platform says each moment its own way, and the prediction is the
/// platform's own physics in every case - what its deceleration WOULD do, read
/// off it rather than modelled here - so a scroller that lands on a card brakes
/// the way every other scroller on that platform does. iOS and Mac Catalyst
/// hand the predicted stop to <c>WillEndDragging</c>; Windows puts it in
/// <c>ViewChanging.FinalView</c>; Android has no such hook on a plain
/// scroller, so the fling it is about to start is run ahead through an
/// <c>OverScroller</c> of its own, from the velocity the touch carried.
/// </para>
/// <para>
/// THE SNAP IS APPLIED WHERE THE PLATFORM DECIDES, never afterwards. UIKit
/// asks its delegate where the deceleration should end and takes the answer
/// by reference; Android is told to scroll smoothly to the rounded point, which
/// replaces the fling it was about to run; WinUI is sent to it with ChangeView.
/// Rounding after the event instead would be a second movement - the platform
/// brakes to its own stop, and only then does the scroller set off again - which
/// is exactly what a carousel must not do. Nothing waits for the Swift side:
/// the interval is a described property, so the answer is already here.
/// </para>
/// <para>
/// A finger coming down on a glide this side asked for STOPS it where it
/// stands and answers the act that asked, so the Swift handler awaiting it
/// resumes. On Android the platform's own touch handling aborts the scroller;
/// on iOS the animation is stopped by writing the offset the presentation
/// layer is showing, and MAUI's pending request is completed by hand because
/// the animation it waits on will never end on its own.
/// </para>
/// <para>
/// A touch that never becomes a drag - a tap that stops a glide - still lifts,
/// and the lift is reported with no speed to shed, so whoever answers lifts
/// can land the offset the tap left between cards.
/// </para>
/// </remarks>
internal sealed class ScrollTouch
{
    /// <summary>What a hook reports: the phase, and the two offsets.</summary>
    internal delegate void Report(SwiftScrollGesturePhase phase, Point offset, Point predicted);

    /// <summary>The scroller whose touch this is.</summary>
    private readonly ScrollView _scroll;

    /// <summary>Where a report goes.</summary>
    private readonly Report _report;

    /// <summary>Whether a finger is down, so that a touch is reported once.</summary>
    private bool _down;

    /// <summary>The hooks for one scroller, not yet attached to anything.</summary>
    internal ScrollTouch(ScrollView scroll, Report report)
    {
        _scroll = scroll;
        _report = report;
    }

    /// <summary>
    /// Attaches to the platform view the scroller has now, where it has one
    /// and this has not attached to it already.
    /// </summary>
    internal void Hook()
    {
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
    /// The nearest offset the scroller may come to rest on, both axes rounded
    /// to the interval. The same point back where there is no interval - and
    /// where a stop is rounded to where it already was, which is what makes a
    /// small drag fall back onto the card it left.
    /// </summary>
    private Point Snapped(Point predicted)
    {
        double interval = Interval;

        if (interval <= 0)
        {
            return predicted;
        }

        return new Point(
            Math.Round(predicted.X / interval) * interval,
            Math.Round(predicted.Y / interval) * interval);
    }

    /// <summary>A finger came down, said once per touch.</summary>
    private void Down()
    {
        if (_down)
        {
            return;
        }

        _down = true;
        _report(SwiftScrollGesturePhase.TouchDown, Offset, Offset);
    }

    /// <summary>The finger lifted, with where the platform would leave the offset.</summary>
    private void Up(Point predicted)
    {
        _down = false;
        _report(SwiftScrollGesturePhase.TouchUp, Offset, predicted);
    }

    /// <summary>The offset is at rest with nothing touching it.</summary>
    private void Stopped()
    {
        if (_down)
        {
            return;
        }

        _report(SwiftScrollGesturePhase.Stopped, Offset, Offset);
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
            Point landing = Snapped(new Point(e.TargetContentOffset.X, e.TargetContentOffset.Y));

            e.TargetContentOffset = new CoreGraphics.CGPoint(landing.X, landing.Y);
            Up(landing);
        };

        // A drag let go of with no speed to shed is at rest the moment it
        // lifts; one with speed is at rest when the deceleration ends; and a
        // glide this side asked for is at rest when its animation ends.
        native.DraggingEnded += (_, e) =>
        {
            if (!e.Decelerate)
            {
                Stopped();
            }
        };

        native.DecelerationEnded += (_, _) => Stopped();
        native.ScrollAnimationEnded += (_, _) => Stopped();
    }

    /// <summary>
    /// The finger landed, or left without ever dragging.
    /// </summary>
    private void Pressed(UIKit.UILongPressGestureRecognizer press)
    {
        if (_native is not UIKit.UIScrollView native)
        {
            return;
        }

        switch (press.State)
        {
            case UIKit.UIGestureRecognizerState.Began:
                // A glide under way is stopped where it is SEEN to be: the
                // model offset already holds the glide's target, and the
                // presentation layer holds where the animation has got to.
                // Writing that offset unanimated removes the animation - and
                // MAUI's request, waiting on an animation that will now never
                // end, is completed by hand so the Swift handler resumes.
                if (native.Layer.PresentationLayer is CoreAnimation.CALayer shown
                    && shown.Bounds.Location != native.ContentOffset)
                {
                    native.SetContentOffset(shown.Bounds.Location, false);
                }

                ((IScrollViewController)_scroll).SendScrollFinished();
                Down();
                break;

            case UIKit.UIGestureRecognizerState.Ended:
            case UIKit.UIGestureRecognizerState.Cancelled:
            case UIKit.UIGestureRecognizerState.Failed:
                // A drag reports its own lift through WillEndDragging, with
                // the prediction. A touch that never became one lifts here,
                // with nothing to predict.
                if (_down && !native.Dragging)
                {
                    Up(Offset);
                }

                break;
        }
    }
#elif ANDROID
    /// <summary>The views the touch listener is on - the outer scroller, and the sideways one inside it where there is one.</summary>
    private readonly HashSet<Android.Views.View> _hooked = [];

    /// <summary>The velocity of the touch under way.</summary>
    private Android.Views.VelocityTracker? _tracker;

    /// <summary>Which quiet after the finger lifted is the current one.</summary>
    private int _quiet;

    /// <summary>
    /// How long the offset must stay unchanged after the finger lifted before
    /// it counts as at rest, in milliseconds. Android's plain scrollers say
    /// nothing when a fling or a smooth scroll ends, so the rest is read off
    /// the scroll reports stopping - two frames and a little.
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

        if (_watchingRest)
        {
            return;
        }

        _watchingRest = true;

        // Every offset report after the lift puts the rest off again.
        _scroll.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == ScrollView.ScrollXProperty.PropertyName
                || e.PropertyName == ScrollView.ScrollYProperty.PropertyName)
            {
                ArmRest();
            }
        };
    }

    /// <summary>Whether the scroller's reports are already watched for the rest.</summary>
    private bool _watchingRest;

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
                        _tracker?.Recycle();
                        _tracker = Android.Views.VelocityTracker.Obtain();
                        ((IScrollViewController)_scroll).SendScrollFinished();
                        Down();
                    }

                    _tracker?.AddMovement(motion);
                    break;

                case Android.Views.MotionEventActions.Up:
                case Android.Views.MotionEventActions.Cancel:
                    if (!_down)
                    {
                        break;
                    }

                    _tracker?.AddMovement(motion);

                    Point landing = Snapped(
                        Predicted(touched, motion.ActionMasked == Android.Views.MotionEventActions.Up));

                    _tracker?.Recycle();
                    _tracker = null;

                    Land(touched, landing);
                    Up(landing);
                    ArmRest();
                    break;
            }
        };
    }

    /// <summary>
    /// Where the fling the platform is about to start would end - its own
    /// physics, run ahead: the velocity the touch carried, over the range the
    /// scroller has, through an <c>OverScroller</c> exactly as the scroller's
    /// own is about to be. Below the platform's minimum fling velocity there
    /// is no fling, and the offset stays where the finger left it.
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
    /// Sends the scroller to the rounded point, replacing the fling it is
    /// about to run.
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
        if (Interval <= 0 || touched.Context is not Android.Content.Context context)
        {
            return;
        }

        int x = (int)Microsoft.Maui.Platform.ContextExtensions.ToPixels(context, landing.X);
        int y = (int)Microsoft.Maui.Platform.ContextExtensions.ToPixels(context, landing.Y);

        touched.Post(() =>
        {
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
    /// when that long has passed with no report and no finger.
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
                Stopped();
            }
        });
    }
#elif WINDOWS
    /// <summary>The ScrollViewer the hooks are on.</summary>
    private Microsoft.UI.Xaml.Controls.ScrollViewer? _viewer;

    /// <summary>Whether the movement under way is the platform's inertia.</summary>
    private bool _inertial;

    /// <summary>
    /// WinUI's ScrollViewer says the three moments for a touch or a pen:
    /// manipulation started, the first inertial view change - whose FinalView
    /// is the predicted stop - and the view change that is not intermediate.
    /// A wheel or a trackpad makes no manipulation, so it reports its rest
    /// and nothing else.
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
            Down();
        };

        viewer.ViewChanging += (_, e) =>
        {
            if (e.IsInertial && !_inertial)
            {
                _inertial = true;

                Point landing = Snapped(new Point(e.FinalView.HorizontalOffset, e.FinalView.VerticalOffset));

                if (Interval > 0)
                {
                    viewer.ChangeView(landing.X, landing.Y, null);
                }

                Up(landing);
            }
        };

        viewer.DirectManipulationCompleted += (_, _) =>
        {
            if (_down)
            {
                Point landing = Snapped(Offset);

                if (Interval > 0 && landing != Offset)
                {
                    viewer.ChangeView(landing.X, landing.Y, null);
                }

                Up(landing);
            }
        };

        viewer.ViewChanged += (_, e) =>
        {
            if (!e.IsIntermediate)
            {
                _inertial = false;
                Stopped();
            }
        };
    }
#endif
}
