// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Globalization;
using System.Runtime.InteropServices;
using System.Text.Json;
using StateUI.Runtime.Interop;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// What a session renders into.
/// </summary>
/// <remarks>
/// Two things implement it: <see cref="StateUIApplication"/>, where Swift
/// owns the windows and their pages, and <see cref="StateUIHost"/>, where a
/// Swift tree is embedded in a page someone else wrote. The loop below is the
/// same either way.
/// </remarks>
internal interface IStateUITarget
{
    /// <summary>
    /// Applies the root Application node. Returns false to ask for the whole
    /// tree instead, which is what a target does when a patch names something it
    /// does not have - a page whose window has just been opened, for instance.
    /// </summary>
    /// <param name="application">
    /// The root Application node of the message, whose children are the windows.
    /// </param>
    /// <param name="complete">
    /// Whether this message describes everything rather than only what changed.
    /// </param>
    bool Apply(SwiftNode application, bool complete);

    /// <summary>Shows a diagnostic in place of the interface.</summary>
    void Fail(string message, Exception? exception);

    /// <summary>
    /// MAUI's dispatcher for the thread this target draws on, or null where
    /// there is no platform under it - a test.
    /// </summary>
    /// <remarks>
    /// Only used to put a suspended Swift handler back on that thread. MAUI is
    /// the authority on which thread that is; the Swift side deliberately has no
    /// opinion, which is what keeps this working the same on four platforms.
    /// </remarks>
    IDispatcher? Dispatcher { get; }
}

/// <summary>
/// The render loop: ask Swift what changed, apply it, forward events, perform
/// what Swift asked for, ask again.
/// </summary>
internal sealed class StateUISession
{
    /// <summary>What this session renders into.</summary>
    private readonly IStateUITarget _target;

    /// <summary>
    /// Where a completed act's answer goes: into Swift, which resumes the
    /// handler awaiting it.
    /// </summary>
    /// <remarks>
    /// The one substitution point an act test needs, and it is deliberately
    /// the OUTWARD one: an act's arguments can be read from a fixture Swift
    /// wrote, but its answer has nowhere to go without a Swift runtime to
    /// resume. Substituted, a test reads exactly what an arm replied - the
    /// bytes, on the completion id the fixture named - which is the only thing
    /// an arm is contractually about. Never substituted in a running app.
    /// </remarks>
    internal Action<int, byte[]> Replies { get; init; } =
        static (id, reply) => NativeMethods.DispatchWire(id, reply, reply.Length);

    /// <summary>
    /// Checks that each crossing into Swift starts on the thread MAUI draws on.
    /// </summary>
    private readonly UiThread _uiThread = new(message => Report(message));

    /// <summary>
    /// This session's numbering of every name the wire carries, learned from
    /// the announcements at the head of each message - see
    /// <see cref="SwiftWireDictionary"/>. One per session, shared by the tree
    /// and the acts, exactly as the Swift side keeps one per renderer.
    /// </summary>
    /// <remarks>
    /// The two are one dictionary in two halves, which is the whole reason
    /// there may be only one live session per process - see <see cref="_live"/>.
    /// A name is announced the FIRST time the Swift side writes it and never
    /// again, so a second session, starting empty here, would read numbers
    /// nothing ever told it the meaning of.
    /// </remarks>
    private readonly SwiftWireDictionary _names = new();

    /// <summary>
    /// How many plain dispatcher turns a resume is given before the looks slow
    /// to the <see cref="LateLookDelaysMs"/> ladder. Turns are cheap and usually
    /// enough; the ladder is for a scheduler that needs wall-clock time - see
    /// <see cref="DrainWhenTheResumeArrives"/>.
    /// </summary>
    private const int TurnsToWaitForAResume = 32;

    /// <summary>
    /// Whether the Swift application has registered itself. Static because there
    /// is one Swift runtime per process - and, over it, the one live session.
    /// </summary>
    private static bool _initialized;

    /// <summary>
    /// The generation of the last message applied in full, quoted back on the
    /// next render.
    /// </summary>
    /// <remarks>
    /// A patch only means anything against the exact tree it was computed from.
    /// Holding the generation - and advancing it only once a message has been
    /// applied without throwing - is what makes Swift send the whole tree again
    /// whenever this side cannot be sure of what it is showing. Zero is never a
    /// generation Swift issues, so it always means "start over".
    /// </remarks>
    private int _generation;

    /// <summary>
    /// How many renders have begun, so that one can tell whether another ran
    /// underneath it.
    /// </summary>
    /// <remarks>
    /// A render can nest: applying a message reaches MAUI, MAUI raises
    /// <c>Navigated</c>, and the window reports a vanished page and pumps. The
    /// inner message is computed against a tree this apply has not finished
    /// writing, so once it has been applied, what is on screen is not reliably
    /// either message - and the outer render must not claim its generation. It
    /// leaves it at zero instead, which asks for the whole tree next time. That
    /// is cheap, because a resync keeps every identity, handler and
    /// <c>@State</c>.
    /// </remarks>
    private int _renders;

    /// <summary>
    /// Calls into the APP's Swift module, which names its Application.
    /// </summary>
    /// <remarks>
    /// Set by the interop file the app project generates. It cannot be a
    /// P/Invoke declared here: the app's Swift module is a separate native
    /// library whose name comes from the project, and this assembly was compiled
    /// before any application existed.
    /// </remarks>
    internal static Action? RegisterApp { get; set; }

    /// <summary>Starts a session against a target.</summary>
    /// <remarks>
    /// A session is made, not started: what it needs from the process - the
    /// push channel, the theme, the Swift runtime itself - it takes at its
    /// first render, in <see cref="BecomeLive"/>. A target builds its session
    /// while it is itself being constructed, and there is nothing to render
    /// into yet.
    /// </remarks>
    public StateUISession(IStateUITarget target)
    {
        _target = target;
        Renderer = new StateUIRenderer(OnEvent, OnReport);
    }

    /// <summary>
    /// The one session rendering the Swift application in this process, or null
    /// while nothing has rendered yet.
    /// </summary>
    /// <remarks>
    /// <para>
    /// <b>One live session per process; the windows belong to that session.</b>
    /// The other side is a single <c>Renderer.shared</c> holding one tree, one
    /// generation, one handler registry, one command queue and one wire
    /// dictionary. A second session here would quote a baseline against a tree
    /// it does not own, read name numbers it never heard announced (see
    /// <see cref="_names"/>), and drain commands raised by the other one's
    /// handlers - all silently, since none of that is on the wire to check.
    /// </para>
    /// <para>
    /// Several things at once is what WINDOWS are for, and they cost a node in
    /// the one tree rather than a second render loop - see
    /// <see cref="StateUIApplication"/>.
    /// </para>
    /// </remarks>
    private static StateUISession? _live;

