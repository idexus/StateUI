using System.Reflection;
using Gtk;
using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;

namespace Gallery;

/// <summary>
/// Takes a popped page's signal closures down on the thread GTK owns, and
/// keeps its wrappers alive until GTK has let the page go.
/// </summary>
/// <remarks>
/// <para>
/// On a pop the backend removes the page's widget from its <c>Gtk.Stack</c>
/// and drops every managed wrapper for the garbage collector. The bindings
/// then invalidate each still-connected signal closure from the FINALIZER
/// thread - of a widget's teardown only the toggle-ref half is marshalled to
/// the main context - while the main loop is destroying the same widgets, and
/// gsignal is not built for two threads: a session that navigates dies within
/// a few hundred pushes, on <c>invalid_closure_notify: assertion failed
/// (handler != NULL)</c> or on a corrupted heap inside
/// <c>g_object_add_toggle_ref</c>.
/// </para>
/// <para>
/// So the closures are not left to the finalizer. After every navigation,
/// each widget that LEFT the stack has the closures the bindings cache on its
/// handle - its event controllers' too - disposed HERE, on the main thread:
/// disposing one disconnects the signal and frees the native closure where
/// gsignal is safe to enter, and the finalizer then has nothing to race. The
/// native widget tree is not touched; a field name that stops resolving
/// leaves the closures to the finalizer, as the backend alone does.
/// </para>
/// <para>
/// The WRAPPERS of that page are then held strongly for a few seconds. A
/// closure kept its widget's wrapper alive; with the closures gone the
/// wrapper is collectible while the stack's slide transition can still
/// re-reference the widget, and the bindings answer a reference to a
/// collected wrapper by throwing straight through a native callback, which
/// aborts the process. Holding the wrappers past the transition removes the
/// condition; letting go afterwards takes the ordinary, marshalled path.
/// </para>
/// </remarks>
internal static class LinuxNavigation
{
    /// <summary>
    /// Where the bindings cache a wrapper's connected closures. Null where a
    /// future release renames it, and teardown then behaves as the backend
    /// leaves it.
    /// </summary>
    private static readonly FieldInfo? Closures =
        typeof(GObject.Internal.ObjectHandle).GetField(
            "closures", BindingFlags.Instance | BindingFlags.NonPublic);

    /// <summary>The wrappers of popped pages GTK may still be letting go of.</summary>
    private static readonly HashSet<List<GObject.Object>> Recent = [];

    /// <summary>How long a popped page's wrappers are held.</summary>
    /// <remarks>
    /// The stack's slide runs 250 ms; this is that with a wide margin, and it
    /// bounds what a navigation burst can keep alive to a few pages.
    /// </remarks>
    private static readonly TimeSpan Grace = TimeSpan.FromSeconds(5);

    /// <summary>Arms every navigation page in the application.</summary>
    internal static void Install() =>
        NavigationPageHandler.CommandMapper[nameof(IStackNavigation.RequestNavigation)] =
            (handler, view, args) =>
            {
                Stack? stack = StackOf(handler.PlatformView);
                List<Widget> before = stack is null ? [] : ChildrenOf(stack);

                NavigationPageHandler.MapRequestNavigation(handler, view, args);

                if (stack is null)
                {
                    return;
                }

                HashSet<nint> kept = [];

                foreach (Widget child in ChildrenOf(stack))
                {
                    kept.Add(child.Handle.DangerousGetHandle());
                }

                foreach (Widget old in before)
                {
                    if (!kept.Contains(old.Handle.DangerousGetHandle()))
                    {
                        List<GObject.Object> held = [];
                        Release(old, held);
                        Recent.Add(held);
                        (view as VisualElement)?.Dispatcher.DispatchDelayed(
                            Grace, () => Recent.Remove(held));
                    }
                }
            };

    /// <summary>The page stack inside the handler's own chrome.</summary>
    /// <param name="container">The handler's platform view.</param>
    private static Stack? StackOf(Box container)
    {
        for (Widget? child = container.GetFirstChild(); child is not null; child = child.GetNextSibling())
        {
            if (child is Stack stack)
            {
                return stack;
            }
        }

        return null;
    }

    /// <summary>One widget's children, read before anything changes them.</summary>
    /// <param name="parent">Whose children.</param>
    private static List<Widget> ChildrenOf(Widget parent)
    {
        List<Widget> children = [];

        for (Widget? child = parent.GetFirstChild(); child is not null; child = child.GetNextSibling())
        {
            children.Add(child);
        }

        return children;
    }

    /// <summary>
    /// Disposes every cached closure under one widget, its controllers'
    /// included, and collects the wrappers touched.
    /// </summary>
    /// <param name="root">The widget the page left behind.</param>
    /// <param name="held">Where its wrappers are kept for the grace period.</param>
    private static void Release(Widget root, List<GObject.Object> held)
    {
        held.Add(root);

        foreach (Widget child in ChildrenOf(root))
        {
            Release(child, held);
        }

        Gio.ListModel controllers = root.ObserveControllers();

        if (controllers is GObject.Object model)
        {
            held.Add(model);
        }

        for (uint i = 0; i < controllers.GetNItems(); i++)
        {
            if (controllers.GetObject(i) is GObject.Object controller)
            {
                held.Add(controller);
                Dispose(controller.Handle);
            }
        }

        Dispose(root.Handle);
    }

    /// <summary>Disposes the closures cached on one handle, on this thread.</summary>
    /// <param name="handle">Whose closures.</param>
    private static void Dispose(GObject.Internal.ObjectHandle handle)
    {
        if (Closures?.GetValue(handle) is Dictionary<Delegate, GObject.Closure> cached)
        {
            foreach (GObject.Closure closure in cached.Values.ToList())
            {
                closure.Dispose();
            }

            cached.Clear();
        }
    }
}
