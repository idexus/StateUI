// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Interop;
using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// Brings the core's work onto the thread MAUI draws on and runs it there: the
/// jobs a resumed handler left, a render when the core needs one, the acts the
/// application called, and a state cycle.
/// </summary>
/// <remarks>
/// Three ways in. The DOORBELL - a thread parked in the core until work lands -
/// posts a drain whenever a job or an act arrives. A reply to an act and a
/// journey's completion ask for a drain too, because the job each resumes does
/// not exist yet when it is answered. And every door the platform's word comes
/// through - an event, a host event, an environment push - runs one turn once
/// it has entered the core.
/// </remarks>
internal sealed class Pump
{
    private readonly IStateUITarget _target;
    private readonly UiThread _uiThread;
    private readonly WireDictionary _names;
    private readonly StateUIRenderer _renderer;
    private readonly ActPerformer _performer;
    private readonly Action<bool> _render;

    /// <summary>The pump of one session.</summary>
    /// <param name="target">What the session renders into, whose dispatcher a drain is posted on.</param>
    /// <param name="uiThread">What checks that a drain starts on the thread MAUI draws on.</param>
    /// <param name="names">The session's wire dictionary, which an act batch is read with.</param>
    /// <param name="renderer">Whose display cycle a turn runs.</param>
    /// <param name="performer">What performs the acts a turn takes.</param>
    /// <param name="render">The session's render of one message: whether a refused one may be asked for again whole.</param>
    internal Pump(IStateUITarget target, UiThread uiThread, WireDictionary names,
        StateUIRenderer renderer, ActPerformer performer, Action<bool> render)
    {
        _target = target;
        _uiThread = uiThread;
        _names = names;
        _renderer = renderer;
        _performer = performer;
        _render = render;
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
    /// Dedicates a thread to asking the moment Swift has work, which is what
    /// lets a handler await something that is NOT a host act.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A resumed handler's job lands on Swift's queue, and the other thing that
    /// empties that queue is this side asking - after an event, after a
    /// completed act. A job produced by anything else - a <c>Task.sleep</c>
    /// coming due, a task an author started finishing, an <c>AsyncStream</c>
    /// yielding - lands when nothing is in flight, so without this thread it
    /// would sit there until the next unrelated event. With it, what a handler
    /// awaits need not be a host act.
    /// </para>
    /// <para>
    /// The thread spends its life inside <see cref="CoreLink.WaitWork"/>;
    /// Swift signals it as a job lands, and all it does with the news is post
    /// one drain onto the UI thread through the session's dispatcher - MAUI's
    /// dispatchers are thread-safe - and park again. It never runs a job
    /// itself: the drain it posts runs on the one thread everything here runs
    /// on.
    /// </para>
    /// <para>
    /// Created BY .NET on purpose, and background on purpose. Mono deadlocks
    /// when native code enters managed from a thread it has never seen - the
    /// measured trap in <c>Core/MainThread.swift</c> - so instead of Swift
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
        if (_doorbellStarted || _target.Dispatcher is null)
        {
            return;
        }

        _doorbellStarted = true;

        var asker = new Thread(() =>
        {
            // Nothing may escape this thread: an unhandled exception on any
            // thread takes the whole process, and this one exists to be
            // forgotten about. A missing library is a headless test whose
            // window rendered into the diagnostic path; a missing entry point
            // is a native library older than this runtime - both mean "no
            // waker", not "no process", and without one the drains after
            // events and completions still carry the work.
            try
            {
                while (true)
                {
                    if (CoreLink.WaitWork() > 0)
                    {
                        DrainWhenTheResumeArrives();
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
                    "the thread that waits for Swift's work has stopped; a handler "
                    + "awaiting something that is not a host act - Task.sleep, a "
                    + "task's value - will now resume at the next event until a "
                    + "later render sends another thread in.", ex);
            }
        })
        {
            IsBackground = true,
            Name = "StateUI doorbell",
        };

        asker.Start();
    }

    /// <summary>
    /// Renders what the core describes, performs the acts and cycles - what a
    /// target's own render asks for, whether or not the core needs one.
    /// </summary>
    internal void Render()
    {
        _render(true);
        PerformActCalls();
        Cycle();
    }

    /// <summary>
    /// Brings the interface up to date and performs whatever the Swift side
    /// asked for while it was running.
    /// </summary>
    /// <remarks>
    /// In that order on purpose: a handler that changes state and acts in the
    /// same breath - focuses a field it has just shown, opens a dialog over
    /// the page it has just changed - acts on an interface that already shows
    /// the change.
    /// </remarks>
    internal void Run()
    {
        // A resumed handler may have left work here since the last look.
        CoreLink.RunJobs();

        // Only re-render if the Swift side says something changed. An event that
        // only reads state - a button that logs, a completed handler that does
        // nothing - has no reason to walk the tree at all.
        if (CoreLink.NeedsRender() != 0)
        {
            _render(true);
        }

        PerformActCalls();
        Cycle();
    }

    /// <summary>
    /// What follows an act's reply: a pump for what it changed, and a drain for
    /// the continuation it resumed.
    /// </summary>
    internal void Replied()
    {
        Run();
        DrainWhenTheResumeArrives();
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
    /// Runs one state cycle, now that the Swift side has had its turn.
    /// </summary>
    /// <remarks>
    /// THE OTHER OCCASION BESIDE A FRAME, and the one that makes a state written
    /// from a handler go anywhere at all: no frame is being made while nothing
    /// moves, so a write would sit in the image until something else happened
    /// to wake the display. One cycle here takes it in, runs whatever follows
    /// it, and lands what those wrote - and the clock is started where the
    /// cycle says there is more to come.
    /// </remarks>
    private void Cycle()
    {
        try
        {
            _renderer.DisplayCycle.Run(CycleReason.Drained);
        }
        catch (Exception ex) when (ex is DllNotFoundException or EntryPointNotFoundException)
        {
            // Said already, and by whoever tried to render: a session with no
            // library to talk to has nothing to cycle over either, and one
            // report of a missing library is enough.
        }
    }

    // ---- Getting a suspended handler back onto the UI thread ---------------

    /// <summary>
    /// How many plain dispatcher turns a resume is given before the looks slow
    /// to the <see cref="LateLookDelaysMs"/> ladder. Turns are cheap and usually
    /// enough; the ladder is for a scheduler that needs wall-clock time - see
    /// <see cref="DrainWhenTheResumeArrives"/>.
    /// </summary>
    private const int TurnsToWaitForAResume = 32;

    /// <summary>
    /// Whether the backstop below has already complained. Once, like every
    /// other standing condition here: a scheduler that has stopped stops for
    /// every handler, and a complaint per suspended one would bury the first.
    /// </summary>
    private bool _saidAResumeNeverArrived;

    /// <summary>
    /// How long each late look waits before the next, once the fast turns are
    /// spent. About two seconds end to end - patience in wall-clock, because the
    /// fast turns are dispatcher turns and a quiet dispatcher burns all of them
    /// in microseconds, well inside the moment Swift's scheduler needs to
    /// produce the job.
    /// </summary>
    private static readonly int[] LateLookDelaysMs = [8, 16, 32, 63, 125, 250, 500, 1000];

    /// <summary>
    /// Asks the Swift side to run whatever a suspended handler has waiting, once
    /// the resume has actually arrived.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Asking, rather than being called back, keeps every crossing in the one
    /// direction the rest of this boundary already goes - and a callback the
    /// other way, Swift into C#, cannot: the resume arrives on a
    /// cooperative-pool thread, and entering managed code from a thread .NET
    /// has never seen makes Mono attach it, which deadlocks the UI thread under
    /// a debugger on Android. Measured: the app froze on the first
    /// <c>await</c> in a handler and Android stopped delivering touches.
    /// </para>
    /// <para>
    /// Nothing here blocks: a fast look is one posted turn of MAUI's own
    /// dispatcher, and a late look is one delayed post. Progress resets the
    /// patience, so a burst of resumes is followed for as long as it keeps
    /// producing.
    /// </para>
    /// <para>
    /// It asks TWO questions, and the second is the one a resume count alone
    /// cannot answer. <c>ResumesPending</c> says a handler has been told its act
    /// is over and has not run a line since - but a handler suspended on its own
    /// child tasks (<c>async let</c>) resumes through a job no completion
    /// accounting covers, because what it awaited was never a host act. So
    /// <c>JobsPending</c> is asked beside it: work that is coming, and work that
    /// is already there. Polling only the first gives up exactly one job too
    /// early - measured: the gallery's concurrent-animation loop froze mid-beat
    /// on every platform whenever its long animation outlived its short ones.
    /// </para>
    /// <para>
    /// And when both read zero, ONE more delayed look is taken before stopping:
    /// a child task lowers the resume count on a pool thread a moment before
    /// the parent's job lands in the queue, so a single instant of quiet is not
    /// yet the end. Progress arms the confirming look again.
    /// </para>
    /// </remarks>
    internal void DrainWhenTheResumeArrives() => ScheduleDrain(look: 0, confirmedQuiet: false);

    /// <summary>One look of <see cref="DrainWhenTheResumeArrives"/>, scheduled.</summary>
    /// <param name="look">
    /// Which look this is: below <see cref="TurnsToWaitForAResume"/> a plain
    /// dispatcher turn, above it a delayed one from <see cref="LateLookDelaysMs"/>.
    /// </param>
    /// <param name="confirmedQuiet">
    /// Whether a quiet queue has already been given its one confirming look.
    /// </param>
    private void ScheduleDrain(int look, bool confirmedQuiet)
    {
        IDispatcher? dispatcher = _target.Dispatcher;

        if (dispatcher is null)
        {
            // No platform under it - a test. Whatever is there is all there is.
            CoreLink.RunJobs();
            return;
        }

        void Look()
        {
            try
            {
                _uiThread.Verify(dispatcher, "a resumed Swift handler");

                bool progressed = CoreLink.RunJobs() > 0;

                if (progressed)
                {
                    Run();
                }
                else
                {
                    // A look that ran nothing may still have been woken FOR
                    // something that lands no job here - the wake that
                    // announced it is all there is. Two of those: an act
                    // queued from a plain Task, and a state WRITE made from a
                    // child task, which queues nothing at all. So
                    // this pumps rather than only taking the acts - and
                    // a pump whose tree is clean renders nothing, so a quiet
                    // look stays quiet.
                    Run();
                }

                // Both halves: resumes still in flight, and jobs already
                // landed. Something HAVING run does not end the loop either
                // way - an unrelated job drains on the same queue, and the
                // resume this look is for may land a moment later.
                bool owed = CoreLink.ResumesPending() > 0 || CoreLink.JobsPending() > 0;

                if (!owed)
                {
                    if (progressed || !confirmedQuiet)
                    {
                        // The one confirming look, off the heat of this turn.
                        ScheduleDrain(TurnsToWaitForAResume, confirmedQuiet: true);
                    }

                    return;
                }

                if (progressed)
                {
                    ScheduleDrain(look: 0, confirmedQuiet: false);
                    return;
                }

                if (look + 1 < TurnsToWaitForAResume + LateLookDelaysMs.Length)
                {
                    ScheduleDrain(look + 1, confirmedQuiet);
                    return;
                }

                if (_saidAResumeNeverArrived)
                {
                    return;
                }

                _saidAResumeNeverArrived = true;

                StateUISession.Report(
                    "a handler was told its act had finished about two seconds ago "
                    + "and Swift has still not produced the work to resume it. It is "
                    + "not lost - the next event drains the queue too, so it will "
                    + "continue then - but something is holding up Swift's scheduler, "
                    + "and until it moves that handler is stopped where it awaited.");
            }
            catch (Exception ex)
            {
                _target.Fail("Resuming a Swift handler failed", ex);
            }
        }

        if (look < TurnsToWaitForAResume)
        {
            dispatcher.Dispatch(Look);
        }
        else
        {
            int late = Math.Min(look - TurnsToWaitForAResume, LateLookDelaysMs.Length - 1);
            dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(LateLookDelaysMs[late]), Look);
        }
    }
}
