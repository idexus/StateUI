// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Linux;

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
/// AND NOTHING HERE SAYS WHEN A GESTURE IS OVER but <c>scroll-end</c>, which
/// only Wayland raises. The four platforms with hooks of their own announce a
/// drag ending; this one does not, so a scroller reads REST from its reports
/// going quiet - fifty milliseconds of it - while a trackpad pauses for about
/// 150 ms inside one drag. So the scroller is told the reader is on it while
/// scroll events arrive and for <c>Holding</c> after the last one: a pause is
/// not a rest, and a rest in the middle of a drag is where a composition such
/// as <c>GalleryView</c> settles, writing the offset out from under the hand.
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

        // AND A CONTENT THAT GOES IS TAKEN OFF - see Emptied.
        ScrollViewHandler.Mapper.AppendToMapping<IScrollView, ScrollViewHandler>("Content", Emptied);
    }

    /// <summary>
    /// Takes the old content off a scroller whose content has gone.
    /// </summary>
    /// <remarks>
    /// The backend's content mapper answers a new content and nothing else, so
    /// a scroller told it holds NOTHING goes on drawing what it held - MAUI's
    /// <c>Content</c> null, GTK's viewport still carrying the old panel,
    /// measured. A list whose items all went kept every row on screen until an
    /// item came back and replaced them: the inspector's Clear emptied the
    /// record and the renders stood there until the next one landed. The
    /// VIEWPORT stays and is emptied rather than taken away, because it is the
    /// backend's own and a content that comes back is put into it.
    /// </remarks>
    /// <param name="handler">The scroller's handler.</param>
    /// <param name="view">The scroller itself.</param>
    private static void Emptied(ScrollViewHandler handler, IScrollView view)
    {
        if (view.PresentedContent is not null || handler.PlatformView is not Gtk.ScrolledWindow window)
        {
            return;
        }

        if (window.GetChild() is Gtk.Viewport viewport)
        {
            viewport.SetChild(null);
        }
        else
        {
            window.SetChild(null);
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
        /// In the CAPTURE phase, so it is told before the scroller's own
        /// controllers: every <c>scroll</c> marks the reader as on the
        /// scroller, and <c>scroll-end</c> - raised only for a device that
        /// scrolls smoothly, and only where the platform says the fingers left
        /// - marks them off. It answers nothing and leaves the scrolling to the
        /// scroller's own controllers.
        /// </para>
        /// <para>
        /// The scroller's movement is looked up when the gesture happens rather
        /// than kept: it is made the first time the tree asks this scroller for
        /// its rest or its offset, which is after the handler is connected, and
        /// a scroller that never asks for either has nothing here to tell.
        /// </para>
        /// </remarks>
        /// <param name="platformView">The scroller this handler drives.</param>
        protected override void ConnectHandler(Gtk.ScrolledWindow platformView)
        {
            base.ConnectHandler(platformView);

            // A SCROLLER CUTS WHAT IS PAST ITS EDGE, and on GTK that has to be
            // asked for: a widget's overflow is VISIBLE unless it is told
            // otherwise, so a row placed a little past the bottom of the run's
            // window was drawn in full - over the card's own border and the
            // words under it (measured on the gallery's *Row state*, where the
            // row at the foot of a scroll spilled 24 points past the frame and
            // came back the next frame). The viewport inside it takes the same
            // word, being what the content is actually laid in.
            platformView.SetOverflow(Gtk.Overflow.Hidden);

            for (Gtk.Widget? child = platformView.GetFirstChild();
                child is not null;
                child = child.GetNextSibling())
            {
                child.SetOverflow(Gtk.Overflow.Hidden);
            }

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

            // Heard and handed on: GTK's own scrolling answers every message.
            fingers.OnScroll += (_, _) =>
            {
                Rolled();

                return false;
            };

            platformView.AddController(fingers);
        }

        /// <summary>
        /// How long after the last scroll event the reader is still taken to
        /// be on the scroller, in milliseconds.
        /// </summary>
        /// <remarks>
        /// A PAUSE IS NOT AN ENDING. A trackpad reports only while the fingers
        /// MOVE, and a reader dragging a scroller holds still between pushes -
        /// measured on this platform as gaps of about 150 ms inside one
        /// continuous drag, and a reader deciding where to stop pauses for
        /// longer than that. The scroller's own quiet is fifty, so every one of
        /// those pauses would read as a rest, and a rest is where a composition
        /// that settles writes the offset - under the hand. Waiting this long
        /// costs a reader who HAS finished a moment before the rest is heard,
        /// which is the cheaper of the two mistakes by far. It has to clear the
        /// pause a hand makes inside one drag, and no more than that: every
        /// millisecond past it is a millisecond the rest is heard late.
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

            Scroller?.Dispatcher.DispatchDelayed(
                TimeSpan.FromMilliseconds(Holding),
                () =>
                {
                    if (ticket == _quiet)
                    {
                        Told(false);
                    }
                });
        }

        /// <summary>
        /// The scroller this handler drives, or nothing where it drives none.
        /// </summary>
        /// <remarks>
        /// THE TYPED <c>VirtualView</c> THROWS ON NULL, and this handler is
        /// asked questions after its view has gone: the rest of a gesture is
        /// worked out <see cref="Holding"/> - seven tenths of a second - after
        /// the last message, and a reader who leaves the page inside that wait
        /// left the delayed work running against a handler MAUI had already
        /// disconnected - which took the
        /// whole application down with *"VirtualView cannot be null here"*
        /// (measured, walking out of the gallery's list sample straight after
        /// a scroll). The interface's own property answers null instead.
        /// </remarks>
        private ScrollView? Scroller => ((IElementHandler)this).VirtualView as ScrollView;

        /// <summary>Tells this scroller's movement whether the reader is on it.</summary>
        /// <param name="down">Whether the reader is on it.</param>
        private void Told(bool down)
        {
            if (Scroller is ScrollView scroll
                && scroll.GetValue(StateUIRenderer.ScrollMovementProperty) is ScrollMovement movement)
            {
                movement.Fingers(down);
            }
        }

        /// <summary>The content's size, held to the constraints.</summary>
        /// <param name="widthConstraint">The room across.</param>
        /// <param name="heightConstraint">The room down.</param>
        public override Size GetDesiredSize(double widthConstraint, double heightConstraint)
        {
            if (((IElementHandler)this).VirtualView is not ICrossPlatformLayout content)
            {
                return base.GetDesiredSize(widthConstraint, heightConstraint);
            }

            Size size = content.CrossPlatformMeasure(widthConstraint, heightConstraint);
            double width = Math.Min(size.Width, widthConstraint);
            double height = Math.Min(size.Height, heightConstraint);

            if (Scroller is VisualElement element)
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
