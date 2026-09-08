// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Gtk;
using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;
using StateUI.Runtime.Rendering;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Keeps the backend's layout bookkeeping honest: a stale page is laid out
/// again, a drawn view stops wishing for the size it was last given, and a
/// page that has been left is not asked to lay itself out for ever after.
/// </summary>
/// <remarks>
/// <para>
/// THE BACKEND NEVER RE-LAYS-OUT ON ITS OWN. Its panel only replays the
/// bounds MAUI wrote into it, MAUI's arrange runs only when something calls
/// it from above - a window resize, a scroller's own arrange - and the
/// <c>InvalidateMeasure</c> command every size-relevant change raises falls
/// through to a mapping that does nothing there. A view shown by
/// <c>IsVisible</c> after the page settled therefore keeps whatever bounds it
/// had while hidden - measured: switching a sample page to its IN SWIFT tab
/// showed the code in a scroller one unit square. The answer maps the
/// command: the outermost panel above the view that owns a cross-platform
/// layout is measured and arranged again at its current size, once per idle
/// however many views invalidated in the burst.
/// </para>
/// <para>
/// AND A BOX ONCE STRETCHED WISHED FOR THAT WIDTH FOR EVER: the backend draws
/// a <c>BoxView</c> on a GTK <c>DrawingArea</c> whose arrange writes the
/// ARRANGED size into the widget as its content size, which is exactly what
/// the shared measure reads back as the widget's natural one - so the tab
/// strip's two-unit underline claimed the full window and every tab but the
/// first sat off the screen's right edge. A box has nothing of its own to
/// measure - its size is its author's to say - so its handler here answers
/// the author's <c>WidthRequest</c> and <c>HeightRequest</c>, and where one
/// is not given, the 40 units MAUI documents as a BoxView's default. The
/// shape handlers share the DrawingArea and the same write at arrange; they
/// keep the backend's behaviour until a sample shows it mattering.
/// </para>
/// <para>
/// AND THE OUTERMOST LAYOUT IS NEVER TOLD WHERE IT WAS PUT. A panel's
/// allocation calls <c>CrossPlatformArrange</c>, which arranges the layout's
/// CHILDREN - every one of them told its rectangle by MAUI's own arrange - and
/// says nothing to the layout itself, so the one view with no MAUI parent to
/// arrange it keeps <c>Frame</c> at the (0, 0, -1, -1) that means NOWHERE for
/// the life of the page. Nothing draws wrongly for it, which is why it went
/// unseen: what breaks is every page that is built FROM its own room. Measured
/// on the gallery's home page, where the room read back as -1 by -1: the
/// heading was hidden as not fitting, the run of cards collapsed to its floor,
/// and the entrance waited out its whole patience for a measurement that could
/// never arrive. So the panel's layout is WRAPPED, and the outermost one -
/// having no layout panel above it - is arranged the way a parent would arrange
/// it, which writes the frame and then does the children as before.
/// </para>
/// <para>
/// AND A PAGE THAT HAS BEEN LEFT IS STILL ASKED TO LAY ITSELF OUT: the
/// backend subscribes a layout handler to the window's size and to a flyout
/// paned's position and unsubscribes NEITHER, so a popped page's handler is
/// called for every resize after it. Its own guard is
/// <c>if (VirtualView != null)</c> over a getter that THROWS on null, so the
/// first resize after leaving any page takes the process down - enter a
/// group, come back, drag the window edge. <see cref="Detaching"/> takes
/// those subscriptions down where they were made for a handler that is
/// going.
/// </para>
/// </remarks>
[System.Runtime.Versioning.SupportedOSPlatform("linux")]
internal static class LinuxMeasures
{
    /// <summary>
    /// The panels whose subtree asked to be laid out again, taken in one idle
    /// pass so a burst of invalidations costs one layout.
    /// </summary>
    private static readonly Dictionary<GtkLayoutPanel, (int Width, int Height)> Stale = [];


    /// <summary>Arms the invalidation pass, the layouts and the BoxView measure.</summary>
    /// <param name="builder">Whose handler registry takes the replacements.</param>
    internal static void Install(MauiAppBuilder builder)
    {
        builder.ConfigureMauiHandlers(handlers =>
        {
            handlers.AddHandler<BoxView, Requested>();
            handlers.AddHandler<Microsoft.Maui.Controls.Border, Bounded>();
            handlers.AddHandler<Microsoft.Maui.Controls.Image, Shown>();
            handlers.AddHandler<Layout, Detaching>();
            handlers.AddHandler<Microsoft.Maui.Controls.Label, Spaced>();
        });

        // The shared command mapper is where every handler's InvalidateMeasure
        // lands, none of the backend's own defining it closer.
        Microsoft.Maui.Handlers.ViewHandler.ViewCommandMapper["InvalidateMeasure"] = Invalidated;

        // AND THE PANE SLIDING BACK IS A RESIZE NOBODY ANNOUNCES. The detail
        // side is given the whole window again when the flyout closes, and
        // nothing tells MAUI: the page goes on wearing the frame it had while
        // the pane was over it - measured on the gallery's home page, which
        // stayed a flyout's width narrow, its run of cards off centre, until
        // the window itself was dragged. So the presentation is heard and the
        // detail's own root laid out again at the size it now has.
        Microsoft.Maui.Handlers.ViewHandler.ViewMapper.AppendToMapping(
            "StateUILinuxFlyoutWidth",
            (_, view) =>
            {
                if (view is not FlyoutPage flyout || !Hear(flyout))
                {
                    return;
                }

                flyout.IsPresentedChanged += (_, _) => Relay(flyout);

                // AND A PAGE THAT ARRIVES IS A PAGE LAID OUT ONCE. Nothing
                // lays it out again on this backend, so whatever its first
                // arrangement decided it keeps - and anything that happens to
                // cause another puts it right, which is how a reader finds it:
                // *"wystarczy że okienko straci focus i trafiają przyciski na
                // dobre miejsce"*. Measured on the gallery's *RefreshView*,
                // whose switch and button sat across the card's top edge until
                // the window was touched.
                if (flyout.Detail is NavigationPage stack && Fresh(stack))
                {
                    stack.Pushed += (_, _) => Arrived(flyout);
                    stack.Popped += (_, _) => Arrived(flyout);
                    stack.PoppedToRoot += (_, _) => Arrived(flyout);
                }

                // AND A WINDOW RESIZE IS THE SAME RESIZE, ANNOUNCED NO BETTER.
                // Queued, because the widget is parented a moment after the
                // mapper runs and the walk to the window goes upwards.
                GLib.Functions.IdleAdd(0, () =>
                {
                    for (Widget? above = flyout.Handler?.PlatformView as Widget;
                         above is not null; above = above.GetParent())
                    {
                        if (above is Gtk.Window window)
                        {
                            // WHICH PROPERTY IS NOT WORTH ASKING: a resize
                            // notifies `default-width` and `default-height`
                            // (measured), and the watch below compares the
                            // width itself, so a notify about anything else
                            // costs one integer and takes itself back.
                            window.OnNotify += (_, _) => Relay(flyout);

                            break;
                        }
                    }

                    return false;
                });
            });
    }

