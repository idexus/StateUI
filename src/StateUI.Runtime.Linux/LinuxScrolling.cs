// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Lets a scroller ask for the room its content needs, and tells it when a
/// reader's fingers are on it.
/// </summary>
/// <remarks>
/// <para>
/// The backend's <c>ScrollViewHandler.GetDesiredSize</c> answers AT MOST 50
/// UNITS of height for any scroller without an explicit
/// <c>HeightRequest</c>, whatever its content measures - so a code listing,
/// which is a scroller that runs ACROSS, shows one line and no more, and a
/// run of cards is a sliver. The cap sits in the MEASURE, which is why
/// telling the GTK side to propagate its natural height changes nothing: MAUI
/// has already decided the number before GTK is asked.
/// </para>
/// <para>
/// The answer is a handler registered over the backend's own whose measure
/// says what every other platform's does: the content's measured size, held
/// to the constraints, with an author's <c>WidthRequest</c> and
/// <c>HeightRequest</c> still winning. A scroller that runs across is then as
/// tall as what is in it, and one that runs down takes what the layout can
/// give.
/// </para>
/// <para>
/// The GTK half still gets <c>SetPropagateNaturalHeight</c> on the
/// orientation it scrolls, so the widget's own answer agrees with the
/// measure's when GTK asks it directly.
/// </para>
/// <para>
/// AND NOTHING HERE SAYS WHEN A GESTURE IS OVER. The four platforms with
/// hooks of their own announce a drag ending; this one announces nothing, so
/// a scroller that snaps reads REST from its reports going quiet - fifty
/// milliseconds of it. A trackpad's smooth scrolling arrives in BURSTS with
/// gaps longer than that, so every gap read as an ending and the offset was
/// put on its grid under the reader's own hand: measured as sixty-three
/// corrections in one drag, one per card crossed, each a glide of 235 ms
/// pulling against the finger, which is a run of cards that will not stop
/// twitching. GTK does say it - a smooth-scroll device opens and closes its
/// gesture - so the scroller is told, and the quiet is then counted from
/// where it means something.
/// </para>
/// </remarks>
[System.Runtime.Versioning.SupportedOSPlatform("linux")]
internal static class LinuxScrolling
{
    /// <summary>Arms every scroller in the application.</summary>
    /// <param name="builder">Whose handler registry takes the replacement.</param>
    internal static void Install(MauiAppBuilder builder)
    {
        builder.ConfigureMauiHandlers(handlers =>
            handlers.AddHandler<ScrollView, Measured>());

        // AFTER ALL THREE keys, because the way it scrolls and the bars it
        // shows are one decision and the backend makes them separately - see
        // Policy. Whichever of the three a change came through, this runs last
        // and states the whole answer.
        foreach (string key in (string[])["Orientation", "HorizontalScrollBarVisibility", "VerticalScrollBarVisibility"])
        {
            ScrollViewHandler.Mapper.AppendToMapping<IScrollView, ScrollViewHandler>(key, Policy);
        }
    }

    /// <summary>
    /// Says which way this scroller scrolls and which bars it shows, in one
    /// pass over both axes.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The backend writes the policy TWICE, from two mappers, and the second
    /// does not know what the first decided: the orientation's mapper sets the
    /// axis that scrolls, and the scroll-bar mappers then overwrite BOTH axes
    /// from the bar visibilities alone. The visibility mappers run last, so
    /// every scroller ends up scrolling both ways whatever its orientation
    /// says - which is what put a page's own scroller under a code listing's
    /// and moved the wrong one under the reader's finger.
    /// </para>
    /// <para>
    /// The axis a scroller does NOT run along is GTK's <c>Never</c>, which is
    /// what stops it scrolling there. Along the axis it DOES run, a hidden bar
    /// is <c>External</c> rather than <c>Never</c>: hiding the bar is all an
    /// author asked for, and the backend's <c>Never</c> takes the scrolling
    /// with it - the gallery's tab strip, which hides its bar, could not be
    /// moved at all.
    /// </para>
    /// </remarks>
    /// <param name="handler">The scroller's handler.</param>
    /// <param name="view">The scroller itself.</param>
    private static void Policy(ScrollViewHandler handler, IScrollView view)
    {
        if (handler.PlatformView is not Gtk.ScrolledWindow window)
        {
            return;
        }

        bool across = view.Orientation is ScrollOrientation.Horizontal or ScrollOrientation.Both;
        bool down = view.Orientation is ScrollOrientation.Vertical or ScrollOrientation.Both;

        window.SetPolicy(
            Bars(across, view.HorizontalScrollBarVisibility),
            Bars(down, view.VerticalScrollBarVisibility));

        // A scroller that runs across is as tall as what is in it; one that
        // runs down takes the room the layout gives it.
        window.SetPropagateNaturalHeight(!down);
    }

