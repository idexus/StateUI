// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Reflection;
using System.Runtime.InteropServices;
using Gtk;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace StateUI.Runtime.Linux;

/// <summary>
/// What a turned, scaled or moved view is drawn by, what it is drawn OVER, and
/// what keeps it from freeing its graphene point twice.
/// </summary>
/// <remarks>
/// <para>
/// The backend's <c>ApplyTransform</c> allocates a graphene point through the
/// bindings and calls <c>graphene_point_free</c> on it by hand - but the
/// wrapper it allocated THROUGH owns the point too, and frees it again when
/// the garbage collector reaches it. Every view wearing a <c>Scale</c>,
/// <c>Rotation</c> or translation frees its point twice, and the process dies
/// on a corrupted heap at the collection after the first press of a card that
/// dips - deterministically, with nothing said.
/// </para>
/// <para>
/// The pair cannot be separated from C#: both frees are the backend's and the
/// bindings' own. What can be done is to make the EXPLICIT one say nothing:
/// <c>graphene-shim.c</c> builds into a library defining that one symbol as a
/// no-op with the real libgraphene as its dependency, and this hands the
/// bindings that library instead of the real one - their resolver caches
/// whatever handle its <c>TargetLibraryPointer</c> field holds, so seeding
/// the field is the whole install. Every other graphene call falls through
/// the shim's dependency to the real thing, and the collector's free - which
/// runs inside GLib, not through the bindings' imports - stays real and
/// becomes the only one.
/// </para>
/// <para>
/// A shim that is missing, cannot load, or no longer reaches the real
/// library, and a field a future release renames, each leave the bindings
/// untouched - the backend then behaves as it does alone.
/// </para>
/// <para>
/// AND THE TRANSFORM IT WORKS OUT IS NEVER DRAWN. The panel is a
/// <c>Gtk.Fixed</c>, so the backend hands GTK the transform the way one tells
/// a Fixed - and the panel does not lay its children out the way a Fixed
/// does. It drives a layout manager of its own, whose allocate gives every
/// child the transform from ITS OWN table, and nothing the backend writes ever
/// reaches that table: measured on the gallery's run of cards, where a card
/// asked for seven degrees and a scale of 0.36 and was drawn square and full
/// size, with the table holding nothing at all. So a layout's arrangement is
/// where its children's transforms are handed over, into the table the
/// allocate actually reads.
/// </para>
/// <para>
/// AND NOTHING ANSWERS A DRAWING ORDER. GTK paints a container's children in
/// the order it holds them and has no notion of a z, so a view MAUI puts in
/// front is drawn wherever it happens to sit in the list - measured on the
/// same run of cards, where the card furthest away was painted over the one
/// in front of it. So the children are re-linked into the order their z asks
/// for, ties going to the one written first, which is what a z means
/// everywhere else here. Only when the order is actually WRONG: re-linking a
/// child queues a resize, and a queue raised from inside the arrangement that
/// caused it is a pass that never ends.
/// </para>
/// <para>
/// THE TRANSFORM CARRIES THE PLACE AS WELL. A child with an entry in that
/// table is allocated by it ALONE - the position the arrangement worked out is
/// in the transform the table holds and nowhere else - so one carrying a
/// rotation and nothing more draws the view turned in the panel's top left
/// corner (measured: the whole run of cards stacked against the window's
/// edge). The chain is therefore the place, then the turn and the sizing about
/// the view's own anchor, which is what MAUI's transform means everywhere
/// else.
/// </para>
/// </remarks>
[System.Runtime.Versioning.SupportedOSPlatform("linux")]
internal static class LinuxTransforms
{
    /// <summary>
    /// Hands a panel the transforms its children wear, for the allocate that
    /// follows.
    /// </summary>
    /// <remarks>
    /// A child wearing nothing is left to the backend's own placing, which
    /// costs a table entry and a chain of graphene points for every view in
    /// every layout otherwise. One that HAS worn something is written even
    /// once it is plain again - the entry is what the allocate reads, so a
    /// view that stops turning must be handed its place back rather than have
    /// its last turn stand for ever.
    /// </remarks>
    /// <param name="panel">The panel about to allocate its children.</param>
    /// <param name="layout">The layout whose children they are.</param>
    /// <param name="worn">
    /// Which of them have been handed a transform before - weakly, a child
    /// being free to leave its layout and be collected, and keyed by the VIEW
    /// rather than its widget, the bindings being free to hand out a second
    /// wrapper for one widget and this table telling its keys apart by
    /// reference.
    /// </param>
    internal static void Wear(
        GtkLayoutPanel panel,
        Microsoft.Maui.ILayout layout,
        System.Runtime.CompilerServices.ConditionalWeakTable<VisualElement, object> worn)
    {
        foreach (IView kid in layout)
        {
            if (kid is not VisualElement view
                || Held(panel, view.Handler?.PlatformView as Widget) is not { } widget)
            {
                continue;
            }

            bool plain = view.Rotation == 0 && view.RotationX == 0 && view.RotationY == 0
                && view.Scale == 1 && view.ScaleX == 1 && view.ScaleY == 1
                && view.TranslationX == 0 && view.TranslationY == 0;

            if (plain && !worn.Remove(view))
            {
                continue;
            }

            if (!plain)
            {
                worn.AddOrUpdate(view, view);
            }

            Rect frame = view.Frame;
            double anchorX = view.AnchorX * frame.Width;
            double anchorY = view.AnchorY * frame.Height;

            Gsk.Transform transform = Gsk.Transform.New()
                .Translate(At(
                    frame.X + view.TranslationX + anchorX,
                    frame.Y + view.TranslationY + anchorY))
                .Rotate((float)view.Rotation)
                .Scale(
                    (float)(view.Scale * view.ScaleX),
                    (float)(view.Scale * view.ScaleY))
                .Translate(At(-anchorX, -anchorY));

            panel.SetChildTransform(widget, transform);
        }
    }

