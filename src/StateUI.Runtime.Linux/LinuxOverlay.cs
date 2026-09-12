// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.CompilerServices;
using System.Runtime.Versioning;
using Microsoft.Maui.Platform;
using StateUI.Runtime.Rendering;
using Gtk;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Lays a window's overlay - the panel a debug inspector docks in - over the
/// content that window is already showing.
/// </summary>
/// <remarks>
/// <para>
/// MAUI has no place for a view outside a page, so every platform hands the
/// overlay to its own window directly. This backend has no such answer of its
/// own, and the renderer's own file compiles to nothing here, so a panel
/// docked at the side or the bottom was rendered and laid nowhere: the tree
/// described it, the host built it, and the reader saw the inspector's window
/// close with nothing taking its place.
/// </para>
/// <para>
/// GTK's own answer is <c>GtkOverlay</c>, which draws a child over its
/// content, so the window's content is re-parented under one - once, and again
/// if MAUI ever sets the window's child afresh. Re-parenting a live child is
/// safe: the managed wrapper holds a reference of its own, and the page under
/// it goes on drawing and answering (measured on this platform with a probe of
/// nothing but GTK).
/// </para>
/// <para>
/// WHAT IS HANDED TO GTK IS THE PANEL, NOT THE WHOLE OVERLAY, and that is the
/// one thing this platform cannot do the way the others do. Elsewhere the
/// overlay's root fills the window and answers no touch itself - MAUI's
/// <c>InputTransparent</c> without the cascade - so a touch beside the panel
/// reaches the page. GTK has no such thing: a widget is picked anywhere in its
/// allocation, and <c>can-target</c>, the only way to refuse, takes the whole
/// subtree with it - measured, with the panel's own buttons going dead while
/// every click reached the page. An overlay child that does NOT fill is picked
/// where it is and nowhere else, which is exactly the behaviour wanted - so
/// the PANEL is the widget, and the root the tree wrapped it in stays a MAUI
/// object with no widget at all.
/// </para>
/// <para>
/// Where the panel goes is still the tree's to say, and it says it by placing
/// the panel in that root: running the root's own layout over the window's
/// size is how this side reads the rectangle back, and the margins put the
/// child exactly there. So a panel docked at the bottom, folded to one line or
/// down the side is laid where every other platform lays it, from the same
/// description, with nothing about the place crossing the wire.
/// </para>
/// </remarks>
[SupportedOSPlatform("linux")]
internal static class LinuxOverlay
{
    /// <summary>Makes this platform the one that lays an overlay.</summary>
    /// <remarks>
    /// Said with the namespace because MAUI has a <c>WindowOverlay</c> of its
    /// own - a drawn layer for a visual diagnostic - and the workload's
    /// implicit usings bring it in here.
    /// </remarks>
    internal static void Install() => Rendering.WindowOverlay.Provided = new Overlays();

    /// <summary>Every overlay this platform has laid.</summary>
    private sealed class Overlays : IWindowOverlays
    {
        /// <summary>What was laid, by the view the tree described.</summary>
        /// <remarks>
        /// WEAK, as everything the host keeps about a control is: a panel whose
        /// window the platform destroyed is never taken down by name, and a
        /// dictionary would hold that view - and the whole tree under it - for
        /// the life of the process.
        /// </remarks>
        private readonly ConditionalWeakTable<View, Laid> _laid = [];

        /// <summary>The GTK overlay wrapped around each window's content.</summary>
        private readonly ConditionalWeakTable<Gtk.Window, Overlay> _shells = [];

        /// <inheritdoc/>
        public void Show(Microsoft.Maui.Controls.Window window, View view, IMauiContext context)
        {
            if (window.Handler?.PlatformView is not Gtk.Window native
                || Panel(view) is not View panel
                || panel.ToPlatform(context) is not Widget drawn)
            {
                return;
            }

            Overlay shell = Shell(native);

            if (_laid.TryGetValue(view, out Laid? standing))
            {
                // The tree said something about a panel already laid. The
                // widget is the same one - the renderer keeps controls between
                // renders - so all that is owed is the place, which the panel's
                // own size may have changed.
                standing.Wear(panel, shell, drawn);
                standing.Watch();
                return;
            }

            var laid = new Laid(view, panel, shell, drawn);

            _laid.AddOrUpdate(view, laid);
            laid.Show();
        }