    /// <summary>What one axis is worth: whether it scrolls, and what it shows.</summary>
    /// <param name="scrolls">Whether the scroller runs along this axis.</param>
    /// <param name="bar">What the tree asked its bar to do.</param>
    private static Gtk.PolicyType Bars(bool scrolls, ScrollBarVisibility bar)
    {
        if (!scrolls)
        {
            return Gtk.PolicyType.Never;
        }

        return bar switch
        {
            ScrollBarVisibility.Always => Gtk.PolicyType.Always,
            ScrollBarVisibility.Never => Gtk.PolicyType.External,
            _ => Gtk.PolicyType.Automatic,
        };
    }

    /// <summary>The backend's scroller handler with the measure corrected.</summary>
    private sealed class Measured : ScrollViewHandler
    {
        /// <summary>Hears the reader's fingers open and close a gesture.</summary>
        /// <remarks>
        /// <para>
        /// In the CAPTURE phase and answering nothing: the scroller's own
        /// controllers are what scroll it, and a second one that took an event
        /// would take the scrolling with it. This one is here to be told
        /// <c>scroll-begin</c> and <c>scroll-end</c>, which GTK raises for a
        /// device that scrolls smoothly and for no other - a wheel has no
        /// gesture to open, and goes on being read from the quiet as before.
        /// </para>
        /// <para>
        /// The snap is looked up when the gesture happens rather than kept: it
        /// is made the first time the tree asks this scroller for a grid,
        /// which is after the handler is connected, and a scroller that never
        /// asks for one has nothing here to tell.
        /// </para>
        /// </remarks>
        /// <param name="platformView">The scroller this handler drives.</param>
        protected override void ConnectHandler(Gtk.ScrolledWindow platformView)
        {
            base.ConnectHandler(platformView);

            var fingers = Gtk.EventControllerScroll.New(
                Gtk.EventControllerScrollFlags.BothAxes);

            fingers.SetPropagationPhase(Gtk.PropagationPhase.Capture);

            // A GESTURE'S OWN ENDING WHERE THERE IS ONE. Wayland says when the
            // fingers leave; X11 does not - a trackpad reaches an X server as
            // XI2 valuators, which have no begin and no end - so this is taken
            // where it is offered and never relied on.
            fingers.OnScrollEnd += (_, _) =>
            {
                _quiet++;
                Told(false);
            };

            fingers.OnScroll += (_, e) =>
            {
                Rolled();

                return Stepped(e.Dx, e.Dy, fingers.GetUnit() == Gdk.ScrollUnit.Wheel);
            };

            platformView.AddController(fingers);
        }

        /// <summary>
        /// How long after the last scroll event the reader is still taken to
        /// be on the scroller, in milliseconds.
        /// </summary>
        /// <remarks>
        /// A PAUSE IS NOT AN ENDING. A trackpad reports only while the fingers
        /// MOVE, and a reader crossing a run of cards holds still between
        /// pushes - measured on this platform as gaps of about 150 ms inside
        /// one continuous drag, and a reader deciding where to stop pauses for
        /// longer than that. The scroller's own quiet is fifty, so every one of
        /// those pauses was read as the gesture being over and the run was put
        /// on its grid under the hand. Waiting this long costs a reader who HAS
        /// finished a moment before the cards settle, which is the cheaper of
        /// the two mistakes by far. It has to clear the pause a hand makes
        /// while it pushes a card through several notches, and no more than
        /// that: every millisecond past it is a millisecond the run sits
        /// between two cards with nobody touching it.
        /// </remarks>
        private const int Holding = 700;

