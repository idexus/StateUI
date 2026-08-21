using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// The Swift application: one render session, and the windows it describes.
/// </summary>
/// <remarks>
/// <para>
/// Not a MAUI <see cref="Application"/> - the app's own <c>App</c> class is
/// that, and it still opens a <see cref="StateUIWindow"/> from its
/// <c>CreateWindow</c>. This is what sits behind those windows: the root of
/// every message is an <c>Application</c> node whose children are windows, and
/// keeping the platform's windows in step with that list is the whole of what
/// this class does.
/// </para>
/// <para>
/// <b>One session, N windows.</b> A window is a target for its own node and
/// nothing more - it holds no session, no generation counter and no baseline.
/// That is what lets a second window cost a node in the tree instead of a
/// second render loop, and it is why the session's target is this rather than
/// any one window. It is also the only shape that works: a process holds ONE
/// live session, and windows are how one of those shows several things at
/// once. See <see cref="StateUISession"/>.
/// </para>
/// <para>
/// <b>What opens a window.</b> A node in the list that has no window yet, and
/// nothing else. <see cref="Microsoft.Maui.Controls.Application.OpenWindow"/>
/// remembers the instance it is given under a generated id and hands that very
/// instance back when the platform's new scene asks for a window, so the window
/// built here is the window that appears. What CLOSES one is the node leaving
/// an arranged list.
/// </para>
/// <para>
/// <b>A window is BUILT, then described, and only then opened.</b> The slot is
/// recorded first, the node is applied into the window it names, and the
/// platform is asked to show it last - so what reaches the platform is a window
/// with the page the tree described. WinUI reads a window's content INSIDE
/// <c>OpenWindow</c> (<c>NavigationRootManager.Connect</c> asks for it before
/// the call returns) and throws <i>"No page was set on the window"</i> when
/// there is none, where Apple connects its scene later and never asks. Two
/// things follow, and both are the point: the platform never sees a blank
/// window, and the slot exists before anything can throw - so a window that
/// fails to open fails ONCE, instead of being opened again by every render that
/// finds no slot for its node.
/// </para>
/// <para>
/// <b>What the platform closes stays closed.</b> A window the reader dismissed
/// is reported through <c>Window.Destroying</c> - the same event an author
/// hears - and its slot is kept, emptied, so that a node still describing it
/// does not open it again a moment later. The application says a window has
/// gone by no longer describing it; until it does, there is nothing to open.
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
    /// One per window the tree describes, in the order the tree names them.
    /// </summary>
    private readonly List<Slot> _slots = [];

    /// <summary>
    /// The windows the platform has handed over that no node has claimed yet,
    /// oldest first.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The application's first window arrives this way: MAUI asks the app for
    /// one, the app builds a <see cref="StateUIWindow"/>, and only then is
    /// there anything to render into. It is claimed by the first described
    /// window that has no window of its own.
    /// </para>
    /// <para>
    /// A QUEUE rather than one window, because the platform can hand over
    /// several before the tree has answered for any of them - a Mac restoring
    /// the scene sessions of a session that ended with four windows open
    /// connects them about 13 ms apart, and the tree's answer to the first is a
    /// render, which is slower than that. Holding one would leak every window
    /// but the last: the leaked ones are neither described nor closed, and the
    /// nodes that were meant for them find nothing free and OPEN A WINDOW EACH -
    /// which the platform remembers, so the next launch restores more of them
    /// than this one did. Measured on Mac Catalyst: a bundle grew
    /// from two windows to 138 that way, and went on growing by roughly half
    /// again per launch.
    /// </para>
    /// </remarks>
    private readonly Queue<StateUIWindow> _free = new();

    /// <summary>
    /// MAUI's dispatcher, kept from the first window, so that a suspended Swift
    /// handler can be put back on the UI thread even while no window is open.
    /// </summary>
    private IDispatcher? _dispatcher;

    /// <summary>The window that was activated last.</summary>
    private StateUIWindow? _active;

    /// <summary>
    /// The handler id for <c>creatingWindow</c>, or null while the application
    /// declares no answer.
    /// </summary>
    /// <remarks>
    /// Kept here rather than looked up at fire time the way a control's is,
    /// because the application is no <see cref="BindableObject"/> and has
    /// nowhere to carry a <c>RenderedElement</c>. Replaced whole whenever a
    /// message names the application's events, which is the same rule
    /// <see cref="StateUIRenderer.Track"/> follows.
    /// </remarks>
    private int? _creatingWindow;

    /// <summary>
    /// How many of <see cref="_free"/> are windows the PLATFORM opened while
    /// others were already showing - ones the tree has been asked about and has
    /// not answered for yet.
    /// </summary>
    /// <remarks>
    /// A count rather than a flag: one question is asked per window handed over,
    /// and each is answered by its own render. The window that starts the
    /// application is not one of them - nobody was asked about it.
    /// </remarks>
    private int _asked;

    /// <summary>
    /// Whether the message being applied has taken a window off
    /// <see cref="_free"/>.
    /// </summary>
    /// <remarks>
    /// What tells an answer from a decline while several questions are in
    /// flight. See <see cref="Unclaimed"/>.
    /// </remarks>
    private bool _claimed;

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
    /// in, which is the one the platform activated last.
    /// </summary>
    /// <remarks>
    /// MAUI does not say which window has the keyboard. Activation does, and it
    /// is reported per window - so an alert raised from the second window opens
    /// over the second window. Null until a platform has activated anything,
    /// which is every test.
    /// </remarks>
    internal StateUIWindow? Active => _active ?? Windows.FirstOrDefault();

    /// <summary>The windows that are open, in the order the tree names them.</summary>
    internal IEnumerable<StateUIWindow> Windows =>
        _slots.Select(slot => slot.Window).OfType<StateUIWindow>();

    /// <summary>Makes an application with a session and no windows yet.</summary>
    internal StateUIApplication()
    {
        _session = new StateUISession(this);
    }

    IDispatcher? IStateUITarget.Dispatcher => _dispatcher;

    // ---- The windows the platform gives us ---------------------------------

    /// <summary>
    /// Subscribes to a window's lifecycle - the tree's handlers and this
    /// class's own bookkeeping.
    /// </summary>
    internal void Watch(StateUIWindow window)
    {
        _dispatcher ??= window.Dispatcher;

        // The window's own lifecycle - created, activated, stopped, resumed -
        // subscribed once, before the platform can raise any of it. Which
        // handlers hear it is the tree's business: the window tracks its node,
        // and Raise quotes whatever ids that node carries.
        Renderer.WireWindow(window);

        window.Activated += (sender, _) => _active = sender as StateUIWindow;
        window.Destroying += (sender, _) => Buried(sender as StateUIWindow);
    }

    /// <summary>
    /// Takes a window the platform has just made and renders into it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The launch path, and the relaunch path with it: a Mac keeps the process
    /// alive after its last window closes and asks the app for a new one when
    /// the dock icon is clicked. Both arrive here, and both mean the same
    /// thing - nothing of ours is on screen - so the slots are dropped and the
    /// whole tree is described again into windows that are all new.
    /// </para>
    /// <para>
    /// A window arriving while another is still open is the READER asking for
    /// one - <i>File ▸ New Window</i> on a Mac, the window controls on an iPad.
    /// WinUI never gets here: it calls <c>CreateWindow</c> once, from
    /// <c>OnLaunched</c>, and a launch reaching a live process returns without
    /// making anything, so a second window there is a second PROCESS.
    /// Nothing describes it yet, so it is PARKED and the
    /// tree is told through <c>creatingWindow</c>; the render that answers finds
    /// a described window with no window of its own and is handed this one. An
    /// application that does not answer gets it closed again - see
    /// <see cref="Unclaimed"/>.
    /// </para>
    /// </remarks>
    internal void Adopt(StateUIWindow window)
    {
        if (Windows.Any())
        {
            // A PAGE AT ONCE, whatever happens next. MAUI hands the window
            // straight to the scene that asked for it and throws
            // "No page was set on the window" if there is none - measured on Mac
            // Catalyst, where Cmd+N took the whole application down. The tree's
            // answer cannot be synchronous - a Swift handler runs on the Swift
            // executor - so the window waits behind an empty page of the same
            // colour as everything else, for the one render it takes.
            window.Page ??= new ContentPage();

            // Nobody to ask: an application shows the windows it lists, and it
            // lists none for this one. Closing beats a window left blank, and
            // beats an error page - the reader did nothing wrong by using
            // their platform's own gesture.
            if (_creatingWindow is not int handler)
            {
                Application.Current?.CloseWindow(window);
                return;
            }

            _free.Enqueue(window);
            _asked++;

            // Through the dispatcher, like every other report: this is called
            // from the platform's scene machinery, and a handler that appends to
            // state must not run inside whatever else is in flight.
            _dispatcher?.Dispatch(() => Renderer.Announce(handler));
            return;
        }

        // The SLOTS go, and nothing else: this branch is only reached when none
        // of them holds a window, so there is nothing in them to lose. The
        // QUEUE stays, because a window waiting for an answer is on screen
        // ALREADY, blank, and the platform knows about it - forget it and it is
        // a window nothing describes and nothing closes, whose answer then
        // finds nothing free and opens one more. That is the growth the queue
        // exists to stop, reached from the other side.
        _slots.Clear();
        _free.Enqueue(window);

        // The WHOLE tree: what this side is showing is nothing, whatever the
        // last message said.
        _session.Resync();

        // NOTHING was claimed, which is the application describing no window at
        // all - a different thing from this particular window not being the one
        // the first node took. The others stay queued: they were asked about,
        // and an arranged message that declines them closes them one at a time.
        if (!Windows.Any())
        {
            Drop(window);
            window.ShowError("This application describes no window to show.", null);
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

        if (_asked > _free.Count)
        {
            _asked = _free.Count;
        }
    }

    /// <summary>
    /// Notes that a window has gone, whoever took it away.
    /// </summary>
    /// <remarks>
    /// The slot stays and is emptied rather than removed: the node may still be
    /// described - an application that does not fold a closed window back into
    /// its own state goes on describing it - and an empty slot is what stops
    /// the next render from opening it again.
    /// </remarks>
    private void Buried(StateUIWindow? window)
    {
        if (window is null)
        {
            return;
        }

        Drop(window);

        if (ReferenceEquals(_active, window))
        {
            _active = null;
        }

        foreach (Slot slot in _slots)
        {
            if (ReferenceEquals(slot.Window, window))
            {
                slot.Window = null;
            }
        }
    }

    // ---- The windows the tree describes -------------------------------------

    bool IStateUITarget.Apply(SwiftNode application, bool complete)
    {
        // Whether THIS message answers for a window the platform handed over.
        // See Unclaimed, which is the one thing that reads it.
        _claimed = false;

        // The application's own handler ids, replaced WHOLE whenever a message
        // names them: Swift keeps an id for as long as the element handles that
        // event, so a message that says nothing about events has not changed
        // them. The same rule StateUIRenderer.Track follows for a control.
        if (application.Events is { } events)
        {
            _creatingWindow = events.TryGetValue(SwiftEvent.CreatingWindow, out int id) ? id : null;
        }

        // Nothing below the application changed - unless the list ARRIVED
        // arranged and empty, which is every window closing at once.
        if (application.Children is not { Count: > 0 } described)
        {
            if (application.Arranged)
            {
                Settle([]);
                Unclaimed();
            }

            return true;
        }

        if (application.Arranged)
        {
            Settle(described);
        }

        foreach (SwiftNode child in described)
        {
            if (child.Type != SwiftNodeType.Window)
            {
                ((IStateUITarget)this).Fail(
                    $"Swift described a '{child.TypeName}' where a Window was expected.\n\n" +
                    "An application's `windows` are Windows; a page goes inside one.",
                    null);

                return true;
            }

            Slot slot = Claim(child);

            // A window the platform took away. Nothing is opened in its place:
            // see the note on Buried.
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

        if (application.Arranged)
        {
            Unclaimed();
        }

        return true;
    }

    /// <summary>
    /// Closes the window the platform opened if the tree, having been asked
    /// about it, went on describing the same windows as before.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Only after an ARRANGED list, because that is the message in which the
    /// application says what its windows ARE. One that changes a label inside a
    /// window says nothing about the list, and closing on it would race the
    /// handler that is about to append.
    /// </para>
    /// <para>
    /// The handler may of course decline - an application with one document
    /// open per file has every reason to. Declining is describing nothing new,
    /// and the window goes away; there is no second way to say no.
    /// </para>
    /// <para>
    /// ONE window per message, and none at all from a message that claimed one.
    /// Several questions can be in flight together - a Mac restores a whole
    /// session's worth of windows in a few dozen milliseconds - and each is
    /// answered by its own render. A message that took a window off the queue
    /// is an answer, and the windows still waiting behind it are for the
    /// renders still to come; closing them here would take away the very window
    /// the next answer is about.
    /// </para>
    /// </remarks>
    private void Unclaimed()
    {
        if (_claimed || _asked == 0 || _free.Count == 0)
        {
            return;
        }

        StateUIWindow window = _free.Dequeue();
        _asked--;

        Application.Current?.CloseWindow(window);
    }

    /// <summary>
    /// Closes the windows the tree no longer describes, and puts the slots in
    /// the order it does.
    /// </summary>
    private void Settle(List<SwiftNode> described)
    {
        for (int index = _slots.Count - 1; index >= 0; index--)
        {
            Slot slot = _slots[index];

            if (described.Any(node => node.Key == slot.Key))
            {
                continue;
            }

            _slots.RemoveAt(index);

            // Only one the platform was asked to show: a window built for a
            // node whose message never applied has never been opened, and
            // closing what was never opened is not a thing to ask of MAUI.
            if (slot.Opened && slot.Window is StateUIWindow window)
            {
                // The platform's own close, so it animates and reports the way
                // any other does - Destroying reaches the tree's handler, and
                // Buried hears it too.
                Application.Current?.CloseWindow(window);
            }
        }
    }

    /// <summary>
    /// The slot a described window belongs to - building one, unopened, if this
    /// window is new.
    /// </summary>
    /// <remarks>
    /// The slot is in the list before the method returns, whatever else
    /// happens afterwards. That is what makes a window that cannot be shown a
    /// failure rather than a cascade: the next render finds the slot and
    /// applies into the window it holds, instead of deciding this node has no
    /// window and asking for another one.
    /// </remarks>
    private Slot Claim(SwiftNode node)
    {
        foreach (Slot known in _slots)
        {
            if (known.Key == node.Key)
            {
                return known;
            }
        }

        Slot slot;

        if (_free.Count > 0)
        {
            // The window the platform handed over is already on screen, so it
            // counts as opened and there is nothing left to close: this IS the
            // window the reader asked for, and it now has a node. The OLDEST
            // waiting one, so that windows are claimed in the order the platform
            // handed them over.
            StateUIWindow waiting = _free.Dequeue();

            if (_asked > 0)
            {
                _asked--;
            }

            _claimed = true;

            slot = new Slot { Key = node.Key, Window = waiting, Opened = true };
        }
        else
        {
            slot = new Slot { Key = node.Key, Window = new StateUIWindow(this) };
        }

        _slots.Add(slot);
        return slot;
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

    /// <summary>One window the tree describes, and the window showing it.</summary>
    private sealed class Slot
    {
        /// <summary>The identity of the node this window came from.</summary>
        internal string Key { get; init; } = "";

        /// <summary>
        /// The window, or null once the platform has destroyed it.
        /// </summary>
        internal StateUIWindow? Window { get; set; }

        /// <summary>
        /// Whether the platform has been asked to show this window - true from
        /// the start for one the platform itself handed over.
        /// </summary>
        internal bool Opened { get; set; }
    }
}
