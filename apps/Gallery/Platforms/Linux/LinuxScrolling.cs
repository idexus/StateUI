using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;

namespace Gallery;

/// <summary>
/// Lets a scroller ask for the room its content needs.
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
/// </remarks>
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
