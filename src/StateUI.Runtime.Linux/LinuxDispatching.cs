// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Dispatching;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Makes a dispatch a TURN, never a plain call.
/// </summary>
/// <remarks>
/// <para>
/// The backend's dispatcher runs an action INLINE whenever it is already on
/// the main thread, and every other platform's queues it - which is the
/// contract this library leans on wherever it defers a report "a turn": a
/// presence raised from inside a message apply is dispatched so it lands
/// AFTER the apply, and run inline it lands inside the very apply whose
/// guard drops it. Measured: MAUI raises <c>Loaded</c> as a pushed page's
/// views attach, which is the apply's own work, so <c>.onLoaded</c> never
/// reached the tree and the incremental-loading sample sat at
/// "Batch 0 - 0 of 300" for good - the first batch is that handler's to ask
/// for.
/// </para>
/// <para>
/// The answer is a dispatcher whose <c>Dispatch</c> always goes through the
/// loop's idle, whichever thread asks - registered over the backend's own
/// provider, which the scoped resolution then also installs as the process's
/// current one. <c>DispatchDelayed</c> and the timer keep the backend's
/// behaviour, which was already a queue.
/// </para>
/// </remarks>
[System.Runtime.Versioning.SupportedOSPlatform("linux")]
internal static class LinuxDispatching
{
    /// <summary>The one provider, answering the one dispatcher.</summary>
    private static readonly Provider Shared = new();

    /// <summary>Registers the queueing dispatcher over the backend's.</summary>
    /// <param name="builder">Whose services take the replacement.</param>
    internal static void Install(MauiAppBuilder builder) =>
        builder.Services.AddSingleton<IDispatcherProvider>(_ => Shared);

    /// <summary>Hands out the queueing dispatcher, to every thread alike.</summary>
    private sealed class Provider : IDispatcherProvider
    {
        /// <summary>The dispatcher itself, one for the process.</summary>
        private readonly Queued _dispatcher = new();

        /// <summary>The queueing dispatcher.</summary>
        /// <returns>The same instance for every caller.</returns>
        public IDispatcher? GetForCurrentThread() => _dispatcher;
    }

    /// <summary>
    /// A dispatcher that queues on the GLib main loop even when asked from
    /// the main thread.
    /// </summary>
    private sealed class Queued : IDispatcher
    {
        /// <summary>Whether the caller is off the loop's own thread.</summary>
        public bool IsDispatchRequired =>
            !GLib.Functions.MainContextDefault().IsOwner();

        /// <summary>Queues the action for the loop's next idle.</summary>
        /// <param name="action">What to run.</param>
        /// <returns>True: the queue took it.</returns>
        public bool Dispatch(Action action)
        {
            GLib.Functions.IdleAdd(0, () =>
            {
                action();
                return false;
            });

            return true;
        }

        /// <summary>Queues the action for after the delay.</summary>
        /// <param name="delay">How long to wait.</param>
        /// <param name="action">What to run then.</param>
        /// <returns>True: the queue took it.</returns>
        public bool DispatchDelayed(TimeSpan delay, Action action)
        {
            GLib.Functions.TimeoutAdd(0, (uint)Math.Max(0, delay.TotalMilliseconds), () =>
            {
                action();
                return false;
            });

            return true;
        }

        /// <summary>The backend's own timer, which already queues.</summary>
        /// <returns>A fresh timer.</returns>
        public IDispatcherTimer CreateTimer() => new GtkDispatcherTimer();
    }
}
