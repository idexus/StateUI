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

        // On the ORIENTATION, which is the property that decides it and the
        // one that runs again if an author ever changes their mind.
        ScrollViewHandler.Mapper.AppendToMapping<IScrollView, ScrollViewHandler>(
            "Orientation",
            (handler, view) =>
                handler.PlatformView?.SetPropagateNaturalHeight(
                    view.Orientation is ScrollOrientation.Horizontal));
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
