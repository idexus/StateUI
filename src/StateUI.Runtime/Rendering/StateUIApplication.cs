// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Runtime.Interop;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// The Swift application: one render session, the scenes it describes, and
/// the platform windows each of them shows.
/// </summary>
/// <remarks>
/// <para>
/// Not a MAUI <see cref="Application"/> - the app's own <c>App</c> class is
/// that, and it still opens a <see cref="StateUIWindow"/> from its
/// <c>CreateWindow</c>. This is what sits behind those windows. The root of
/// every message is an <c>Application</c> node whose children are SCENES, one
/// per session the application has open, and a scene's children are its
/// windows - its MAIN window first, then the windows it has open beside it,
/// each of those carrying its group's kind:
/// <code>
/// Application
///   Scene "1"
///     Window "main"
///     Window "gallery.fonts 1"     windowType, windowValue, autoHide, floatsOnTop
/// </code>
/// Keeping the platform's windows in step with that is the whole of what this
/// class does.
/// </para>
/// <para>
/// <b>One session, N windows.</b> A window is a target for its own node and
/// nothing more - it holds no session, no generation counter and no baseline.
/// That is what lets a second window cost a node in the tree instead of a
/// second render loop, and it is why the session's target is this rather than
/// any one window. A process holds ONE live session, and scenes and their
/// windows are how one of those shows several things at once. See
/// <see cref="StateUISession"/>.
/// </para>
/// <para>
/// <b>A window the platform makes is a scene's main window.</b> At launch,
/// for <i>File ▸ New Window</i> and for every scene the system restores, the
/// platform asks the app for a window and the app builds one of these. Swift is
/// told at once, with whatever the platform kept for that session, and its
/// answer - a scene with no window yet - is rendered before the constructor
/// returns, so the platform never shows the window without the page the tree
/// described. A restored window that was ANOTHER scene's - a tool window, a
/// document - says so in what the platform kept, and is offered to that scene
/// instead; one the scene does not take is closed. See
/// <see cref="SceneSessions"/>.
/// </para>
/// <para>
/// <b>Any other window is opened for a node that has none.</b>
/// <see cref="Microsoft.Maui.Controls.Application.OpenWindow"/> remembers the
/// instance it is given under a generated id and hands that very instance back
/// when the platform's new scene asks for a window, so the window built here is
/// the window that appears. It is BUILT, then described, and only then opened:
/// WinUI reads a window's content INSIDE <c>OpenWindow</c> and throws <i>"No
/// page was set on the window"</i> when there is none, and the slot recorded
/// first is what makes a window that fails to open fail ONCE, instead of being
/// opened again by every render that finds no slot for its node. What CLOSES
/// one is its node leaving an arranged list.
/// </para>
/// <para>
/// <b>What the reader closes is reported, and never opened again.</b> A
/// scene's main window going is the scene ending, which closes every window
/// beside it; any other window going is that window closing, and its scene is
/// told which. The slot stays, emptied, until the tree stops describing it, so
/// a render in between opens nothing.
/// </para>
/// </remarks>
internal sealed class StateUIApplication : IStateUITarget
{
    /// <summary>
    /// The one a plain <c>new StateUIWindow()</c> joins.
    /// </summary>
    /// <remarks>
    /// A process runs one Swift application - <c>Renderer.shared</c> on the
    /// other side is a single object too - so the window an app returns from
    /// <c>CreateWindow</c> has exactly one session it can belong to. Tests make
    /// their own instead of reaching this, which is what keeps one test's
    /// windows out of the next one's.
    /// </remarks>
    private static StateUIApplication? _current;

    /// <summary>The application every window without one of its own joins.</summary>
    internal static StateUIApplication Current => _current ??= new StateUIApplication();

    /// <summary>The render loop behind every window here.</summary>
    private readonly StateUISession _session;

    /// <summary>
    /// What tells Swift the platform has handed over a scene's window - the
    /// native call, or whatever a test puts in its place.
    /// </summary>
    private readonly Func<byte[], int> _connect;

    /// <summary>One per scene the tree describes, in the order the tree names them.</summary>
    private readonly List<SceneSlot> _scenes = [];

    /// <summary>
    /// The windows the platform has handed over as a scene's main window that
    /// no scene has claimed yet, oldest first.
    /// </summary>
    /// <remarks>
    /// Claimed by the render the handing over asks for, which is the next thing
    /// that happens - so a window waits here only while that render cannot run:
    /// a failed one, or a test that applies its messages by hand. A QUEUE for
    /// the case the platform hands several over together, which a Mac restoring
    /// a session's worth of windows does about 13 ms apart.
    /// </remarks>
    private readonly Queue<StateUIWindow> _free = new();

    /// <summary>
    /// The windows the system restored as one of a scene's other windows,
    /// until that scene says whether it takes them.
    /// </summary>
    private readonly List<Restored> _restored = [];

    /// <summary>
    /// MAUI's dispatcher, kept from the first window, so that a suspended Swift
    /// handler can be put back on the UI thread even while no window is open.
    /// </summary>
    private IDispatcher? _dispatcher;

    /// <summary>The window the reader came to last.</summary>
    private StateUIWindow? _active;

    /// <summary>The scene the reader is working in, once they have come to one.</summary>
    private SceneSlot? _front;

    /// <summary>How many messages have been applied - what an offer is timed against.</summary>
    private int _applies;

    /// <summary>
    /// Whether a window's hiding changed during the message being applied, so
    /// the scenes' windows are arranged again once it has been.
    /// </summary>
    private bool _rearrange;

    /// <summary>
    /// The timer that closes the restored windows whose scene never came back,
    /// while one is running.
    /// </summary>
    private IDispatcherTimer? _abandoning;

