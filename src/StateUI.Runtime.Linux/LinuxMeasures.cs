// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Gtk;
using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;
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
    private static readonly HashSet<GtkLayoutPanel> Stale = [];

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
    }

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
        // The OUTERMOST panel that owns a layout - the page's root, or the
        // whole flyout's - so star rows and fills above the view are counted
        // again, not just the view's own parent.
        GtkLayoutPanel? top = null;

        for (Widget? above = widget; above is not null; above = above.GetParent())
        {
            if (above is GtkLayoutPanel panel && panel.CrossPlatformLayout is not null)
            {
                top = panel;
            }
        }

        if (top is null)
        {
            widget.QueueResize();
            return;
        }

        bool scheduled = Stale.Count > 0;

        Stale.Add(top);

        if (!scheduled)
        {
            GLib.Functions.IdleAdd(0, () =>
            {
                Sweep();
                return false;
            });
        }
    }

    /// <summary>Lays every marked root out again at its current size.</summary>
    private static void Sweep()
    {
        GtkLayoutPanel[] roots = [.. Stale];

        Stale.Clear();

        foreach (GtkLayoutPanel root in roots)
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

            root.CrossPlatformMeasure(width, height);
            root.CrossPlatformArrange(new Rect(0, 0, width, height));
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
    }
}
