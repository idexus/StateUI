// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Reflection;
using System.Runtime.CompilerServices;
using Gtk;
using Microsoft.Maui.Handlers;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Wires the gesture recognizers a view carries to the widget drawing it.
/// </summary>
/// <remarks>
/// <para>
/// The GTK4 backend has the whole of this - <c>GtkGestureExtensions</c> turns
/// every recognizer MAUI has into a GTK event controller - and nothing in the
/// package ever calls it: <c>AttachGestures</c> has no caller anywhere in the
/// assembly, so without this a tap on a view is heard by no one. Hanging it on
/// <c>ViewHandler.ViewMapper</c>, MAUI's own and the bottom of every handler's
/// chain here, arms every view there is.
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
[System.Runtime.Versioning.SupportedOSPlatform("linux")]
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
    /// The three a POINTER is told through - internal to MAUI, and plain
    /// methods rather than an interface's, so a lookup by name finds them.
    /// </summary>
    private static readonly MethodInfo? SendPointerEntered = Pointer("SendPointerEntered");

    private static readonly MethodInfo? SendPointerMoved = Pointer("SendPointerMoved");

    private static readonly MethodInfo? SendPointerExited = Pointer("SendPointerExited");

    /// <summary>One of the pointer recognizer's own reporting methods.</summary>
    /// <param name="name">Which one.</param>
    /// <returns>The method, or nothing where a release renamed it.</returns>
    private static MethodInfo? Pointer(string name) =>
        typeof(PointerGestureRecognizer).GetMethod(
            name, BindingFlags.Instance | BindingFlags.NonPublic);

    /// <summary>
    /// Tells one of them, with as many arguments as it happens to take: the
    /// sender, where the pointer is, and - where a release added one - the
    /// platform's own event, which this has nothing to hand over.
    /// </summary>
    /// <param name="method">Which report.</param>
    /// <param name="pointer">The recognizer being told.</param>
    /// <param name="element">The view it belongs to.</param>
    /// <param name="x">Where the pointer is, across.</param>
    /// <param name="y">And down.</param>
    private static void Told(
        MethodInfo? method, PointerGestureRecognizer pointer, View element, double x, double y)
    {
        if (method is null)
        {
            return;
        }

        Func<IElement?, Point?> at = _ => new Point(x, y);
        object?[] said = method.GetParameters().Length switch
        {
            2 => [element, at],
            3 => [element, at, null],
            _ => [element, at, null, null],
        };

        method.Invoke(pointer, said);
    }

    /// <summary>Which pan this is, so its three reports belong together.</summary>
    /// <remarks>
    /// A pan is told through <c>IPanGestureController</c>, which the recognizer
    /// implements EXPLICITLY - so the three methods are reached by a CAST and
    /// are not on the type under those names at all: a lookup for
    /// <c>SendPan</c> among its own methods finds nothing, and the drag then
    /// reports to nobody (measured - the controller fired 49 updates and every
    /// one of them went nowhere).
    /// </remarks>
    private static int _panning;

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

            // HEARD BEFORE THE SCROLLER UNDER IT. A scrolled window has
            // gestures of its own and takes the press first, so a tap on a
            // view inside one is never told about - measured on the gallery's
            // home page, where the invisible scroller over the run of cards
            // ate every tap on the card in front, twenty-five of them across
            // the whole run.
            click.SetPropagationPhase(PropagationPhase.Capture);

            widget.AddController(click);
            mine.Add(click);
        }

        foreach (IGestureRecognizer recognizer in element.GestureRecognizers)
        {
            if (recognizer is not PanGestureRecognizer pan)
            {
                continue;
            }

            // A DRAG IS THE OTHER HALF THE BACKEND LEAVES SILENT. Its own
            // attach makes no controller a pointer drag ever reaches, so a
            // view told `.panX($x)` answered nothing at all: measured on the
            // gallery, where dragging the box of *Pan* left it reading
            // `Moved 0, 0`, and the ring of *A layout of your own* would not
            // turn by hand.
            GestureDrag drag = GestureDrag.New();
            int id = ++_panning;

            var told = (IPanGestureController)pan;

            drag.OnDragBegin += (_, _) => told.SendPanStarted(element, id);

            drag.OnDragUpdate += (sender, _) =>
            {
                // GTK answers the offset from where the fingers went down,
                // which is what MAUI means by a pan's total distance.
                if (sender.GetOffset(out double x, out double y))
                {
                    told.SendPan(element, x, y, id);
                }
            };

            drag.OnDragEnd += (_, _) => told.SendPanCompleted(element, id);

            widget.AddController(drag);
            mine.Add(drag);
        }

        foreach (IGestureRecognizer recognizer in element.GestureRecognizers)
        {
            if (recognizer is not PointerGestureRecognizer pointer)
            {
                continue;
            }

            // WHAT A TOUCH-ONLY DEVICE NEVER SENDS, and what this backend never
            // sends either: a hover is a motion controller's, and nothing here
            // makes one - measured on the gallery's *Pointer*, whose box read
            // `last: nothing yet` however far a mouse was walked over it.
            // WHAT A TOUCH-ONLY DEVICE NEVER SENDS, and what this backend never
            // sends either: a hover is a motion controller's, and nothing here
            // makes one - measured on the gallery's *Pointer*, whose box read
            // `last: nothing yet` however far a mouse was walked over it.
            EventControllerMotion motion = EventControllerMotion.New();

            motion.OnEnter += (_, args) => Told(SendPointerEntered, pointer, element, args.X, args.Y);
            motion.OnMotion += (_, args) => Told(SendPointerMoved, pointer, element, args.X, args.Y);
            motion.OnLeave += (_, _) => Told(SendPointerExited, pointer, element, 0, 0);

            widget.AddController(motion);
            mine.Add(motion);
        }

        if (mine.Count > 0)
        {
            Added.Add(widget, mine);
        }
    }
}