    /// <summary>What materializes the views - one renderer for the lot.</summary>
    internal StateUIRenderer Renderer => _session.Renderer;

    /// <summary>
    /// Drops the tree the session believes C# is showing, so the next render
    /// is complete - what a window calls when it has replaced its page with an
    /// error. See <see cref="StateUISession.Forget"/>.
    /// </summary>
    internal void Forget() => _session.Forget();

    /// <summary>
    /// The window a page-level act should reach: the one the reader is working
    /// in, which is the one they came to last.
    /// </summary>
    /// <remarks>
    /// MAUI does not say which window has the keyboard; activation does on most
    /// platforms and AppKit's own notification does on a Mac (see
    /// <see cref="SceneFocus"/>) - so an alert raised from the second window
    /// opens over the second window. The first described window until the
    /// reader has come to one; null while the tree describes no window that
    /// is still there.
    /// </remarks>
    internal StateUIWindow? Active => _active ?? Windows.FirstOrDefault();

    /// <summary>
    /// The windows that are open, scene by scene - each scene's main window
    /// first, then the others in the order they opened.
    /// </summary>
    internal IEnumerable<StateUIWindow> Windows =>
        _scenes.SelectMany(scene => scene.Windows).Select(slot => slot.Window).OfType<StateUIWindow>();

    /// <summary>Makes an application with a session and no windows yet.</summary>
    internal StateUIApplication()
        : this(null, null)
    {
    }

    /// <summary>
    /// An application whose reports and handings over go somewhere of the
    /// caller's - what a test hears them through, there being no Swift behind
    /// it.
    /// </summary>
    /// <param name="dispatch">
    /// Where the scenes' reports go: a handler id and a payload. Null for Swift.
    /// </param>
    /// <param name="connect">
    /// What a window the platform handed over is announced with - the payload
    /// of kept names and values - answering what the native call answers. Null
    /// for Swift.
    /// </param>
    internal StateUIApplication(Action<int, byte[]?>? dispatch, Func<byte[], int>? connect)
    {
        _session = dispatch is null ? new StateUISession(this) : new StateUISession(this, dispatch);
        _connect = connect ?? Connect;
    }

    IDispatcher? IStateUITarget.Dispatcher => _dispatcher;

    /// <summary>Tells the Swift side a window was handed over, where there is one.</summary>
    /// <param name="payload">The scene's kept values, as name and value pairs.</param>
    /// <returns>What the native call answers; nought where there is nothing to call.</returns>
    private static int Connect(byte[] payload)
    {
        try
        {
            return NativeMethods.ConnectScene(payload, payload.Length);
        }
        catch (Exception ex) when (ex is DllNotFoundException or EntryPointNotFoundException)
        {
            // No Swift side - the render that follows says so, once.
            return 0;
        }
    }

    // ---- The windows the platform gives us ---------------------------------

    /// <summary>
    /// Subscribes to a window's lifecycle - the tree's handlers and this
    /// class's own bookkeeping.
    /// </summary>
    /// <param name="window">A window of this application, as it is built.</param>
    internal void Watch(StateUIWindow window)
    {
        _dispatcher ??= window.Dispatcher;

        // MAUI's six Window events, subscribed once, before the platform can
        // raise any of them. Every window node carries a handler for each,
        // which moves that window's WindowSession.phase: the window tracks its
        // node, and Raise quotes the ids on it.
        Renderer.WireWindow(window);

        // And what its SCENE hears: where the scene stands, and a window going.
        window.Activated += (sender, _) => Activated(sender as StateUIWindow);
        window.Deactivated += (sender, _) => Deactivated(sender as StateUIWindow);
        window.Stopped += (sender, _) => Stopped(sender as StateUIWindow, SwiftEvent.Stopped);
        window.Resumed += (sender, _) => Stopped(sender as StateUIWindow, SwiftEvent.Deactivated);
        window.Destroying += (sender, _) => Buried(sender as StateUIWindow);
    }

    /// <summary>
    /// Takes a window the platform has just made - a scene's main window, or a
    /// restored window some scene owned - and renders into it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The platform makes a window at launch, for <i>File ▸ New Window</i> and
    /// an iPad's window controls, for every scene the system restores, and -
    /// on a Mac that kept the process alive after its last window closed - when
    /// the dock icon is clicked. WinUI calls <c>CreateWindow</c> once, from
    /// <c>OnLaunched</c>; a second window there is one this side opens.
    /// </para>
    /// <para>
    /// A PAGE AT ONCE, whatever happens next: MAUI hands the window straight
    /// to the scene that asked for it and throws <i>"No page was set on the
    /// window"</i> if there is none - measured on Mac Catalyst, where
    /// <i>Cmd+N</i> took the whole application down.
    /// </para>
    /// </remarks>
    /// <param name="window">The window the app's <c>CreateWindow</c> built.</param>
    internal void Adopt(StateUIWindow window)
    {
        window.Page ??= new ContentPage();
        window.Origin = SceneSessions.Take();

        // One of a scene's OTHER windows, restored by the system: its scene is
        // asked whether it still takes it, once that scene is open.
        if (window.Origin is { Owner: string owner })
        {
            var restored = new Restored(window);
            _restored.Add(restored);

            if (SceneOwning(owner) is SceneSlot scene)
            {
                Later(() => Offer(scene, restored));
            }
            else
            {
                AbandonLater();
            }

            return;
        }

        bool showing = Windows.Any();

        _free.Enqueue(window);

        // The application before anything is handed to it: registering is
        // what gives Swift the scene waiting for the platform's first window,
        // and a registration that came AFTER this window's announcement would
        // start the scenes over without it.
        _session.Register();

        // Swift first, with what the platform kept for the session - its
        // answer is a scene still waiting for its window, and the render below
        // puts that scene in this one.
        List<SwiftWireValue> kept = [];

        foreach ((string name, SwiftWireValue value) in window.Origin?.Kept ?? [])
        {
            kept.Add(SwiftWireValue.Of(name));
            kept.Add(value);
        }

        if (_connect(SwiftWire.WritePayload([.. kept]) ?? []) < 0)
        {
            StateUISession.Report(
                "the Swift side could not read what the platform kept for a scene; " +
                "the scene opens with its states as declared.");
        }

        // The WHOLE tree when nothing of ours is on screen, whatever the last
        // message said; otherwise the change, which describes the new scene
        // entire because it is new.
        if (showing)
        {
            _session.Render();
        }
        else
        {
            _session.Resync();
        }
    }