    /// <summary>
    /// Lays the flyout out again as a page arrives, and once more when it has.
    /// </summary>
    /// <remarks>
    /// A PUSH IS NOT ONE MOMENT. The page is announced before its widgets are
    /// allocated, so a pass taken at the announcement lays out what is there
    /// THEN - measured on the gallery's *RefreshView*, whose bottom row sat in
    /// the middle of the card on arrival and at its foot after anything at all
    /// laid the page out again (the reader's own way in was to let the window
    /// lose focus). So the room is asked for twice: now, and after the settle
    /// a page needs to exist.
    /// </remarks>
    /// <param name="flyout">The page whose sides are to follow.</param>
    private static void Arrived(FlyoutPage flyout)
    {
        Relay(flyout);

        GLib.Functions.TimeoutAdd(0, Settling, () =>
        {
            Relay(flyout);
            return false;
        });
    }

    /// <summary>How long a pushed page takes to be worth laying out again.</summary>
    private const uint Settling = 250;

    /// <summary>Lays both sides of the flyout out again at the room they have.</summary>
    /// <remarks>
    /// THE PANE IS A PAGE TOO, and it is given a height by the same window.
    /// Left out, it keeps whatever it was laid out at: measured on the gallery
    /// at 1500x1000, where the pane's own list stopped half way through *Lists
    /// &amp; cards* and its footer sat under that, both at the 768-tall
    /// window's places, while the detail beside it had followed.
    /// </remarks>
    /// <param name="flyout">The page whose sides are to follow.</param>
    private static void Relay(FlyoutPage flyout)
    {
        if (flyout.Detail?.Handler?.PlatformView is Widget detail)
        {
            Widen(detail);
        }

        if (flyout.Flyout?.Handler?.PlatformView is Widget pane)
        {
            Widen(pane);
        }
    }

    /// <summary>Whether this navigation stack is being heard for the first time.</summary>
    /// <param name="stack">The detail's own stack.</param>
    /// <returns>Whether it has just been added.</returns>
    private static bool Fresh(NavigationPage stack)
    {
        if (Stacks.TryGetValue(stack, out _))
        {
            return false;
        }

        Stacks.Add(stack, stack);

        return true;
    }

    /// <summary>The navigation stacks already being heard.</summary>
    private static readonly System.Runtime.CompilerServices
        .ConditionalWeakTable<NavigationPage, object> Stacks = [];

    /// <summary>
    /// The flyouts already being heard - weakly, a page being free to go.
    /// </summary>
    private static readonly System.Runtime.CompilerServices
        .ConditionalWeakTable<FlyoutPage, object> Heard = [];

    /// <summary>The details already being watched, so one watch does for a burst.</summary>
    private static readonly System.Runtime.CompilerServices
        .ConditionalWeakTable<Widget, object> Widening = [];

    /// <summary>
    /// Lays the detail side out again until the room it has stands still.
    /// </summary>
    /// <remarks>
    /// A RESIZE'S END IS ANNOUNCED BY NOBODY, whichever resize it is. At the
    /// moment a flyout's presentation changes the detail still has the width
    /// it had under the pane - measured: 723 of 1024 when the flyout closes,
    /// and 1024 four hundred milliseconds later - so a pass taken there
    /// arranges the page at the OLD width and pins it there. A WINDOW resize
    /// is the same story with a different cause: the notify arrives before the
    /// new allocation, and one taken at face value lays the page out at the
    /// size it is leaving. Measured on the gallery, asking the window manager
    /// for 1500x1000 with the Layout group open: the rows stayed 1000 wide in
    /// a 1500-wide window, and asking for 900 ran them off the right edge -
    /// while a resize made in ten steps came out right, each step laying the
    /// page out at the size of the step before.
    ///
    /// So the frame clock is asked instead: every frame the room has changed,
    /// the roots are laid out again at it, and the callback takes itself back
    /// once the size has stood still for a few frames. One watch does for a
    /// burst - a single resize notifies several times.
    /// </remarks>
    /// <param name="detail">The widget the detail page is drawn in.</param>
    private static void Widen(Widget detail)
    {
        if (Widening.TryGetValue(detail, out _))
        {
            return;
        }

        Widening.Add(detail, detail);

        int last = -1;
        int tall = -1;
        int still = 0;

        // AT THE ROOM THE DETAIL NOW HAS, never the panel's own allocation:
        // MAUI gives a widget a size request from the arrangement, so the
        // page's root goes on asking for the narrow width and GTK goes on
        // handing it exactly that, however wide the box around it has become -
        // measured as the box back at 1024 with its panel standing at 723,
        // sweep after sweep. Laid out at the box's width, the arrangement
        // writes the new request and the widget follows.
        // INSIDE the detail rather than above it: the box IS the page, and the
        // panel that owns its layout is the child it holds.
        //
        // EVERY PAGE INSIDE IT, not just the first: a detail is a navigation
        // stack, and each page it holds has a root of its own that GTK will not
        // re-allocate while the request the last arrangement wrote still fits.
        void Lay(int width, int height)
        {
            foreach (GtkLayoutPanel root in Roots(detail))
            {
                // AT THE ROOM THE PAGE HAS, WHICH IS NOT THE DETAIL'S. The
                // detail holds the navigation bar as well as the page, so its
                // height is fifty-one points more than the page's - measured,
                // detail 900 against box 849 - and a page laid out at the
                // larger number puts everything anchored to its foot below the
                // window's edge: the gallery's home page kept its last line
                // half cut off after every drag of the window. The box is the
                // page's own container, allocated by GTK and never carrying
                // the request the last arrangement wrote, which is what makes
                // the panel's own allocation useless here.
                Widget? box = ((Widget)root).GetParent();

                int room = box?.GetAllocatedWidth() is int wide and > 0 ? wide : width;
                int deep = box?.GetAllocatedHeight() is int high and > 0 ? high : height;

                ((Widget)root).SetSizeRequest(-1, -1);

                root.CrossPlatformMeasure(room, deep);
                root.CrossPlatformArrange(new Rect(0, 0, room, deep));
            }
        }

        detail.AddTickCallback((_, _) =>
        {
            int now = detail.GetAllocatedWidth();
            int high = detail.GetAllocatedHeight();

            if (now != last || high != tall)
            {
                (last, tall, still) = (now, high, 0);
                Lay(now, high);

                return true;
            }

            // AND THE SETTLED SIZE IS LAID OUT TOO, which is the whole reason
            // the still frames are counted rather than the callback simply
            // taken off at the first one. A tick runs BEFORE the frame's own
            // allocation, so the room read here is the one the LAST frame had:
            // laid out only where it changed, every step of a drag is one step
            // behind and the last step is never caught up - measured as the
            // page's footer left below the window's edge after the mouse was
            // released, and the whole page one step stale while the edge was
            // being dragged.
            Lay(now, high);

            if (++still <= Settled)
            {
                return true;
            }

            Widening.Remove(detail);

            return false;
        });
    }

