// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

/// <summary>
/// One scroller's movement as the host knows it: whether the reader's hand is
/// on it, the offset as a target the state's channel moves and the place it
/// was left at, and the moment a movement of the reader's comes to rest.
/// </summary>
/// <remarks>
/// <para>
/// THE SCROLLING IS THE PLATFORM'S. A drag, a throw, a wheel and a key move the
/// scroller under the platform's own physics, and nothing here aims, shortens
/// or corrects them. What this adds is what the platform does not say in one
/// shape everywhere: when a movement of the reader's is over, which offset
/// reports are the reader's, and where the scroller was left.
/// </para>
/// <para>
/// REST, <see cref="Rested"/>, is said once per movement of the reader's, and
/// only when the offset moved. Each platform has its own moment for it: UIKit
/// ends a drag, a deceleration and an animated scroll; WinUI ends a view
/// change, a run of the wheel held together as one movement; Android, and a
/// platform with no hooks here, is read at rest once the reports have gone
/// quiet for <see cref="RestAfterMs"/>. Nothing rests while the reader's hand
/// is on the scroller.
/// </para>
/// <para>
/// THE OFFSET IS ALSO A TARGET, <see cref="Walked"/>: the platform declares it
/// read-only, so a state tied to it moves the scroller through here. The
/// reports the geometry vouches for go back to that state through
/// <see cref="Slid"/>, and a relayout's clamps do not.
/// </para>
/// <para>
/// A TRAVEL THE APPLICATION WROTE IS NOT THE READER'S. While the state's
/// channel moves the scroller, and for a quiet after its last frame, what the
/// scroller reports is that travel: it reaches no state, counts as no
/// movement and ends in no rest - the application knows where it sent the
/// scroller. The reader taking hold stops the travel where it stands.
/// </para>
/// <para>
/// THE PLACE SURVIVES A RELAYOUT. Where the scroller was left - by the reader,
/// or by the state's channel - is put back once a change of geometry has
/// clamped it away.
/// </para>
/// </remarks>
internal sealed class ScrollMovement
{
    /// <summary>The scroller whose movement this is.</summary>
    private readonly ScrollView _scroll;

    /// <summary>
    /// Whether the reader's hand is on it, so nothing rests and nothing is put
    /// back under one.
    /// </summary>
    /// <remarks>
    /// Written only by a platform's own hooks and by <see cref="Fingers"/>, so
    /// the build with no platform at all - which is the one the tests run
    /// against - reads the false it is given here until something calls that.
    /// Every one of them that puts the hand down also takes hold of the
    /// scroller (<see cref="Grip"/>), so no travel is ever under way beneath
    /// a hand.
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
    /// Where the scroller was left, in device units - the place a change of
    /// geometry has to give back: where the reader held it or let it come to
    /// rest, or where the state's channel last put it. Nothing until the
    /// scroller has been somewhere: a run that has never moved has nothing to
    /// lose.
    /// </summary>
    private Point? _kept;

    /// <summary>
    /// How many relayouts are still to be answered. Above zero the offset the
    /// platform reports is the clamp's, not the reader's, so nothing is
    /// learnt from it; the last one to be answered is the one that puts the
    /// place back, every earlier one having been overtaken by a newer layout.
    /// </summary>
    private int _storms;

    /// <summary>Which wait for the quiet after a report is the current one.</summary>
    private int _restQuiet;

    /// <summary>
    /// Whether a travel the application wrote is under way - from its first
    /// frame until <see cref="RestAfterMs"/> after its last.
    /// </summary>
    /// <remarks>
    /// THE QUIET IS PART OF THE TRAVEL because a platform may answer a written
    /// offset late: WinUI answers <c>ChangeView</c> at its next frame, so the
    /// report of a travel's last frame arrives after the write that made it,
    /// and without the quiet it would be heard as the reader's.
    /// </remarks>
    private bool _travelling;

    /// <summary>Which wait for the end of a travel is the current one.</summary>
    private int _travelQuiet;

    /// <summary>
    /// How long the offset must stay unchanged before it counts as at rest, in
    /// milliseconds. A platform that says nothing when a fling or a smooth
    /// scroll ends has its rest read off the scroll reports stopping - two
    /// frames and a little. A travel is over that long after its last frame.
    /// </summary>
    private const int RestAfterMs = 50;