    /// <summary>
    /// A window the platform has attached, which is when its session can be
    /// told what to keep.
    /// </summary>
    /// <remarks>
    /// A window this side opened learns which session it is here: the platform
    /// connected a scene for it a moment ago and handed back the very instance
    /// <c>OpenWindow</c> was given, without asking the app to build one.
    /// </remarks>
    /// <param name="window">A window of this application.</param>
    internal void Attached(StateUIWindow window)
    {
        window.Origin ??= SceneSessions.Take();

        SceneFocus.Watch();

        if (SlotOf(window) is not Slot slot)
        {
            return;
        }

        Remember(slot);

        // A main window's session is what the scene's other windows name as
        // their owner, so theirs are written again now that it has one.
        if (slot.Main)
        {
            foreach (Slot other in slot.Scene.Windows)
            {
                if (!other.Main)
                {
                    Remember(other);
                }
            }
        }
    }

    /// <summary>Takes a window out of the queue of unclaimed ones.</summary>
    /// <param name="window">The window to drop, wherever it stands.</param>
    private void Drop(StateUIWindow window)
    {
        StateUIWindow[] rest = [.. _free.Where(queued => !ReferenceEquals(queued, window))];

        if (rest.Length == _free.Count)
        {
            return;
        }

        _free.Clear();

        foreach (StateUIWindow queued in rest)
        {
            _free.Enqueue(queued);
        }
    }

    /// <summary>
    /// Notes that a window has gone, whoever took it away, and tells its scene
    /// where the reader was the one.
    /// </summary>
    /// <remarks>
    /// The slot stays and is emptied rather than removed: the node goes on
    /// being described until the scene has heard, and an empty slot is what
    /// stops the next render from opening it again. A window the TREE closed
    /// has no slot by the time it goes - the slot is taken out first - so it is
    /// reported to nobody.
    /// </remarks>
    /// <param name="window">The window that went.</param>
    private void Buried(StateUIWindow? window)
    {
        if (window is null)
        {
            return;
        }

        Drop(window);
        _restored.RemoveAll(restored => ReferenceEquals(restored.Window, window));

        if (ReferenceEquals(_active, window))
        {
            _active = null;
        }

        if (SlotOf(window) is not Slot slot)
        {
            return;
        }

        slot.Window = null;

        // A scene's main window going is the scene ending; any other going is
        // that window closing, told by the name the tree knows it by.
        if (slot.Main)
        {
            Report(slot.Scene, SwiftEvent.Destroying);
        }
        else
        {
            Report(slot.Scene, SwiftEvent.WindowClosed, SwiftWireValue.Of(slot.Name));
        }
    }

    // ---- Restored windows ----------------------------------------------------

    /// <summary>
    /// Asks a scene whether it takes a window the system restored as one of
    /// its own.
    /// </summary>
    /// <remarks>
    /// "No" is an answer too, and it is given by the render that follows: the
    /// scene describes the window, which claims it, or does not, and it is
    /// closed. See <see cref="Decide"/>.
    /// </remarks>
    /// <param name="scene">The scene it names as its owner.</param>
    /// <param name="restored">The window.</param>
    private void Offer(SceneSlot scene, Restored restored)
    {
        if (!_restored.Contains(restored) || restored.Asked is not null)
        {
            return;
        }

        if (!_scenes.Contains(scene)
            || scene.Events?.TryGetValue(SwiftEvent.WindowRestored, out int handler) != true
            || restored.Window.Origin is not { Kind: string kind } origin)
        {
            Close(restored);
            return;
        }

        restored.Asked = _applies;

        if (origin.Value is string value)
        {
            Renderer.Announce(handler, SwiftWireValue.Of(kind), SwiftWireValue.Of(value));
        }
        else
        {
            Renderer.Announce(handler, SwiftWireValue.Of(kind));
        }
    }

    /// <summary>
    /// Offers a scene the windows the system restored for it before it was
    /// open - once its main window has told this side which session it is.
    /// </summary>
    /// <param name="scene">The scene that has just been given its main window.</param>
    private void OfferWaiting(SceneSlot scene)
    {
        if (scene.Session is not string session)
        {
            return;
        }

        foreach (Restored restored in _restored)
        {
            if (restored.Asked is null && restored.Window.Origin?.Owner == session)
            {
                Restored offered = restored;

                // A turn later: this is called from inside a message, where a
                // report is not made.
                Later(() => Offer(scene, offered));
            }
        }
    }

    /// <summary>
    /// Closes every restored window whose scene was asked before this message
    /// and did not describe it - the scene's "no".
    /// </summary>
    /// <param name="applying">The number of the message just applied.</param>
    private void Decide(int applying)
    {
        foreach (Restored restored in _restored.ToList())
        {
            if (restored.Asked is int asked && asked < applying)
            {
                Close(restored);
            }
        }
    }

