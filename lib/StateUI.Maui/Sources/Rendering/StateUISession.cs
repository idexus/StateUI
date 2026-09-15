// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Globalization;
using System.Runtime.InteropServices;
using System.Text.Json;
using StateUI.Maui.Interop;
using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

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
    /// The root Application node of the message, whose children are its scenes,
    /// and theirs the windows.
    /// </param>
    /// <param name="complete">
    /// Whether this message describes everything rather than only what changed.
    /// </param>
    bool Apply(HostPatch application, bool complete);

    /// <summary>Shows a diagnostic in place of the interface.</summary>
    void Fail(string message, Exception? exception);

    /// <summary>
    /// MAUI's dispatcher for the thread this target draws on, or null where
    /// there is no platform under it - a test.
    /// </summary>
    /// <remarks>
    /// Used to put a suspended Swift handler back on that thread, and to carry
    /// there whatever arrives from another - an event, a host event, an
    /// environment push - before it enters Swift; a target with none parks no
    /// waiting thread. MAUI is the authority on which thread that is; the Swift
    /// side deliberately has no opinion, which is what keeps this working the
    /// same on every platform.
    /// </remarks>
    IDispatcher? Dispatcher { get; }
}

/// <summary>
/// One interface's session with the core: it takes the process, renders the
/// core's messages into its target and carries the platform's word in - events,
/// host events, environment pushes - while its <see cref="Pump"/> brings the
/// core's work back out.
/// </summary>
internal sealed class StateUISession
{
    /// <summary>What this session renders into.</summary>
    private readonly IStateUITarget _target;

    /// <summary>
    /// Checks that each crossing into Swift starts on the thread MAUI draws on.
    /// </summary>
    private readonly UiThread _uiThread = new(message => Report(message));

    /// <summary>
    /// This session's numbering of every name the wire carries, learned from
    /// the announcements at the head of each message - see
    /// <see cref="WireDictionary"/>. One per session, shared by the tree
    /// and the acts, exactly as the Swift side keeps one per renderer.
    /// </summary>
    /// <remarks>
    /// The two are one dictionary in two halves, which is the whole reason
    /// there may be only one live session per process - see <see cref="_live"/>.
    /// A name is announced the FIRST time the Swift side writes it and never
    /// again, so a second session, starting empty here, would read numbers
    /// nothing ever told it the meaning of.
    /// </remarks>
    private readonly WireDictionary _names = new();

    /// <summary>
    /// Whether the Swift application has registered itself. Static because there
    /// is one Swift runtime per process - and, over it, the one live session.
    /// </summary>
    private static bool _initialized;

    /// <summary>Takes the core's messages into the tree, one whole message at a time.</summary>
    private readonly PatchIntake _intake = new();

