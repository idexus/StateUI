// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if WINDOWS
using Microsoft.UI.Xaml.Controls;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// The wheel over a scroller on Windows - taken over whole, which is what lets
/// everything else about the platform's scrolling stay the platform's.
/// </summary>
/// <remarks>
/// <para>
/// THE WHEEL IS THIS SIDE'S ENTIRELY. A mouse and a precision touchpad both
/// arrive as wheel messages - the touchpad's synthesized, in fractions of a
/// notch - and each one is turned into a distance and the offset WRITTEN, so
/// the content moves by exactly what the device asked and CANNOT be carried
/// past the end: a written offset is clamped where an elastic pan is not.
/// Left to the platform instead, a touchpad's stream was answered with a wheel
/// ANIMATION whose standing inertia had to be spent before the next run of the
/// fingers was felt at all - the crossing a reader has to push through before
/// the content goes their way. That is why the wheel cannot be the platform's;
/// it is the one input this file exists for.
/// </para>
/// <para>
/// TOUCH AND THE PEN ARE LEFT ALONE, inertia included. They reach the scroller
/// through DirectManipulation, which the wheel take-over never touches - and
/// their inertia is the very thing the grid is aimed by, because WinUI hands
/// over the end of it as it begins (<c>ViewChanging.FinalView</c>, read in
/// <see cref="ScrollSnap"/>), the same shape as the other platforms' own
/// predicted stop. Inertia was once turned off here wholesale, for the
/// touchpad's sake; the take-over made that reason obsolete, and turning it
/// off costs touch its aim - a drag then stops dead where the fingers leave,
/// and no gesture is ever held to <c>snapsAtMost</c>.
/// </para>
/// <para>
/// A scroller with a GRID answers the message itself - see
/// <see cref="ScrollSnap"/> - and a scroller without one is slid straight
/// through here. Either way the movement is counted from what the wheel has
/// ASKED FOR rather than from where the scroller has got to: a touchpad sends
/// faster than the platform draws, and reading the offset back would lose every
/// message that shared a frame with another.
/// </para>
/// <para>
/// A wheel this scroller cannot answer is left alone, which is what keeps a
/// page scrolling under the pointer while a run of cards inside it holds still.
/// </para>
/// </remarks>
internal static class ScrollTuning
{
    /// <summary>What one whole notch of the wheel reports.</summary>
    internal const double Whole = 120;

    /// <summary>
    /// How far one notch of the wheel carries a scroller, in device units -
    /// WinUI's own, measured at 139. It is what makes a touchpad's stream move
    /// the content as far as the fingers asked, so the number matters only in
    /// that it is the platform's rather than one of ours.
    /// </summary>
    internal const double Notch = 140;

    /// <summary>
    /// How long a slide goes on counting from what it last asked for, in ms. A
    /// gap longer than this is a fresh run of the wheel, by which time the
    /// scroller is where it was put.
    /// </summary>
    private const double Settled = 200;

    /// <summary>Where the trace is written, once <c>STATEUI_SCROLL</c> asks for one.</summary>
    private static readonly string? TracePath =
        Environment.GetEnvironmentVariable("STATEUI_SCROLL") is not null
            ? Path.Combine(MotionTrace.Somewhere(), "stateui-scroll.log")
            : null;

    /// <summary>When the wheel's trace started, so its lines order against the snap's.</summary>
    private static readonly System.Diagnostics.Stopwatch Clock =
        System.Diagnostics.Stopwatch.StartNew();

    /// <summary>Writes one line of what the wheel did, where one is asked for.</summary>
    /// <param name="line">What happened.</param>
    private static void Note(string line)
    {
        if (TracePath is null)
        {
            return;
        }

        try
        {
            File.AppendAllText(TracePath, $"{Clock.ElapsedMilliseconds,7} wheel {line}\n");
        }
        catch (IOException)
        {
        }
    }

    /// <summary>Takes the wheel over one scroller, once it has a platform view.</summary>
    /// <param name="scroll">The scroller being built.</param>
    internal static void Watch(Microsoft.Maui.Controls.ScrollView scroll)
    {
        scroll.HandlerChanged += (sender, _) =>
        {
            if ((sender as Microsoft.Maui.Controls.ScrollView)?.Handler?.PlatformView
                is not ScrollViewer viewer)
            {
                return;
            }

            Note($"watching {viewer.GetType().Name} content={viewer.Content?.GetType().Name}");
            Hook(scroll, viewer);
        };
    }