    /// <summary>
    /// Puts the rest off by <see cref="RestAfterMs"/>: the offset is at rest
    /// when that long has passed with no report and no finger.
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

        int ticket = ++_restQuiet;

        _scroll.Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(RestAfterMs), () =>
        {
            if (ticket == _restQuiet)
            {
                Rest();
            }
        });
    }

    /// <summary>
    /// Says whether the reader's hand is on this scroller, for a platform
    /// whose own hooks cannot say it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// REST IS INFERRED FROM QUIET where a platform announces no end - fifty
    /// milliseconds with no report and no finger. That reading is only ever
    /// as good as the finger half of it: a trackpad's smooth scrolling
    /// arrives in BURSTS with real gaps between them, so a scroller with
    /// nothing to say about the fingers reads every gap as the gesture being
    /// over and reports a rest WHILE THE READER IS STILL MOVING it - and a
    /// composition that settles on its rest then writes the offset out from
    /// under the hand.
    /// </para>
    /// <para>
    /// A hand coming down takes hold of the scroller, which stops a written
    /// travel where it stands - see <see cref="Grip"/>.
    /// </para>
    /// <para>
    /// The four platforms with hooks of their own never call this - they
    /// write the same flag from a real gesture - so it is inert everywhere
    /// but where a platform package answers it.
    /// </para>
    /// </remarks>
    /// <param name="down">Whether the reader is on the scroller.</param>
    internal void Fingers(bool down)
    {
        if (_down == down)
        {
            return;
        }

        _down = down;

        if (down)
        {
            Grip();
            return;
        }

        // A GESTURE THAT ENDED IS A REST NOBODY ARMED: the reports stop with
        // the fingers, and the quiet that follows is the one this side would
        // otherwise have counted from.
        ArmRest();
    }

    /// <summary>
    /// A movement of the reader's has come to rest: nothing is moving, no
    /// finger is on it, and it is where it is going to stay.
    /// </summary>
    internal event Action? Rested;

    /// <summary>
    /// Where a vouched-for offset report is handed on, when the tree gave this
    /// scroller a state to report into - the renderer points it at
    /// <see cref="StateCycle.Slid"/>. Nothing when no number is set.
    /// </summary>
    internal Action<double[]>? Slid;

    /// <summary>
    /// Hands one offset report to the channel it reports into, if any.
    /// </summary>
    /// <remarks>
    /// HERE rather than in a subscription of its own, because this watcher is
    /// the one place that knows a report from a relayout's clamp: a state fed
    /// raw reports drew the run at the start of every resize, and nothing
    /// could put those properties right - the tree does not know the host
    /// wrote them. See <see cref="StateCycle"/>.
    /// </remarks>
    /// <param name="property">Which offset the report is about.</param>
    private void Told(string property)
    {
        if (Slid is not { } tell)
        {
            return;
        }

        // THE WHOLE POINT, whichever axis moved: the offset is one value and a
        // report of half of it would lay half an image.
        if (property == ScrollView.ScrollXProperty.PropertyName
            || property == ScrollView.ScrollYProperty.PropertyName)
        {
            tell([_scroll.ScrollX, _scroll.ScrollY]);
        }
    }

    /// <summary>The hooks for one scroller, not yet attached to anything.</summary>
    /// <param name="scroll">The scroller.</param>
    internal ScrollMovement(ScrollView scroll)
    {
        _scroll = scroll;
        _sliding = new Sliding(this);
    }

    /// <summary>The offset, as something the walker can move.</summary>
    private readonly Sliding _sliding;

    /// <summary>The key the scroller's offset is known by as a target.</summary>
    internal static readonly object Slide = new();

    /// <summary>The offset, as the walker walks it - two lanes, one point.</summary>
    /// <remarks>
    /// What a state tied to <c>scrollOffset($:)</c> aims at: the platform
    /// declares the offset read-only, so a written state moves the scroller
    /// through this rather than through a setter that does not exist.
    /// </remarks>
    internal ITripTarget Walked => _sliding;

    /// <summary>
    /// The scroller's offset, as a value the walker moves like any other.
    /// </summary>
    /// <remarks>
    /// Held inside what the scroller can REACH, every frame: a run reported
    /// short one beat and whole the next must not be sent where it cannot go.
    /// </remarks>
    private sealed class Sliding : ITripTarget
    {
        private readonly ScrollMovement _movement;

        internal Sliding(ScrollMovement movement) => _movement = movement;

        public object Owner => _movement._scroll;

        public object Key => Slide;

        public int Lanes => 2;

        public bool Read(double[] into)
        {
            Point at = _movement.Offset;

            into[0] = at.X;
            into[1] = at.Y;

            return true;
        }

        public void Write(double[] from) => _movement.Written((Point)Compose(from));

        public object Compose(double[] from) => _movement.Reachable(new Point(from[0], from[1]));
    }

    /// <summary>
    /// The state's channel puts the offset somewhere - a frame of a travel the
    /// application wrote, a value snapped into place, or where another
    /// scroller's reader moved the same state.
    /// </summary>
    /// <remarks>
    /// <para>
    /// WHERE IT IS PUT IS WHERE THE SCROLLER WAS LEFT, so a relayout after it
    /// gives this place back - never the one the reader had before the offset
    /// was written.
    /// </para>
    /// <para>
    /// AND IT IS NOT THE READER'S MOVEMENT. Away from a hand it is a travel -
    /// see <see cref="Travelled"/>. Under a hand it is only put, and the
    /// hand's own reports go on being the reader's.
    /// </para>
    /// </remarks>
    /// <param name="point">Where the offset goes, already held to what the scroller can reach.</param>
    private void Written(Point point)
    {
        _kept = point;

        if (!_down)
        {
            Travelled();
        }

        Put(point);
    }

    /// <summary>
    /// One frame of a travel: what the scroller reports until the frames have
    /// stopped for <see cref="RestAfterMs"/> is the travel's.
    /// </summary>
    /// <remarks>
    /// A TRAVEL'S REPORTS ARE NOBODY'S NEWS. They reach no state - the state
    /// is what sent the scroller there - count as no movement, and end in no
    /// rest: the application knows where it sent the scroller, and awaiting
    /// the journey is how it hears the arrival. So the quiet ends the travel
    /// and says nothing.
    /// </remarks>
    private void Travelled()
    {
        if (!_travelling)
        {
            Trace($"travel from={_scroll.ScrollX:F1},{_scroll.ScrollY:F1}");
        }

        _travelling = true;

        int ticket = ++_travelQuiet;

        _scroll.Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(RestAfterMs), () =>
        {
            if (ticket != _travelQuiet)
            {
                return;
            }

            _travelling = false;

            Trace($"travel over at={_scroll.ScrollX:F1},{_scroll.ScrollY:F1}");
        });
    }

    /// <summary>
    /// The reader takes hold of the scroller - a finger, a drag, a turn of the
    /// wheel: a written travel under way stops where it stands.
    /// </summary>
    /// <remarks>
    /// WHERE IT STANDS GOES THE READER'S WAY, as a report: the value and where
    /// it is going land on the state together, which is what lets the state's
    /// channel go - so no frame of the travel is written under the hand, and
    /// the reader's next report is heard. Nothing is written back: the
    /// scroller is already where the travel had reached.
    /// </remarks>
    private void Grip()
    {
        if (!_travelling)
        {
            return;
        }

        _travelling = false;
        _travelQuiet++;

        Trace($"travel taken at={_scroll.ScrollX:F1},{_scroll.ScrollY:F1}");
        Slid?.Invoke([_scroll.ScrollX, _scroll.ScrollY]);
    }