    /// <summary>
    /// Starts the timer that closes restored windows whose scene never comes
    /// back, unless it is running already.
    /// </summary>
    /// <remarks>
    /// The system restores a session's scenes together, a few milliseconds
    /// apart and in no promised order, so a window can arrive before the scene
    /// that owns it and wait for it here. A scene that has not come in three
    /// seconds is not coming - its session was discarded - and a window left
    /// waiting for it would stand blank for good.
    /// </remarks>
    private void AbandonLater()
    {
        if (_abandoning is not null || _dispatcher is null)
        {
            return;
        }

        _abandoning = _dispatcher.CreateTimer();
        _abandoning.Interval = TimeSpan.FromSeconds(3);
        _abandoning.IsRepeating = false;
        _abandoning.Tick += (_, _) =>
        {
            _abandoning = null;
            Abandon();
        };

        _abandoning.Start();
    }

    /// <summary>
    /// Closes the restored windows whose scene is not open and was never
    /// asked - what the timer does when it runs out.
    /// </summary>
    internal void Abandon()
    {
        foreach (Restored restored in _restored.ToList())
        {
            if (restored.Asked is null
                && (restored.Window.Origin?.Owner is not string owner || SceneOwning(owner) is null))
            {
                Close(restored);
            }
        }
    }

    /// <summary>Closes a restored window no scene took.</summary>
    /// <param name="restored">The window.</param>
    private void Close(Restored restored)
    {
        _restored.Remove(restored);
        Application.Current?.CloseWindow(restored.Window);
    }

    /// <summary>
    /// The restored window a scene's new window node stands for - the one
    /// owned by that scene's session, of the node's kind, for its value.
    /// </summary>
    /// <param name="scene">The scene describing the window.</param>
    /// <param name="slot">The window's new slot, its kind and value read.</param>
    /// <returns>The window, taken off the list; null where none matches.</returns>
    private StateUIWindow? TakeRestored(SceneSlot scene, Slot slot)
    {
        Restored? match = _restored.Find(restored =>
            restored.Window.Origin is { } origin
            && origin.Owner == scene.Session
            && origin.Kind == slot.Kind
            && origin.Value == slot.Value);

        if (match is null)
        {
            return null;
        }

        _restored.Remove(match);
        return match.Window;
    }

    /// <summary>The scene whose main window's session is the one named.</summary>
    /// <param name="session">The platform's identity for the session.</param>
    private SceneSlot? SceneOwning(string session) =>
        _scenes.Find(scene => scene.Session == session);

    // ---- What the platform keeps --------------------------------------------

    /// <summary>
    /// Writes down one of a scene's kept values - what the
    /// <see cref="SwiftAct.PersistSceneValue"/> act asks for.
    /// </summary>
    /// <remarks>
    /// Kept by the platform on the session of the scene's main window, which is
    /// what the system restores that scene by: the whole set is written each
    /// time, so what a restored session holds is what the scene held last.
    /// </remarks>
    /// <param name="command">
    /// The act: argument 0 the scene's number, 1 the key, 2 the value.
    /// </param>
    internal void Keep(SwiftCommand command)
    {
        if (command.GetName(0) is not string id
            || command.GetName(1) is not string name
            || command.Arguments.Count < 3
            || _scenes.Find(scene => scene.Id == id) is not SceneSlot scene)
        {
            return;
        }

        scene.Kept[name] = command.Arguments[2];

        if (scene.Main is Slot main)
        {
            Remember(main);
        }
    }

    /// <summary>
    /// What the platform is to keep for a window's session, as it stands.
    /// </summary>
    /// <remarks>
    /// A main window's session keeps its scene's values; any other window's
    /// keeps which scene it belongs to - by that scene's session - its kind and
    /// its value. What <see cref="SceneSessions.Remember"/> writes, and what a
    /// test reads where there is no platform to write it to.
    /// </remarks>
    /// <param name="window">A window of this application.</param>
    /// <returns>What to keep; null for a window no scene describes.</returns>
    internal SceneOrigin? Remembered(StateUIWindow window)
    {
        if (SlotOf(window) is not Slot slot)
        {
            return null;
        }

        return slot.Main
            ? new SceneOrigin(
                window.Origin?.Session,
                null,
                null,
                null,
                [.. slot.Scene.Kept.Select(pair => (pair.Key, pair.Value))])
            : new SceneOrigin(window.Origin?.Session, slot.Scene.Session, slot.Kind, slot.Value, []);
    }

    /// <summary>Writes down what the platform keeps for a window's session.</summary>
    /// <param name="slot">The window's slot.</param>
    private void Remember(Slot slot)
    {
        if (slot.Window is StateUIWindow window && Remembered(window) is SceneOrigin kept)
        {
            SceneSessions.Remember(window, kept);
        }
    }

    // ---- Where the reader is --------------------------------------------------

    /// <summary>
    /// The reader has come to a window: its scene is in front, the others are
    /// behind, and the windows that hide with their scene follow.
    /// </summary>
    /// <param name="window">The window they came to.</param>
    internal void CameToFront(StateUIWindow window)
    {
        // A window the reader is in is not hidden, whatever put it where it is.
        window.HiddenByScene = false;

        if (SlotOf(window) is not Slot came)
        {
            return;
        }

        _active = window;
        _front = came.Scene;

        foreach (SceneSlot scene in _scenes)
        {
            if (ReferenceEquals(scene, _front))
            {
                Phase(scene, SwiftEvent.Activated);
            }
            else if (scene.Phase == SwiftEvent.Activated)
            {
                Phase(scene, SwiftEvent.Deactivated);
            }
        }

        Arrange();
    }

    /// <summary>
    /// A window says it was activated - the reader coming to it, or a window
    /// its scene hid saying it is shown again.
    /// </summary>
    /// <param name="window">The window.</param>
    private void Activated(StateUIWindow? window)
    {
        if (window is null)
        {
            return;
        }

        // The report a window makes when its scene shows it again - about
        // the showing, and not about the reader, who is in another window of
        // the same scene.
        if (window.HiddenByScene)
        {
            window.HiddenByScene = false;
            return;
        }

        CameToFront(window);
    }