    /// <summary>How many still frames say a slide is over.</summary>
    private const int Settled = 4;

    /// <summary>Whether this flyout is being heard for the first time.</summary>
    /// <param name="flyout">The page.</param>
    /// <returns>Whether it has just been added.</returns>
    private static bool Hear(FlyoutPage flyout)
    {
        if (Heard.TryGetValue(flyout, out _))
        {
            return false;
        }

        Heard.Add(flyout, flyout);
        return true;
    }

    /// <summary>
    /// Gives the seven shapes the measure their author asked for.
    /// </summary>
    /// <remarks>
    /// LAST, AFTER THE LIBRARY'S OWN REGISTRATION. The shapes are this
    /// library's own classes over MAUI's sealed originals, registered to the
    /// shared handler by <c>SwiftShapes</c> - and a handler registry answers
    /// with whatever was registered last, so this has to be told after that.
    /// </remarks>
    /// <param name="builder">Whose handler registry takes them.</param>
    internal static MauiAppBuilder Shapes(MauiAppBuilder builder) =>
        builder.ConfigureMauiHandlers(handlers =>
        {
            handlers.AddHandler<SwiftRectangle, Drawn>();
            handlers.AddHandler<SwiftRoundRectangle, Drawn>();
            handlers.AddHandler<SwiftEllipse, Drawn>();
            handlers.AddHandler<SwiftLine, Drawn>();
            handlers.AddHandler<SwiftPath, Drawn>();
            handlers.AddHandler<SwiftPolygon, Drawn>();
            handlers.AddHandler<SwiftPolyline, Drawn>();
        });

    /// <summary>
    /// A view's measure went stale: marks the layout root above it and
    /// schedules the one pass that puts the whole subtree right.
    /// </summary>
    /// <remarks>
    /// Deferred to the loop's idle rather than run in place, because the
    /// command is raised from inside property applies and layout passes - an
    /// arrange started there would run into the very pass that caused it.
    /// </remarks>
    /// <param name="handler">The view's handler.</param>
    /// <param name="view">The view whose measure went stale.</param>
    /// <param name="args">Unused.</param>
    private static void Invalidated(IElementHandler handler, IElement view, object? args)
    {
        if (handler.PlatformView is Widget widget)
        {
            Mark(widget);
        }
    }

    /// <summary>
    /// Marks the layout root above a widget and schedules the pass that lays
    /// it out again.
    /// </summary>
    /// <param name="widget">Whatever went stale.</param>
    private static void Mark(Widget widget)
    {
        GtkLayoutPanel? top = Top(widget);

        if (top is null)
        {
            widget.QueueResize();
            return;
        }

        bool scheduled = Stale.Count > 0;

        // THE SIZE IT WAS MARKED AT, so a pass GTK makes in the meantime is
        // known for what it is - see the sweep.
        Stale[top] = (((Widget)top).GetAllocatedWidth(), ((Widget)top).GetAllocatedHeight());

        if (!scheduled)
        {
            GLib.Functions.IdleAdd(0, () =>
            {
                Sweep();
                return false;
            });
        }
    }

    /// <summary>
    /// The OUTERMOST panel that owns a layout above a widget - the page's root,
    /// or the whole flyout's - so star rows and fills above it are counted
    /// again, not just the view's own parent.
    /// </summary>
    /// <param name="widget">Where to start looking.</param>
    /// <returns>The panel, or nothing where none is above it.</returns>
    private static GtkLayoutPanel? Top(Widget widget)
    {
        GtkLayoutPanel? top = null;

        for (Widget? above = widget; above is not null; above = above.GetParent())
        {
            if (above is GtkLayoutPanel panel && panel.CrossPlatformLayout is not null)
            {
                top = panel;
            }
        }

        return top;
    }

    /// <summary>
    /// Every panel that owns a layout inside a widget without another such
    /// panel above it - one per page the detail holds.
    /// </summary>
    /// <param name="widget">Where to start looking.</param>
    /// <returns>The panels, outermost first.</returns>
    private static IEnumerable<GtkLayoutPanel> Roots(Widget widget)
    {
        if (widget is GtkLayoutPanel { CrossPlatformLayout: not null } here)
        {
            yield return here;
            yield break;
        }

        for (Widget? child = widget.GetFirstChild(); child is not null; child = child.GetNextSibling())
        {
            foreach (GtkLayoutPanel found in Roots(child))
            {
                yield return found;
            }
        }
    }

    /// <summary>
    /// The outermost panel that owns a layout INSIDE a widget - the page's own
    /// root, which is a child of the box a page is drawn in rather than an
    /// ancestor of it.
    /// </summary>
    /// <param name="widget">Where to start looking.</param>
    /// <returns>The panel, or nothing where it holds none.</returns>
    private static GtkLayoutPanel? Inside(Widget widget)
    {
        if (widget is GtkLayoutPanel { CrossPlatformLayout: not null } here)
        {
            return here;
        }

        for (Widget? child = widget.GetFirstChild(); child is not null; child = child.GetNextSibling())
        {
            if (Inside(child) is { } found)
            {
                return found;
            }
        }

        return null;
    }

    /// <summary>The panels already told to cut what is past their edge.</summary>
    private static readonly System.Runtime.CompilerServices
        .ConditionalWeakTable<Widget, object> Cut = [];

    /// <summary>
    /// Tells a panel inside a scroller to cut what is past its edge, once.
    /// </summary>
    /// <param name="panel">The panel being arranged.</param>
    private static void Clipped(Widget panel)
    {
        if (Cut.TryGetValue(panel, out object? _))
        {
            return;
        }

        for (Widget? above = panel.GetParent(); above is not null; above = above.GetParent())
        {
            if (above is Gtk.ScrolledWindow)
            {
                panel.SetOverflow(Gtk.Overflow.Hidden);
                Cut.Add(panel, panel);
                return;
            }
        }

        Cut.Add(panel, panel);
    }

