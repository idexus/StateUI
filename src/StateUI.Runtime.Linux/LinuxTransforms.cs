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
    internal static void Wear(GtkLayoutPanel panel, Microsoft.Maui.ILayout layout)
    {
        Arranging++;

        try
        {
            foreach (IView kid in layout)
            {
                if (kid is VisualElement view)
                {
                    Listen(view);
                    Write(panel, view);
                }
            }
        }
        finally
        {
            Arranging--;
        }
    }

    /// <summary>
    /// Which views have been handed a transform before - weakly, a child being
    /// free to leave its layout and be collected, and keyed by the VIEW rather
    /// than its widget, the bindings being free to hand out a second wrapper
    /// for one widget and this table telling its keys apart by reference.
    /// </summary>
    private static readonly System.Runtime.CompilerServices
        .ConditionalWeakTable<VisualElement, object> Worn = [];

    /// <summary>How many arrangements are handing over transforms right now.</summary>
    private static int Arranging;

    /// <summary>Which views are already being listened to.</summary>
    private static readonly System.Runtime.CompilerServices
        .ConditionalWeakTable<VisualElement, object> Listening = [];

    /// <summary>
    /// Hears one view's turns, sizings and moves, once.
    /// </summary>
    /// <remarks>
    /// NOTHING THE SUBSCRIPTION MAKES MAY HOLD THE VIEW: the handler is a
    /// static method reading its own sender, so the delegate has no target to
    /// keep a control alive with, and the table it is remembered in is weakly
    /// keyed. The subscription itself lives on the view and goes with it.
    /// </remarks>
    /// <param name="view">The view to hear.</param>
    private static void Listen(VisualElement view)
    {
        if (Listening.TryGetValue(view, out _))
        {
            return;
        }

        Listening.AddOrUpdate(view, view);
        view.PropertyChanged += Followed;
    }

    /// <summary>One view saying it has been turned, sized or moved.</summary>
    /// <param name="sender">The view.</param>
    /// <param name="e">Which property was written.</param>
    private static void Followed(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (sender is not VisualElement view)
        {
            return;
        }

        // A DRAWING ORDER WRITTEN BETWEEN ARRANGEMENTS IS HEARD HERE AND
        // NOWHERE ELSE. GTK paints in child order and has no z, so the order
        // is re-linked - but that was asked for from the ARRANGE alone, and a
        // placement writes its z on the host's own frames without arranging
        // anything: a move is a translation and invalidates nothing. So the
        // run kept whatever order the last arrangement gave it. Measured on
        // the gallery's home page, stepping the cards one at a time: at the
        // fourth card the run's z read `[12,14,16,15,13,...]` - the card
        // BEHIND the front one still ranked highest - and *Using state* was
        // drawn over *Animation*, caption and all, with nothing to put it
        // right.
        if (e.PropertyName == nameof(VisualElement.ZIndex))
        {
            Restacked(view);
            return;
        }

        if (Array.IndexOf(Moving, e.PropertyName) >= 0)
        {
            Moved(view);
        }
    }

    /// <summary>Asks for one child's layout to be drawn in its z order again.</summary>
    /// <param name="view">The child whose z has just changed.</param>
    private static void Restacked(VisualElement view)
    {
        if (view.Parent is Microsoft.Maui.ILayout layout
            && layout is IView held
            && held.Handler?.PlatformView is GtkLayoutPanel panel)
        {
            Stack(panel, layout);
        }
    }

    /// <summary>
    /// Hands one panel one child's transform, for the allocate that reads it.
    /// </summary>
    /// <param name="panel">The panel holding it.</param>
    /// <param name="view">The child.</param>
    /// <returns>Whether the panel was told anything.</returns>
    private static bool Write(GtkLayoutPanel panel, VisualElement view)
    {
        if (Held(panel, view.Handler?.PlatformView as Widget) is not { } widget)
        {
            return false;
        }

        // AND A PLACE IS PART OF IT. The table an allocate reads carries the
        // whole of where a child goes, so a child that has an entry is placed
        // by it alone - and one that has none is left where the backend puts
        // it, which for a layout whose children are placed by ARITHMETIC is
        // the panel's own corner. Measured on the gallery's home page: the
        // invisible box that answers a tap on the card in front is the right
        // size and carries the right rectangle, and with no turn, no scale and
        // no translation of its own it was drawn at the run's beginning - so
        // every tap on the card went to the box behind it, until a scroll gave
        // the box a translation and put it where it belonged.
        bool plain = view.Rotation == 0 && view.RotationX == 0 && view.RotationY == 0
            && view.Scale == 1 && view.ScaleX == 1 && view.ScaleY == 1
            && view.TranslationX == 0 && view.TranslationY == 0
            && view.Frame.X == 0 && view.Frame.Y == 0;

        if (plain && !Worn.Remove(view))
        {
            return false;
        }

        if (!plain)
        {
            Worn.AddOrUpdate(view, view);
        }

        Rect frame = view.Frame;
        double anchorX = view.AnchorX * frame.Width;
        double anchorY = view.AnchorY * frame.Height;

        // EVERY STEP OF THE CHAIN IS TYPED NULLABLE and none of them answers
        // null here: GSK reads a null transform as the IDENTITY, which is why
        // the binding admits one, and an operation over a transform that
        // exists always answers a transform. Said once per step because each
        // return re-introduces the question.
        Gsk.Transform transform = Gsk.Transform.New()!
            .Translate(At(
                frame.X + view.TranslationX + anchorX,
                frame.Y + view.TranslationY + anchorY))!
            .Rotate((float)view.Rotation)!
            .Scale(
                (float)(view.Scale * view.ScaleX),
                (float)(view.Scale * view.ScaleY))!
            .Translate(At(-anchorX, -anchorY))!;

        panel.SetChildTransform(widget, transform);

        return true;
    }

    /// <summary>
    /// One view whose turn, size or place has just been written, handed over
    /// at once rather than waiting for an arrangement that may never come.
    /// </summary>
    /// <remarks>
    /// A TRANSFORM INVALIDATES NO LAYOUT, which is the whole point of moving a
    /// view by one - so on this platform, where the table the allocate reads is
    /// filled by the arrangement alone, a view moved between two arrangements
    /// was drawn wearing whatever it wore at the last one. Measured on the
    /// gallery's run of cards: every card kept the angle and the size it had
    /// when the page was laid out, and a swipe rearranged nothing, so the run
    /// drew as a stack of stale frames until something else asked for a pass.
    /// The allocate is asked for, never the measure: the child's rectangle has
    /// not moved, and GTK folds however many of these a frame brings into one
    /// pass.
    /// </remarks>
    /// <param name="view">The view whose transform has changed.</param>
    internal static void Moved(VisualElement view)
    {
        if (view.Parent is not Microsoft.Maui.ILayout layout
            || layout is not IView held
            || held.Handler?.PlatformView is not GtkLayoutPanel panel
            || !Write(panel, view))
        {
            return;
        }

        // NOT FROM INSIDE THE PASS THAT IS ALREADY DOING IT: an arrangement
        // hands every child its transform as it goes, and a pass that queues
        // itself from inside itself is a pass that never ends.
        if (Arranging == 0)
        {
            panel.QueueAllocate();
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

    /// <summary>
    /// The properties a view is turned, sized and moved by - the ones whose
    /// writing must reach the table an allocate reads.
    /// </summary>
    /// <remarks>
    /// Heard on the VIEW rather than through a mapper: this backend's handlers
    /// answer nothing appended to <c>ViewHandler.ViewMapper</c> for any of
    /// them, so a mapper is a subscription that never fires (measured - not one
    /// call while a run of cards was swiped from end to end).
    /// </remarks>
    private static readonly string[] Moving =
    [
        nameof(IView.Rotation),
        nameof(IView.RotationX),
        nameof(IView.RotationY),
        nameof(IView.Scale),
        nameof(IView.ScaleX),
        nameof(IView.ScaleY),
        nameof(IView.TranslationX),
        nameof(IView.TranslationY),
        nameof(IView.AnchorX),
        nameof(IView.AnchorY),
    ];

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