#if IOS || MACCATALYST || ANDROID || WINDOWS
    /// <summary>Takes every hook back off the platform views they were put on.</summary>
    /// <remarks>
    /// NOTHING PUT ON A PLATFORM VIEW MAY OUTLIVE THE PAGE. A gesture
    /// recognizer holds the managed target its selector names, and an event
    /// handler holds whatever its closure captured - both of them this object,
    /// which holds the scroller. The platform keeps its own view for as long
    /// as it pleases, so a hook nobody takes off is a hand on the whole
    /// subtree: measured on the gallery's ScrollView sample on Mac Catalyst as
    /// one live tracked ScrollView per scroller per visit, climbing for ever
    /// (428, 441, 452, 464, 476 over five open-and-leave cycles; flat at 390
    /// once the hooks come off).
    /// </remarks>
    private Action? _unhook;
#endif

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
    /// against the range the scroller ends up with. A finger down, or a
    /// scroller that has never been anywhere, and there is nothing to give
    /// back. A travel under way is given back the frame it had reached, that
    /// being where it left the scroller.
    /// </remarks>
    private void Restore(int asks = 0)
    {
        if (_kept is not Point kept || _down)
        {
            return;
        }

        int ticket = ++_storms;

        _scroll.Dispatcher.Dispatch(() =>
        {
            if (ticket != _storms || _down)
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
                Trace($"restore to={back.X:F1},{back.Y:F1} from={_scroll.ScrollX:F1},{_scroll.ScrollY:F1}");
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

    /// <summary>
    /// An offset the scroller can actually be at, both axes - see
    /// <see cref="StateUIRenderer.Reachable"/> for why nothing may be put
    /// anywhere else.
    /// </summary>
    private Point Reachable(Point offset) => new(
        StateUIRenderer.Reachable(offset.X, _scroll.ContentSize.Width, _scroll.Width),
        StateUIRenderer.Reachable(offset.Y, _scroll.ContentSize.Height, _scroll.Height));

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
            else if (_travelling)
            {
                // THE TRAVEL'S OWN REPORT is nobody's news: the state sent the
                // scroller here, and nothing the reader did moved it.
                return;
            }
            else
            {
                if (_down)
                {
                    _kept = Offset;
                }

                // A REPORT THE GEOMETRY VOUCHES FOR is one a state may hear:
                // the relayout's own clamps take the branch above and reach no
                // number, and the offset the restore puts back arrives here with
                // the geometry already settled. See StateCycle.
                Told(e.PropertyName);
            }

            _moved = true;

#if !IOS && !MACCATALYST && !WINDOWS
            // Every report puts the rest off again, so the quiet after the last
            // one is where a movement nobody announced comes to an end - which
            // on Android is a fling's, and on a platform this file has no hooks
            // for is every movement there is.
            ArmRest();
#endif
        };
    }

    /// <summary>Puts the offset there, at once.</summary>
    /// <remarks>
    /// The platform view directly where there is one. MAUI's own request
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
    /// A movement of the reader's has stopped: where nothing is left to move,
    /// says so - once. Nothing happens under a finger, while a run of the
    /// wheel is still turning, or while a written travel is under way.
    /// </summary>
    private void Rest()
    {
        if (_down || _travelling)
        {
            return;
        }

#if WINDOWS
        // A WHEEL STILL TURNING IS A FINGER STILL DOWN: nothing rests until
        // the run's quiet has run out - which is what runs this again, through
        // Ended.
        if (_wheeling)
        {
            return;
        }
#endif

        Point here = Offset;

        // PAST ITS OWN END the scroller is bouncing, and the platform is
        // already carrying it back. That is not where it stays: the end of the
        // bounce reports again, and the rest is that one.
        if (here != Reachable(here))
        {
            return;
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

        Trace($"rest at={here.X:F1},{here.Y:F1}");
        Rested?.Invoke();
    }

    /// <summary>Where the trace is written, once <c>STATEUI_SCROLL</c> asks for one.</summary>
    private static readonly string? TracePath =
        Environment.GetEnvironmentVariable("STATEUI_SCROLL") is not null
            ? Path.Combine(MotionTrace.Somewhere(), "stateui-scroll.log")
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
    /// UIScrollView says every moment itself, but for the finger coming DOWN:
    /// <c>DraggingStarted</c> fires once the finger has moved far enough to be
    /// a drag, and a tap that stops a movement never gets that far. A press
    /// recognizer with no minimum duration fires the instant the finger lands,
    /// recognizes beside the scroller's own pan, and cancels nothing.
    /// </summary>
    private void HookApple()
    {
        UIKit.UIScrollView? native = _scroll.Handler?.PlatformView as UIKit.UIScrollView;

        if (ReferenceEquals(_native, native))
        {
            return;
        }

        // The handler changed, which is a disconnect and then possibly a
        // connect. Whatever was put on the old view comes off first.
        _unhook?.Invoke();
        _unhook = null;
        _native = null;

        if (native is null)
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

        // A GESTURE THAT TOUCHES NOTHING - a trackpad, a wheel - lands no
        // finger for the press to hear, so the drag beginning is where the
        // reader takes hold of the scroller.
        void DraggingStarted(object? sender, EventArgs e) => Grip();

        native.DraggingStarted += DraggingStarted;

        // Every way a movement can end, which is where the guarantee is kept:
        // a drag let go of, a deceleration that ran out, and an animated
        // scroll.
        void DraggingEnded(object? sender, UIKit.DraggingEventArgs e)
        {
            _down = false;

            if (!e.Decelerate)
            {
                Rest();
            }
        }

        void Ended(object? sender, EventArgs e) => Rest();

        native.DraggingEnded += DraggingEnded;
        native.DecelerationEnded += Ended;
        native.ScrollAnimationEnded += Ended;

        _unhook = () =>
        {
            native.RemoveGestureRecognizer(press);
            native.DraggingStarted -= DraggingStarted;
            native.DraggingEnded -= DraggingEnded;
            native.DecelerationEnded -= Ended;
            native.ScrollAnimationEnded -= Ended;
        };
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
                Grip();
                break;

            case UIKit.UIGestureRecognizerState.Ended:
            case UIKit.UIGestureRecognizerState.Cancelled:
            case UIKit.UIGestureRecognizerState.Failed:
                if (!_down)
                {
                    break;
                }

                _down = false;

                // A drag hands its own end to DraggingEnded. A touch that never
                // became one ends here, and a movement it stopped has come to
                // rest where it stands.
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
        Android.Views.ViewGroup? outer = _scroll.Handler?.PlatformView as Android.Views.ViewGroup;

        if (ReferenceEquals(_outer, outer))
        {
            return;
        }

        // The handler changed, which is a disconnect and then possibly a
        // connect. Whatever was put on the old views comes off first - see
        // <see cref="_unhook"/> for why nothing may be left on one.
        _unhook?.Invoke();
        _unhook = null;
        _hooked.Clear();
        _outer = null;

        if (outer is null)
        {
            return;
        }

        _outer = outer;

        Listen(outer);
        _surface = outer;

        if (outer.ChildCount > 0 && outer.GetChildAt(0) is Android.Widget.HorizontalScrollView across)
        {
            Listen(across);
            _surface = across;
        }
    }

    /// <summary>The ViewGroup the listeners are on.</summary>
    private Android.Views.ViewGroup? _outer;

    /// <summary>One touch listener on one view, once.</summary>
    private void Listen(Android.Views.View view)
    {
        if (!_hooked.Add(view))
        {
            return;
        }

        // Never consumed: the platform's own handling is what scrolls, flings
        // and - on a touch landing mid-movement - aborts its scroller.
        void Touched(object? sender, Android.Views.View.TouchEventArgs e)
        {
            e.Handled = false;

            if (e.Event is not Android.Views.MotionEvent motion)
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
                        Grip();
                    }

                    break;

                case Android.Views.MotionEventActions.Up:
                case Android.Views.MotionEventActions.Cancel:
                    if (!_down)
                    {
                        break;
                    }

                    // A fling the platform starts from here reports as it
                    // goes, and the quiet after its last report is the rest.
                    _down = false;
                    ArmRest();
                    break;
            }
        }

        view.Touch += Touched;

        Action? was = _unhook;

        _unhook = () =>
        {
            was?.Invoke();
            view.Touch -= Touched;
        };
    }