        /// <inheritdoc/>
        public void Hide(View view)
        {
            if (!_laid.Remove(view, out Laid? laid))
            {
                return;
            }

            laid.Hide();
        }

        /// <summary>
        /// The panel the overlay is about: the one view the root the tree
        /// describes holds. The root itself is never given a widget - see the
        /// note on this class - so a root that holds anything else is laid
        /// whole, which is what an application's own overlay would be.
        /// </summary>
        /// <param name="view">The view the tree described.</param>
        private static View? Panel(View view) =>
            view is Layout { Count: 1 } root && root[0] is View panel ? panel : view;

        /// <summary>
        /// The GTK overlay over a window's content, made the first time one is
        /// wanted - and again where MAUI has set the window's child since,
        /// which is what makes this heal itself rather than leave a panel
        /// parented to an overlay nothing shows.
        /// </summary>
        /// <param name="native">The window's own GTK window.</param>
        private Overlay Shell(Gtk.Window native)
        {
            if (_shells.TryGetValue(native, out Overlay? standing)
                && ReferenceEquals(native.GetChild(), standing))
            {
                return standing;
            }

            bool first = !_shells.TryGetValue(native, out _);
            Widget? content = native.GetChild();
            Overlay shell = Overlay.New();

            // Off the window first: GTK refuses a widget that still has a
            // parent, and the wrapper holding this one keeps it alive across
            // the moment it has none.
            native.SetChild(null);

            if (content is not null)
            {
                shell.SetChild(content);
            }

            native.SetChild(shell);
            _shells.AddOrUpdate(native, shell);

            if (first)
            {
                // A RESIZE IS THE PLATFORM'S TO SAY HERE. MAUI is told nothing
                // about one on this backend - its window's own SizeChanged
                // never fires - so the panel would keep the place it was given
                // at the size the window happened to have, anchored at its old
                // left edge and stretched by the new one. The window's own
                // notify is what a resize does say; which property is not
                // worth asking, the way LinuxMeasures reads it, so anything
                // else costs one watch of a few frames.
                native.OnNotify += (_, _) => Placed(native);
            }

            return shell;
        }

        /// <summary>Places whatever hangs over one window again.</summary>
        /// <remarks>
        /// Asked of the WINDOW rather than of the overlay the notify was
        /// subscribed beside, because a window whose child MAUI set afresh
        /// wears a new overlay and the panel moves to it.
        /// </remarks>
        /// <param name="native">The window's own GTK window.</param>
        private void Placed(Gtk.Window native)
        {
            if (!_shells.TryGetValue(native, out Overlay? shell))
            {
                return;
            }

            foreach (KeyValuePair<View, Laid> laid in _laid)
            {
                if (ReferenceEquals(laid.Value.Shell, shell))
                {
                    laid.Value.Watch();
                }
            }
        }
    }

    /// <summary>How many still frames say a window has settled at a size.</summary>
    private const int Settled = 3;

    /// <summary>How many frames a panel waits for a size before giving up.</summary>
    private const int Patience = 240;

    /// <summary>One overlay, laid over one window.</summary>
    /// <param name="view">The root view the tree described.</param>
    /// <param name="panel">The view inside it that is actually shown.</param>
    /// <param name="shell">The GTK overlay it hangs in.</param>
    /// <param name="drawn">The panel's own widget.</param>
    private sealed class Laid(View view, View panel, Overlay shell, Widget drawn)
    {
        /// <summary>The view inside the root that is actually shown.</summary>
        private View _panel = panel;

        /// <summary>Whether the frames are already being watched.</summary>
        private bool _watching;

        /// <summary>Whether the panel has been taken down.</summary>
        private bool _gone;

        /// <summary>The GTK overlay it hangs in.</summary>
        private Overlay _shell = shell;

        /// <summary>The overlay it hangs in - what a resize is answered for.</summary>
        internal Overlay Shell => _shell;

        /// <summary>The panel's own widget.</summary>
        private Widget _drawn = drawn;

        /// <summary>Hangs it up, and keeps it placed while the window lives.</summary>
        internal void Show()
        {
            _shell.AddOverlay(_drawn);
            Watch();
        }

        /// <summary>Takes it down again.</summary>
        internal void Hide()
        {
            _gone = true;

            if (ReferenceEquals(_drawn.GetParent(), _shell))
            {
                _shell.RemoveOverlay(_drawn);
            }
        }

