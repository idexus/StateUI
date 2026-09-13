// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Reflection;
using Gtk;
using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Takes a popped page's signal closures down on the thread GTK owns, keeps
/// its wrappers alive until GTK has let the page go, and gives the toolbar's
/// buttons the pictures their items asked for.
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
/// each widget that LEFT the stack - and each toolbar button the nav bar
/// dropped, those being rebuilt with a click closure apiece on every move -
/// has the closures the bindings cache on its
/// handle - its event controllers' too - disposed HERE, on the main thread:
/// disposing one disconnects the signal and frees the native closure where
/// gsignal is safe to enter, and the finalizer then has nothing to race. The
/// native widget tree is not touched; a field name that stops resolving
/// leaves the closures to the finalizer, as the backend alone does.
/// </para>
/// <para>
/// A TOOLBAR ITEM'S PICTURE is the other half of the same moment. The backend
/// builds each item as <c>Button.NewWithLabel(Text)</c> and reads its
/// <c>IconImageSource</c> nowhere, so a button that is a picture everywhere
/// else is the item's TEXT here - the gallery's way home read "Home" instead
/// of showing its house. The buttons are rebuilt on every navigation, in the
/// order of the page's own items, so this is where each one is given its
/// picture, with the text becoming the tooltip it always meant.
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
[System.Runtime.Versioning.SupportedOSPlatform("linux")]
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
                Box? toolbar = ToolbarOf(handler.PlatformView);
                List<Widget> before = stack is null ? [] : ChildrenOf(stack);

                // The nav bar's toolbar buttons are REBUILT on every
                // navigation, each wearing a click closure, and the removed
                // ones are dropped the same way a page is.
                if (toolbar is not null)
                {
                    before.AddRange(ChildrenOf(toolbar));
                }

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

                if (toolbar is not null)
                {
                    foreach (Widget child in ChildrenOf(toolbar))
                    {
                        kept.Add(child.Handle.DangerousGetHandle());
                    }
                }

                Furnish(toolbar, view, args);

                List<GObject.Object> held = [];

                foreach (Widget old in before)
                {
                    if (!kept.Contains(old.Handle.DangerousGetHandle()))
                    {
                        Release(old, held);
                    }
                }

                if (held.Count > 0)
                {
                    Recent.Add(held);
                    (view as VisualElement)?.Dispatcher.DispatchDelayed(
                        Grace, () => Recent.Remove(held));
                }
            };

    /// <summary>How wide and tall a toolbar item's picture is drawn.</summary>
    private const int Icon = 22;

    /// <summary>
    /// Gives each toolbar button the picture its item asked for, and the bar's
    /// own colour where it stays a caption.
    /// </summary>
    /// <remarks>
    /// The buttons arrive in the order of the page's own items, which is how
    /// each is matched to the item it was built from. A picture becomes the
    /// button's whole content and the caption becomes its tooltip - a toolbar
    /// item with an icon says its words on hover everywhere. Without a picture
    /// the caption stays, and is painted in <c>BarTextColor</c>, which the
    /// backend gives the bar's title and Back button and no one else.
    /// </remarks>
    /// <param name="toolbar">The box the buttons were just rebuilt in.</param>
    /// <param name="view">The navigation page, for the bar's colour.</param>
    /// <param name="args">The request, which carries the stack it arrived at.</param>
    private static void Furnish(Box? toolbar, IStackNavigationView view, object? args)
    {
        if (toolbar is null
            || args is not NavigationRequest request
            || request.NavigationStack.LastOrDefault() is not Page page)
        {
            return;
        }

        Color? ink = (view as NavigationPage)?.BarTextColor;
        int index = 0;

        for (Widget? child = toolbar.GetFirstChild(); child is not null; child = child.GetNextSibling())
        {
            if (child is not Gtk.Button button || index >= page.ToolbarItems.Count)
            {
                continue;
            }

            ToolbarItem item = page.ToolbarItems[index++];

            if (Drawn(item) is string file)
            {
                Gtk.Image picture = Gtk.Image.NewFromFile(file);

                picture.SetPixelSize(Icon);
                button.SetChild(picture);
                button.SetTooltipText(item.Text ?? "");
            }
            else if (ink is { } colour)
            {
                LinuxStyling.Ink(button, colour);
            }
        }
    }

    /// <summary>
    /// The file one item's picture is in, where it has one that is there.
    /// </summary>
    /// <remarks>
    /// A file source and nothing else: a font glyph or a stream is a picture
    /// this would have to build rather than open, and the applications here
    /// name files.
    /// </remarks>
    /// <param name="item">The toolbar item to read.</param>
    private static string? Drawn(ToolbarItem item)
    {
        if (item.IconImageSource is not FileImageSource source
            || string.IsNullOrEmpty(source.File))
        {
            return null;
        }

        string path = Path.Combine(AppContext.BaseDirectory, source.File);

        return File.Exists(path) ? path : null;
    }

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

    /// <summary>The toolbar box at the end of the handler's nav bar.</summary>
    /// <param name="container">The handler's platform view.</param>
    private static Box? ToolbarOf(Box container) =>
        container.GetFirstChild() is Box navBar ? navBar.GetLastChild() as Box : null;

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

        for (uint i = 0; i < controllers.GetNItems(); i++)
        {
            if (controllers.GetObject(i) is GObject.Object controller)
            {
                held.Add(controller);
                Dispose(controller.Handle);
            }
        }

        // The observer model goes AT ONCE - kept around, the widget pokes it
        // during its own teardown, after the model's wrapper may already be
        // gone, which is the reference-to-a-collected-wrapper abort again.
        if (controllers is GObject.Object model)
        {
            model.Dispose();
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