    /// <summary>
    /// A window says it was deactivated: where it was the scene in front, the
    /// reader has left that scene - for another of ours, which says so next,
    /// or for another application.
    /// </summary>
    /// <param name="window">The window.</param>
    private void Deactivated(StateUIWindow? window)
    {
        if (window is null || window.HiddenByScene || SlotOf(window) is not Slot slot)
        {
            return;
        }

        if (ReferenceEquals(slot.Scene, _front))
        {
            Phase(slot.Scene, SwiftEvent.Deactivated);
        }
    }

    /// <summary>
    /// A scene's main window has gone to the background, or come back from it -
    /// which is where the scene is. Its other windows say nothing about it.
    /// </summary>
    /// <param name="window">The window.</param>
    /// <param name="phase">Where that leaves the scene.</param>
    private void Stopped(StateUIWindow? window, SwiftEvent phase)
    {
        if (window is null || window.HiddenByScene || SlotOf(window) is not { Main: true } slot)
        {
            return;
        }

        Phase(slot.Scene, phase);
    }

    /// <summary>
    /// Notes where a scene now stands and tells it a turn later - so a reader
    /// moving between two windows of one scene, which deactivates one and
    /// activates the other, tells the scene nothing at all.
    /// </summary>
    /// <param name="scene">The scene.</param>
    /// <param name="phase">Activated, deactivated or stopped.</param>
    private void Phase(SceneSlot scene, SwiftEvent phase)
    {
        scene.Phase = phase;

        Later(() =>
        {
            if (scene.Phase is not SwiftEvent now || now == scene.Reported || !_scenes.Contains(scene))
            {
                return;
            }

            scene.Reported = now;
            Report(scene, now);
        });
    }

    /// <summary>
    /// Hides the windows that hide while their scene is behind and shows them
    /// while it is in front, keeps up the ones that float on top, and keeps
    /// every window beside a main one off the platform's list of the
    /// application's windows - see <see cref="Listed"/>.
    /// </summary>
    private void Arrange()
    {
        foreach (SceneSlot scene in _scenes)
        {
            bool behind = _front is not null && !ReferenceEquals(scene, _front);

            foreach (Slot slot in scene.Windows)
            {
                if (!slot.Main && slot.Window is StateUIWindow window)
                {
                    SceneFocus.List(window, Listed(window));
                    SceneFocus.Float(window, slot.FloatsOnTop);
                    SceneFocus.Show(window, !(behind && slot.AutoHide));
                }
            }
        }
    }

    // ---- What the tree describes --------------------------------------------

    bool IStateUITarget.Apply(SwiftNode application, bool complete)
    {
        // WHAT THIS MESSAGE CARRIES, on the motion trace's own clock - so a
        // render can be read beside the frames around it, and a page that
        // costs two messages where one was expected says what the second one
        // was about. `STATEUI_FRAMES=1`; see MotionTrace.
        if (MotionTrace.Watching)
        {
            MotionTrace.Say($"apply{(complete ? " (complete)" : "")}: {Sketch(application)}");
        }

        try
        {
            return RenderTally.Measure(() => ApplyScenes(application, complete));
        }
        catch (SwiftTreeDriftException drift)
        {
            // A patch about a tree this side is not holding. REFUSED, not
            // failed: the session answers a refusal by dropping the generation
            // and asking Swift for everything, which is the recovery this
            // condition wants. Said out loud too, because drift
            // that keeps happening is a bug in the differ rather than a hiccup.
            StateUISession.Report($"The interface drifted and is being asked for again: {drift.Message}");
            return false;
        }
    }

    /// <summary>
    /// A message in one line: every element it says anything about, by type,
    /// with the property, event and state keys it carries.
    /// </summary>
    /// <remarks>
    /// The elements that carry only the path down to a changed one are left
    /// out, which is what makes the line short enough to read: a render of one
    /// label in a deep page is <c>Label{text}</c> and nothing else.
    /// </remarks>
    /// <param name="node">The message's root.</param>
    /// <returns>What it carries, capped so a resync cannot fill the file.</returns>
    private static string Sketch(SwiftNode node)
    {
        List<string> said = [];

        void Walk(SwiftNode n)
        {
            if (said.Count >= 24)
            {
                return;
            }

            List<string> parts = [];

            if (n.Props is { Count: > 0 } props) { parts.AddRange(props.Keys.Select(k => k.ToString())); }
            if (n.Cleared is { Count: > 0 } cleared) { parts.AddRange(cleared.Select(k => "-" + k.Prop)); }
            if (n.States is { Count: > 0 } states) { parts.AddRange(states.Select(e => "$" + e.Key.Prop)); }
            if (n.Replace) { parts.Add("replace"); }

            if (parts.Count > 0)
            {
                said.Add($"{n.Type}{{{string.Join(",", parts)}}}");
            }

            if (n.Children is { Count: > 0 } children)
            {
                foreach (SwiftNode child in children)
                {
                    Walk(child);
                }
            }
        }

        Walk(node);

        return said.Count == 0 ? "(nothing)" : string.Join(" ", said);
    }

