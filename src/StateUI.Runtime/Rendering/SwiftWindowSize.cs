using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Opens a Mac Catalyst window at the size the Swift side asked for.
/// </summary>
/// <remarks>
/// <para>
/// MAUI does not implement <c>Window.Width</c> and <c>Window.Height</c> on Mac
/// Catalyst: assigning them changes nothing, from <c>CreateWindow</c> and from
/// <c>Activated</c> alike, and the property is overwritten with whatever the
/// platform decided. Measured with plain C# as well, so it is MAUI's gap rather
/// than this boundary's.
/// </para>
/// <para>
/// What Catalyst DOES honour is the size restriction behind
/// <c>MaximumWidth</c> - it takes effect at once and forces the window down to
/// it. So an opening size is a maximum imposed for as long as it takes to bite,
/// and then given back. This is the handler MAUI did not write, in the one place
/// that can write it.
/// </para>
/// <para>
/// <b>Releasing it is the whole difficulty, and it was measured rather than
/// guessed.</b> Let go the moment the platform reports the size and the window
/// springs back to where it came from; let go on the NEXT turn of the run loop
/// and it stays. So the trigger is a state check - the platform's own frame is
/// at or inside the cap - followed by one <c>Dispatch</c>. Not a timer: a
/// wall-clock delay works too and is a race on a slower machine.
/// </para>
/// <para>
/// Everywhere else this does nothing. Windows applies Width and Height itself,
/// and a phone has no window to size.
/// </para>
/// </remarks>
internal static class SwiftWindowSize
{
#if MACCATALYST
    /// <summary>
    /// Whether this window has already been opened at the size it was given.
    /// Attached to the window, so it lives exactly as long as the window does.
    /// </summary>
    private static readonly BindableProperty AskedProperty = BindableProperty.CreateAttached(
        "SwiftWindowSizeAsked",
        typeof(bool),
        typeof(SwiftWindowSize),
        defaultValue: false);
#endif

    /// <summary>
    /// Asks the platform to open <paramref name="window"/> at the width and
    /// height <paramref name="node"/> carries, where the platform needs asking.
    /// </summary>
    /// <remarks>
    /// Runs at most once per window: an opening size is about opening, and a
    /// window the user has since resized is not something a later render should
    /// snatch back.
    /// </remarks>
    public static void OpenAtRequestedSize(Window window, SwiftNode node)
    {
#if MACCATALYST
        if ((bool)window.GetValue(AskedProperty))
        {
            return;
        }

        double width = node.GetNumber(SwiftProp.Width) ?? double.PositiveInfinity;
        double height = node.GetNumber(SwiftProp.Height) ?? double.PositiveInfinity;

        if (double.IsPositiveInfinity(width) && double.IsPositiveInfinity(height))
        {
            return;
        }

        window.SetValue(AskedProperty, true);

        // What the maximum is meant to be once this is over - whatever the tree
        // asked for, which ApplyWindow has already assigned, or no maximum at
        // all. Read before the cap goes on, or the cap would become permanent.
        double restoreWidth = window.MaximumWidth;
        double restoreHeight = window.MaximumHeight;

        window.MaximumWidth = Math.Min(width, restoreWidth);
        window.MaximumHeight = Math.Min(height, restoreHeight);

        EventHandler? release = null;

        release = (_, _) =>
        {
            // The platform's own frame, not Window.Width: that one holds
            // whatever was last assigned to it, including by us, and would
            // report success before anything had happened.
            if (window.Handler?.PlatformView is not UIKit.UIWindow platform
                || platform.Frame.Width > window.MaximumWidth + 1
                || platform.Frame.Height > window.MaximumHeight + 1)
            {
                return;
            }

            window.SizeChanged -= release;

            window.Dispatcher.Dispatch(() =>
            {
                window.MaximumWidth = restoreWidth;
                window.MaximumHeight = restoreHeight;
            });
        };

        window.SizeChanged += release;
#endif
    }
}