    /// <summary>
    /// Takes the process for this session, or shows why it cannot have it.
    /// Returns false when another session is already live.
    /// </summary>
    /// <remarks>
    /// Claimed at the FIRST RENDER rather than in the constructor, because
    /// rendering is what reaches Swift: a session that never renders - the ones
    /// the tests build by the dozen - takes nothing and blocks nobody.
    /// </remarks>
    private bool BecomeLive()
    {
        if (ReferenceEquals(_live, this))
        {
            return true;
        }

        // Nothing to be live WITH. An application with no Swift module at all
        // has a different problem and is told about it below; a session that
        // cannot reach a runtime takes nothing from the process, which is also
        // what leaves the tests free to build sessions by the dozen.
        if (RegisterApp is null)
        {
            return true;
        }

        if (_live is not null)
        {
            _target.Fail(
                "StateUI is already showing an interface in this process.\n\n" +
                "One session renders the Swift application, and every window is a " +
                "node in its tree - so a second StateUIHost, a host beside a " +
                "StateUIWindow, or a host built again after an earlier one went " +
                "away, has no tree of its own to describe. An application that " +
                "shows several things at once lists them as windows; one that " +
                "embeds a Swift tree in a C# page keeps THAT host and puts it back " +
                "where it is needed.",
                null);

            return false;
        }

        _live = this;

        // The push channel's way in: a raise belongs to the interface that is
        // showing, and until something is live there is none.
        StateUIEvents.Session = this;

        // Telling the AppInfo provider is the WHOLE of what a theme change
        // does here. Nothing on this side knows what a themed colour is:
        // `Color(light:dark:)` picks its half on the Swift side as the value
        // is written onto a node, and that read is recorded like any other -
        // so pushing `requestedTheme` dirties exactly the views that asked and
        // the render that follows carries the other colours. No binding, no
        // states to build again. See Types/Color.swift.
        //
        // Subscribed for the life of the process, which is the life of the one
        // session. There is no application to hear it from in a test, where
        // MAUI's controls are plain objects.
        if (Application.Current is Application application)
        {
            application.RequestedThemeChanged += (_, _) => StateUIEnvironment.ThemeChanged();
        }

        return true;
    }