    /// <summary>Lays every marked root out again at its current size.</summary>
    private static void Sweep()
    {
        (GtkLayoutPanel Root, (int Width, int Height) Was)[] roots =
            [.. Stale.Select(one => (one.Key, one.Value))];

        Stale.Clear();

        foreach ((GtkLayoutPanel root, (int Width, int Height) was) in roots)
        {
            // A page popped between the mark and this pass takes its panels
            // with it; a dead handle is nothing to lay out.
            if (root.Handle.IsClosed || root.Handle.IsInvalid)
            {
                continue;
            }

            int width = ((Widget)root).GetAllocatedWidth();
            int height = ((Widget)root).GetAllocatedHeight();

            // Not laid out yet: the first allocation will arrange it anyway.
            if (width < 1 || height < 1)
            {
                continue;
            }

            // AND A PASS GTK HAS MADE SINCE IS NEWER THAN THIS ONE. A window
            // being dragged allocates its panel again and again, each time
            // laying the page out at the size it has THEN - and this sweep,
            // asked for before that, would lay the same page out at the size
            // it had WHEN IT WAS ASKED. Measured on the gallery's lists: the
            // page flipped between the new arrangement and the one before it
            // on every step of a drag, which is a list whose height jumps by
            // a row and settles the moment the hand stops.
            // UNLESS IT HAD NO SIZE AT ALL WHEN IT WAS MARKED, which is the
            // other reason to be here: a page laid out before GTK allocated
            // its panel was laid out at the window's size, and the size it has
            // NOW is the one it should have been laid out at.
            if ((width, height) != was && was is not (0, 0))
            {
                continue;
            }

            root.CrossPlatformMeasure(width, height);

            // THROUGH THE VIEW, never straight into the layout. A page's own
            // arrange is where MAUI takes off what the page does not have -
            // the navigation bar above it, a safe area - so a sweep that
            // called `CrossPlatformArrange` handed the CONTENT the whole
            // panel and made it that much too tall: measured on the gallery's
            // lists as a card of 644 points inside a 717-point page, against
            // 593 from the arrangement GTK makes, and the two alternating on
            // every scroll.
            if (root.CrossPlatformLayout is IView page)
            {
                page.Arrange(new Rect(0, 0, width, height));
            }
            else
            {
                root.CrossPlatformArrange(new Rect(0, 0, width, height));
            }
        }
    }

    /// <summary>
    /// A panel's layout, with the frame the panel gave it written down.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Every layout wears one and only the OUTERMOST acts: a layout with a
    /// panel above it is arranged by that panel's own cross-platform pass,
    /// which tells it its rectangle in the parent's coordinates - the x and y
    /// included. A panel arranges in ITS OWN, from (0, 0), so a nested layout
    /// given that rectangle would be told it sits at the top left of a page it
    /// is nowhere near.
    /// </para>
    /// <para>
    /// The outermost has no such parent, and its own space and the page's are
    /// the same space, which is what makes the panel's rectangle the right
    /// answer there. <see cref="IView.Arrange"/> rather than a write to
    /// <c>Frame</c>, so the frame is the one MAUI itself would have computed -
    /// a margin and an alignment on the page's root view are honoured on this
    /// platform exactly as they are on the other four.
    /// </para>
    /// <para>
    /// THAT ARRANGE COMES BACK THROUGH HERE, and the second pass is where the
    /// children are done. MAUI's arrange writes the frame and then hands it to
    /// the handler, whose <c>PlatformArrange</c> is the panel's own
    /// <c>CrossPlatformArrange</c> - so the call re-enters this wrapper, and
    /// without a guard it re-enters it for ever (measured: a stack overflow
    /// before the first window). Held, the two passes are exactly the one
    /// arrangement the panel asked for: the outer writes the frame, the inner
    /// lays the subtree out at it.
    /// </para>
    /// </remarks>
    /// <param name="panel">The panel whose allocation this answers.</param>
    /// <param name="inner">The layout the backend put there.</param>
    private sealed class Framed(GtkLayoutPanel panel, ICrossPlatformLayout inner)
        : ICrossPlatformLayout
    {
        /// <summary>Whether MAUI's own arrange of this layout is running.</summary>
        private bool _arranging;

        /// <inheritdoc/>
        /// <remarks>
        /// A PAGE IS NEVER MEASURED BIGGER THAN THE ROOM IT HAS. The backend
        /// subscribes every layout handler to the WINDOW's size and lays the
        /// page out from that closure at the window's own height - fifty-one
        /// points more than a page under a navigation bar has - so a grid's
        /// star row came out fifty-one too tall and everything under it landed
        /// below the page's foot. It is arranged at the right size a moment
        /// later, which is what makes it a FLICKER rather than a resting
        /// defect: measured on the gallery's lists, where the same scroller
        /// was measured at 532 by GTK's own pass and at 583 by that closure,
        /// and the caption under the list flew onto the window's edge on two
        /// frames of every scroll and came back.
        /// </remarks>
        public Size CrossPlatformMeasure(double widthConstraint, double heightConstraint)
        {
            if (inner is VisualElement { Parent: Page })
            {
                int wide = ((Widget)panel).GetAllocatedWidth();
                int high = ((Widget)panel).GetAllocatedHeight();

                if (wide > 0 && high > 0)
                {
                    widthConstraint = Math.Min(widthConstraint, wide);
                    heightConstraint = Math.Min(heightConstraint, high);
                }
            }

            return inner.CrossPlatformMeasure(widthConstraint, heightConstraint);
        }

        /// <inheritdoc/>
        public Size CrossPlatformArrange(Rect bounds)
        {
            // A PAGE DOES NOT PAINT OUTSIDE ITSELF. GTK leaves a widget's
            // overflow VISIBLE, and a layout whose children stand where
            // arithmetic puts them reaches well outside its own box - so the
            // gallery's run of cards was drawn ACROSS THE FLYOUT PANE, three
            // cards over the pane's own rows, the moment the window was narrow
            // enough for the run to reach that far. The page is the boundary:
            // a card may leave the row it is placed in, which is what a placed
            // run is for, and may not leave the page.
            if (inner is VisualElement { Parent: Page })
            {
                ((Widget)panel).SetOverflow(Gtk.Overflow.Hidden);
            }

            // AND ONLY WHERE THE PAGE'S ROOT ASKS FOR SOMETHING THE PANEL
            // WOULD IGNORE. Arranging through the VIEW is how a margin or an
            // alignment on that root is honoured here as it is on the other
            // four platforms - and it is also a second opinion about how big
            // the content is: measured on the gallery's lists, a page arranged
            // that way put a card of 644 points inside 717, where the same
            // page laid out straight into its layout put 593 there and left
            // its own border and the words under it on the screen. So the
            // detour is taken for the views that need it and for no others.
            if (_arranging || inner is not IView view || !Outermost() || !Asks(view))
            {
                Size answer = inner.CrossPlatformArrange(bounds);

                // AND THE ROOT IS TOLD WHERE IT WAS PUT. Arranging the layout
                // directly places its CHILDREN and leaves the layout's own
                // frame at whatever it was: MAUI writes a view's frame from
                // its parent's arrange, and the outermost has no parent that
                // arranges - so a page's own root reported no frame here at
                // all, and `.frame($room)` and `.onFrameChanged` on it were
                // silent for the life of the page. Measured on the gallery's
                // home page, whose run of cards is sized from that
                // measurement: the cards stood at their declared 400 points
                // in a window too short to hold them, drawn over the words
                // underneath, and the entrance waited out its patience every
                // launch because the room it watches never arrived.
                // AND A PAGE'S OWN ROOT IS TOLD WHERE IT WAS PUT. Arranging
                // the layout directly places its CHILDREN and leaves the
                // layout's own frame at whatever it was - MAUI writes a view's
                // frame from its PARENT's arrange, and a page's content has no
                // parent that arranges here - so `.frame($room)` and
                // `.onFrameChanged` on a page's own root were silent for the
                // life of that page. Measured on the gallery's home page,
                // whose run of cards is sized from that measurement: the cards
                // stood at their declared 400 points in a window too short to
                // hold them, drawn over the words underneath, and the entrance
                // waited out its patience at every launch because the room it
                // watches never arrived.
                //
                // THE PAGE'S ROOT AND NOTHING ELSE. Any layout the platform
                // wraps can be outermost by the widget walk - a card inside a
                // placed run is - and a frame written onto one of those is a
                // size nobody asked for: measured as the run of cards pushed
                // down over its own caption, two card-sized frames written
                // over and over. And only where the ALLOCATION agrees, because
                // the bounds handed here are the whole window until GTK has
                // allocated this panel.
                if (inner is VisualElement root
                    && root.Parent is Page
                    && ((Widget)panel).GetAllocatedHeight() > 0
                    && Math.Abs(bounds.Width - ((Widget)panel).GetAllocatedWidth()) < 1
                    && Math.Abs(bounds.Height - ((Widget)panel).GetAllocatedHeight()) < 1
                    && root.Frame != bounds)
                {
                    root.Frame = bounds;
                }

                // AND WHAT LIES INSIDE A SCROLLER IS CUT AT ITS EDGE. GTK
                // leaves a widget's overflow VISIBLE unless it is told, and a
                // row placed a little past the window of a run was drawn in
                // full - over the card's own border and the words under it.
                // The scroller says it of itself and of what it holds; this
                // says it of the panels below that, which is where a list's
                // rows actually live (measured on the gallery's *Row state*:
                // the row at the foot of a scroll spilled 24 points past the
                // frame, on every scroll, and only under a real device).
                Clipped(panel);

                if (inner is Microsoft.Maui.ILayout layout)
                {
                    LinuxTransforms.Wear(panel, layout);
                    LinuxTransforms.Stack(panel, layout);
                }

                return answer;
            }

            _arranging = true;

            try
            {
                // A PAGE LAID OUT BEFORE ITS PANEL HAS A SIZE IS LAID OUT AT
                // THE WINDOW'S. The bounds handed here are the whole window
                // where GTK has not allocated this panel yet - which for a
                // page under a navigation bar is fifty-one points more room
                // than it has - and everything sized from that is too tall:
                // measured on the gallery's lists, where the card came out 644
                // points inside a 717-point page and its own bottom border,
                // the caption under it and part of a row fell below the
                // window. The pass is still made, since something has to be
                // drawn, and the root is marked so the sweep lays it out again
                // the moment it knows its size.
                if (((Widget)panel).GetAllocatedHeight() < 1)
                {
                    Mark(panel);
                }

                // MEASURED AT THE SIZE IT IS ABOUT TO BE ARRANGED AT. A page
                // arranged without one keeps whatever measure it was last
                // given - and where that was taken with no bound, its content
                // takes the size it WISHES for: measured on the gallery's
                // lists as a card of 644 points inside a 717-point page,
                // against 593 when the same page was measured first.
                view.Measure(bounds.Width, bounds.Height);

                return view.Arrange(bounds);
            }
            finally
            {
                _arranging = false;
            }
        }

        /// <summary>
        /// Whether this root asks for something only MAUI's own arrange can
        /// give it - a margin, or an alignment other than filling.
        /// </summary>
        /// <param name="view">The layout the panel holds.</param>
        /// <returns>Whether the arrangement has to go through the view.</returns>
        private static bool Asks(IView view) =>
            view.Margin != default
                || view.HorizontalLayoutAlignment != Microsoft.Maui.Primitives.LayoutAlignment.Fill
                || view.VerticalLayoutAlignment != Microsoft.Maui.Primitives.LayoutAlignment.Fill;

        /// <summary>
        /// Whether nothing above this panel is a layout MAUI arranges.
        /// </summary>
        /// <remarks>
        /// Asked at every arrange rather than kept, a panel being free to be
        /// re-parented: a page pushed onto a stack, a view moved between
        /// layouts. It is a walk of a handful of pointers up a widget tree,
        /// against an arrange that lays a whole subtree out.
        /// </remarks>
        /// <returns>Whether this panel is the top of its layout.</returns>
        private bool Outermost()
        {
            for (Widget? above = panel.GetParent(); above is not null; above = above.GetParent())
            {
                if (above is GtkLayoutPanel { CrossPlatformLayout: not null })
                {
                    return false;
                }
            }

            return true;
        }
    }