#elif WINDOWS
    /// <summary>The ScrollViewer the hooks are on.</summary>
    private Microsoft.UI.Xaml.Controls.ScrollViewer? _viewer;

    /// <summary>
    /// How long after the last wheel message a run of the wheel counts as
    /// over, in ms.
    /// </summary>
    /// <remarks>
    /// Long enough that neither a touchpad's stream nor the decaying tail it
    /// ends with is ever cut in two: a tail cut in two is a second rest in the
    /// middle of one gesture.
    /// </remarks>
    private const double Quiet = 150;

    /// <summary>
    /// Which wait for the wheel's quiet is the current one, so a message that
    /// arrives first makes the wait it interrupted stale.
    /// </summary>
    private int _wheelQuiet;

    /// <summary>
    /// Whether a run of the wheel is under way - which holds the rest off
    /// until the run's quiet.
    /// </summary>
    private bool _wheeling;

    /// <summary>
    /// WinUI's ScrollViewer says when a manipulation of touch or the pen
    /// starts and ends, and when the view has stopped changing - which is
    /// where a movement rests: a drag let go of with no speed, a throw's
    /// inertia and a key alike. The wheel makes no manipulation and changes
    /// the view once per message, so a run of it is held together by
    /// <see cref="Wheeled"/>.
    /// </summary>
    private void HookWindows()
    {
        Microsoft.UI.Xaml.Controls.ScrollViewer? viewer =
            _scroll.Handler?.PlatformView as Microsoft.UI.Xaml.Controls.ScrollViewer;

        if (ReferenceEquals(_viewer, viewer))
        {
            return;
        }

        // THE HANDLER CHANGED, which is a disconnect and then possibly a
        // connect. Whatever was put on the old viewer comes off FIRST, and
        // this runs ahead of every guard about the new one: a disconnect
        // arrives with a NULL platform view, so a guard that returns on one
        // leaves three handlers on a scroller nobody will look at again - and
        // each of them holds this object, which holds the scroller.
        _unhook?.Invoke();
        _unhook = null;
        _viewer = null;

        if (viewer is null)
        {
            return;
        }

        _viewer = viewer;

        EventHandler<object> started = (_, _) =>
        {
            _wheeling = false;
            _down = true;
            Grip();
            Trace($"down at={viewer.HorizontalOffset:F1},{viewer.VerticalOffset:F1}");
        };

        EventHandler<object> completed = (_, _) =>
        {
            _down = false;
            Trace($"up at={viewer.HorizontalOffset:F1},{viewer.VerticalOffset:F1}");
        };

        EventHandler<Microsoft.UI.Xaml.Controls.ScrollViewerViewChangedEventArgs> changed = (_, e) =>
        {
            if (!e.IsIntermediate)
            {
                Rest();
            }
        };

        viewer.DirectManipulationStarted += started;
        viewer.DirectManipulationCompleted += completed;
        viewer.ViewChanged += changed;

        // What comes off, and the only reason the three are held by name.
        _unhook = () =>
        {
            viewer.DirectManipulationStarted -= started;
            viewer.DirectManipulationCompleted -= completed;
            viewer.ViewChanged -= changed;
        };
    }

    /// <summary>
    /// A wheel message over this scroller, from <see cref="ScrollWheel"/>: one
    /// run of the wheel is one movement, and it rests once, at the run's quiet.
    /// </summary>
    /// <remarks>
    /// The wheel writes an offset per message and every write completes a view
    /// change, so without the run the rest would be reported per message,
    /// DURING the scroll. A turn of the wheel is also the reader taking hold:
    /// a written travel under way stops where it stands.
    /// </remarks>
    internal void Wheeled()
    {
        _wheeling = true;
        Grip();
        Await();
    }

    /// <summary>
    /// The run of the wheel is over - its quiet ran out with no message
    /// interrupting - so the rest the gate in <see cref="Rest"/> held back is
    /// asked for now.
    /// </summary>
    private void Ended()
    {
        if (!_wheeling)
        {
            return;
        }

        _wheeling = false;

        Trace("wheel run over");
        Rest();
    }

    /// <summary>Waits another quiet before asking whether the run is over.</summary>
    private void Await()
    {
        int ticket = ++_wheelQuiet;

        _scroll.Dispatcher.DispatchDelayed(
            TimeSpan.FromMilliseconds(Quiet),
            () =>
            {
                if (ticket == _wheelQuiet)
                {
                    Ended();
                }
            });
    }
#endif
}