    /// <summary>The scenes the message describes, applied one at a time.</summary>
    /// <param name="application">The application node - the root of a message.</param>
    /// <param name="complete">Whether it describes the whole tree.</param>
    private bool ApplyScenes(SwiftNode application, bool complete)
    {
        int applying = ++_applies;

        // Nothing below the application changed - unless the list ARRIVED
        // arranged and empty, which is every scene ending at once.
        if (application.Children is not { Count: > 0 } described)
        {
            if (application.Arranged)
            {
                SettleScenes([]);
            }

            Decide(applying);
            return true;
        }

        if (application.Arranged)
        {
            SettleScenes(described);
        }

        foreach (SwiftNode child in described)
        {
            if (child.Type != SwiftNodeType.Scene)
            {
                ((IStateUITarget)this).Fail(
                    $"Swift described a '{child.TypeName}' where a Scene was expected.\n\n" +
                    "An application's children are its scenes; a window goes inside one.",
                    null);

                return true;
            }

            SceneSlot scene = ClaimScene(child);
            long began = RenderTally.Inspecting ? System.Diagnostics.Stopwatch.GetTimestamp() : 0;

            if (!ApplyScene(scene, child, complete))
            {
                return false;
            }

            // How long this scene's part took, for an inspector - by its place
            // in the list, which a patch naming only some scenes cannot say.
            if (RenderTally.Inspecting)
            {
                RenderTally.Scene(_scenes.IndexOf(scene), began);
            }
        }

        if (_rearrange)
        {
            _rearrange = false;
            Arrange();
        }

        Decide(applying);
        return true;
    }

    /// <summary>
    /// Applies one scene: its handlers, the windows it no longer describes,
    /// and each window it does.
    /// </summary>
    /// <param name="scene">The scene's slot.</param>
    /// <param name="node">The scene's node.</param>
    /// <param name="complete">Whether the message describes the whole tree.</param>
    /// <returns>False to ask for the whole tree instead.</returns>
    private bool ApplyScene(SceneSlot scene, SwiftNode node, bool complete)
    {
        // The scene's handler ids, replaced WHOLE whenever a message names
        // them: Swift keeps an id for as long as the element handles that
        // event, so a message that says nothing about events has not changed
        // them. The same rule StateUIRenderer.Track follows for a control.
        if (node.Events is { } events)
        {
            scene.Events = events;
        }

        if (node.Arranged)
        {
            SettleWindows(scene, node.Children ?? []);
        }

        // No child means nothing below the scene changed.
        if (node.Children is not { Count: > 0 } described)
        {
            return true;
        }

        foreach (SwiftNode child in described)
        {
            if (child.Type != SwiftNodeType.Window)
            {
                ((IStateUITarget)this).Fail(
                    $"Swift described a '{child.TypeName}' where a Window was expected.\n\n" +
                    "A scene's children are its windows; a page goes inside one.",
                    null);

                return true;
            }

            Slot slot = ClaimWindow(scene, child);

            // A window the reader closed. Nothing is opened in its place: see
            // the note on Buried.
            if (slot.Window is not StateUIWindow window)
            {
                continue;
            }

            if (!window.Apply(child, complete))
            {
                return false;
            }

            // Now that it has the page the tree describes - see the note on
            // this class. A window whose message could not be applied is never
            // shown at all: the resync that follows describes it entire, and
            // this is reached with the real page in place.
            Show(slot);
        }

        return true;
    }

    /// <summary>
    /// Closes the scenes the tree no longer describes - every window of each -
    /// and keeps the rest in the order they opened.
    /// </summary>
    /// <param name="described">The scenes the message lists.</param>
    private void SettleScenes(List<SwiftNode> described)
    {
        for (int index = _scenes.Count - 1; index >= 0; index--)
        {
            SceneSlot scene = _scenes[index];

            if (described.Any(node => node.Key == scene.Key))
            {
                continue;
            }

            // Out of the list FIRST, so the windows going below report nothing:
            // the scene has ended, and there is nobody to tell.
            _scenes.RemoveAt(index);

            if (ReferenceEquals(_front, scene))
            {
                _front = null;
            }

            foreach (Slot slot in scene.Windows)
            {
                Close(slot);
            }
        }
    }

    /// <summary>Closes the windows a scene no longer describes.</summary>
    /// <param name="scene">The scene.</param>
    /// <param name="described">The windows its message lists.</param>
    private static void SettleWindows(SceneSlot scene, List<SwiftNode> described)
    {
        for (int index = scene.Windows.Count - 1; index >= 0; index--)
        {
            Slot slot = scene.Windows[index];

            if (described.Any(node => node.Key == slot.Key))
            {
                continue;
            }

            scene.Windows.RemoveAt(index);
            Close(slot);
        }
    }

    /// <summary>
    /// Closes a slot's window, where the platform was asked to show it: a
    /// window built for a node whose message never applied has never been
    /// opened, and closing what was never opened is not a thing to ask of
    /// MAUI.
    /// </summary>
    /// <remarks>
    /// WHAT THE TREE CLOSED HAS NOBODY LEFT TO TELL, so its elements go before
    /// the window does. The window left the tree in the render that produced
    /// this message and everything under it went too - its six lifecycle
    /// handlers, its page's, its views' - while a platform closing a window
    /// raises Deactivated, Stopped and Destroying on it and Disappearing on
    /// the page. Quoted off the elements the controls still carried, those
    /// reports reached handler ids the Swift side had already dropped, which
    /// is a complaint per id and nothing else. Measured on Linux, closing the
    /// inspector's window: two of <c>a control reported to handler N, which
    /// the Swift side does not know</c> every time. The scene hears the close
    /// either way - <see cref="Buried"/> is subscribed to the window itself
    /// and needs no id - and a window the READER closes still reports its own,
    /// the tree describing it until the scene has heard.
    /// </remarks>
    /// <param name="slot">A slot already out of its list.</param>
    private static void Close(Slot slot)
    {
        if (slot.Opened && slot.Window is StateUIWindow window)
        {
            Forget(window.Application.Renderer, window);

            // The platform's own close, so it animates and reports the way any
            // other does - and Buried hears it.
            Application.Current?.CloseWindow(window);
        }
    }