    /// <summary>
    /// Where the bindings cache a wrapper's connected closures. Null where a
    /// future release renames it, and a subscription then stays as the backend
    /// leaves it.
    /// </summary>
    private static readonly System.Reflection.FieldInfo? Closures =
        typeof(GObject.Internal.ObjectHandle).GetField(
            "closures",
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);

    /// <summary>
    /// Disconnects every signal on one object whose handler was written by the
    /// given owner.
    /// </summary>
    /// <param name="owner">The object the subscriptions sit on.</param>
    /// <param name="handler">Whose subscriptions are to go.</param>
    private static void Drop(GObject.Object owner, object handler)
    {
        if (Closures?.GetValue(owner.Handle) is not Dictionary<Delegate, GObject.Closure> cached)
        {
            return;
        }

        foreach (Delegate written in cached.Keys.ToList())
        {
            if (!Wrote(written.Target, handler, depth: 3))
            {
                continue;
            }

            cached[written].Dispose();
            cached.Remove(written);
        }
    }

    /// <summary>
    /// Whether a delegate's captured state holds the handler - which is what
    /// says the subscription was made for it and dies with it.
    /// </summary>
    /// <remarks>
    /// Only the compiler's own capture classes are walked into. A field
    /// holding a widget is compared and left alone, so this reads a closure's
    /// captures rather than the object graph behind them.
    /// </remarks>
    /// <param name="captured">What the delegate closed over.</param>
    /// <param name="handler">The handler being looked for.</param>
    /// <param name="depth">How many capture classes deep to look.</param>
    private static bool Wrote(object? captured, object handler, int depth)
    {
        if (captured is null || depth <= 0)
        {
            return false;
        }

        if (ReferenceEquals(captured, handler))
        {
            return true;
        }

        foreach (System.Reflection.FieldInfo field in captured.GetType().GetFields(
            System.Reflection.BindingFlags.Instance
            | System.Reflection.BindingFlags.Public
            | System.Reflection.BindingFlags.NonPublic))
        {
            object? value = field.GetValue(captured);

            if (ReferenceEquals(value, handler))
            {
                return true;
            }

            if (value?.GetType().Name.Contains("DisplayClass") == true
                && Wrote(value, handler, depth - 1))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// A layout handler that hears the window resize for its own page, and
    /// takes every subscription of its own down when it goes.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The backend subscribes a layout to the window's size and to a flyout
    /// paned's position, and unsubscribes NEITHER - so a popped page's
    /// handler is asked to lay out for ever after. Its own guard is
    /// <c>if (VirtualView != null)</c> over a getter that THROWS on null, so
    /// the first resize after any page is left kills the process: enter a
    /// group, come back, drag the window edge.
    /// </para>
    /// <para>
    /// And the subscription is only ever made for the FIRST panel that has no
    /// layout above it, which on this arrangement is the page the window
    /// opened with: a PUSHED page was never re-laid-out on a resize at all,
    /// its rows keeping the width they were built at.
    /// </para>
    /// <para>
    /// So the subscription is this handler's own - one per page root, holding
    /// the delegate, removed in <c>DisconnectHandler</c> - and the backend's
    /// leftovers are disconnected there too, by finding the closures whose
    /// captures hold this handler.
    /// </para>
    /// </remarks>
    private sealed class Detaching : LayoutHandler
    {
        /// <summary>
        /// What the backend subscribed this handler to: the window, and the
        /// paned a flyout puts between them.
        /// </summary>
        private readonly List<GObject.Object> _asked = [];

        /// <inheritdoc/>
        public override void SetVirtualView(IView view)
        {
            base.SetVirtualView(view);

            // AFTER the base, which is what puts the layout on the panel: the
            // wrapper stands in front of whatever it left there. Asked twice
            // for one panel - a handler re-used, a view swapped - the second
            // wrap would hide the first, so a panel already wearing one is
            // left alone.
            if (PlatformView is { CrossPlatformLayout: { } inner and not Framed } panel)
            {
                panel.CrossPlatformLayout = new Framed(panel, inner);
            }
        }

        /// <inheritdoc/>
        protected override void ConnectHandler(GtkLayoutPanel platformView)
        {
            base.ConnectHandler(platformView);

            // Queued rather than run here, because the panel is parented a
            // moment later and both walks go upwards.
            GLib.Functions.IdleAdd(0, () =>
            {
                Remember(platformView);
                return false;
            });
        }

        /// <inheritdoc/>
        protected override void DisconnectHandler(GtkLayoutPanel platformView)
        {
            base.DisconnectHandler(platformView);

            foreach (GObject.Object asked in _asked)
            {
                Drop(asked, this);
            }

            _asked.Clear();
        }

        /// <summary>
        /// Notes what the backend subscribed this handler to, so the
        /// subscription can be taken down with the handler.
        /// </summary>
        /// <param name="platformView">The panel this handler drives.</param>
        private void Remember(Widget platformView)
        {
            for (Widget? above = platformView.GetParent(); above is not null; above = above.GetParent())
            {
                if (above is Gtk.Window or Paned)
                {
                    _asked.Add(above);
                }
            }
        }
    }

    /// <summary>
    /// A label handler whose measure leaves room for the spacing between the
    /// characters.
    /// </summary>
    /// <remarks>
    /// Character spacing is written as CSS <c>letter-spacing</c>, which lays a
    /// gap after EVERY character - the last one included - while the natural
    /// width GTK answers leaves the last gap out. A label given exactly that
    /// width is one gap short of its own text, so it wraps: measured, the
    /// gallery's tab strip asked for 79 units for "EXAMPLE 1" at a spacing of
    /// one and drew it on two lines, where the same caption without spacing
    /// measured 71 and fitted. One spacing back is the whole of the
    /// difference.
    /// </remarks>
    private sealed class Spaced : LabelHandler
    {
        /// <summary>
        /// What the backend answers, widened by one character's spacing - and
        /// measured again for the height, since a line that now fits is a line
        /// less tall.
        /// </summary>
        /// <param name="widthConstraint">The room across.</param>
        /// <param name="heightConstraint">The room down.</param>
        /// <returns>What this label wishes for.</returns>
        public override Size GetDesiredSize(double widthConstraint, double heightConstraint)
        {
            Size size = base.GetDesiredSize(widthConstraint, heightConstraint);

            if (VirtualView is not ITextStyle { CharacterSpacing: > 0 } text
                || PlatformView is not Gtk.Label label)
            {
                return size;
            }

            double width = Math.Min(size.Width + text.CharacterSpacing, widthConstraint);

            label.Measure(
                Orientation.Vertical,
                (int)Math.Ceiling(width),
                out int _,
                out int natural,
                out int _,
                out int _);

            double height = Math.Min(natural, heightConstraint);

            if (VirtualView is VisualElement element && element.HeightRequest >= 0)
            {
                height = Math.Min(element.HeightRequest, heightConstraint);
            }

            return new Size(width, Math.Max(1, height));
        }
    }

    /// <summary>
    /// An Image handler that has the page measured again once the picture is
    /// actually there.
    /// </summary>
    /// <remarks>
    /// The backend loads a picture on a task and hands it to the widget from an
    /// IDLE - long after the layout measured a widget that had nothing in it.
    /// A picture has no size until its texture arrives, so the measure answers
    /// the one unit a widget is never given less than, and nothing asks again:
    /// an image with a height and no width is a 1-unit sliver for ever, which
    /// is a starter application whose picture is simply not there. Watching the
    /// widget's own paintable is what says the picture arrived.
    /// </remarks>
    private sealed class Shown : ImageHandler
    {
        /// <inheritdoc/>
        protected override void ConnectHandler(Picture platformView)
        {
            base.ConnectHandler(platformView);

            platformView.OnNotify += (widget, args) =>
            {
                if (args.Pspec.GetName() == "paintable")
                {
                    Mark((Widget)widget);
                }
            };
        }
    }

    /// <summary>
    /// A Border handler whose measure counts the size its author asked for.
    /// </summary>
    /// <remarks>
    /// The backend measures a border as its CONTENT and nothing else, so a
    /// border with no content at all is nothing at all - however wide and tall
    /// it says it is. The analog clock is drawn out of exactly that: its face
    /// is an empty 220-unit border with a round shape, its hub an empty
    /// 12-unit one, and neither was there. What is added back is the pair of
    /// requests, which is what every other platform's measure answers.
    /// </remarks>
    private sealed class Bounded : BorderHandler
    {
        /// <summary>The content's size, with an author's requests winning.</summary>
        /// <param name="widthConstraint">The room across.</param>
        /// <param name="heightConstraint">The room down.</param>
        /// <returns>What this border wishes for.</returns>
        public override Size GetDesiredSize(double widthConstraint, double heightConstraint)
        {
            Size size = base.GetDesiredSize(widthConstraint, heightConstraint);

            if (VirtualView is not VisualElement element)
            {
                return size;
            }

            return new Size(
                element.WidthRequest >= 0 ? Math.Min(element.WidthRequest, widthConstraint) : size.Width,
                element.HeightRequest >= 0 ? Math.Min(element.HeightRequest, heightConstraint) : size.Height);
        }
    }

    /// <summary>
    /// A BoxView handler whose measure answers the author's requests rather
    /// than the size the widget was last arranged to.
    /// </summary>
    /// <summary>A shape, held to the size its author asked for.</summary>
    /// <remarks>
    /// THE SEVEN OUTLINES MAUI DRAWS ARE DRAWN AT NOTHING HERE. A shape's own
    /// desired size on this backend is its geometry's, and a Rectangle or an
    /// Ellipse has none of its own - what says how big one is, everywhere else,
    /// is what the author asked for. Measured on the gallery's *Shapes*, whose
    /// seven 56-unit shapes drew nothing at all while their headings and their
    /// words drew perfectly.
    /// </remarks>
    private sealed class Drawn : ShapeViewHandler
    {
        /// <summary>What this shape wishes for.</summary>
        /// <param name="widthConstraint">The width on offer.</param>
        /// <param name="heightConstraint">And the height.</param>
        /// <returns>The author's requests, held to the constraints.</returns>
        public override Size GetDesiredSize(double widthConstraint, double heightConstraint)
        {
            Size wanted = base.GetDesiredSize(widthConstraint, heightConstraint);

            if (VirtualView is not VisualElement element)
            {
                return wanted;
            }

            double width = element.WidthRequest >= 0 ? element.WidthRequest : wanted.Width;
            double height = element.HeightRequest >= 0 ? element.HeightRequest : wanted.Height;

            return new Size(
                Math.Max(1, Math.Min(width, widthConstraint)),
                Math.Max(1, Math.Min(height, heightConstraint)));
        }

        /// <summary>Paints the outline itself.</summary>
        /// <remarks>
        /// AND NOTHING ON THIS BACKEND DRAWS ONE. A shape's widget is a
        /// drawing area of the right size with no draw function that paints a
        /// path, so the gallery's seven shapes were seven empty rows. What a
        /// shape IS, though, is a path fitted to its bounds - MAUI works that
        /// out on this side, in <c>IShape.PathForBounds</c> - so the drawing
        /// is that path laid into Cairo, filled with the brush and stroked
        /// with the pen the author asked for.
        /// </remarks>
        /// <param name="platformView">The drawing area.</param>
        protected override void ConnectHandler(DrawingArea platformView)
        {
            base.ConnectHandler(platformView);

            platformView.SetDrawFunc((_, cr, width, height) =>
            {
                if (VirtualView is not Microsoft.Maui.Controls.Shapes.Shape shape
                    || width <= 0 || height <= 0)
                {
                    return;
                }

                double pen = shape.StrokeThickness;
                double inset = pen / 2;

                // THE STROKE IS DRAWN ON THE PATH, half of it either side, so
                // the path is fitted to the room LESS that half - which is
                // what keeps a 4-unit outline inside the 56 units it was
                // given rather than clipped by them.
                var room = new Microsoft.Maui.Graphics.Rect(
                    inset, inset, Math.Max(width - pen, 0), Math.Max(height - pen, 0));

                if (((Microsoft.Maui.Graphics.IShape)shape).PathForBounds(room) is not { } path)
                {
                    return;
                }

                Lay(cr, path);

                if (Painted(cr, shape.Fill, room))
                {
                    cr.FillPreserve();
                }

                if (pen > 0 && Painted(cr, shape.Stroke, room))
                {
                    cr.LineWidth = pen;
                    cr.LineCap = shape.StrokeLineCap switch
                    {
                        Microsoft.Maui.Controls.Shapes.PenLineCap.Round => Cairo.LineCap.Round,
                        Microsoft.Maui.Controls.Shapes.PenLineCap.Square => Cairo.LineCap.Square,
                        _ => Cairo.LineCap.Butt,
                    };
                    cr.LineJoin = shape.StrokeLineJoin switch
                    {
                        Microsoft.Maui.Controls.Shapes.PenLineJoin.Round => Cairo.LineJoin.Round,
                        Microsoft.Maui.Controls.Shapes.PenLineJoin.Bevel => Cairo.LineJoin.Bevel,
                        _ => Cairo.LineJoin.Miter,
                    };
                    cr.MiterLimit = shape.StrokeMiterLimit;

                    // THE DASHES ARE COUNTED IN STROKE THICKNESSES, which is
                    // what every other platform here means by them.
                    if (shape.StrokeDashArray is { Count: > 0 } dashes)
                    {
                        cr.SetDash(
                            [.. dashes.Select(one => one * pen)], shape.StrokeDashOffset * pen);
                    }

                    cr.Stroke();
                }

                cr.NewPath();
            });
        }

        /// <summary>
        /// Sets the context's source to what a brush paints with - one colour,
        /// or a gradient along a line or out from a point.
        /// </summary>
        /// <remarks>
        /// A GRADIENT'S POINTS ARE FRACTIONS of the thing being painted, which
        /// is what MAUI means by them everywhere, so they are read against the
        /// room the shape was given rather than taken as device units.
        /// </remarks>
        /// <param name="cr">The context to paint on.</param>
        /// <param name="brush">What the author asked for.</param>
        /// <param name="room">The rectangle the shape is drawn in.</param>
        /// <returns>Whether there is anything to paint with.</returns>
        private static bool Painted(
            Cairo.Context cr, Brush? brush, Microsoft.Maui.Graphics.Rect room)
        {
            switch (brush)
            {
                case SolidColorBrush { Color: { } colour }:
                    cr.SetSourceRgba(colour.Red, colour.Green, colour.Blue, colour.Alpha);
                    return true;

                case LinearGradientBrush line:
                {
                    using var ramp = new Cairo.LinearGradient(
                        room.X + (line.StartPoint.X * room.Width),
                        room.Y + (line.StartPoint.Y * room.Height),
                        room.X + (line.EndPoint.X * room.Width),
                        room.Y + (line.EndPoint.Y * room.Height));

                    Stops(ramp, line.GradientStops);
                    cr.SetSource(ramp);
                    return true;
                }

                case RadialGradientBrush ring:
                {
                    double reach = ring.Radius * Math.Max(room.Width, room.Height);
                    double centreX = room.X + (ring.Center.X * room.Width);
                    double centreY = room.Y + (ring.Center.Y * room.Height);

                    using var ramp = new Cairo.RadialGradient(
                        centreX, centreY, 0, centreX, centreY, Math.Max(reach, 0.0001));

                    Stops(ramp, ring.GradientStops);
                    cr.SetSource(ramp);
                    return true;
                }

                default:
                    return false;
            }
        }

        /// <summary>Lays a brush's stops onto a gradient.</summary>
        /// <param name="ramp">The gradient.</param>
        /// <param name="stops">What the author wrote.</param>
        private static void Stops(Cairo.Gradient ramp, GradientStopCollection stops)
        {
            foreach (GradientStop stop in stops)
            {
                Microsoft.Maui.Graphics.Color colour = stop.Color ?? Colors.Transparent;

                ramp.AddColorStopRgba(
                    stop.Offset, colour.Red, colour.Green, colour.Blue, colour.Alpha);
            }
        }

        /// <summary>Lays a path into a Cairo context, segment by segment.</summary>
        /// <param name="cr">The context.</param>
        /// <param name="path">The path MAUI worked out for these bounds.</param>
        private static void Lay(Cairo.Context cr, Microsoft.Maui.Graphics.PathF path)
        {
            int point = 0;
            int arc = 0;
            Microsoft.Maui.Graphics.PointF at = default;

            for (int operation = 0; operation < path.OperationCount; operation++)
            {
                switch (path.GetSegmentType(operation))
                {
                    case Microsoft.Maui.Graphics.PathOperation.Move:
                        at = path[point];
                        cr.MoveTo(at.X, at.Y);
                        point++;
                        break;

                    case Microsoft.Maui.Graphics.PathOperation.Line:
                        at = path[point];
                        cr.LineTo(at.X, at.Y);
                        point++;
                        break;

                    case Microsoft.Maui.Graphics.PathOperation.Quad:
                    {
                        // CAIRO HAS NO QUADRATIC, so the one control point
                        // becomes the two a cubic takes - which draws exactly
                        // the same curve.
                        Microsoft.Maui.Graphics.PointF from = at;
                        Microsoft.Maui.Graphics.PointF control = path[point];
                        Microsoft.Maui.Graphics.PointF to = path[point + 1];

                        cr.CurveTo(
                            from.X + (2.0 / 3 * (control.X - from.X)),
                            from.Y + (2.0 / 3 * (control.Y - from.Y)),
                            to.X + (2.0 / 3 * (control.X - to.X)),
                            to.Y + (2.0 / 3 * (control.Y - to.Y)),
                            to.X,
                            to.Y);

                        at = to;
                        point += 2;
                        break;
                    }

                    case Microsoft.Maui.Graphics.PathOperation.Cubic:
                        cr.CurveTo(
                            path[point].X, path[point].Y,
                            path[point + 1].X, path[point + 1].Y,
                            path[point + 2].X, path[point + 2].Y);
                        at = path[point + 2];
                        point += 3;
                        break;

                    case Microsoft.Maui.Graphics.PathOperation.Arc:
                    {
                        // An arc is two points and the angles the path holds
                        // beside them: a circle scaled into that rectangle.
                        Microsoft.Maui.Graphics.PointF corner = path[point];
                        Microsoft.Maui.Graphics.PointF far = path[point + 1];
                        float start = path.GetArcAngle(arc);
                        float end = path.GetArcAngle(arc + 1);
                        bool clockwise = path.GetArcClockwise(arc / 2);

                        arc += 2;

                        double halfWidth = (far.X - corner.X) / 2;
                        double halfHeight = (far.Y - corner.Y) / 2;
                        double centreX = corner.X + halfWidth;
                        double centreY = corner.Y + halfHeight;

                        cr.Save();
                        cr.Translate(centreX, centreY);
                        cr.Scale(Math.Max(halfWidth, 0.0001), Math.Max(halfHeight, 0.0001));

                        double from = -start * Math.PI / 180;
                        double to = -end * Math.PI / 180;

                        if (clockwise) { cr.Arc(0, 0, 1, from, to); }
                        else { cr.ArcNegative(0, 0, 1, from, to); }

                        cr.Restore();
                        point += 2;
                        break;
                    }

                    case Microsoft.Maui.Graphics.PathOperation.Close:
                        cr.ClosePath();
                        break;
                }
            }
        }
    }

    private sealed class Requested : BoxViewHandler
    {
        /// <summary>
        /// The author's requests, held to the constraints; 40 units - MAUI's
        /// own default for a BoxView - where a side was not given.
        /// </summary>
        /// <param name="widthConstraint">The width on offer.</param>
        /// <param name="heightConstraint">And the height.</param>
        /// <returns>What this box wishes for.</returns>
        public override Size GetDesiredSize(double widthConstraint, double heightConstraint)
        {
            double width = 40;
            double height = 40;

            if (VirtualView is VisualElement element)
            {
                if (element.WidthRequest >= 0)
                {
                    width = element.WidthRequest;
                }

                if (element.HeightRequest >= 0)
                {
                    height = element.HeightRequest;
                }
            }

            return new Size(
                Math.Max(1, Math.Min(width, widthConstraint)),
                Math.Max(1, Math.Min(height, heightConstraint)));
        }

        /// <summary>Paints the box itself, corners and all.</summary>
        /// <remarks>
        /// A BOX WITH ROUNDED CORNERS IS DRAWN SQUARE HERE. The backend paints
        /// a box view by filling its drawing area with the colour and knows
        /// nothing about <c>CornerRadius</c> - measured on the gallery's
        /// *Motion*, whose panels ask for 28 and were drawn with corners as
        /// sharp as the page. So the drawing is this side's: one rounded
        /// rectangle in the view's own colour, which is the whole of what a
        /// box view is.
        /// </remarks>
        /// <param name="platformView">The drawing area.</param>
        protected override void ConnectHandler(DrawingArea platformView)
        {
            base.ConnectHandler(platformView);

            platformView.SetDrawFunc((_, cr, width, height) =>
            {
                if (VirtualView is not BoxView box || box.Color is not { } colour)
                {
                    return;
                }

                // FOUR CORNERS, each held to half the shorter side - which is
                // what a radius bigger than the box means everywhere else.
                double most = Math.Min(width, height) / 2;
                Microsoft.Maui.CornerRadius corners = box.CornerRadius;

                double Held(double asked) => Math.Min(Math.Max(asked, 0), most);

                double topLeft = Held(corners.TopLeft);
                double topRight = Held(corners.TopRight);
                double bottomRight = Held(corners.BottomRight);
                double bottomLeft = Held(corners.BottomLeft);

                if (topLeft + topRight + bottomRight + bottomLeft > 0)
                {
                    const double Half = Math.PI / 2;

                    cr.NewSubPath();
                    cr.Arc(width - topRight, topRight, topRight, -Half, 0);
                    cr.Arc(width - bottomRight, height - bottomRight, bottomRight, 0, Half);
                    cr.Arc(bottomLeft, height - bottomLeft, bottomLeft, Half, Math.PI);
                    cr.Arc(topLeft, topLeft, topLeft, Math.PI, Math.PI + Half);
                    cr.ClosePath();
                }
                else
                {
                    cr.Rectangle(0, 0, width, height);
                }

                cr.SetSourceRgba(colour.Red, colour.Green, colour.Blue, colour.Alpha);
                cr.Fill();
            });
        }
    }
}