    /// <summary>
    /// Lets the process be claimed again - what a test resets between cases.
    /// </summary>
    /// <remarks>
    /// There is deliberately no way for an application to do this: a live
    /// session owns Swift's tree and its handlers, and nothing here can make
    /// the other side forget them. A test never subscribes the theme, having
    /// no <see cref="Application.Current"/> to subscribe to, so there is
    /// nothing to undo but the two references.
    /// </remarks>
    internal static void Release()
    {
        _live = null;
        StateUIEvents.Session = null;
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
    /// handler awaits that is not a host command would resume only at the next
    /// unrelated event.
    /// </remarks>
    private static bool _askerParked;

    /// <summary>
    /// Dedicates a thread to asking the moment Swift has work, which is what
    /// lets a handler await something that is NOT a host command.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A resumed handler's job lands on Swift's queue, and the other thing that
    /// empties that queue is this side asking - after an event, after a
    /// completed command. A job produced by anything else - a <c>Task.sleep</c>
    /// coming due, a task an author started finishing, an <c>AsyncStream</c>
    /// yielding - lands when nothing is in flight, so without this thread it
    /// would sit there until the next unrelated event. With it, what a handler
    /// awaits need not be a host command.
    /// </para>
    /// <para>
    /// The thread spends its life inside <see cref="NativeMethods.WaitWork"/>;
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
    private void AskWheneverWorkLands()
    {
        if (_askerParked || _target.Dispatcher is null)
        {
            return;
        }

        _askerParked = true;

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
                    if (NativeMethods.WaitWork() > 0)
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
                _askerParked = false;

                Report(
                    "the thread that waits for Swift's work has stopped; a handler "
                    + "awaiting something that is not a host command - Task.sleep, a "
                    + "task's value - will now resume at the next event until a "
                    + "later render sends another thread in.", ex);
            }
        })
        {
            IsBackground = true,
            Name = "StateUI asker",
        };

        asker.Start();
    }

    /// <summary>Materializes views; targets use it for page content.</summary>
    public StateUIRenderer Renderer { get; }

    /// <summary>
    /// Brings the interface up to date, then performs whatever the render asked
    /// for.
    /// </summary>
    public void Render()
    {
        // Started HERE and not in the constructor, and the placement is
        // load-bearing twice over: a target may not have had a dispatcher
        // while the session was being made, and a session in a test never
        // renders - rendering is the native-backed path, so a session that
        // reaches it has a library for the asker to park in. A test session
        // has neither, and a thread parked in a P/Invoke with nothing behind
        // it took the whole test process down.
        // And the process itself, before either: a session that is not the
        // live one has no tree to describe and no queue to drain - the
        // commands below belong to whichever session owns the runtime.
        if (!BecomeLive())
        {
            return;
        }

        AskWheneverWorkLands();

        Render(mayRetry: true);
        PerformCommands();
        Cycled();
    }

    /// <summary>
    /// Runs one number cycle, now that the Swift side has had its turn.
    /// </summary>
    /// <remarks>
    /// THE OTHER OCCASION BESIDE A FRAME, and the one that makes a number written
    /// from a handler go anywhere at all: no frame is being made while nothing
    /// moves, so a write would sit in the image until something else happened
    /// to wake the display. One cycle here takes it in, runs whatever follows
    /// it, and lands what those wrote - and the clock is started where the
    /// cycle says there is more to come.
    /// </remarks>
    private void Cycled()
    {
        try
        {
            Renderer.States.Run(CycleReason.Drained);
        }
        catch (Exception ex) when (ex is DllNotFoundException or EntryPointNotFoundException)
        {
            // Said already, and by whoever tried to render: a session with no
            // library to talk to has nothing to cycle over either, and one
            // report of a missing library is enough.
        }
    }

    /// <summary>
    /// Renders the WHOLE tree rather than the change since the last message.
    /// </summary>
    /// <remarks>
    /// What a target asks for when what it is showing is nothing: a window the
    /// platform has just handed over has no page on it, however little the
    /// interface has changed since the last render. Dropping the generation is
    /// all it takes - Swift answers a baseline it does not recognize with the
    /// whole tree, reconciled against the one it is already showing, so every
    /// identity, handler and <c>@State</c> survives.
    /// </remarks>
    internal void Resync()
    {
        _generation = 0;
        Render();
    }

    /// <summary>
    /// Drops the generation WITHOUT rendering, so the next render describes the
    /// whole tree.
    /// </summary>
    /// <remarks>
    /// What a target calls when it has just shown an error in place of its
    /// page: the tree it was showing is gone, but the generation still names
    /// it, so a patch computed against it would be sparse over a tree the
    /// target no longer holds. Unlike <see cref="Resync"/> this does not
    /// render - it is called from inside an apply, and from a fault that fires
    /// after one - so it only resets the baseline; the next render, whenever it
    /// comes, is complete.
    /// </remarks>
    internal void Forget() => _generation = 0;

    /// <summary>
    /// Asks Swift for the change since the last message applied in full, and
    /// applies it.
    /// </summary>
    /// <param name="mayRetry">
    /// Whether a target that cannot apply the message may be given one more go
    /// with the whole tree. False on that second attempt, which is what makes it
    /// terminate.
    /// </param>
    private void Render(bool mayRetry)
    {
        // Dropped first, so that anything going wrong below leaves this side
        // asking for the whole tree rather than for a patch onto a visual tree
        // it only half applied.
        int baseline = _generation;
        _generation = 0;

        int began = ++_renders;

        _uiThread.Verify(_target.Dispatcher, "a render");

        try
        {
            // Ahead of the first crossing, and on EVERY render rather than
            // only the first: a module that never registered is the reason
            // nothing can be described, whichever render notices.
            if (RegisterApp is not { } register)
            {
                _target.Fail(
                    "No Swift UI module is registered.\n\n" +
                    "The app project should generate an interop file that sets " +
                    "StateUIHost.RegisterApp. Check that its .csproj imports " +
                    "StateUI.targets and that the Swift directory contains at " +
                    "least one .swift file.",
                    null);
                return;
            }

            if (!_initialized)
            {
                register();

                // Two halves built from different versions must fail HERE,
                // with a sentence - never later, by reading each other's
                // bytes wrong. A library too old to have the export fails the
                // same check as EntryPointNotFoundException below.
                int wire = NativeMethods.WireVersion();
                if (wire != SwiftWire.Version)
                {
                    _target.Fail(
                        $"The native library speaks wire version {wire} and " +
                        $"this runtime speaks {SwiftWire.Version}.\n\n" +
                        "A native library and a runtime built from different " +
                        "versions - rebuild the app so the two halves match.",
                        null);
                    return;
                }

                // KEPT STATE, before anything is built: a `@State` under a
                // PersistentKey has to hold the stored value the first time a
                // view reads it, and a Swift read cannot wait for this side.
                // Once per process rather than once per render - the block is
                // behind _initialized, and Resync deliberately does not clear
                // it, or a lost generation would reload the store over live
                // state.
                StateUIPersistence.Start();

                // The standard environment: every provider's values, told
                // BEFORE the first tree is built - which pages exist may
                // depend on the idiom - and wired to the platform's change
                // events for everything after.
                StateUIEnvironment.Start(this);
                _initialized = true;
            }

            SwiftMessage message;
            int described = 0;
            IntPtr raw = RenderTally.Time(
                ref RenderTally.Described,
                () => NativeMethods.RenderWire(baseline, out described));
            int length = described;

            if (raw == IntPtr.Zero || length <= 0)
            {
                _target.Fail("Swift returned an empty UI tree", null);
                return;
            }

            try
            {
                // Read IN PLACE, straight off the native buffer - no copy, no
                // transcoding, nothing materialized but the values themselves.
                IntPtr bytes = raw;
                int count = length;

                message = RenderTally.Time(
                    ref RenderTally.ReadTicks,
                    () =>
                    {
                        unsafe
                        {
                            return SwiftWire.ReadMessage(
                                new ReadOnlySpan<byte>((void*)bytes, count), _names);
                        }
                    });
            }
            finally
            {
                NativeMethods.FreeBuffer(raw);
            }

            if (message.Root is null)
            {
                _target.Fail("Swift returned an empty UI tree", null);
                return;
            }

            if (message.Root.Type != SwiftNodeType.Application)
            {
                _target.Fail(
                    $"Swift described a '{message.Root.TypeName}' where an Application " +
                    "was expected.\n\nUsually a native library built from an older " +
                    "version of the Swift side than this runtime.",
                    null);
                return;
            }

            // HOW EVERY LAYOUT'S CHILDREN TRAVEL, said once for the whole
            // application: a layout that agrees with it is on no message at
            // all, which is what keeps the common case off the wire. See
            // MotionArranger.
            if (message.Root.Moves && message.Root.Motion is MotionSpec placement)
            {
                Renderer.Motion.Travel = placement;
            }

            // Swift says whether this is the whole tree; it is not inferred from
            // the baseline, which is right for a first render and wrong for
            // every other resync. A baseline of zero always brings the whole
            // tree back, which is what makes the retry below terminate.

            if (!_target.Apply(message.Root, complete: message.Complete))
            {
                if (mayRetry)
                {
                    Render(mayRetry: false);
                }
                else
                {
                    _target.Fail(
                        "The interface could not be applied even after Swift sent " +
                        "the whole tree.",
                        null);
                }

                return;
            }

            // Only when nothing rendered underneath this one - see _renders.
            if (_renders == began)
            {
                _generation = message.Generation;
            }
        }
        catch (DllNotFoundException ex)
        {
            _target.Fail(
                "The StateUI native library was not found.\n\n" +
                "Build it for this platform with the scripts in build/, then " +
                "rebuild the app.",
                ex);
        }
        catch (EntryPointNotFoundException ex)
        {
            _target.Fail(
                "The native library loaded but is missing an expected function.\n\n" +
                "Usually a stale build, or - on Windows - a missing entry in the " +
                "generated .def export list.",
                ex);
        }
        catch (InvalidDataException ex)
        {
            _target.Fail("The UI tree from Swift could not be read", ex);
        }
        catch (Exception ex)
        {
            // Applying THREW rather than refusing - a MAUI setter or a converter
            // that did not like a value. The generation is already zero, so one
            // more go brings the whole tree: the same recovery a refusal gets,
            // terminating on the same flag. Without this the error escaped into
            // whoever called, which from a target's constructor is the
            // application's startup path.
            if (mayRetry)
            {
                Render(mayRetry: false);
                return;
            }

            _target.Fail(
                "The interface could not be applied, even from the whole tree.",
                ex);
        }
    }

    // ---- Getting a suspended handler back onto the UI thread ---------------

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
    /// accounting covers, because what it awaited was never a host command. So
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
    private void DrainWhenTheResumeArrives() => ScheduleDrain(look: 0, confirmedQuiet: false);

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
            NativeMethods.RunJobs();
            return;
        }

        void Look()
        {
            try
            {
                _uiThread.Verify(dispatcher, "a resumed Swift handler");

                bool progressed = NativeMethods.RunJobs() > 0;

                if (progressed)
                {
                    Pump();
                }
                else
                {
                    // A look that ran nothing may still have been woken FOR
                    // something that lands no job here - the wake that
                    // announced it is all there is. Two of those: an act
                    // queued from a plain Task, and a FLIGHT, which writes
                    // state from a child task and queues nothing at all. So
                    // this pumps rather than only taking the commands - and
                    // a pump whose tree is clean renders nothing, so a quiet
                    // look stays quiet.
                    Pump();
                }

                // Both halves: resumes still in flight, and jobs already
                // landed. Something HAVING run does not end the loop either
                // way - an unrelated job drains on the same queue, and the
                // resume this look is for may land a moment later.
                bool owed = NativeMethods.ResumesPending() > 0 || NativeMethods.JobsPending() > 0;

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

                Report(
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

    /// <summary>
    /// Says something went wrong where nothing else can - a state the interface
    /// cannot show without making things worse.
    /// </summary>
    /// <param name="message">What happened, in the imperative where there is something to do.</param>
    /// <param name="exception">The cause, if there was one.</param>
    /// <remarks>
    /// Console rather than <c>Debug.WriteLine</c>: .NET for Android redirects
    /// stdout and stderr into logcat, so this is the one channel that reaches a
    /// developer on every platform this library targets. Prefixed so it can be
    /// grepped for.
    /// </remarks>
    internal static void Report(string message, Exception? exception = null)
    {
        Console.Error.WriteLine($"StateUI: {message}");

        if (exception is not null)
        {
            Console.Error.WriteLine($"StateUI: {exception}");
        }
    }

    // ---- Events and acts ---------------------------------------------------

    /// <summary>
    /// Reports an event to Swift, then brings the interface up to date.
    /// </summary>
    /// <remarks>
    /// Everything the Swift side ever runs happens inside a call like this one,
    /// on the UI thread - which is what its whole concurrency model rests on.
    /// </remarks>
    /// <param name="handlerId">the id the control reported with</param>
    /// <param name="payload">what the event has to say, or null</param>
    /// <param name="leaving">
    /// Whether the control is on its way out of the tree, which is what makes
    /// an id the Swift side no longer knows ordinary rather than a fault - see
    /// <see cref="ReportAnEventNobodyHeard"/>.
    /// </param>
    private void OnEvent(int handlerId, byte[]? payload, bool leaving)
    {
        // The one crossing MAUI decides the thread of: a platform handler raised
        // this, and everything the Swift handler does happens inside the call
        // below.
        //
        // A REPORT FROM THE WRONG THREAD IS MOVED RATHER THAN TAKEN. The Swift
        // side holds no lock - its safety is that one thread enters it - so a
        // crossing from anywhere else is a state write that can be lost against
        // a render, silently. The dispatcher exists to answer exactly that, and
        // what it costs is one turn of the loop.
        //
        // Measured on Linux, where a platform ticks its animations off the UI
        // thread: a flight's completion arrived on a pool thread, which is the
        // only report that ever did. The check below stands - it is what names
        // a platform doing this - and the move is what keeps the tree safe
        // while it does.
        // Nothing is said about it, because nothing is wrong once it has moved:
        // the check below is for a crossing this cannot answer, and a warning
        // about state being lost would be untrue of a report that was carried
        // to the right thread instead.
        if (_target.Dispatcher is IDispatcher dispatcher && dispatcher.IsDispatchRequired)
        {
            dispatcher.Dispatch(() => OnEvent(handlerId, payload, leaving));
            return;
        }

        _uiThread.Verify(_target.Dispatcher, "an event from MAUI");

        try
        {
            if (NativeMethods.DispatchWire(handlerId, payload, payload?.Length ?? 0) == 0
                && !leaving)
            {
                ReportAnEventNobodyHeard(handlerId);
            }

            // Not while a message is being applied - a flight completion can
            // land here from INSIDE one, a snap over a walking property
            // aborting it mid-apply. Rendering there is a resync against a
            // generation the host has not finished taking, and it would kill
            // every other walk in the air; the write has dirtied the tree,
            // and the drain that follows the apply renders it a moment
            // later, exactly as a flight report's does one method down.
            if (!Renderer.Busy)
            {
                Pump();
            }

            // A NEGATIVE id is not an event: it is a completion, and what it
            // resumed is a handler whose next job does not exist yet. The
            // command path says the same thing one method down; a flight lands
            // here instead, having queued no command to be completed.
            if (handlerId < 0)
            {
                DrainWhenTheResumeArrives();
            }
        }
        catch (Exception ex)
        {
            _target.Fail("Event dispatch failed", ex);
        }
    }

    /// <summary>
    /// Says where a walk has got to, then brings the interface up to date.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A sample lands inside MAUI's animation tick, on the UI thread, and the
    /// Swift side writes it into whatever state was watching. That write dirties
    /// the tree exactly as any other does, so the <see cref="Pump"/> below is
    /// what puts the new reading on screen - one render per sample, which is
    /// why the cadence is the author's and stated in milliseconds rather than
    /// one per frame.
    /// </para>
    /// <para>
    /// Nobody listening is ordinary, not an error: a sample can cross a frame
    /// after its flight was stopped, and the flight's own answer has already
    /// had the last word.
    /// </para>
    /// </remarks>
    private void OnReport(int channel, byte[]? payload)
    {
        _uiThread.Verify(_target.Dispatcher, "a flight report from MAUI");

        try
        {
            if (NativeMethods.ReportFlight(channel, payload, payload?.Length ?? 0) == 0)
            {
                return;
            }

            // Not while a message is being applied, which is where a walk's
            // FIRST sample lands: rendering there asks Swift for a whole tree
            // against a generation the host has not finished taking, and the
            // walked property comes back as a plain value - ending the very
            // walk that reported. The write has dirtied the tree, and a dirty
            // tree is work the waker announces, so the drain that follows the
            // apply renders it a moment later.
            if (!Renderer.Busy)
            {
                Pump();
            }
        }
        catch (Exception ex)
        {
            _target.Fail("Flight report failed", ex);
        }
    }

    /// <summary>
    /// The unknown handler ids already reported. One report per id, for the
    /// reason <see cref="UiThread"/> reports once: a dead control is a standing
    /// condition, and its every press repeating the complaint would bury the
    /// first. Per ID rather than one for the whole session, because one benign
    /// late event - a replaced control's Unfocused arriving after the apply -
    /// must not use up the report a genuinely dead page needs later.
    /// </summary>
    private readonly HashSet<int> _saidNobodyHeard = [];

    /// <summary>
    /// Says that a control reported to a handler the Swift side does not know.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The Swift side answers whether anyone heard an event, and reading that
    /// answer is what keeps a whole class of bug from being silent. An id nobody
    /// knows means the controls on screen and the tree describing them have come
    /// apart: the element that issued this id has left the tree, taking its
    /// handlers with it, while the control it was rendered as is still there
    /// being pressed. Usually a page released too early.
    /// </para>
    /// <para>
    /// Nothing is refused: an event that reaches nobody has already done all the
    /// harm it can, and a diagnosable interface beats a broken one. Only element
    /// ids are reported - a COMPLETION is negative, and a completion that
    /// resumes nobody is an ordinary answer rather than a fault, which
    /// <c>Renderer.resumesPending</c> already accounts for.
    /// </para>
    /// <para>
    /// So is a control on its way OUT: <c>unloaded</c> is raised by a view the
    /// tree has already stopped describing, and the Swift side answered it as
    /// the element left. That one arrives with <c>leaving</c> set and is not a
    /// fault - see <see cref="OnEvent"/>.
    /// </para>
    /// </remarks>
    private void ReportAnEventNobodyHeard(int handlerId)
    {
        if (handlerId < 0 || !_saidNobodyHeard.Add(handlerId))
        {
            return;
        }

        Report(
            $"a control reported to handler {handlerId}, which the Swift side does " +
            "not know.\n" +
            "That control is on screen while the element behind it has left the " +
            "tree, so it will go on doing nothing. Usually something released a " +
            "page too early - see StateUIWindow.PagesStillShowing.\n" +
            "Each id is reported once.");
    }

    /// <summary>
    /// Reports an event the HOST raises by name - <see cref="StateUIEvents"/>'
    /// transport. Safe to call from any thread: the application's sources push
    /// from wherever they fire (a battery broadcast, a connectivity callback),
    /// and everything Swift runs must happen on the thread MAUI draws on, so
    /// this marshals first and dispatches then.
    /// </summary>
    internal void RaiseHostEvent(string eventName, SwiftWireValue[] payload)
    {
        IDispatcher? dispatcher = _target.Dispatcher;

        if (dispatcher is not null && dispatcher.IsDispatchRequired)
        {
            dispatcher.Dispatch(() => RaiseHostEventNow(eventName, payload));
            return;
        }

        RaiseHostEventNow(eventName, payload);
    }

    /// <summary>
    /// Pushes one standard-environment domain into Swift -
    /// <see cref="StateUIEnvironment"/>'s transport, the
    /// <see cref="RaiseHostEvent"/> shape: safe from any thread, marshalled
    /// first, dispatched then.
    /// </summary>
    /// <param name="domain">Which provider - the domain bytes on
    /// <see cref="StateUIEnvironment"/>.</param>
    /// <param name="snapshot">Builds the values ON the UI thread, so a push
    /// racing the platform's own event reads a settled answer. One that
    /// throws pushes nothing - a platform that cannot answer keeps the
    /// provider's defaults, the desktop-battery rule.</param>
    /// <param name="pump">False only for the startup pushes, which run inside
    /// the render that is about to happen anyway.</param>
    internal void PushEnvironment(byte domain, Func<SwiftWireValue[]> snapshot, bool pump = true)
    {
        IDispatcher? dispatcher = _target.Dispatcher;

        if (dispatcher is not null && dispatcher.IsDispatchRequired)
        {
            dispatcher.Dispatch(() => PushEnvironmentNow(domain, snapshot, pump));
            return;
        }

        PushEnvironmentNow(domain, snapshot, pump);
    }

    /// <summary>Whether the environment complaint was already made - a
    /// standing condition, said once, the <see cref="UiThread"/> rule.</summary>
    private bool _saidEnvironmentUnreadable;

    /// <summary>
    /// The on-thread half of <see cref="PushEnvironment"/>: builds the
    /// snapshot, writes the buffer, hands it to the library, and - outside
    /// startup - brings the interface up to date, so the views that read the
    /// changed provider are rebuilt in the same breath.
    /// </summary>
    private void PushEnvironmentNow(byte domain, Func<SwiftWireValue[]> snapshot, bool pump)
    {
        _uiThread.Verify(_target.Dispatcher, "an environment push");

        SwiftWireValue[] values;

        try
        {
            values = snapshot();
        }
        catch (Exception)
        {
            // The platform does not say - headless, or a desktop asked about
            // its battery. Nothing is pushed and the provider keeps its
            // defaults, which is the honest answer rather than a crash.
            return;
        }

        try
        {
            byte[] bytes = SwiftWire.WriteEnvironment(domain, values);

            if (NativeMethods.SetEnvironment(bytes, bytes.Length) <= 0
                && !_saidEnvironmentUnreadable)
            {
                _saidEnvironmentUnreadable = true;
                Report(
                    $"the library refused the environment push for domain {domain}. " +
                    "Usually a native library and a runtime built from different " +
                    "versions.");
            }

            if (pump)
            {
                Pump();
            }
        }
        catch (EntryPointNotFoundException)
        {
            // A native library from before the standard environment existed.
            // Its providers keep their defaults; the condition is standing,
            // so it is said once.
            if (!_saidEnvironmentUnreadable)
            {
                _saidEnvironmentUnreadable = true;
                Report("the native library predates the standard environment; " +
                    "@Environment providers keep their defaults. Rebuild the Swift side.");
            }
        }
        catch (Exception ex)
        {
            _target.Fail("Environment push failed", ex);
        }
    }

    /// <summary>Whether the stale-library complaint was already made - a
    /// standing condition, said once, the <see cref="UiThread"/> rule.</summary>
    private bool _saidHostEventsUnreadable;

    /// <summary>
    /// The on-thread half of <see cref="RaiseHostEvent"/>: writes the buffer,
    /// hands it to the library, and brings the interface up to date - a
    /// handler the raise ran may have written state, and a render must follow
    /// the same breath, the <see cref="OnEvent"/> rule.
    /// </summary>
    private void RaiseHostEventNow(string eventName, SwiftWireValue[] payload)
    {
        _uiThread.Verify(_target.Dispatcher, "an event from the host");

        try
        {
            byte[] bytes = SwiftWire.WriteHostEvent(eventName, payload);

            if (NativeMethods.DispatchHostEvent(bytes, bytes.Length) < 0
                && !_saidHostEventsUnreadable)
            {
                _saidHostEventsUnreadable = true;
                Report(
                    $"the library could not read the host event '{eventName}'. " +
                    "Usually a native library and a runtime built from different " +
                    "versions.");
            }

            Pump();
        }
        catch (EntryPointNotFoundException)
        {
            // A native library from before this channel existed. The raise is
            // dropped - nobody on that side could have subscribed - and the
            // condition is standing, so it is said once.
            if (!_saidHostEventsUnreadable)
            {
                _saidHostEventsUnreadable = true;
                Report("the native library predates host events; " +
                    "StateUIEvents.Raise is doing nothing. Rebuild the Swift side.");
            }
        }
        catch (Exception ex)
        {
            _target.Fail("Host event dispatch failed", ex);
        }
    }

    /// <summary>
    /// Brings the interface up to date and performs whatever the Swift side
    /// asked for while it was running.
    /// </summary>
    /// <remarks>
    /// In that order on purpose: a handler that changes state and navigates in
    /// the same breath should navigate to a page that already shows the change.
    /// </remarks>
    private void Pump()
    {
        // A resumed handler may have left work here since the last look.
        NativeMethods.RunJobs();

        // Only re-render if the Swift side says something changed. An event that
        // only reads state - a button that logs, a completed handler that does
        // nothing - has no reason to walk the tree at all.
        if (NativeMethods.NeedsRender() != 0)
        {
            Render(mayRetry: true);
        }

        PerformCommands();
        Cycled();
    }

    /// <summary>
    /// Takes what Swift queued and performs each act. Empty most of the time.
    /// </summary>
    private void PerformCommands()
    {
        List<SwiftCommand>? commands;

        try
        {
            IntPtr buffer = NativeMethods.TakeCommandsWire(out int length);

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
                    commands = SwiftWire.ReadCommands(
                        new ReadOnlySpan<byte>((void*)buffer, length), _names);
                }
            }
            finally
            {
                NativeMethods.FreeBuffer(buffer);
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
                NativeMethods.FailTakenCommands(
                    "the host could not read the command batch this act was in. " +
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

            _target.Fail("The commands from Swift could not be read", ex);
            return;
        }

        if (commands is null)
        {
            return;
        }

        Perform(commands);
    }

    /// <summary>
    /// Performs a batch of acts - the loop <see cref="PerformCommands"/> ends
    /// with, and the door a test comes in through.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The take above is the half that needs a Swift runtime: it reads a native
    /// buffer and frees it. Everything an ACT does is on this side of that, so
    /// splitting here is what lets a test hand the session commands read from a
    /// `fixtures/commands/*.bin` - bytes SWIFT wrote - and watch the arms, the
    /// refusal sentences and the catch blocks run for real.
    /// </para>
    /// <para>
    /// A test drives it with <see cref="Replies"/> substituted. What follows a
    /// reply - <c>Pump</c>, and the drain it schedules - still reaches the
    /// native library and fails there with no Swift runtime loaded, so a test
    /// reads the REPLY it recorded and lets the target's failures be.
    /// </para>
    /// </remarks>
    /// <param name="commands">The batch, in the order Swift queued it.</param>
    internal void Perform(IReadOnlyList<SwiftCommand> commands)
    {
        foreach (SwiftCommand command in commands)
        {
            Perform(command);
        }
    }

    /// <summary>
    /// Performs one act and reports the outcome back.
    /// </summary>
    /// <remarks>
    /// <para>
    /// <c>async void</c> deliberately: this is the far end of an event, with
    /// nobody to await it, and blocking the UI thread on a navigation would
    /// defeat the point. Everything is inside a try, so nothing escapes to the
    /// synchronization context.
    /// </para>
    /// <para>
    /// The awaiting happens on this side, where MAUI's dispatcher puts the
    /// continuation back on the UI thread. What Swift gets is the OUTCOME,
    /// reported through the same event dispatch that carries a button tap - and
    /// what resumes there is a Swift continuation, on the thread MAUI draws on.
    /// See <c>Core/MainThread.swift</c>.
    /// </para>
    /// <para>
    /// The reply crosses as typed values (<see cref="SwiftWire.WriteReply"/>):
    /// what the method returned, none for a method that returns nothing - or,
    /// when it could not be performed, a failure carrying the reason, which
    /// the awaiting Swift handler throws.
    /// </para>
    /// </remarks>
    private async void Perform(SwiftCommand command)
    {
        SwiftWireValue[] result = [];
        string? failure = null;

        try
        {
            switch (command.Act)
            {
                case SwiftAct.Focus:
                case SwiftAct.Unfocus:
                    (result, failure) = Focus(command);
                    break;

                case SwiftAct.GoBack:
                case SwiftAct.GoForward:
                case SwiftAct.Reload:
                case SwiftAct.EvaluateJavaScriptAsync:
                    (result, failure) = await Web(command);
                    break;

                case SwiftAct.MoveToRegion:
                    (result, failure) = MoveMap(command);
                    break;

                case SwiftAct.ScrollToAsync:
                    (result, failure) = await Scroll(command);
                    break;

                case SwiftAct.StopFlight:
                    // The channel, and nothing else: the host knows what that
                    // flight is moving, and the Swift side deliberately does
                    // not - it holds state, not controls.
                    result = command.GetInt(0) is int channel
                        ? Renderer.Flights.Stop(channel)
                        : [];
                    break;

                case SwiftAct.HideSoftInput:
                    // Not a MAUI method - see SwiftFocus for why there is none
                    // to call. The page is asked which of its views has the
                    // focus, because the Swift side cannot know.
                    result = [SwiftWireValue.Of(SwiftFocus.Hide(Showing()))];
                    break;

                case SwiftAct.DisplayAlertAsync:
                case SwiftAct.DisplayActionSheetAsync:
                case SwiftAct.DisplayPromptAsync:
                    (result, failure) = await Dialog(command);
                    break;

                case SwiftAct.DateTimeNow:
                {
                    // The time of day, because the Swift side deliberately has
                    // no clock: reading one through Foundation arrives with
                    // ICU, the dependency that library cannot take. Four
                    // numbers - hour, minute, second, millisecond - with the
                    // fraction because a clock ticking once a second sleeps to
                    // the NEXT whole second, and without it every lap drifts a
                    // little until a tick reads the same second twice and the
                    // one after skips one.
                    DateTime now = DateTime.Now;
                    result = [SwiftWireValue.Of(now.Hour, now.Minute, now.Second, now.Millisecond)];
                    break;
                }

                case SwiftAct.LocalTimeZone:
                    // The IANA name, whatever the platform calls its zones.
                    // Foundation's own database speaks IANA, and Windows is the
                    // one platform naming them its own way - the conversion maps
                    // "Central European Standard Time" to the CLDR canonical
                    // zone, which shares its rules with the device's even when
                    // it is a neighbouring city's name.
                    TimeZoneInfo zone = TimeZoneInfo.Local;
                    result = [SwiftWireValue.Of(
                        zone.HasIanaId ? zone.Id
                        : TimeZoneInfo.TryConvertWindowsIdToIanaId(zone.Id, out string? iana) ? iana
                        : zone.Id)];
                    break;

                case SwiftAct.GetUtcOffset:
                {
                    // Minutes, signed, as one number - India is 330 and New
                    // York is -240 in summer. The Swift side reads them into a
                    // Duration, which is stdlib rather than Foundation.
                    // The zone is TEXT - an IANA identifier is not a member of
                    // any vocabulary - and the wire's own nothing means the
                    // host's own, an empty identifier reading the same way.
                    // The day is its three numbers, and the wire's own nothing
                    // when none was asked for, so a day nobody named cannot be
                    // mistaken for one that failed to arrive.
                    string? zoneId = command.GetString(0);
                    IReadOnlyList<double>? day = command.GetNumbers(1);

                    TimeZoneInfo asked = string.IsNullOrEmpty(zoneId)
                        ? TimeZoneInfo.Local
                        : TimeZoneInfo.FindSystemTimeZoneById(zoneId);

                    TimeSpan offset;

                    if (day is not [double year, double month, double dayOfMonth])
                    {
                        // A moment, so there is nothing to interpret: an offset
                        // for "now" asked as a local DateTime would be read in
                        // the HOST's zone before the asked-for one.
                        offset = asked.GetUtcOffset(DateTimeOffset.UtcNow);
                    }
                    else
                    {
                        // NOON, deliberately. A day is a day in the zone being
                        // asked about, and midnight is the hour summer time
                        // moves in several of them - Brazil put its clocks
                        // forward at exactly 00:00, so a date read there was
                        // one the calendar had skipped.
                        var when = new DateTime(
                            (int)year, (int)month, (int)dayOfMonth, 12, 0, 0, DateTimeKind.Unspecified);

                        offset = asked.GetUtcOffset(when);
                    }

                    result = [SwiftWireValue.Of((int)offset.TotalMinutes)];
                    break;
                }

                case SwiftAct.PersistValue:
                    // Nothing is waiting on this one: the value is already in
                    // Swift's own state, and the store is where it goes to
                    // survive the process.
                    StateUIPersistence.Save(command);
                    break;

                case SwiftAct.HandlerFailed:
                    // A Swift handler let something escape. Nothing is waiting
                    // on this one - it is reported so that a failed `try await`
                    // is visible rather than lost.
                    //
                    // Through Report, like everything else here:
                    // Debug.WriteLine reaches logcat on Android and NOTHING on
                    // Apple without a debugger attached, which would leave a
                    // handler failing on a Mac silent.
                    Report($"a handler failed: {command.GetString(0)}");
                    break;

                default:
                    // The application's own acts first - a C# function
                    // registered under this name performs it, and its values
                    // answer the Swift `try await` exactly as a library act's
                    // would. See StateUIActs.
                    if (StateUIActs.Find(command.Name) is { } performer)
                    {
                        result = await performer(command);
                        break;
                    }

                    failure = $"unknown command '{command.Name}'";

                    // A command with a completion carries the failure to the
                    // Swift `try await` below; one WITHOUT would fail into
                    // silence - a version-skewed native library asking for an
                    // act this runtime has no case for - so it is reported
                    // here, the only place that will ever hear of it.
                    if (command.Completion is null)
                    {
                        Report(failure);
                    }

                    break;
            }
        }
        catch (Exception ex)
        {
            failure = ex.Message;
        }

        try
        {
            if (command.Completion is int id)
            {
                // The one chain whose thread an AWAIT decided: everything up to
                // here came back through whatever context the awaited API
                // resumed on, and what follows enters Swift.
                _uiThread.Verify(_target.Dispatcher, "a completed command");

                byte[] reply = failure is null
                    ? SwiftWire.WriteReply(result)
                    : SwiftWire.WriteFailure(failure);

                Replies(id, reply);
                Pump();

                // The continuation this just resumed is not runnable yet.
                DrainWhenTheResumeArrives();
            }
        }
        catch (Exception ex)
        {
            _target.Fail("Reporting a completed command failed", ex);
        }
    }


    // ---- Aiming an act at a view on screen ---------------------------------

    /// <summary>
    /// The view argument of an act: which map answers, the key into it, and
    /// how a failure names the view.
    /// </summary>
    /// <remarks>
    /// The same two namespaces the tree's ids travel in: a string is a name the
    /// author wrote (<see cref="StateUIRenderer.Named"/>), a number is the
    /// identity a <c>ControlState</c> captured
    /// (<see cref="StateUIRenderer.Tracked"/>).
    /// </remarks>
    /// <param name="Key">The name, or the identity's text.</param>
    /// <param name="ByIdentity">Whether the argument was a number.</param>
    private readonly record struct ActTarget(string Key, bool ByIdentity)
    {
        /// <summary>How a message names the view - "called 'panel'" or "#17".</summary>
        public string Label => ByIdentity ? $"#{Key}" : $"called '{Key}'";
    }

    /// <summary>
    /// Reads which view an act is about from its argument 0, or null when
    /// nothing usable is there.
    /// </summary>
    /// <param name="command">The act.</param>
    /// <returns>The target, or null when argument 0 is neither kind of id.</returns>
    private static ActTarget? TargetOf(SwiftCommand command)
    {
        if (command.GetString(0) is string name)
        {
            return new ActTarget(name, ByIdentity: false);
        }

        // The differ's identities are integers, and the tracked map's keys are
        // their decimal spelling.
        if (command.GetDouble(0) is double identity)
        {
            return new ActTarget(
                ((long)identity).ToString(CultureInfo.InvariantCulture),
                ByIdentity: true);
        }

        return null;
    }

    /// <summary>
    /// The control an act's target resolves to, through whichever map its
    /// namespace says.
    /// </summary>
    /// <param name="target">The act's view argument.</param>
    /// <returns>Null when nothing it names is being shown.</returns>
    private (VisualElement View, string Type)? Find(ActTarget target) =>
        target.ByIdentity ? Renderer.Tracked(target.Key) : Renderer.Named(target.Key);

    /// <summary>
    /// The same lookup, for an APPLICATION's registered act - reached through
    /// <see cref="StateUIActs.TargetOf"/>, which is the only thing that calls
    /// this.
    /// </summary>
    /// <remarks>
    /// The two maps are the renderer's and stay its own; what an application
    /// needs is the answer, not the namespaces. Type is dropped on the way out
    /// because a performer written for one control tests for it with <c>is</c>,
    /// which reads better than comparing the name this side happens to use.
    /// </remarks>
    /// <param name="command">The act, with the control's identity at 0.</param>
    /// <returns>The control, or null when argument 0 names none on screen.</returns>
    internal VisualElement? Aimed(SwiftCommand command) =>
        TargetOf(command) is { } target && Find(target) is { } found ? found.View : null;

    /// <summary>
    /// Slides the Map the Swift side named to the region around a point -
    /// MAUI's <c>MoveToRegion</c>, the span built with
    /// <c>MapSpan.FromCenterAndRadius</c> and the radius in meters, which is
    /// what <c>Distance</c> is at bottom.
    /// </summary>
    /// <remarks>
    /// The same shape as a WebView act: the view at argument 0, found through
    /// <see cref="TargetOf"/>, and a view of another type is a FAILURE rather
    /// than a silence. The three numbers are REFUSED when absent or NaN - a map
    /// moved to a zero nobody asked for is the Atlantic, drawn perfectly.
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private (SwiftWireValue[] Result, string? Failure) MoveMap(SwiftCommand command)
    {
        if (TargetOf(command) is not { } target)
        {
            return ([], "a Map act has to say which view it is for");
        }

        if (Find(target) is not { } found)
        {
            return ([], $"there is no view {target.Label} on screen");
        }

        if (found.View is not Microsoft.Maui.Controls.Maps.Map map)
        {
            return ([], $"the view {target.Label} is a {found.Type}, not a Map");
        }

        if (command.GetDouble(1) is not double latitude
            || command.GetDouble(2) is not double longitude
            || command.GetDouble(3) is not double radius)
        {
            return ([], "Map.MoveToRegion needs latitude, longitude and a radius "
                + "in meters, and one of them is absent or not a number");
        }

        map.MoveToRegion(SwiftValues.MapSpan(latitude, longitude, radius));

        return ([], null);
    }

    /// <summary>
    /// Drives the WebView the Swift side named - back, forward, fetching the
    /// page again, and running JavaScript in it.
    /// </summary>
    /// <remarks>
    /// All four are MAUI methods on the control, named at argument 0 like every
    /// other act's view. A view of another type is a FAILURE rather than a
    /// silence: an act that does nothing looks exactly like a page with no
    /// history.
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private async Task<(SwiftWireValue[] Result, string? Failure)> Web(SwiftCommand command)
    {
        if (TargetOf(command) is not { } target)
        {
            return ([], "a WebView act has to say which view it is for");
        }

        if (Find(target) is not { } found)
        {
            return ([], $"there is no view {target.Label} on screen");
        }

        if (found.View is not WebView web)
        {
            return ([], $"the view {target.Label} is a {found.Type}, not a WebView");
        }

        switch (command.Act)
        {
            case SwiftAct.GoBack:
                web.GoBack();
                return ([], null);

            case SwiftAct.GoForward:
                web.GoForward();
                return ([], null);

            case SwiftAct.Reload:
                web.Reload();
                return ([], null);

            default:
                // What the script's last expression evaluated to, as the
                // platform writes it - null when the page answered nothing.
                string script = command.GetString(1) ?? "";
                return ([SwiftWireValue.Of(await web.EvaluateJavaScriptAsync(script) ?? "")], null);
        }
    }

    /// <summary>
    /// Scrolls a ScrollView to the offset the Swift side asked for.
    /// </summary>
    /// <remarks>
    /// MAUI's method on the control, named at argument 0 like every other act's
    /// view; a view of another type is a FAILURE rather than a silence, the
    /// WebView rule. The MAUI task is completed by <c>SendScrollFinished</c>,
    /// which only a live platform handler calls - so a view that is NOT
    /// attached is reported done without calling, the way walking an off-screen
    /// view reports finished. Awaiting there instead would suspend the Swift
    /// handler forever, with nothing anywhere saying why.
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private async Task<(SwiftWireValue[] Result, string? Failure)> Scroll(SwiftCommand command)
    {
        if (TargetOf(command) is not { } target)
        {
            return ([], "a scroll act has to say which view it is for");
        }

        if (Find(target) is not { } found)
        {
            return ([], $"there is no view {target.Label} on screen");
        }

        if (found.View is not ScrollView scroller)
        {
            return ([], $"the view {target.Label} is a {found.Type}, not a ScrollView");
        }

        if (command.GetDouble(1) is not double x
            || command.GetDouble(2) is not double y
            || command.GetBool(3) is not bool animated)
        {
            return ([], "scrolling takes an x, a y, and whether to animate");
        }

        if (scroller.Handler is null)
        {
            return ([], null);
        }

        // An ANIMATED scroll is the same movement a settle is - this side's
        // own curve over this side's own time - so an author moving a carousel
        // by assigning a position sees what a reader letting go of it sees.
        // Told to jump, MAUI's own request is the shortest way there.
        if (animated)
        {
            await Renderer.SettleOf(scroller).GlideTo(x, y);
        }
        else
        {
            await Renderer.SettleOf(scroller).JumpTo(x, y);
        }

        return ([], null);
    }

    /// <summary>
    /// Moves the keyboard onto, or off, the control the Swift side named.
    /// </summary>
    /// <remarks>
    /// Both are MAUI methods on the view, named at argument 0 like every other
    /// act's view - an id being the only handle that survives a render.
    /// <c>Focus</c> answers whether the view took the focus, which is MAUI's own
    /// answer and an ordinary one: a disabled view, or one with nothing to type
    /// into, says no.
    /// <c>Unfocus</c> answers nothing, so the Swift call awaits and reads no
    /// result.
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private (SwiftWireValue[] Result, string? Failure) Focus(SwiftCommand command)
    {
        if (TargetOf(command) is not { } target)
        {
            return ([], "a focus act has to say which view it is for");
        }

        if (Find(target) is not { } found)
        {
            return ([], $"there is no view {target.Label} on screen");
        }

        if (command.Act == SwiftAct.Unfocus)
        {
            found.View.Unfocus();
            return ([], null);
        }

        return ([SwiftWireValue.Of(found.View.Focus())], null);
    }

    /// <summary>
    /// Shows a dialog on the page the reader is looking at, and reports what
    /// they chose. MAUI: Page.DisplayAlertAsync, DisplayActionSheetAsync and
    /// DisplayPromptAsync - the two alert forms told apart by their argument
    /// count, everything in the order MAUI's parameters have.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The command names no page: a dialog belongs to whatever is showing -
    /// the modal top included - which only the host can know. The SoftInput
    /// reasoning, one act over.
    /// </para>
    /// <para>
    /// The page must be ON SCREEN: MAUI completes these tasks from the
    /// platform's alert manager, so on a page with no handler they NEVER
    /// complete and the awaiting Swift handler hangs forever with nothing
    /// anywhere saying why - the ScrollToAsync lesson. Reported as a failure
    /// instead, which reaches the Swift `try await` as a thrown error.
    /// </para>
    /// <para>
    /// Two of the answers can be NOTHING - an action sheet dismissed without
    /// choosing, a prompt cancelled - and the reply's COUNT is what says so: a
    /// choice crosses as one string value, a dismissal as no values at all. An
    /// accepted prompt with nothing typed is one empty string - an empty
    /// answer, which is not the same as no answer.
    /// </para>
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private async Task<(SwiftWireValue[] Result, string? Failure)> Dialog(SwiftCommand command)
    {
        if (SwiftFocus.Showing(Showing()) is not Page page)
        {
            return ([], "there is no page to show a dialog on");
        }

        if (page.Handler is null)
        {
            return ([], "the page is not on screen, so a dialog would never return");
        }

        string title = command.GetString(0) ?? "";

        switch (command.Act)
        {
            case SwiftAct.DisplayAlertAsync when command.Arguments?.Count == 3:
                await page.DisplayAlertAsync(
                    title, command.GetString(1) ?? "", command.GetString(2) ?? "OK");
                return ([], null);

            case SwiftAct.DisplayAlertAsync:
                bool accepted = await page.DisplayAlertAsync(
                    title,
                    command.GetString(1) ?? "",
                    command.GetString(2) ?? "OK",
                    command.GetString(3) ?? "Cancel");
                return ([SwiftWireValue.Of(accepted)], null);

            case SwiftAct.DisplayActionSheetAsync:
                // The two optional captions arrive as the wire's own nothing
                // when they are absent, and read as null here without a
                // sentinel in between: an empty string is a caption someone
                // could have written, and telling the special ones apart would
                // be the reader's job.
                var buttons = new string[Math.Max(0, (command.Arguments?.Count ?? 3) - 3)];
                for (int index = 0; index < buttons.Length; index++)
                {
                    buttons[index] = command.GetString(index + 3) ?? "";
                }

                string? pressed = await page.DisplayActionSheetAsync(
                    title,
                    command.GetString(1),
                    command.GetString(2),
                    buttons);
                return (Chosen(pressed), null);

            default:
                string? typed = await page.DisplayPromptAsync(
                    title,
                    command.GetString(1) ?? "",
                    command.GetString(2) ?? "OK",
                    command.GetString(3) ?? "Cancel",
                    command.GetString(4),

                    // -1 is MAUI's own "no limit" for this parameter, not a
                    // sentinel of ours: the wire says the length is not there
                    // and this is what MAUI wants to hear for that.
                    command.GetInt(5) ?? -1,
                    SwiftValues.KeyboardOf(command.GetEnumeration(6)) ?? Keyboard.Default,
                    command.GetString(7) ?? "");
                return (Chosen(typed), null);
        }
    }

    /// <summary>
    /// An answer that may be nothing: the caption that was pressed, or the
    /// wire's own nothing for a dialog the reader dismissed.
    /// </summary>
    /// <remarks>
    /// One value either way, so that the fact sits IN the answer rather than in
    /// the shape of the reply: an empty reply already means "this act returns
    /// nothing at all", which is a different thing from a reader who chose
    /// nothing. Both read as null on the Swift side.
    /// </remarks>
    private static SwiftWireValue[] Chosen(string? answer) =>
        [answer is null ? new SwiftWireValue(SwiftWireValue.TagNothing) : SwiftWireValue.Of(answer)];


    /// <summary>
    /// The page whose focus is on screen, wherever the application put it.
    /// </summary>
    /// <remarks>
    /// The window's page - which is an ARRANGEMENT, so what the reader is
    /// actually looking at is found by descending through it; that is
    /// <see cref="SwiftFocus.Showing"/>'s job, and every caller here goes
    /// through it.
    /// <para>
    /// The window the reader is WORKING IN, where a desktop application has
    /// several. MAUI does not say which window has the keyboard, but it does
    /// report activation per window - so the application follows that, and an
    /// alert raised from the second window opens over the second window. Any
    /// other target - a Swift tree embedded in someone else's page - has no
    /// window list of its own and falls back to MAUI's first.
    /// </para>
    /// </remarks>
    /// <returns>The page, or null when the application has no window yet.</returns>
    private Page? Showing() =>
        (_target as StateUIApplication)?.Active?.Page
            ?? Application.Current?.Windows.FirstOrDefault()?.Page;

    // ---- Diagnostics -------------------------------------------------------

    /// <summary>
    /// Renders a diagnostic instead of throwing, so the app stays usable and the
    /// cause is visible on the device rather than only in a log.
    /// </summary>
    public static View BuildError(string message, Exception? exception)
    {
        var stack = new VerticalStackLayout
        {
            Padding = new Thickness(24),
            Spacing = 12,
        };

        stack.Add(new Label
        {
            Text = "StateUI",
            FontSize = 24,
            FontAttributes = FontAttributes.Bold,
            TextColor = Colors.Firebrick,
        });

        stack.Add(new Label { Text = message });

        if (exception is not null)
        {
            stack.Add(new Label
            {
                Text = exception.Message,
                FontSize = 12,
                TextColor = Colors.Gray,
            });
        }

        return new ScrollView { Content = stack };
    }
}