        /// <summary>Which wait for quiet is the live one.</summary>
        private int _quiet;

        /// <summary>
        /// One scroll event: the reader is on the scroller, and stays on it
        /// until the events stop for <see cref="Holding"/>.
        /// </summary>
        private void Rolled()
        {
            Told(true);

            int ticket = ++_quiet;

            (VirtualView as ScrollView)?.Dispatcher.DispatchDelayed(
                TimeSpan.FromMilliseconds(Holding),
                () =>
                {
                    if (ticket == _quiet)
                    {
                        // THE FINGER GOES FIRST. Nothing is moved under one -
                        // that is the whole of what the flag is for - so a
                        // settle asked for while it is still down is a glide
                        // that never writes a frame, and the run stays wherever
                        // the last message left it, off the grid.
                        Told(false);
                        Settle();
                    }
                });
        }

        /// <summary>
        /// How quickly the movement answers the device, as a time constant in
        /// milliseconds.
        /// </summary>
        /// <remarks>
        /// <para>
        /// WHAT THE DEVICE SAYS IS A MEASUREMENT, and a coarse one: this
        /// platform hands over whole notches and fractions of them, at a rate
        /// nothing paces. Fed straight to the movement, every one of them
        /// re-aims it and the run answers each in turn. Passed through this
        /// first, the target itself is a smooth line and the movement has one
        /// thing to follow - the two together being a first-order lag ahead of
        /// the glide's own second-order one, which is what makes a chopped
        /// stream read as a hand.
        /// </para>
        /// <para>
        /// SHORT, BECAUSE IT IS THE SECOND FILTER IN THE CHAIN. The movement
        /// below has a lag of its own and does most of the smoothing; this one
        /// only has to take the corners off the target it is given. Long, the
        /// two lags add up and the run swims after the hand instead of going
        /// with it.
        /// </para>
        /// </remarks>
        private const double Answering = 10;

        /// <summary>Where the device has actually asked for, unsmoothed.</summary>
        private Point _asked;

        /// <summary>When the last message came, on the clock below.</summary>
        private double _at;

        /// <summary>What has been running since this scroller was hooked.</summary>
        private readonly System.Diagnostics.Stopwatch _clock =
            System.Diagnostics.Stopwatch.StartNew();

        /// <summary>Where the wheel is taking this scroller, while it is taking it.</summary>
        private Point _aim;

        /// <summary>Where the gesture that is taking it there began.</summary>
        private Point _began;

        /// <summary>Whether that aim is a live one.</summary>
        private bool _aiming;