    /// <summary>
    /// Drops what a window and everything under it stood for - see
    /// <see cref="Close"/>.
    /// </summary>
    /// <param name="renderer">The renderer holding them.</param>
    /// <param name="element">The window, and then whatever it holds.</param>
    private static void Forget(StateUIRenderer renderer, IVisualTreeElement element)
    {
        if (element is BindableObject control)
        {
            renderer.Forget(control);
        }

        foreach (IVisualTreeElement child in element.GetVisualChildren())
        {
            Forget(renderer, child);
        }
    }

    /// <summary>The slot a described scene belongs to, made if the scene is new.</summary>
    /// <param name="node">The scene's node.</param>
    private SceneSlot ClaimScene(SwiftNode node)
    {
        foreach (SceneSlot known in _scenes)
        {
            if (known.Key == node.Key)
            {
                return known;
            }
        }

        var scene = new SceneSlot(node.Key, node.Name ?? node.Key);
        _scenes.Add(scene);
        return scene;
    }

    /// <summary>
    /// The slot a described window belongs to - with the window it is shown
    /// in: one the platform handed over, one the system restored for it, or
    /// one built here, unopened.
    /// </summary>
    /// <remarks>
    /// The slot is in the list before the method returns, whatever else
    /// happens afterwards. That is what makes a window that cannot be shown a
    /// failure rather than a cascade: the next render finds the slot and
    /// applies into the window it holds, instead of deciding this node has no
    /// window and asking for another one.
    /// </remarks>
    /// <param name="scene">The scene describing it.</param>
    /// <param name="node">The window's node.</param>
    private Slot ClaimWindow(SceneSlot scene, SwiftNode node)
    {
        foreach (Slot known in scene.Windows)
        {
            if (known.Key == node.Key)
            {
                if (!known.Main && Describe(known, node))
                {
                    Remember(known);
                }

                return known;
            }
        }

        // A scene's main window is the one that names no group: every other
        // window is described with its kind from the first message on.
        var slot = new Slot(
            scene, node.Key, node.Name ?? node.Key, main: node.GetName(SwiftProp.WindowType) is null);

        if (!slot.Main)
        {
            Describe(slot, node);
        }

        if (slot.Main && _free.Count > 0)
        {
            // The window the platform handed over is already on screen, so it
            // counts as opened and there is nothing left to show: this IS the
            // window the reader has, and it now has a scene. The OLDEST
            // waiting one, in the order the platform handed them over.
            StateUIWindow waiting = _free.Dequeue();

            slot.Window = waiting;
            slot.Opened = true;
            scene.Windows.Insert(0, slot);

            foreach ((string name, SwiftWireValue value) in waiting.Origin?.Kept ?? [])
            {
                scene.Kept[name] = value;
            }

            OfferWaiting(scene);
            return slot;
        }

        if (!slot.Main && TakeRestored(scene, slot) is StateUIWindow restored)
        {
            // The window the system put back on screen for this very node.
            slot.Window = restored;
            slot.Opened = true;
            scene.Windows.Add(slot);

            Remember(slot);
            return slot;
        }

        slot.Window = new StateUIWindow(this);

        if (slot.Main)
        {
            scene.Windows.Insert(0, slot);
        }
        else
        {
            scene.Windows.Add(slot);
        }

        return slot;
    }

    /// <summary>
    /// Reads what one of a scene's other windows is - its kind, its value,
    /// whether it hides with its scene and whether it floats on top - off a
    /// node that says so.
    /// </summary>
    /// <remarks>
    /// A patch carries what changed, so what it leaves out stands. None of the
    /// four is ever taken off a window it was on: a window's kind and value are
    /// what its key was made from, and whether it hides or floats is said
    /// either way.
    /// </remarks>
    /// <param name="slot">The window's slot.</param>
    /// <param name="node">Its node.</param>
    /// <returns>Whether anything the platform keeps for it changed.</returns>
    private bool Describe(Slot slot, SwiftNode node)
    {
        string? kind = node.GetName(SwiftProp.WindowType) ?? slot.Kind;
        string? value = node.GetString(SwiftProp.WindowValue) ?? slot.Value;
        bool hides = node.GetBool(SwiftProp.AutoHide) ?? slot.AutoHide;
        bool floats = node.GetBool(SwiftProp.FloatsOnTop) ?? slot.FloatsOnTop;

        if (hides != slot.AutoHide || floats != slot.FloatsOnTop)
        {
            slot.AutoHide = hides;
            slot.FloatsOnTop = floats;
            _rearrange = true;
        }

        bool changed = kind != slot.Kind || value != slot.Value;

        slot.Kind = kind;
        slot.Value = value;

        return changed;
    }

    /// <summary>
    /// Asks the platform to show a window that has its page, once.
    /// </summary>
    /// <remarks>
    /// MAUI remembers the instance under a generated id and gives it back when
    /// the platform's new scene asks for a window, so this is the window that
    /// appears rather than one built by the app's <c>CreateWindow</c>. Where a
    /// platform cannot open a second window - a phone - the request is refused
    /// and the window built here is never shown.
    /// <para>
    /// The slot is marked BEFORE the ask, not after: a platform that throws
    /// here throws for a reason that will not have changed by the next render,
    /// and asking again would open a window per render for as long as the tree
    /// describes the node.
    /// </para>
    /// </remarks>
    /// <param name="slot">The window's slot.</param>
    private static void Show(Slot slot)
    {
        if (slot.Opened || slot.Window is not StateUIWindow window)
        {
            return;
        }

        slot.Opened = true;

        Application.Current?.OpenWindow(window);
    }

    void IStateUITarget.Fail(string message, Exception? exception)
    {
        // Whatever is on screen, and the window waiting for its first tree if
        // nothing is: a failure with nowhere to be shown is a blank window.
        StateUIWindow? window = Windows.FirstOrDefault() ?? _free.FirstOrDefault();
        window?.ShowError(message, exception);
    }