        /// <summary>
        /// Follows a widget or an overlay that has changed hands - a window
        /// whose content MAUI set afresh is a new overlay, and the panel moves
        /// to it.
        /// </summary>
        /// <param name="panel">The view inside the root that is shown.</param>
        /// <param name="shell">The overlay it should hang in.</param>
        /// <param name="drawn">The widget it should show.</param>
        internal void Wear(View panel, Overlay shell, Widget drawn)
        {
            _panel = panel;

            if (ReferenceEquals(_shell, shell) && ReferenceEquals(_drawn, drawn))
            {
                return;
            }

            if (ReferenceEquals(_drawn.GetParent(), _shell))
            {
                _shell.RemoveOverlay(_drawn);
            }

            _shell = shell;
            _drawn = drawn;
            _shell.AddOverlay(_drawn);
        }

        /// <summary>
        /// Places the panel where the tree put it: the root's own layout over
        /// the window's size works the rectangle out, and the margins hand GTK
        /// exactly that rectangle to allocate.
        /// </summary>
        /// <remarks>
        /// The rectangle is asked of the root RATHER THAN STATED, because the
        /// root is a layout like any other and the renderer carries its
        /// children: a panel moving from the side to the bottom, or folding to
        /// its last render, TRAVELS there, and what the root answers is
        /// wherever that journey has got to. So the place is taken again on
        /// every frame until it holds still - see <see cref="Watch"/>.
        /// </remarks>
        /// <returns>The place it wrote, or nothing where there was none.</returns>
        internal Rect Lay()
        {
            double width = _shell.GetAllocatedWidth();
            double height = _shell.GetAllocatedHeight();

            // The overlay is not laid out yet - a panel is described as its
            // page is built - and a place worked out against a size of nothing
            // is no place at all.
            if (width <= 0 || height <= 0 || view is not Microsoft.Maui.ICrossPlatformLayout root)
            {
                return Rect.Zero;
            }

            root.CrossPlatformMeasure(width, height);
            root.CrossPlatformArrange(new Rect(0, 0, width, height));

            Rect place = ((IView)_panel).Frame;

            if (place.Width <= 0 || place.Height <= 0)
            {
                return Rect.Zero;
            }

            _drawn.Halign = Align.Fill;
            _drawn.Valign = Align.Fill;
            _drawn.MarginStart = Edge(place.X);
            _drawn.MarginTop = Edge(place.Y);
            _drawn.MarginEnd = Edge(width - place.Right);
            _drawn.MarginBottom = Edge(height - place.Bottom);

            return place;
        }

        /// <summary>One margin, in whole units and never negative.</summary>
        /// <param name="of">What the layout worked out.</param>
        private static int Edge(double of) => (int)Math.Max(0, Math.Round(of));

        /// <summary>
        /// Places the panel on the display's own frames until it holds still,
        /// and takes itself off again.
        /// </summary>
        /// <remarks>
        /// A PLACE IS NOT ONE MOMENT HERE, twice over. The panel is described
        /// inside the render that docks it, before the overlay it hangs in has
        /// been allocated anything; and once there is a size, the place the
        /// root answers TRAVELS, the renderer carrying a panel that moves from
        /// the side to the bottom or folds to one line. So this asks every
        /// frame and stops once the same place has come back
        /// <see cref="Settled"/> times. It is a FRAME callback and never an
        /// idle: an idle that re-arms itself while it waits for a size outruns
        /// the frame clock that would have given it one, which is a whole core
        /// spent and a panel that never appears - measured, at 4.3 million
        /// passes over one dock.
        /// </remarks>
        internal void Watch()
        {
            if (_watching)
            {
                return;
            }

            _watching = true;

            Rect last = Rect.Zero;
            int still = 0;
            int waited = 0;

            _shell.AddTickCallback((_, _) =>
            {
                if (_gone)
                {
                    return Done();
                }

                Rect place = Lay();

                if (place == Rect.Zero)
                {
                    // Nothing to place it against yet, and a window that will
                    // never give it one is not watched for ever.
                    return ++waited < Patience || Done();
                }

                if (place != last)
                {
                    (last, still) = (place, 0);

                    return true;
                }

                return ++still < Settled || Done();
            });
        }

        /// <summary>Answers a tick callback that it is over.</summary>
        /// <returns>False, which is what ends one.</returns>
        private bool Done()
        {
            _watching = false;
            return false;
        }
    }
}
