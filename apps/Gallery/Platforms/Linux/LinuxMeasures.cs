using Gtk;
using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace Gallery;

/// <summary>
/// Keeps the backend's measures honest: a stale layout is laid out again, and
/// a drawn view stops wishing for the size it was last given.
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
/// </remarks>
internal static class LinuxMeasures
{
    /// <summary>
    /// The panels whose subtree asked to be laid out again, taken in one idle
    /// pass so a burst of invalidations costs one layout.
    /// </summary>
    private static readonly HashSet<GtkLayoutPanel> Stale = [];

    /// <summary>Arms the invalidation pass and the BoxView measure.</summary>
    /// <param name="builder">Whose handler registry takes the replacement.</param>
    internal static void Install(MauiAppBuilder builder)
    {
        builder.ConfigureMauiHandlers(handlers =>
            handlers.AddHandler<BoxView, Requested>());

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
        if (handler.PlatformView is not Widget widget)
        {
            return;
        }

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