    // ---- Small things -------------------------------------------------------

    /// <summary>
    /// Whether the platform's list of the application's windows - the Window
    /// menu, the Dock's - names a window: its scene's main window, and never
    /// one beside it. What the list offers is the application's scenes, and a
    /// window of one chosen there would come forward while its scene stays
    /// where it is.
    /// </summary>
    /// <param name="window">A window of the application.</param>
    internal bool Listed(StateUIWindow window) => SlotOf(window) is { Main: true };

    /// <summary>Whether a window floats above the application's others, its group saying so.</summary>
    /// <param name="window">A window of the application.</param>
    internal bool FloatsOnTop(StateUIWindow window) => SlotOf(window) is { FloatsOnTop: true };

    /// <summary>The slot a window is shown in, in whichever scene.</summary>
    /// <param name="window">The window.</param>
    private Slot? SlotOf(StateUIWindow window)
    {
        foreach (SceneSlot scene in _scenes)
        {
            foreach (Slot slot in scene.Windows)
            {
                if (ReferenceEquals(slot.Window, window))
                {
                    return slot;
                }
            }
        }

        return null;
    }

    /// <summary>
    /// Tells a scene something through the handler its node carries for it -
    /// a scene that does not handle it hears nothing.
    /// </summary>
    /// <param name="scene">The scene.</param>
    /// <param name="raised">What happened.</param>
    /// <param name="payload">What the handler reads, in order.</param>
    private void Report(SceneSlot scene, SwiftEvent raised, params SwiftWireValue[] payload)
    {
        if (scene.Events?.TryGetValue(raised, out int handler) == true)
        {
            Renderer.Announce(handler, payload);
        }
    }

    /// <summary>
    /// Runs work a turn later - at once where there is no dispatcher to put it
    /// off with.
    /// </summary>
    /// <param name="work">What to run.</param>
    private void Later(Action work)
    {
        if (_dispatcher is IDispatcher dispatcher)
        {
            dispatcher.Dispatch(work);
        }
        else
        {
            work();
        }
    }

    /// <summary>One scene the tree describes, and the windows showing it.</summary>
    /// <param name="key">The identity of the node the scene came from.</param>
    /// <param name="id">The scene's number - what its kept values are sent under.</param>
    private sealed class SceneSlot(string key, string id)
    {
        /// <summary>The identity of the node the scene came from.</summary>
        internal string Key { get; } = key;

        /// <summary>The scene's number - what its kept values are sent under.</summary>
        internal string Id { get; } = id;

        /// <summary>Its windows: the main one first, then the others in the order they opened.</summary>
        internal List<Slot> Windows { get; } = [];

        /// <summary>The scene's handler ids, as its node last named them.</summary>
        internal Dictionary<SwiftEvent, int>? Events { get; set; }

        /// <summary>
        /// Its <c>@State(sceneKey:)</c> values by name, as the platform is to
        /// keep them - in name order, so what is written is the same each time.
        /// </summary>
        internal SortedDictionary<string, SwiftWireValue> Kept { get; } = new(StringComparer.Ordinal);

        /// <summary>Where it stands, as its windows last said: activated, deactivated or stopped.</summary>
        internal SwiftEvent? Phase { get; set; }

        /// <summary>Where it was last told it stands.</summary>
        internal SwiftEvent? Reported { get; set; }

        /// <summary>Its main window's slot.</summary>
        internal Slot? Main => Windows.Find(slot => slot.Main);

        /// <summary>
        /// The platform's identity for its main window's session - what the
        /// scene's other windows name as their owner.
        /// </summary>
        internal string? Session => Main?.Window?.Origin?.Session;
    }

    /// <summary>One window the tree describes, and the window showing it.</summary>
    /// <param name="scene">The scene it belongs to.</param>
    /// <param name="key">The identity of the node it came from.</param>
    /// <param name="name">The name the tree knows it by - what its scene is told when it closes.</param>
    /// <param name="main">Whether it is its scene's main window.</param>
    private sealed class Slot(SceneSlot scene, string key, string name, bool main)
    {
        /// <summary>The scene it belongs to.</summary>
        internal SceneSlot Scene { get; } = scene;

        /// <summary>The identity of the node it came from.</summary>
        internal string Key { get; } = key;

        /// <summary>The name the tree knows it by.</summary>
        internal string Name { get; } = name;

        /// <summary>Whether it is its scene's main window.</summary>
        internal bool Main { get; } = main;

        /// <summary>The window, or null once the platform has destroyed it.</summary>
        internal StateUIWindow? Window { get; set; }

        /// <summary>
        /// Whether the platform has been asked to show this window - true from
        /// the start for one the platform itself handed over.
        /// </summary>
        internal bool Opened { get; set; }

        /// <summary>Its group's kind; nothing for a main window.</summary>
        internal string? Kind { get; set; }

        /// <summary>The value it stands for, as the tree wrote it; nothing for a group of one.</summary>
        internal string? Value { get; set; }

        /// <summary>Whether it hides while another scene is in front.</summary>
        internal bool AutoHide { get; set; }

        /// <summary>Whether it floats above the application's other windows.</summary>
        internal bool FloatsOnTop { get; set; }
    }

    /// <summary>
    /// A window the system restored as one of a scene's other windows, until
    /// that scene says whether it takes it.
    /// </summary>
    /// <param name="window">The window.</param>
    private sealed class Restored(StateUIWindow window)
    {
        /// <summary>The window, carrying what its session kept in its origin.</summary>
        internal StateUIWindow Window { get; } = window;

        /// <summary>
        /// The number of the last message applied before its scene was asked -
        /// null while its scene is not open.
        /// </summary>
        internal int? Asked { get; set; }
    }
}