    /// <summary>
    /// The panels whose children may be drawn in the wrong order, put right
    /// once per idle however many arrangements asked.
    /// </summary>
    private static readonly Dictionary<GtkLayoutPanel, Microsoft.Maui.ILayout> Restack = [];

    /// <summary>
    /// Asks for a layout's children to be drawn in the order their z says.
    /// </summary>
    /// <remarks>
    /// OUT OF THE ARRANGEMENT, always. Re-linking a child queues a resize on
    /// its parent, and this is called from inside the panel's own allocate -
    /// where a queued resize is a pass that starts over on what it has just
    /// worked out. Deferred, the order is one frame behind the placement,
    /// which is a card crossing another a frame late and nothing a reader can
    /// see.
    /// </remarks>
    /// <param name="panel">The panel holding them.</param>
    /// <param name="layout">The layout whose children they are.</param>
    internal static void Stack(GtkLayoutPanel panel, Microsoft.Maui.ILayout layout)
    {
        bool scheduled = Restack.Count > 0;

        Restack[panel] = layout;

        if (scheduled)
        {
            return;
        }

        GLib.Functions.IdleAdd(0, () =>
        {
            (GtkLayoutPanel Panel, Microsoft.Maui.ILayout Layout)[] asked =
                [.. Restack.Select(pair => (pair.Key, pair.Value))];

            Restack.Clear();

            foreach ((GtkLayoutPanel panel, Microsoft.Maui.ILayout layout) in asked)
            {
                if (!panel.Handle.IsClosed && !panel.Handle.IsInvalid)
                {
                    Order(panel, layout);
                }
            }

            return false;
        });
    }