    /// <summary>
    /// Brings the core's work onto the thread MAUI draws on - the doorbell, the
    /// drain after a resume, and each turn of jobs, a pending cycle, the render
    /// and the acts.
    /// </summary>
    private readonly Pump _pump;

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
        Renderer = new StateUIRenderer(OnEvent);
        ActPerformer = new(target, Renderer, _uiThread, () => _pump!.Replied());
        _pump = new Pump(target, _uiThread, _names, Renderer, ActPerformer, Render, () => _intake.Mounted);
    }

    /// <summary>
    /// A session whose events go somewhere of the caller's instead of to Swift -
    /// what a test hears an application's reports through, there being no Swift
    /// behind it to hear them.
    /// </summary>
    /// <param name="target">What the session renders into.</param>
    /// <param name="dispatch">Where an event goes: its handler id and its payload.</param>
    internal StateUISession(IStateUITarget target, Action<int, byte[]?> dispatch)
    {
        _target = target;
        Renderer = new StateUIRenderer(dispatch);
        ActPerformer = new(target, Renderer, _uiThread, () => _pump!.Replied());
        _pump = new Pump(target, _uiThread, _names, Renderer, ActPerformer, Render, () => _intake.Mounted);
    }

    /// <summary>
    /// The one session rendering the Swift application in this process, or null
    /// while nothing has rendered yet.
    /// </summary>
    /// <remarks>
    /// <para>
    /// <b>One live session per process; the windows belong to that session.</b>
    /// The other side is a single <c>Renderer.shared</c> holding one tree, one
    /// generation, one handler registry, one act queue and one wire
    /// dictionary. A second session here would quote a baseline against a tree
    /// it does not own, read name numbers it never heard announced (see
    /// <see cref="_names"/>), and drain acts raised by the other one's
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
                "shows several things at once opens them as windows of its scenes; one that " +
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
        // `Color(light:dark:)` and `ImageSource(light:dark:)` carry both halves
        // as far as the differ, which picks the half as it builds the element
        // wearing one and records that read against the element - so pushing
        // `requestedTheme` builds exactly the elements wearing a pair, and the
        // render that follows carries their other halves. The wire never
        // carries a pair; no binding, no states to build again. See
        // Types/Color.swift and Core/Diff.swift.
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

    /// <summary>Materializes views; targets use it for page content.</summary>
    public StateUIRenderer Renderer { get; }

    /// <summary>
    /// Brings the interface up to date, then performs whatever the render asked
    /// for.
    /// </summary>
    public void Render()
    {
        // Started HERE and not in the constructor, because a target may not
        // have had a dispatcher while the session was being made - and a
        // test's target has none, which is what keeps a test session,
        // rendering or not, from parking a thread: a thread parked in a
        // P/Invoke with nothing behind it took the whole test process down.
        // See Pump.StartDoorbell.
        // And the process itself comes first: a session that is not the
        // live one has no tree to describe and no queue to drain - the
        // acts below belong to whichever session owns the runtime.
        if (!BecomeLive())
        {
            return;
        }

        _pump.StartDoorbell();
        _pump.Render();
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
        _intake.Forget();
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
    internal void Forget() => _intake.Forget();

    /// <summary>
    /// Registers the application before anything is handed to it - what a
    /// target calls before telling Swift about a window the platform made.
    /// </summary>
    /// <remarks>
    /// Registering is what gives Swift its application, and with it the one
    /// scene waiting for the platform's first window: a window announced before
    /// that is announced to nothing, and the registration that follows starts
    /// the scenes over without it. The first render registers anyway; this is
    /// the same once-per-process step, taken earlier.
    /// </remarks>
    internal void Register()
    {
        if (_initialized || RegisterApp is not { } register || !BecomeLive())
        {
            return;
        }

        try
        {
            Initialize(register);
        }
        catch (Exception ex) when (ex is DllNotFoundException or EntryPointNotFoundException)
        {
            // No runtime to register with - the render that follows says so.
        }
    }

    /// <summary>
    /// Registers the Swift application and gives it what it needs before its
    /// first tree - once per process.
    /// </summary>
    /// <param name="register">The app module's registration.</param>
    /// <returns>False where the two halves do not match, which has been said.</returns>
    private bool Initialize(Action register)
    {
        // Two halves built from different versions must fail HERE, with a
        // sentence - never later, by reading each other's bytes wrong. A
        // library too old to have the export fails the same check as
        // EntryPointNotFoundException. First of all, because everything after
        // it hands the library bytes.
        int wire = CoreLink.WireVersion();
        if (wire != WireCodec.Version)
        {
            _target.Fail(
                $"The native library speaks wire version {wire} and " +
                $"this runtime speaks {WireCodec.Version}.\n\n" +
                "A native library and a runtime built from different " +
                "versions - rebuild the app so the two halves match.",
                null);
            return false;
        }

        // The standard environment: every provider's values, told BEFORE the
        // application is made - its `init` writes its session from them, a
        // style sheet answering the idiom - and before the first tree, which
        // pages exist may depend on; then wired to the platform's change
        // events for everything after.
        StateUIEnvironment.Start(this);

        register();

        // KEPT STATE, before anything is built: a `@State` under a
        // PersistentKey has to hold the stored value the first time a view
        // reads it, and a Swift read cannot wait for this side. Once per
        // process rather than once per render - behind _initialized, which
        // Resync deliberately does not clear, or a lost generation would
        // reload the store over live state.
        StateUIPersistence.Start();

        // STATEUI_INSPECT=1: asking once is what starts the Swift side
        // recording, so the first render is in the log too.
        RenderTally.WriteInspection();

        _initialized = true;
        return true;
    }

    /// <summary>
    /// Renders one message with the application's handlers held until it is
    /// in - see <see cref="RenderMessage"/>.
    /// </summary>
    /// <remarks>
    /// THE HANDLERS WAIT FOR THE MESSAGE: one raised while it is being applied -
    /// a journey landing, a window restored - is raised once it is in and its
    /// generation claimed, so it neither runs inside the apply nor is lost to
    /// it. See <see cref="HandlerDispatch"/>.
    /// </remarks>
    /// <param name="mayRetry">Whether a refused message may be asked for again whole.</param>
    private void Render(bool mayRetry)
    {
        Renderer.Handlers.Hold();

        try
        {
            RenderMessage(mayRetry);
        }
        finally
        {
            Renderer.Handlers.Release();
        }
    }

    /// <summary>
    /// Asks Swift for the change since the last message applied in full, and
    /// applies it.
    /// </summary>
    /// <param name="mayRetry">
    /// Whether a target that cannot apply the message may be given one more go
    /// with the whole tree. False on that second attempt, which is what makes it
    /// terminate.
    /// </param>
    private void RenderMessage(bool mayRetry)
    {
        // Dropped as it is quoted, so that anything going wrong below leaves
        // this side asking for the whole tree rather than for a patch onto a
        // visual tree it only half applied.
        int baseline = _intake.Quote();

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

            if (!_initialized && !Initialize(register))
            {
                return;
            }

            // WHAT AN INSPECTOR IS SHOWN of this side's half: asked of Swift
            // once a render, and measured and reported only while one is
            // recording. The counts are the tally's own, kept for the length
            // of this message. See Core/Inspection.swift.
            bool inspecting = CoreLink.Inspecting() != 0;
            RenderTally.Inspecting = inspecting;
            RenderTally.Scenes.Clear();
            long nodes = RenderTally.Nodes;
            long made = RenderTally.Made;
            long kept = RenderTally.Kept;
            long adopted = RenderTally.Adopted;

            HostRender message;
            int described = 0;
            IntPtr raw = RenderTally.Time(
                ref RenderTally.Described,
                () => CoreLink.RenderWire(baseline, out described));
            int length = described;
            long reading = System.Diagnostics.Stopwatch.GetTimestamp();

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
                            return WireCodec.ReadMessage(
                                new ReadOnlySpan<byte>((void*)bytes, count), _names);
                        }
                    });
            }
            finally
            {
                CoreLink.FreeBuffer(raw);
            }

            double read = RenderTally.Micros(reading);

            if (message.Root is null)
            {
                _target.Fail("Swift returned an empty UI tree", null);
                return;
            }

            if (message.Root.Type != HostNodeType.Application)
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
            // LayoutMotion.
            if (message.Root.Moves && message.Root.Motion is HostMotion placement)
            {
                Renderer.Walker.Travel = placement;
            }

            // Swift says whether this is the whole tree; it is not inferred from
            // the baseline, which is right for a first render and wrong for
            // every other resync. A baseline of zero always brings the whole
            // tree back, which is what makes the retry below terminate.

            long applying = System.Diagnostics.Stopwatch.GetTimestamp();

            if (!_intake.Take(message, _target.Apply))
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

            // Every scene's part first, then the message's own, which is the
            // report the Swift side finishes the render with.
            if (inspecting)
            {
                double apply = RenderTally.Micros(applying);

                for (int index = 0; index < RenderTally.Scenes.Count; index++)
                {
                    CoreLink.InspectScene(message.Generation, index, RenderTally.Scenes[index]);
                }

                CoreLink.InspectApplied(
                    message.Generation,
                    read,
                    apply,
                    (int)(RenderTally.Nodes - nodes),
                    (int)(RenderTally.Made - made),
                    (int)(RenderTally.Kept - kept),
                    (int)(RenderTally.Adopted - adopted));

                RenderTally.WriteInspection();
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

    /// <summary>
    /// Says something went wrong where nothing else can - a state the interface
    /// cannot show without making things worse.
    /// </summary>
    /// <param name="message">What happened, in the imperative where there is something to do.</param>
    /// <param name="exception">The cause, if there was one.</param>
    /// <remarks>
    /// Console rather than <c>Debug.WriteLine</c>: stderr reaches a developer
    /// on every platform, and a Debug build on Android forwards it to logcat -
    /// a Release build there forwards nothing, so a Release diagnostic on that
    /// platform goes through <c>Android.Util.Log</c>. Prefixed so it can be
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
    private void OnEvent(int handlerId, byte[]? payload)
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
        // thread: a journey's completion arrived on a pool thread, which is the
        // only report that ever did. The check below stands - it is what names
        // a platform doing this - and the move is what keeps the tree safe
        // while it does.
        // Nothing is said about it, because nothing is wrong once it has moved:
        // the check below is for a crossing this cannot answer, and a warning
        // about state being lost would be untrue of a report that was carried
        // to the right thread instead.
        if (_target.Dispatcher is IDispatcher dispatcher && dispatcher.IsDispatchRequired)
        {
            dispatcher.Dispatch(() => OnEvent(handlerId, payload));
            return;
        }

        _uiThread.Verify(_target.Dispatcher, "an event from MAUI");

        try
        {
            if (CoreLink.DispatchWire(handlerId, payload, payload?.Length ?? 0) == 0)
            {
                ReportAnEventNobodyHeard(handlerId);
            }

            // Never inside an apply: the handler dispatch holds whatever is
            // raised while a message is being applied - a journey's
            // completion, a snap over a walking property aborting it - until
            // the message is in, so the render asked for here is one of its
            // own rather than a resync against a generation not yet claimed.
            _pump.Run();

            // A NEGATIVE id is not an event: it is a completion, and what it
            // resumed is a handler whose next job does not exist yet. The
            // act path says the same thing in Pump.Replied; a journey's
            // answer lands here instead, having queued no act.
            if (handlerId < 0)
            {
                _pump.DrainWhenTheResumeArrives();
            }
        }
        catch (Exception ex)
        {
            _target.Fail("Event dispatch failed", ex);
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
            "page too early - see PagePresenter, which keeps a page for as long as the arrangement it is on names it.\n" +
            "Each id is reported once.");
    }

    /// <summary>
    /// Reports an event the HOST raises by name - <see cref="StateUIEvents"/>'
    /// transport. Safe to call from any thread: the application's sources push
    /// from wherever they fire (a battery broadcast, a connectivity callback),
    /// and everything Swift runs must happen on the thread MAUI draws on, so
    /// this marshals first and dispatches then.
    /// </summary>
    internal void RaiseHostEvent(string eventName, HostValue[] payload)
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
    internal void PushEnvironment(byte domain, Func<HostValue[]> snapshot, bool pump = true)
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
    private void PushEnvironmentNow(byte domain, Func<HostValue[]> snapshot, bool pump)
    {
        _uiThread.Verify(_target.Dispatcher, "an environment push");

        HostValue[] values;

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
            byte[] bytes = WireCodec.WriteEnvironment(domain, values);

            if (CoreLink.SetEnvironment(bytes, bytes.Length) <= 0
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
                _pump.Run();
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
    private void RaiseHostEventNow(string eventName, HostValue[] payload)
    {
        _uiThread.Verify(_target.Dispatcher, "an event from the host");

        try
        {
            byte[] bytes = WireCodec.WriteHostEvent(eventName, payload);

            if (CoreLink.DispatchHostEvent(bytes, bytes.Length) < 0
                && !_saidHostEventsUnreadable)
            {
                _saidHostEventsUnreadable = true;
                Report(
                    $"the library could not read the host event '{eventName}'. " +
                    "Usually a native library and a runtime built from different " +
                    "versions.");
            }

            _pump.Run();
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

    /// <summary>Performs the acts the application calls, and answers each.</summary>
    internal ActPerformer ActPerformer { get; }

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
