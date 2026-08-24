#if WINDOWS
using Microsoft.UI.Xaml.Controls;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// What a scroller is told about the platform's own scrolling on Windows.
/// </summary>
/// <remarks>
/// <para>
/// A DESK IS NOT A TOUCHSCREEN. WinUI scrolls a ScrollViewer through
/// DirectManipulation, and a precision touchpad PANS it rather than turning a
/// wheel - so the inertia one run of the fingers leaves standing has to be
/// spent before the next run is felt at all, which reads as a point that has to
/// be crossed before the content goes the way the fingers are going. The
/// inertia is therefore taken away, and that is the whole of the fix.
/// </para>
/// <para>
/// THE SECOND HALF IS ONLY THERE BECAUSE OF THE FIRST. Inertia is also what
/// damps the elastic edge, so without it a device's own tail - the wheel events
/// that keep arriving after the fingers have gone - each over-pan the end and
/// snap straight back, and the end rings. A wheel event that has nowhere left
/// to go is dropped, that being the only kind which can over-pan.
/// </para>
/// <para>
/// Dropping it costs nothing, because a WinUI ScrollViewer wound to its end
/// takes the wheel and keeps it: a scroller inside another one never hands it
/// upwards, so there is no chaining to lose. Only the over-pan goes.
/// </para>
/// <para>
/// Nothing here aims a scroller anywhere or decides where it comes to rest, and
/// a wheel that CAN scroll is never touched. The rounds that tried to take the
/// wheel over, and why they were taken back off, are in notes/lists.md.
/// </para>
/// </remarks>
internal static class ScrollTuning
{
    /// <summary>Tells one scroller both things, once it has a platform view.</summary>
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

            viewer.IsScrollInertiaEnabled = false;
            Drop(viewer);
        };
    }

    /// <summary>
    /// Listens for a wheel event that has nowhere left to go, which is the only
    /// kind that can over-pan.
    /// </summary>
    /// <remarks>
    /// On the CONTENT, because a handler there runs before the ScrollViewer's
    /// own class handler while one on the viewer itself would run after it. The
    /// content is not there yet when the handler is, so a scroller without one
    /// waits for <c>Loaded</c> - which can arrive more than once, hence the
    /// guard.
    /// </remarks>
    /// <param name="viewer">The platform scroller.</param>
    private static void Drop(ScrollViewer viewer)
    {
        bool hooked = false;

        void Hook(Microsoft.UI.Xaml.UIElement content)
        {
            if (hooked)
            {
                return;
            }

            hooked = true;
            content.PointerWheelChanged += (_, e) => Full(viewer, e);
        }

        if (viewer.Content is Microsoft.UI.Xaml.UIElement now)
        {
            Hook(now);
            return;
        }

        viewer.Loaded += (_, _) =>
        {
            if (viewer.Content is Microsoft.UI.Xaml.UIElement later)
            {
                Hook(later);
            }
        };
    }

    /// <summary>Marks a wheel event handled where the scroller under it is full.</summary>
    /// <param name="viewer">The scroller under the pointer.</param>
    /// <param name="e">The wheel event.</param>
    private static void Full(ScrollViewer viewer, Microsoft.UI.Xaml.Input.PointerRoutedEventArgs e)
    {
        // Ctrl and the wheel is a zoom on this platform, and never a scroll.
        if (e.KeyModifiers.HasFlag(Windows.System.VirtualKeyModifiers.Control))
        {
            return;
        }

        Microsoft.UI.Input.PointerPointProperties properties = e.GetCurrentPoint(viewer).Properties;
        int delta = properties.MouseWheelDelta;

        if (delta == 0)
        {
            return;
        }

        // WHICH WAY THIS SCROLLER ACTUALLY RUNS. A sideways wheel is always
        // about the horizontal, and an ordinary one is read across by a
        // scroller with no vertical of its own - which is what a run of cards
        // is.
        bool sideways = properties.IsHorizontalMouseWheel || viewer.ScrollableHeight <= 0;
        double offset = sideways ? viewer.HorizontalOffset : viewer.VerticalOffset;
        double most = sideways ? viewer.ScrollableWidth : viewer.ScrollableHeight;

        // Nothing to scroll either way, so the event is somebody else's.
        if (most <= 0)
        {
            return;
        }

        // A sideways wheel counts UP towards the right; an ordinary one counts
        // DOWN as it goes on.
        bool onward = properties.IsHorizontalMouseWheel ? delta > 0 : delta < 0;

        if (onward ? offset >= most - 0.5 : offset <= 0.5)
        {
            e.Handled = true;
        }
    }
}
#endif
