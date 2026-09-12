// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Diagnostics;
using System.Runtime.Versioning;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Linux;

/// <summary>
/// The display's own rhythm, which nothing here answers by itself.
/// </summary>
/// <remarks>
/// <para>
/// Every value this library moves is stepped by a frame signal, and on the
/// other four platforms that signal is the display's - a display link, a
/// choreographer, a composition. This backend has no such seam of its own: its
/// ticker is a plain timer of about sixteen milliseconds, which drifts against
/// whatever the screen is actually doing and knows nothing of a display that
/// draws faster.
/// </para>
/// <para>
/// GTK has the real thing - a frame clock per surface, which is what the
/// compositor paces - and a widget can ask to be told about every frame of it.
/// So this waits for a window to exist, hangs a tick callback off its root,
/// and hands each of those ticks to the engine.
/// </para>
/// <para>
/// The callback is REMOVED when nothing is moving, and asked for again when
/// something is: a signal arriving sixty times a second over a still screen is
/// a laptop's battery being spent on nothing. That is also why the backend's
/// own tick callback - which it adds for layout and never takes back - is not
/// what this rides on.
/// </para>
/// </remarks>
[SupportedOSPlatform("linux")]
internal static class LinuxFrames
{
    /// <summary>Makes this platform's frame clock the engine's.</summary>
    internal static void Install()
    {
        MotionClock.Provided = () => new Clock();

        // And the desktop's own "less movement, please", which is one setting
        // here where the other platforms each have their own.
        MotionMood.Provided = () => Gtk.Settings.GetDefault()?.GtkEnableAnimations == false;
    }

    /// <summary>One window's frame clock, asked for a tick at a time.</summary>
    private sealed class Clock : IMotionClock
    {
        /// <summary>What GTK gave the callback, so it can be taken back.</summary>
        private uint _ticket;

        /// <summary>The widget the callback hangs off.</summary>
        private Gtk.Widget? _on;

        /// <summary>Whether anything has asked for frames.</summary>
        private bool _running;

        /// <summary>Whether a tick is being answered right now.</summary>
        /// <remarks>
        /// A frame is where a value lands and another starts, so the clock is
        /// stopped and started again from inside the very callback it is
        /// running - and a ticket taken back there, with a new one hung up
        /// beside it, is TWO callbacks on one surface from then on. So the
        /// ticket is left alone while its own callback runs: the callback ends
        /// by taking itself back if nothing wants it any more, and
        /// <see cref="Attach"/> refuses to hang up a second one while the
        /// first is alive.
        /// </remarks>
        private bool _ticking;

        /// <inheritdoc/>
        public event Action? Frame;

        /// <inheritdoc/>
        public void Start()
        {
            if (_running)
            {
                return;
            }

            _running = true;
            Attach();
        }

        /// <inheritdoc/>
        public void Stop()
        {
            if (!_running)
            {
                return;
            }

            _running = false;

            if (_ticking)
            {
                return;
            }

            if (_on is not null && _ticket != 0)
            {
                _on.RemoveTickCallback(_ticket);
            }

            _ticket = 0;
            _on = null;
        }

        /// <summary>
        /// Hangs the callback off whatever window is up, or waits for one.
        /// </summary>
        /// <remarks>
        /// The first setpoint of a session can arrive before there is a window
        /// to hang anything off - a page describes itself as it is built - so a
        /// clock with nowhere to attach asks again on the next idle rather than
        /// giving up. Until then the engine simply gets no frames, which is a
        /// value arriving at once and never a value lost.
        /// </remarks>
        private void Attach()
        {
            if (!_running || _ticket != 0)
            {
                return;
            }

            if (Microsoft.Maui.Controls.Application.Current?.Windows is not { Count: > 0 } windows
                || windows[0].Handler?.PlatformView is not Gtk.Widget widget)
            {
                GLib.Functions.IdleAdd(0, () =>
                {
                    Attach();
                    return false;
                });

                return;
            }

            _on = widget;
            _ticket = widget.AddTickCallback((_, _) =>
            {
                if (!_running)
                {
                    return Gone();
                }

                _ticking = true;

                try
                {
                    Frame?.Invoke();
                }
                finally
                {
                    _ticking = false;
                }

                return _running || Gone();
            });
        }

        /// <summary>
        /// Answers the callback that it is over, having taken back its own
        /// ticket.
        /// </summary>
        /// <remarks>
        /// Returning false IS the removal, so nothing else may take the ticket
        /// back - what is left is to forget it, or the next
        /// <see cref="Attach"/> would think one were still hung up.
        /// </remarks>
        /// <returns>False, which is what a callback answers to end.</returns>
        private bool Gone()
        {
            _ticket = 0;
            _on = null;
            return false;
        }

        /// <inheritdoc/>
        public long Now => Stopwatch.GetTimestamp();
    }
}
