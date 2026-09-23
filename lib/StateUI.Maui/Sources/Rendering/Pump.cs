// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Interop;
using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// Brings the core's work onto the thread MAUI draws on and runs it there: the
/// jobs a resumed handler left, a pending state cycle, a render when the core
/// needs one, and the acts the application called.
/// </summary>
/// <remarks>
/// Two ways in. The DOORBELL - a thread parked in the core until work lands -
/// posts a turn whenever a job, an act or a value waiting for a cycle arrives:
/// the job a resumed handler continues in, after an act's reply or a journey's
/// answer, a <c>Task.sleep</c> coming due, an act queued from a plain
/// <c>Task</c>, a movement one started. And every door the
/// platform's word comes through - an event, a host event, an environment push -
/// runs one turn once it has entered the core.
/// </remarks>
internal sealed class Pump
{
    private readonly IStateUITarget _target;
    private readonly UiThread _uiThread;
    private readonly WireDictionary _names;
    private readonly StateUIRenderer _renderer;
    private readonly ActPerformer _performer;
    private readonly Action<bool> _render;
    private readonly Func<bool> _mounted;

    /// <summary>The pump of one session.</summary>
    /// <param name="target">What the session renders into, whose dispatcher the doorbell posts a turn on.</param>
    /// <param name="uiThread">What checks that a turn the doorbell posts starts on the thread MAUI draws on.</param>
    /// <param name="names">The session's wire dictionary, which an act batch is read with.</param>
    /// <param name="renderer">Whose display cycle a turn runs.</param>
    /// <param name="performer">What performs the acts a turn takes.</param>
    /// <param name="render">The session's render of one message: whether a refused one may be asked for again whole.</param>
    /// <param name="mounted">Whether a tree is mounted - a message has gone in whole.</param>
    internal Pump(IStateUITarget target, UiThread uiThread, WireDictionary names,
        StateUIRenderer renderer, ActPerformer performer, Action<bool> render, Func<bool> mounted)
    {
        _target = target;
        _uiThread = uiThread;
        _names = names;
        _renderer = renderer;
        _performer = performer;
        _render = render;
        _mounted = mounted;
    }

    /// <summary>
    /// Whether a thread is already parked in Swift waiting for work. One per
    /// process, because there is one Swift runtime and one queue behind it -
    /// and one live session over both.
    /// </summary>
    /// <remarks>
    /// Cleared again if the park ever stops, so that the next render sends
    /// another thread in. Without that the process would spend the rest of its
    /// life with the flag standing and no waker behind it, and everything a
    /// handler awaits that is not a host act would resume only at the next
    /// unrelated event.
    /// </remarks>
    private static bool _doorbellStarted;

    /// <summary>
    /// Dedicates a thread to waiting for Swift's work, and posts a turn each
    /// time it lands - which is how every resumed handler comes back.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A resumed handler continues in a job on Swift's queue, and the job lands
    /// a moment after the resume - after an act's reply, a journey's answer, a
    /// <c>Task.sleep</c> coming due, a task an author started finishing, an
    /// <c>AsyncStream</c> yielding. The core rings this thread for every job,
    /// every act and every value written for a cycle that lands after the last
    /// ring was answered, so each runs in the turn the ring posts, whatever the
    /// handler awaited.
    /// </para>
    /// <para>
    /// The thread spends its life inside <see cref="CoreLink.WaitWork"/>;
    /// Swift signals it as a job lands, and all it does with the news is post
    /// one turn onto the UI thread through the session's dispatcher - MAUI's
    /// dispatchers are thread-safe - and park again. It never runs a job
    /// itself: the turn it posts runs on the one thread everything here runs
    /// on.
    /// </para>
    /// <para>
    /// Created BY .NET on purpose, and background on purpose. Mono deadlocks
    /// when native code enters managed from a thread it has never seen - the
    /// measured trap in <c>Core/UIThread.swift</c> - so instead of Swift
    /// calling out, this side sends a thread in. Background, so a process
    /// shutting down does not wait on a park that nothing will ever signal.
    /// </para>
    /// <para>
    /// Headless tests have no dispatcher to post to and drive the queue
    /// themselves, so a session without one does not park a thread.
    /// </para>
    /// </remarks>
    internal void StartDoorbell()
    {
        if (_doorbellStarted || _target.Dispatcher is not IDispatcher dispatcher)
        {
            return;
        }

        _doorbellStarted = true;

        var doorbell = new Thread(() =>
        {
            // Nothing may escape this thread: an unhandled exception on any
            // thread takes the whole process, and this one exists to be
            // forgotten about. A missing library is a headless test whose
            // window rendered into the diagnostic path; a missing entry point
            // is a native library older than this runtime - both mean "no
            // doorbell", not "no process": an event still runs its turn, and
            // a resumed handler continues at the next one.
            try
            {
                while (true)
                {
                    if (CoreLink.WaitWork() > 0)
                    {
                        dispatcher.Dispatch(Ring);
                    }
                }
            }
            catch (DllNotFoundException)
            {
                // No native library to park in - a test. Quietly none.
            }
            catch (Exception ex)
            {
                // Put back, so the next render can park another thread. A
                // DllNotFoundException above deliberately does not: there is no
                // library to park in and every retry would find the same.
                _doorbellStarted = false;

                StateUISession.Report(
                    "the doorbell has stopped; a handler resumed from an await - "
                    + "an act's reply, a Task.sleep, a task's value - will now "
                    + "continue at the next event until a later render sends "
                    + "another thread in.", ex);
            }
        })
        {
            IsBackground = true,
            Name = "StateUI doorbell",
        };

        doorbell.Start();
    }