    /// <summary>Hears the wheel on the scroller's content, once.</summary>
    /// <remarks>
    /// ON THE CONTENT, because a routed event reaches a child before its parent
    /// and the ScrollViewer's own handling is the parent's: marked handled here,
    /// the platform never scrolls and the movement is entirely this side's.
    /// Marking it on the ScrollViewer would be too late - by then it has already
    /// answered the notch. The content is not always there when the handler is,
    /// so a scroller without one waits for <c>Loaded</c>, which can arrive more
    /// than once.
    /// </remarks>
    /// <param name="scroll">The scroller the tree describes.</param>
    /// <param name="viewer">Its platform view.</param>
    private static void Hook(Microsoft.Maui.Controls.ScrollView scroll, ScrollViewer viewer)
    {
        bool hooked = false;

        // WHAT THE WHEEL HAS ASKED FOR, which is what the message after it
        // counts on from. One scroller's, held in the closure that hooked it.
        Point asked = default;
        double heard = double.NegativeInfinity;
        bool snapped = false;
        bool wasAcross = false;
        var clock = System.Diagnostics.Stopwatch.StartNew();

        void Hear(Microsoft.UI.Xaml.UIElement content)
        {
            if (hooked)
            {
                return;
            }

            hooked = true;
            content.PointerWheelChanged += (_, e) => Turn(e);
        }

        void Turn(Microsoft.UI.Xaml.Input.PointerRoutedEventArgs e)
        {
            // Ctrl and the wheel is a zoom on this platform, and never a scroll.
            if (e.KeyModifiers.HasFlag(Windows.System.VirtualKeyModifiers.Control))
            {
                return;
            }

            Microsoft.UI.Input.PointerPointProperties turn =
                e.GetCurrentPoint(viewer).Properties;

            int delta = turn.MouseWheelDelta;

            Note($"turn delta={delta} h={turn.IsHorizontalMouseWheel} "
                + $"sw={viewer.ScrollableWidth:F1} sh={viewer.ScrollableHeight:F1} "
                + $"at={viewer.HorizontalOffset:F1},{viewer.VerticalOffset:F1}");

            if (delta == 0)
            {
                return;
            }

            // WHICH WAY THIS SCROLLER RUNS IS THE TREE'S TO SAY, never the
            // content's. A scroller that runs DOWN is deaf to a sideways wheel:
            // a touchpad puts a little of one into every ordinary scroll, and a
            // page that creeps across under a straight swipe is that noise
            // being answered.
            ScrollOrientation runs = scroll.Orientation;

            if (runs == ScrollOrientation.Vertical && turn.IsHorizontalMouseWheel)
            {
                // TAKEN, AND NOTHING MOVED - which is not the same as leaving
                // it alone. Handed back, it reaches the ScrollViewer's own
                // handler, and a scroller with its inertia turned off pans its
                // undamped edge and rings.
                e.Handled = true;

                return;
            }

            // A scroller that runs NEITHER way - an empty list - has nothing to
            // over-pan either, so its wheel goes on up to whatever is above it.
            if (runs == ScrollOrientation.Neither)
            {
                return;
            }

            // AND A SCROLLER THAT RUNS ACROSS READS AN ORDINARY WHEEL ACROSS,
            // which is the only way a mouse moves a run of cards at all - there
            // is no sideways wheel on one. A scroller that runs BOTH ways gives
            // each wheel its own axis.
            bool across = runs == ScrollOrientation.Horizontal || turn.IsHorizontalMouseWheel;
            double most = across ? viewer.ScrollableWidth : viewer.ScrollableHeight;

            // A wheel this scroller cannot answer belongs to whatever is above
            // it, which is how a page goes on scrolling under the pointer.
            if (most <= 0)
            {
                return;
            }

            // Turned away from the reader - a positive delta - is UP and BACK,
            // so the offset falls; a horizontal wheel is the other way round,
            // its positive being to the right.
            double step = delta / Whole * Notch * (turn.IsHorizontalMouseWheel ? 1 : -1);

            // A FRACTION OF A NOTCH IS A TOUCHPAD, and no mouse sends one.
            bool clicked = Math.Abs(delta) % (int)Whole == 0;

            double now = clock.Elapsed.TotalMilliseconds;

            // ONE RUN IS ONE AXIS. A scroller that runs both ways is fed two
            // interleaved streams, and a component of `asked` held over from
            // the OTHER axis is stale - that axis may have been moved by touch
            // in between - so an axis change starts the count afresh from the
            // viewer, exactly as a pause does.
            bool carry = now - heard < Settled && across == wasAcross;

            // The grid moved the scroller last time, so what this side asked
            // for says nothing about where this message starts.
            bool follow = carry && !snapped;

            heard = now;
            wasAcross = across;
            snapped = false;

            var snap = scroll.GetValue(StateUIRenderer.ScrollSnapProperty) as ScrollSnap;

            if (snap is not null && snap.Turned(across, step, clicked))
            {
                snapped = true;
                e.Handled = true;
                return;
            }

            // TAKEN ONLY WHERE IT WAS ANSWERED. A scroller that has not been
            // laid out yet refuses the offset, and a message marked handled
            // anyway is one the reader simply loses - measured as a page that
            // would not scroll at all for the first seconds after it opened.
            e.Handled = Slide(across, step, most, follow);

            if (!e.Handled)
            {
                // The platform answers this one, with an inertia of its own -
                // which the gesture hooks must not read as a gesture.
                snap?.PlatformWheel();
            }
        }

        bool Slide(bool across, double step, double most, bool carry)
        {

            // A RUN OF THE WHEEL COUNTS ON FROM ITSELF. ChangeView is answered
            // at the next frame, so two messages inside one frame would both
            // read the same offset back and the first one's distance would be
            // lost - which a touchpad, sending faster than the platform draws,
            // would do to a good share of what the fingers asked for.
            //
            // BUT ONLY WHILE THE SCROLLER IS WHERE THE ASKS PUT IT. The viewer
            // lags the asks by a frame or two - a few notches at most - so an
            // offset further off than that was moved by somebody else, an act
            // or a gesture, and counting on from the old asks would write the
            // pre-move offset straight back over their movement.
            if (carry)
            {
                double lag = across
                    ? Math.Abs(asked.X - viewer.HorizontalOffset)
                    : Math.Abs(asked.Y - viewer.VerticalOffset);

                carry = lag <= Notch * 4;
            }

            if (!carry)
            {
                asked = new Point(viewer.HorizontalOffset, viewer.VerticalOffset);
            }

            Point going = across
                ? new Point(Math.Clamp(asked.X + step, 0, most), asked.Y)
                : new Point(asked.X, Math.Clamp(asked.Y + step, 0, most));

            double at = across ? viewer.HorizontalOffset : viewer.VerticalOffset;
            double to = across ? going.X : going.Y;

            // WOUND TO ITS END AND ASKED FOR MORE. Nothing moves, and the
            // message is still this side's: a scroller left to answer it
            // over-pans its own end and springs back, which is the whole of
            // what makes an undamped edge ring.
            if (Math.Abs(to - at) < 0.5)
            {
                asked = going;
                Note($"walled at={at:F1} sent=-");
                return true;
            }

            if (!viewer.ChangeView(going.X, going.Y, null, true))
            {
                // Nothing moved, so what this side asked for is about a
                // scroller that was not there. The next message starts afresh.
                heard = double.NegativeInfinity;
                Note($"refused to={to:F1} at={at:F1}");
                return false;
            }

            asked = going;
            Note($"slid to={going.X:F1},{going.Y:F1} carry={carry}");

            return true;
        }

        if (viewer.Content is Microsoft.UI.Xaml.UIElement content)
        {
            Hear(content);
            return;
        }

        viewer.Loaded += (_, _) =>
        {
            if (viewer.Content is Microsoft.UI.Xaml.UIElement later)
            {
                Hear(later);
            }
        };

        // Loaded can fire BEFORE MAUI has put the content panel in, and it
        // does not fire again - so a scroller built empty and filled later
        // would never be hooked at all. LayoutUpdated fires on every pass and
        // detaches itself the moment the content is there.
        void Late(object? sender, object args)
        {
            if (viewer.Content is not Microsoft.UI.Xaml.UIElement found)
            {
                return;
            }

            viewer.LayoutUpdated -= Late;
            Hear(found);
        }

        viewer.LayoutUpdated += Late;
    }
}
#endif