        /// <summary>
        /// One turn of a wheel over a scroller that has a grid: one point of
        /// that grid, glided to.
        /// </summary>
        /// <remarks>
        /// <para>
        /// GTK CARRIES A NOTCH ITS OWN DISTANCE, and moves the scroller by it
        /// the moment it arrives: 98.4 units for a 976-wide room, whichever
        /// way the reader was going and however long the run is. Left to it,
        /// a message lands wherever that distance falls and the grid drags it
        /// back - measured on this platform as ninety-two messages of exactly
        /// 98.4 in one drag, each followed by a correction. Answered here, the
        /// same distance goes through the filter and the movement below, so
        /// what the reader sees is one line rather than a step and a tug.
        /// </para>
        /// <para>
        /// So a notch is answered HERE and the message is eaten, which is the
        /// only way GTK's own distance never runs: one turn is one point of
        /// the grid, counted from where the wheel is already taking the
        /// scroller so a second turn during the movement means the point after
        /// that one, and the glide is the one every settle uses.
        /// </para>
        /// <para>
        /// A TOUCHPAD REPORTING IN PIXELS IS LEFT ALONE - the platform is not
        /// multiplying those, so there is nothing here to put right. So is a
        /// scroller with no grid: nothing here has an opinion about where it
        /// should stop.
        /// </para>
        /// </remarks>
        /// <param name="dx">How far the message carries across.</param>
        /// <param name="dy">And down.</param>
        /// <param name="notch">Whether it is a whole notch of a wheel.</param>
        /// <returns>Whether this answered it, and GTK must not.</returns>
        private bool Stepped(double dx, double dy, bool notch)
        {
            if (!notch
                || VirtualView is not ScrollView scroll
                || scroll.GetValue(StateUIRenderer.ScrollSnapProperty) is not ScrollSnap snap)
            {
                return false;
            }

            double interval = (double)scroll.GetValue(StateUIRenderer.SnapIntervalProperty);

            if (interval <= 0)
            {
                return false;
            }

            double start = (double)scroll.GetValue(StateUIRenderer.SnapFromProperty);
            bool across = scroll.Orientation is ScrollOrientation.Horizontal;

            // A RUN THAT GOES ACROSS IS TURNED BY AN ORDINARY WHEEL, a mouse
            // having none that goes sideways - so whichever axis the message
            // came on moves the one the scroller runs along.
            double carried = across ? (dx != 0 ? dx : dy) : dy;

            if (carried == 0)
            {
                return false;
            }

            Point from = _aiming ? _asked : new Point(scroll.ScrollX, scroll.ScrollY);

            if (!_aiming)
            {
                _began = from;
                _aim = from;
                _at = _clock.Elapsed.TotalMilliseconds;
            }

            // WHAT A DEVICE SAYS IS A CONSTANT, AND THE GEOMETRY DECIDES WHAT
            // IT IS WORTH. A message carries the distance GTK would have
            // carried it - the viewport to the power of two thirds, which is
            // this platform's own idea of a notch - and how much of a card
            // that is, is the run's own length to say. Nothing here reads a
            // message as a CARD any more: a reading like that answers the same
            // however long the tree makes the run, which is the one thing that
            // must not be true of a sensitivity.
            //
            // NOR IS A WHOLE NOTCH A MOUSE'S DELIBERATE CLICK, answered with
            // one card of its own. It was, and that one path is what made
            // every other number here inert: a touchpad in a virtual machine
            // is handed to the guest AS a mouse, sending whole notches from a
            // source that says Mouse, so every push of a finger skipped the
            // geometry entirely - and a reader could not tell one sensitivity
            // from another, because none of them was reaching them.
            double detent = Math.Pow(Math.Max(across ? scroll.Width : scroll.Height, 1), 2.0 / 3.0);
            double moved = carried * detent;
            double x = from.X + (across ? moved : 0);
            double y = from.Y + (across ? 0 : moved);

            var landing = new Point(
                StateUIRenderer.Reachable(x, scroll.ContentSize.Width, scroll.Width),
                StateUIRenderer.Reachable(y, scroll.ContentSize.Height, scroll.Height));

            // HELD TO WHAT ONE GESTURE MAY CARRY, counted from where it began -
            // a reader whose deck moves one card a swipe means one however many
            // messages the device chose to send.
            int most = (int)(double)scroll.GetValue(StateUIRenderer.SnapsAtMostProperty);

            if (most > 0)
            {
                landing = new Point(
                    Bounded(landing.X, _began.X, most * interval),
                    Bounded(landing.Y, _began.Y, most * interval));
            }

            _asked = landing;
            _aiming = true;

            // THE LAG, WORKED OUT FROM THE TIME THAT PASSED rather than from a
            // count of messages: this platform paces them by nothing at all, so
            // an answer per message would be faster when the device chattered
            // and slower when it did not.
            double now = _clock.Elapsed.TotalMilliseconds;
            double answered = 1 - Math.Exp(-Math.Max(now - _at, 0) / Answering);

            _at = now;
            _aim = new Point(
                _aim.X + ((_asked.X - _aim.X) * answered),
                _aim.Y + ((_asked.Y - _aim.Y) * answered));

            _ = snap.GlideTo(_aim.X, _aim.Y);

            return true;
        }