    /// <summary>One turn the doorbell posted, on the thread MAUI draws on.</summary>
    private void Ring()
    {
        try
        {
            _uiThread.Verify(_target.Dispatcher, "a resumed Swift handler");
            Run();
        }
        catch (Exception ex)
        {
            _target.Fail("Resuming a Swift handler failed", ex);
        }
    }

    /// <summary>
    /// A turn whose render a target asks for: a pending cycle, the render
    /// whether or not the core needs one, then the acts.
    /// </summary>
    internal void Render()
    {
        Cycle();
        _render(true);
        PerformActCalls();
    }

    /// <summary>
    /// One turn: the jobs a resumed handler left, a pending cycle, a render when
    /// the core needs one, then the acts.
    /// </summary>
    /// <remarks>
    /// In that order on purpose. The cycle before the render, so the one
    /// message carries what a handler wrote and what followed it; the acts
    /// after, so a handler that changes state and acts in the same breath -
    /// enables a field and focuses it, opens a dialog over the page it has
    /// just changed - acts on an interface that already shows the change.
    /// </remarks>
    internal void Run()
    {
        // A resumed handler may have left work here since the last turn.
        CoreLink.RunJobs();

        Cycle();

        // Only re-render if the Swift side says something changed. An event that
        // only reads state - a button that logs, a completed handler that does
        // nothing - has no reason to walk the tree at all.
        if (CoreLink.NeedsRender() != 0)
        {
            _render(true);
        }

        PerformActCalls();
    }

    /// <summary>
    /// Takes what Swift queued and performs each act. Empty most of the time.
    /// </summary>
    private void PerformActCalls()
    {
        List<HostActCall>? calls;

        try
        {
            IntPtr buffer = CoreLink.TakeActCallsWire(out int length);

            if (buffer == IntPtr.Zero || length <= 0)
            {
                return;
            }

            try
            {
                // The batch is read IN PLACE, straight off the native buffer -
                // no copy, no transcoding, nothing materialized in between.
                unsafe
                {
                    calls = WireCodec.ReadActCalls(
                        new ReadOnlySpan<byte>((void*)buffer, length), _names);
                }
            }
            finally
            {
                CoreLink.FreeBuffer(buffer);
            }
        }
        catch (Exception ex)
        {
            // The batch is already OFF the Swift queue, and the completion ids
            // are inside the very bytes that would not read - only Swift still
            // knows them. The take keeps a receipt of them, and cashing it
            // fails every act in the batch, so each awaiting handler resumes
            // by throwing instead of staying suspended forever. Deliberately
            // not a timeout: an act may wait unboundedly and legitimately - a
            // dialog waits for the reader - so the failure is causal.
            try
            {
                CoreLink.FailTakenActCalls(
                    "the host could not read the act batch this act was in. " +
                    "Usually a native library and a runtime built from different " +
                    "versions.");
            }
            catch (Exception cashing) when (
                cashing is DllNotFoundException or EntryPointNotFoundException)
            {
                // No library to tell - a session with none at all, or a stale
                // native build without this export. The error page below still
                // names the parse failure.
            }

            _target.Fail("The acts from Swift could not be read", ex);
            return;
        }

        if (calls is null)
        {
            return;
        }

        _performer.Perform(calls);
    }

    /// <summary>
    /// Runs the state cycle a write has left pending, before the render - so the
    /// one render carries what a handler wrote and what followed it.
    /// </summary>
    /// <remarks>
    /// THE OTHER OCCASION BESIDE A FRAME, and the one that makes a state written
    /// from a handler go anywhere at all: no frame is being made while nothing
    /// moves, so a write would sit in the image until something else happened
    /// to wake the display. One cycle here takes it in, runs whatever follows
    /// it, and lands what those wrote - and the clock is started where the
    /// cycle says there is more to come. Only over a mounted tree: before the
    /// first message there is nothing to land a value on.
    /// </remarks>
    private void Cycle()
    {
        if (!_mounted())
        {
            return;
        }

        try
        {
            if (!_renderer.DisplayCycle.Idle())
            {
                _renderer.DisplayCycle.Run(CycleReason.Drained);
            }
        }
        catch (Exception ex) when (ex is DllNotFoundException or EntryPointNotFoundException)
        {
            // Said already, and by whoever tried to render: a session with no
            // library to talk to has nothing to cycle over either, and one
            // report of a missing library is enough.
        }
    }
}
