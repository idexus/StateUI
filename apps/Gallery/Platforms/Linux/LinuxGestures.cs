using System.Reflection;
using System.Runtime.CompilerServices;
using Gtk;
using Microsoft.Maui.Handlers;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace Gallery;

/// <summary>
/// Wires the gesture recognizers a view carries to the widget drawing it.
/// </summary>
/// <remarks>
/// <para>
/// The GTK4 backend has the whole of this - <c>GtkGestureExtensions</c> turns
/// every recognizer MAUI has into a GTK event controller - and **nothing in the
/// package ever calls it**: <c>AttachGestures</c> has no caller anywhere in the
/// assembly, so a tap on a view is heard by no one. That is why every row of the
/// gallery was dead. Hanging it on <c>ViewHandler.ViewMapper</c>, MAUI's own and
/// the bottom of every handler's chain here, arms every view there is.
/// </para>
/// <para>
/// A TAP needs the second half. The backend's own tap controller executes the
/// recognizer's <c>Command</c> and stops there, so a <c>Tapped</c> HANDLER -
/// which is what this library subscribes and what MAUI's own documentation
/// writes - is never raised. This raises it, through the same internal
/// <c>Send…</c> method the backend itself reaches for on a pan, and honours
/// <c>NumberOfTapsRequired</c> while it is there.
/// </para>
/// </remarks>
internal static class LinuxGestures
{
    /// <summary>
    /// <c>TapGestureRecognizer.SendTapped</c>, which is internal to MAUI and is
    /// the only way to raise its event from outside. Null where a future release
    /// renames it, and taps then behave as the backend leaves them.
    /// </summary>
    private static readonly MethodInfo? SendTapped =
        typeof(TapGestureRecognizer).GetMethod(
            "SendTapped", BindingFlags.Instance | BindingFlags.NonPublic);

    /// <summary>
    /// The tap controllers this has added, so they can be taken back - keyed by
    /// the widget for the reason LinuxStyling gives about addresses.
    /// </summary>
    private static readonly ConditionalWeakTable<Widget, List<EventController>> Added = [];

    /// <summary>Arms every handler in the application.</summary>
    internal static void Install() =>
        ViewHandler.ViewMapper.AppendToMapping("StateUILinuxGestures", (handler, view) =>
        {
            if (handler.PlatformView is Widget widget)
            {
                Attach(widget, view);
            }
        });

    /// <summary>Gives one widget the gestures its view asks for.</summary>
    /// <param name="widget">What is drawn.</param>
    /// <param name="view">What described it.</param>
    private static void Attach(Widget widget, IView view)
    {
        // Pan, swipe, pinch and pointer are the backend's own and work; it
        // clears what it added last before adding again, so this is safe to
        // run on every message.
        GtkGestureExtensions.AttachGestures(widget, view);

        if (Added.TryGetValue(widget, out List<EventController>? before))
        {
            Added.Remove(widget);

            foreach (EventController controller in before)
            {
                widget.RemoveController(controller);
            }
        }

        if (view is not View element)
        {
            return;
        }

        List<EventController> mine = [];

        foreach (IGestureRecognizer recognizer in element.GestureRecognizers)
        {
            if (recognizer is not TapGestureRecognizer tap)
            {
                continue;
            }

            GestureClick click = GestureClick.New();

            click.OnReleased += (_, args) =>
            {
                // GTK counts the presses of a run and reports each one, so a
                // recognizer wanting two hears the second and not the first.
                if (args.NPress == Math.Max(tap.NumberOfTapsRequired, 1))
                {
                    SendTapped?.Invoke(tap, [element, null]);
                }
            };

            widget.AddController(click);
            mine.Add(click);
        }

        if (mine.Count > 0)
        {
            Added.Add(widget, mine);
        }
    }
}