    /// <summary>
    /// Moves whichever of a panel's children are drawn out of turn, and no
    /// others.
    /// </summary>
    /// <remarks>
    /// <para>
    /// What is compared, and what is moved, is the panel's OWN child - the
    /// widget a view's handler answers can be wrapped in a clip or a shadow,
    /// and re-linking that inner one would take it out of its wrapper and put
    /// it in the panel, which is a view rebuilt rather than reordered
    /// (measured: a run of cards flickering at every swipe).
    /// </para>
    /// <para>
    /// And only what is out of turn moves. A child already in the right order
    /// relative to the ones before it is left where it stands, so a swipe that
    /// crosses two cards moves those two - where re-linking the whole run
    /// queued fifteen resizes for a change of one.
    /// </para>
    /// </remarks>
    /// <param name="panel">The panel holding them.</param>
    /// <param name="layout">The layout whose children they are.</param>
    private static void Order(GtkLayoutPanel panel, Microsoft.Maui.ILayout layout)
    {
        List<Widget> wanted = [.. layout
            .OfType<VisualElement>()
            .OrderBy(view => view.ZIndex)
            .Select(view => Held(panel, view.Handler?.PlatformView as Widget))
            .OfType<Widget>()];

        if (wanted.Count < 2)
        {
            return;
        }

        // The order the panel is holding them in now, the children it has that
        // nobody here manages passed over.
        List<Widget> held = [];

        for (Widget? child = panel.GetFirstChild(); child is not null; child = child.GetNextSibling())
        {
            if (wanted.Any(one => Same(one, child)))
            {
                held.Add(child);
            }
        }

        // WHAT IS ALREADY IN ORDER STAYS. The run through is the longest
        // stretch of what the panel is holding that is already in the order
        // asked for; everything else is moved into place around it. The
        // children already moved are STEPPED OVER on the way - without that,
        // one child moved to the front leaves every child after it compared
        // against a neighbour that is no longer there, and a swap of two
        // becomes a re-link of the whole run (measured on a fifteen-card
        // gallery: 11 to 14 moved for a change of one, which is what a reader
        // swiping sees as the run flickering).
        HashSet<nint> gone = [];
        int at = 0;
        Widget? after = null;

        foreach (Widget widget in wanted)
        {
            while (at < held.Count && gone.Contains(held[at].Handle.DangerousGetHandle()))
            {
                at++;
            }

            if (at < held.Count && Same(held[at], widget))
            {
                at++;
            }
            else
            {
                widget.InsertAfter(panel, after);
                gone.Add(widget.Handle.DangerousGetHandle());
            }

            after = widget;
        }

    }

    /// <summary>
    /// The panel's own child holding a widget - the widget itself, or whatever
    /// the backend wrapped it in.
    /// </summary>
    /// <param name="panel">The panel.</param>
    /// <param name="widget">The widget to find, or nothing.</param>
    /// <returns>The child, or nothing where the widget is not under it.</returns>
    private static Widget? Held(GtkLayoutPanel panel, Widget? widget)
    {
        for (Widget? child = widget; child is not null; child = child.GetParent())
        {
            if (child.GetParent() is { } above && Same(above, panel))
            {
                return child;
            }
        }

        return null;
    }

    /// <summary>Whether two wrappers stand for one widget.</summary>
    /// <param name="one">A wrapper.</param>
    /// <param name="other">Another.</param>
    /// <returns>Whether they are the same widget.</returns>
    private static bool Same(Widget one, Widget other) =>
        one.Handle.DangerousGetHandle() == other.Handle.DangerousGetHandle();

    /// <summary>One point, for a step of a transform's chain.</summary>
    /// <param name="x">How far across.</param>
    /// <param name="y">How far down.</param>
    /// <returns>The point.</returns>
    private static Graphene.Point At(double x, double y)
    {
        Graphene.Point point = Graphene.Point.Alloc();

        point.Init((float)x, (float)y);

        return point;
    }

    /// <summary>Arms it, before anything touches graphene.</summary>
    internal static void Install()
    {
        string shim = Path.Combine(AppContext.BaseDirectory, "libgraphene-shim.so");

        if (!File.Exists(shim) || !NativeLibrary.TryLoad(shim, out nint handle))
        {
            return;
        }

        // The shim must forward what it does not define, or every graphene
        // call in the process would fail instead of one going quiet.
        if (!NativeLibrary.TryGetExport(handle, "graphene_point_alloc", out _))
        {
            return;
        }

        typeof(Graphene.Point).Assembly
            .GetType("Graphene.Internal.ImportResolver")
            ?.GetField("TargetLibraryPointer", BindingFlags.Static | BindingFlags.NonPublic)
            ?.SetValue(null, handle);
    }
}
