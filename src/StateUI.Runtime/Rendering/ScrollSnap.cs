// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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

    /// <summary>
    /// Where the reader left the scroller, in device units - the place a
    /// change of geometry has to give back. Nothing until the scroller has
    /// been somewhere: a run that has never moved has nothing to lose.
    /// </summary>
    private Point? _kept;

    /// <summary>
    /// How many relayouts are still to be answered. Above zero the offset the
    /// platform reports is the clamp's, not the reader's, so nothing is
    /// learnt from it; the last one to be answered is the one that puts the
    /// place back, every earlier one having been overtaken by a newer layout.
    /// </summary>
    private int _storms;

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

    /// <summary>Which quiet after a movement is the current one.</summary>
    private int _quiet;

    /// <summary>
    /// How long the offset must stay unchanged before it counts as at rest, in
    /// milliseconds. A platform that says nothing when a fling or a smooth
    /// scroll ends has its rest read off the scroll reports stopping - two
    /// frames and a little.
    /// </summary>
    private const int RestAfterMs = 50;

    /// <summary>
    /// Puts the rest off by <see cref="RestAfterMs"/>: the offset is at rest
    /// when that long has passed with no report and no finger, which is where
    /// anything the settle did not reach is put right.
    /// </summary>
    /// <remarks>
    /// The handler guard is what keeps this out of the tests: a scroller there
    /// has no platform behind it, so nothing ever announces an end and nothing
    /// should be inferred from the quiet either.
    /// </remarks>
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

    /// <summary>
    /// The scroller has come to rest: nothing is moving, no finger is on it,
    /// and it is where it is going to stay - the settle, where one was needed,
    /// having already run.
    /// </summary>
    internal event Action? Rested;

    /// <summary>
    /// Where a vouched-for offset report is handed on, when the tree gave this
    /// scroller a channel to report into - the renderer points it at
    /// <see cref="Channels.Moved"/>. Nothing when no channel is set.
    /// </summary>
    internal Action<int, double>? Channelled;

    /// <summary>
    /// Hands one offset report to the channel it reports into, if any.
    /// </summary>
    /// <remarks>
    /// HERE rather than in a subscription of its own, because this watcher is
    /// the one place that knows a report from a relayout's clamp: a channel
    /// fed raw reports drew the run at the start of every resize, and nothing
    /// could put those properties right - the tree does not know the host
    /// wrote them. See <see cref="Channels"/>.
    /// </remarks>
    /// <param name="property">Which offset the report is about.</param>
    private void Told(string property)
    {
        if (Channelled is not { } tell)
        {
            return;
        }

        if (property == ScrollView.ScrollXProperty.PropertyName
            && _scroll.GetValue(StateUIRenderer.ScrollXChannelProperty) is int across
            && across != 0)
        {
            tell(across, _scroll.ScrollX);
        }
        else if (property == ScrollView.ScrollYProperty.PropertyName
            && _scroll.GetValue(StateUIRenderer.ScrollYChannelProperty) is int down
            && down != 0)
        {
            tell(down, _scroll.ScrollY);
        }
    }

    /// <summary>The hooks for one scroller, not yet attached to anything.</summary>
    /// <param name="scroll">The scroller.</param>
    /// <param name="engine">What makes the frames of a movement of this side's own.</param>
    internal ScrollSnap(ScrollView scroll, MotionEngine engine)
    {
        _scroll = scroll;
        _engine = engine;
        _sliding = new Sliding(this);
    }

    /// <summary>What makes the frames of every movement this side asks for.</summary>
    private readonly MotionEngine _engine;

    /// <summary>The offset, as something the engine can move.</summary>
    private readonly Sliding _sliding;

    /// <summary>The one key a scroller's own offset is filed under.</summary>
    private static readonly object Slide = new();

    /// <summary>
    /// The scroller's offset, as a value the engine moves like any other.
    /// </summary>
    /// <remarks>
    /// Written through <see cref="Put"/> and held inside what the scroller can
    /// REACH, every frame, for the same reason the landing is: a run reported
    /// short one beat and whole the next must not be sent where it cannot go.
    /// </remarks>
    private sealed class Sliding : IMotionTarget
    {
        private readonly ScrollSnap _snap;

        internal Sliding(ScrollSnap snap) => _snap = snap;

        public object Owner => _snap._scroll;

        public object Key => Slide;

        public int Lanes => 2;

        public bool Read(double[] into)
        {
            Point at = _snap.Offset;

            into[0] = at.X;
            into[1] = at.Y;

            return true;
        }

        public void Write(double[] from) => _snap.Put((Point)Compose(from));

        public object Compose(double[] from) => _snap.Reachable(new Point(from[0], from[1]));
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

    /// <summary>The scroller's shape as it was last looked at.</summary>
    private (double Width, double Height, double Across, double Down) _geometry;

    /// <summary>
    /// Whether the scroller has been reshaped since this was last asked -
    /// a new viewport, a new content length, or both.
    /// </summary>
    private bool Reshaped()
    {
        var now = (
            _scroll.Width, _scroll.Height,
            _scroll.ContentSize.Width, _scroll.ContentSize.Height);

        if (now == _geometry)
        {
            return false;
        }

        _geometry = now;

        return true;
    }

    /// <summary>
    /// Gives back the place a relayout clamped away, once the layout it
    /// belongs to is over - at the end of the turn, which is where a
    /// platform's own passes have finished writing.
    /// </summary>
    /// <remarks>
    /// Answered by the LAST relayout alone: a squeeze fires several, each
    /// against a half-settled range, and only the last of them is asked
    /// against the range the scroller ends up with. A finger down, a movement
    /// of this side's own, or a scroller that has never been anywhere, and
    /// there is nothing to give back.
    /// </remarks>
    private void Restore(int asks = 0)
    {
        if (_kept is not Point kept || _down || _gliding || _settling)
        {
            return;
        }

        int ticket = ++_storms;

        _scroll.Dispatcher.Dispatch(() =>
        {
            if (ticket != _storms || _down || _gliding || _settling)
            {
                return;
            }

            _storms = 0;

            // AS FAR AS THE RANGE SO FAR ALLOWS, and the place itself is
            // KEPT rather than replaced by what landed: a content still
            // catching up clamps this put as it clamped the platform's, and
            // believing the short landing is how a card is lost for good.
            Point back = Reachable(kept);

            if (Math.Abs(back.X - _scroll.ScrollX) > 0.5
                || Math.Abs(back.Y - _scroll.ScrollY) > 0.5)
            {
                Put(back);
            }

            // Whatever is still short is waiting on a layout that has not
            // happened yet, and one that comes announces itself; a few turns
            // of asking cover the passes that announce nothing.
            if (asks < Asks && back != kept)
            {
                Restore(asks + 1);
            }
        });
    }

    /// <summary>
    /// How many turns a put-back may be re-asked for while the content is
    /// still catching up with the viewport.
    /// </summary>
    private const int Asks = 6;

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
    /// <para>
    /// The shortening is a fraction of the platform's OWN prediction rather
    /// than a distance of this side's own, so a hard throw still goes further
    /// than a gentle one and every platform keeps its own physics where its own
    /// physics is what runs.
    /// </para>
    /// <para>
    /// A THROW ALREADY HEADED FOR AN EDGE IS NOT SHORTENED. No platform
    /// predicts a stop beyond the start or the end of its content, so its
    /// answer for any throw that hard is the EDGE ITSELF - and a fraction of
    /// the way to an edge is not a shorter throw, it is a different
    /// destination. Measured on a run of cards: a quick flick back to the
    /// first card was answered with 0, halved to the middle of the run, and
    /// settled several cards in - which reads as the run bouncing off the
    /// start and jumping forward.
    /// </para>
    /// </remarks>
    /// <param name="predicted">Where the platform says the movement would end.</param>
    private Release Aimed(Point predicted)
    {
        Point here = Offset;
        double momentum = Math.Max(0, Momentum);

        // The far end of each axis - nought is the near one. An unmeasured
        // content has no end to hold against, which `Reachable` answers by
        // holding only the start; the same is said here as `most` of nought.
        double acrossMost = Math.Max(0, _scroll.ContentSize.Width - _scroll.Width);
        double downMost = Math.Max(0, _scroll.ContentSize.Height - _scroll.Height);

        double Shortened(double from, double to, double most) =>
            to <= 0 || (most > 0 && to >= most)
                ? to
                : from + ((to - from) * momentum);

        var shortened = new Point(
            Shortened(here.X, predicted.X, acrossMost),
            Shortened(here.Y, predicted.Y, downMost));

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

        // A CHANGE OF GEOMETRY MUST NOT MOVE THE READER'S PLACE. Every
        // platform re-clamps a scroller's offset into the range it has AT
        // THAT MOMENT, and a relayout is not one moment but several: the
        // viewport is resized in one pass and the content catches up in a
        // later one, so an offset perfectly reachable before and after is
        // clamped away in between - measured as a run of cards walking three
        // back on a turned phone and one back per window resize. So where the
        // scroller has been is kept, and put back once the layout is done
        // with; `Reachable` is what makes a content that really did shrink
        // land correctly rather than fight.
        _scroll.SizeChanged += (_, _) =>
        {
            Reshaped();
            Restore();
        };

        _scroll.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == ScrollView.ContentSizeProperty.PropertyName)
            {
                Reshaped();
                Restore();
                return;
            }

            if (e.PropertyName != ScrollView.ScrollXProperty.PropertyName
                && e.PropertyName != ScrollView.ScrollYProperty.PropertyName)
            {
                return;
            }

            // WHAT THIS REPORT IS depends on whether the scroller is still
            // the shape it was: a report arriving with a new viewport or a new
            // content length is the relayout's own clamp, whatever order the
            // platform announces the two in - which is the whole difficulty,
            // one platform saying the offset moved before it says anything
            // about the size. So the geometry is read from the report itself
            // rather than waited for.
            if (Reshaped())
            {
                Restore();
            }
            else
            {
                if (_down)
                {
                    _kept = Offset;
                }

                // A REPORT THE GEOMETRY VOUCHES FOR is one a channel may hear:
                // the relayout's own clamps take the branch above and reach no
                // channel, and the offset the restore puts back arrives here
                // with the geometry already settled. See Channels.
                Told(e.PropertyName);
            }

            _moved = true;

#if !IOS && !MACCATALYST && !WINDOWS
            // Every report puts the rest off again, so the quiet after the last
            // one is where a movement nobody announced comes to an end - which
            // on Android is every plain scroller's, and on a platform this file
            // has no hooks for is every movement there is.
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

        // ONE MOVEMENT, ONE LAW, ON EVERY PLATFORM: the engine's channel,
        // stepped by the display's own clock. What differs between platforms is
        // only where a release is caught and how its inertia is killed - never
        // how this side's own movement is drawn.
        _engine.Aim(
            _sliding,
            [landing.X, landing.Y],
            MotionSpec.Eased(ScrollGlide.Length(distance, Interval), (int)Protocol.SwiftEasing.CubicOut),
            done: whole =>
            {
                _gliding = false;

                if (!whole)
                {
                    return;
                }

                Put(landing);
                Arrive();
                Rest();
            });
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

        bool was = _gliding;

        if (_gliding)
        {
            _gliding = false;

            // NOTHING is written: the offset stays exactly where the movement
            // had reached, which is what stopping where it stands means.
            _engine.Halt(_scroll, Slide, MotionEnd.Nothing);
        }

        // ONLY A MOVEMENT THAT WAS UNDER WAY has a waiter to answer. Answering
        // unconditionally answered the arrival an act had JUST installed -
        // every Glide begins with this Stop - so an awaited scroll finished at
        // its launch, the host replied at once, and the tree un-marked a
        // flight still in the air, which is what let mid-glide reports through.
        if (!arrived && was)
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
        _falls = 0;
        _rises = 0;
        _tailing = false;
#endif

        // An asked-for movement is where the reader's place now is.
        _kept = Reachable(new Point(x, y));
        _arrival = arrival;
        Glide(_kept.Value);

        return arrival.Task;
    }

    /// <summary>
    /// Moves the scroller to a point AT ONCE, and answers when the request has
    /// been made - what a non-animated scroll act is.
    /// </summary>
    /// <remarks>
    /// THROUGH HERE AND NOT STRAIGHT TO MAUI, because a jump has to end
    /// whatever movement is under way first: a wheel's glide left running
    /// carried on after the jump and took the scroller back to where the
    /// gesture had been going, and the burst's geometry - grip, sweep, aim -
    /// was about a place the scroller no longer is.
    /// </remarks>
    /// <param name="x">Where it is going across.</param>
    /// <param name="y">And down.</param>
    /// <returns>A task that finishes when the request has been made.</returns>
    internal Task JumpTo(double x, double y)
    {
        Stop(arrived: false);

#if WINDOWS
        _turned = null;
        _aim = null;
        _falls = 0;
        _rises = 0;
        _tailing = false;
#endif

        Point landing = Reachable(new Point(x, y));

        // An asked-for movement is where the reader's place now is.
        _kept = landing;

        return _scroll.ScrollToAsync(landing.X, landing.Y, false);
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

        // WHERE THE READER LEFT IT, which is what a change of geometry has to
        // give back: a rest is the one moment the offset is known to be
        // nobody's clamp and nothing's half-way - as long as no relayout is
        // still to be answered, a scroller coming to rest ON a clamp being
        // exactly what must not be learnt from.
        if (_storms == 0)
        {
            _kept = here;
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

    /// <summary>And which posted release is, so an older one drops.</summary>
    private int _releases;

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

#elif WINDOWS
    /// <summary>The ScrollViewer the hooks are on.</summary>
    private Microsoft.UI.Xaml.Controls.ScrollViewer? _viewer;

    /// <summary>Whether the movement under way is the platform's inertia.</summary>
    private bool _inertial;

    /// <summary>
    /// Whether the movement under way is the platform answering a wheel this
    /// side left it - which WinUI reports as inertia just the same, and which
    /// must not be read as a gesture.
    /// </summary>
    /// <remarks>
    /// Set by <see cref="PlatformWheel"/> alone, which is
    /// <see cref="ScrollTuning"/> saying it left a wheel message unhandled -
    /// the only way the platform ever scrolls this viewer from a wheel, the
    /// take-over answering every other message before the platform sees it.
    /// Cleared when a movement completes, and when a gesture takes hold.
    /// </remarks>
    private bool _wheeled;

    /// <summary>
    /// A wheel message was left for the platform to answer, so the inertia it
    /// starts is a wheel's and not a gesture's.
    /// </summary>
    internal void PlatformWheel() => _wheeled = true;

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

    /// <summary>How far the last message carried, unsigned, in device units.</summary>
    private double _lastSize;

    /// <summary>
    /// How far the rest of a tail carries, as a multiple of the message the
    /// hand-over is read at.
    /// </summary>
    /// <remarks>
    /// The tail decays geometrically - measured at about 0.94 per message off
    /// a swipe that fell from 74.7 device units to 28 over a quarter of a
    /// second - and the sum of what is left is size times r/(1-r), which that
    /// ratio makes fifteen. It is a prediction and can miss by a part of a
    /// point; what it buys is the whole throw as ONE movement, where reading
    /// the tail out point by point walked the content from card to card.
    /// </remarks>
    private const double Tail = 15;

    /// <summary>
    /// Whether a FOLLOWED gesture's tail has been handed to the settle: the
    /// fingers have been seen to leave, the throw's end has been predicted,
    /// and the movement is a glide of this side's own.
    /// </summary>
    /// <remarks>
    /// IT IS WHAT REMOVES THE STOP BEFORE THE SETTLE. Followed to its end, a
    /// tail dies off the grid, the quiet passes, and the correction then moves
    /// a content that had already stopped - a jump of up to half a point,
    /// after a standstill, which is the one movement a reader reads as the
    /// scroller correcting them. Handing the tail over at the decay instead
    /// makes the deceleration and the landing ONE movement, leaving from a
    /// content still in motion. Fingers landing again take it back - see the
    /// rises in <see cref="Followed"/>.
    /// </remarks>
    private bool _tailing;

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
                // ENDS THE MANIPULATION ITSELF, and the frames after that are
                // this side's. A ChangeView to where it already is answers true
                // and stops nothing - the inertia goes on writing frames under
                // the glide, wins by writing last, and the correction the
                // fight leaves behind is a settle after a standstill (measured:
                // a flick glided to 1531.5 while the platform carried on to
                // 1631). Cancelling is the content's to ask because the call
                // cancels the manipulations of ANCESTORS.
                Point here = Offset;
                bool killed = (viewer.Content as Microsoft.UI.Xaml.UIElement)
                    ?.CancelDirectManipulations() ?? false;

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
            bool aimed = _inertial || _wheeled || _gliding;

            _down = false;
            Trace($"up at={viewer.HorizontalOffset:F1},{viewer.VerticalOffset:F1} aimed={aimed}");

            // A DRAG RELEASED WITH NO SPEED HAS NO INERTIA, so nothing aimed
            // it: no inertial ViewChanging ever fired, and Rest alone would
            // settle it on the NEAREST point - a slow drag across three cards
            // landing three cards on where the tree said one. The one release
            // the platform never predicts a stop for is aimed here, from where
            // it stands, with the same rounding and the same snapsAtMost hold
            // as every other.
            if (!aimed && Aims && Interval is > 0 and var interval)
            {
                Point landing = Held(Snapped(Offset), interval);

                Glide(landing);
            }
        };

        viewer.ViewChanged += (_, e) =>
        {
            if (!e.IsIntermediate)
            {
                _inertial = false;
                _wheeled = false;

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
    /// it, off the grid included, and the fingers leaving hands the throw to
    /// one glide onto the grid - see <see cref="Followed"/>. <c>snapsAtMost</c>
    /// is not a reading of its own: the wall inside <see cref="Follow"/> holds
    /// the drag and <c>Held</c> inside <see cref="Aimed"/> holds the throw,
    /// both counted from where the fingers landed - so a deck stepped one card
    /// a swipe sticks to the finger exactly as it does on every other
    /// platform.
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
        double interval = Interval;

        if (interval <= 0)
        {
            // NOT THIS SIDE'S TO MOVE, but still its to TIME: the slide writes
            // an offset per message and every write completes a view change,
            // so without a burst the rest was reported per message, DURING the
            // scroll. The burst holds it to one report, at the quiet.
            _turned ??= new Point(0, 0);

            Await();

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
                // AN ASKED-FOR MOVEMENT OUTRANKS A DRIBBLE. While an act's
                // glide is under way - somebody is awaiting it - only a
                // message carrying like a push takes the content back; the
                // tail of the gesture before the press goes on arriving for a
                // quarter of a second, and letting it grip killed the very
                // movement the reader just asked for.
                if (_arrival is not null && size < Decisive)
                {
                    Await();

                    return true;
                }

                Stop(arrived: false);
            }

            _grip = !fraction && _gliding && _aim is { } aimed ? aimed : Offset;
            _turned = new Point(0, 0);
            _clicks = 0;
            _fractional = false;
            _lastSize = 0;
            _falls = 0;
            _rises = 0;
            _tailing = false;
        }

        _fractional |= fraction;

        if (!_fractional && gap >= Click)
        {
            _clicks++;

            // A CLICK IS A RELEASE OF ITS OWN, so it counts - and is held by
            // snapsAtMost - from the point the click before it sent for, not
            // from where the burst began: three deliberate clicks are three
            // points even where one release may only cross one. A coalesced
            // spin stays one release, which is what the gap tells apart.
            if (_clicks > 1 && _aim is { } sent)
            {
                _grip = sent;
                _turned = new Point(0, 0);
            }
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
            + $"rises={_rises} tailing={_tailing} whole={clicked}");

        if (!_fractional)
        {
            Aim(turned, across, interval, fresh);
            return true;
        }

        // A TOUCHPAD FOLLOWS THE FINGERS while they are down, and hands the
        // tail to the settle the moment they are seen to leave. snapsAtMost
        // needs no reading of its own: the wall holds the drag and Held holds
        // the throw, both counted from where the fingers landed.
        Followed(across, turned, step, size, before, interval);

        return true;
    }

    /// <summary>
    /// A FOLLOWED gesture: the content under the fingers while they are down,
    /// and from the moment they leave, one glide to where the throw was going.
    /// </summary>
    /// <remarks>
    /// THE LEAVE IS READ THE WAY A SWIPE READS IT - <see cref="Falls"/>
    /// messages down in a row - and taken back the same way too: a rise of
    /// <see cref="Rises"/> messages ending past <see cref="Decisive"/> is the
    /// fingers again, so the glide stops where it is and the follow resumes
    /// from there. The destination is decided ONCE, at the hand-over: the rest
    /// of the tail's carry (<see cref="Tail"/>) makes this side's own
    /// predicted stop, and that prediction goes through the same
    /// <see cref="Aimed"/> every platform's goes through - momentum shortens
    /// it, the grid rounds it, <c>snapsAtMost</c> holds it - so a desk's throw
    /// obeys the same words a touchscreen's does. Chasing the tail point by
    /// point instead re-aimed a new glide at every card on the way, and each
    /// one decelerated - a hard throw read as stopping at every card it
    /// crossed.
    /// </remarks>
    /// <param name="across">Which axis the gesture moves along.</param>
    /// <param name="turned">How far the burst has swept, signed, both axes.</param>
    /// <param name="step">How far this message carried, signed.</param>
    /// <param name="size">How far it carried, unsigned.</param>
    /// <param name="before">How far the message before it carried, unsigned.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    private void Followed(
        bool across,
        Point turned,
        double step,
        double size,
        double before,
        double interval)
    {
        if (_tailing)
        {
            _rises = size > before ? _rises + 1 : 0;

            // THE FINGERS ARE BACK: the glide gives way where it stands, and
            // the follow resumes from whatever it had reached - the same rule
            // a settle already obeys when a fresh gesture lands.
            if (_rises >= Rises && size >= Decisive)
            {
                Stop(arrived: false);

                _tailing = false;
                _falls = 0;
                _rises = 0;
                _grip = Offset;

                Point resumed = across ? new Point(step, 0) : new Point(0, step);

                _turned = resumed;

                Trace($"fingers back at {size:F1}, following again");

                Follow(resumed, interval);
            }

            // The rest of the tail is spent: its carry is already inside the
            // prediction, and reading it out again would move the landing.
            return;
        }

        _falls = size < before ? _falls + 1 : 0;

        if (_falls >= Falls)
        {
            _tailing = true;
            _rises = 0;

            // THIS SIDE'S OWN PREDICTED STOP: where the fingers left it plus
            // what the rest of the tail carries.
            Point here = Offset;
            double carry = Math.Sign(step) * size * Tail;

            Release release = Aimed(across
                ? new Point(here.X + carry, here.Y)
                : new Point(here.X, here.Y + carry));

            Trace($"thrown to={release.Landing.X:F1},{release.Landing.Y:F1} "
                + $"carry={carry:F1} at={size:F1}");

            Glide(release.Landing);

            return;
        }

        Follow(turned, interval);
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
    /// has. The grid is met by the settle that takes over at the decay - see
    /// <see cref="Followed"/> - never under the fingers.
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
        _tailing = false;

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