        /// <summary>
        /// The reader has stopped: the same movement carries on to the grid.
        /// </summary>
        /// <remarks>
        /// <para>
        /// THE LAST TARGET, MOVED ONTO THE GRID - never a movement of its own.
        /// A target changed while a glide is running is answered from the
        /// value the glide has reached AND the speed it is going, so putting
        /// the grid point in as the target simply bends the movement already
        /// under way. Left to settle by itself instead, the scroller arrives
        /// off the grid, comes to a stop, and is then pulled onto it by a
        /// second movement - which is the twitch this whole path exists to
        /// remove.
        /// </para>
        /// <para>
        /// And it is only ever asked once the messages have stopped, which is
        /// what says the reader is no longer carrying it.
        /// </para>
        /// </remarks>
        private void Settle()
        {
            if (!_aiming
                || VirtualView is not ScrollView scroll
                || scroll.GetValue(StateUIRenderer.ScrollSnapProperty) is not ScrollSnap snap)
            {
                _aiming = false;
                return;
            }

            _aiming = false;

            double interval = (double)scroll.GetValue(StateUIRenderer.SnapIntervalProperty);

            if (interval <= 0)
            {
                return;
            }

            double start = (double)scroll.GetValue(StateUIRenderer.SnapFromProperty);

            // ONTO THE GRID FROM WHERE THE RUN ACTUALLY IS, never from what
            // the messages had added up to. The two are not the same number: a
            // filter that shapes the journey is a filter that lags, so the sum
            // of the messages runs ahead of the content and can sit a whole
            // card past it. Snapped from the sum, the run settles onto a card
            // the reader never saw come to the front, and is dragged BACKWARDS
            // past the one they had stopped on - which is the whole of what
            // they are looking at.
            _ = snap.GlideTo(
                StateUIRenderer.Reachable(
                    StateUIRenderer.SnapPoint(scroll.ScrollX, interval, start),
                    scroll.ContentSize.Width,
                    scroll.Width),
                StateUIRenderer.Reachable(
                    StateUIRenderer.SnapPoint(scroll.ScrollY, interval, start),
                    scroll.ContentSize.Height,
                    scroll.Height));
        }

        /// <summary>One value, held within a distance of another.</summary>
        /// <param name="at">Where the movement is going.</param>
        /// <param name="from">Where the gesture began.</param>
        /// <param name="most">How far it may carry.</param>
        /// <returns>The nearer of the two.</returns>
        private static double Bounded(double at, double from, double most) =>
            Math.Clamp(at, from - most, from + most);

        /// <summary>Tells this scroller's snap whether a gesture is running.</summary>
        /// <param name="down">Whether the reader is on it.</param>
        private void Told(bool down)
        {
            if (VirtualView is ScrollView scroll
                && scroll.GetValue(StateUIRenderer.ScrollSnapProperty) is ScrollSnap snap)
            {
                snap.Fingers(down);
            }
        }

        /// <summary>The content's size, held to the constraints.</summary>
        /// <param name="widthConstraint">The room across.</param>
        /// <param name="heightConstraint">The room down.</param>
        public override Size GetDesiredSize(double widthConstraint, double heightConstraint)
        {
            if (VirtualView is not ICrossPlatformLayout content)
            {
                return base.GetDesiredSize(widthConstraint, heightConstraint);
            }

            Size size = content.CrossPlatformMeasure(widthConstraint, heightConstraint);
            double width = Math.Min(size.Width, widthConstraint);
            double height = Math.Min(size.Height, heightConstraint);

            if (VirtualView is VisualElement element)
            {
                if (element.WidthRequest >= 0)
                {
                    width = Math.Min(element.WidthRequest, widthConstraint);
                }

                if (element.HeightRequest >= 0)
                {
                    height = Math.Min(element.HeightRequest, heightConstraint);
                }
            }

            return new Size(width, height);
        }
    }
}
