// Several windows, as the host keeps them.
//
// The root of a message is the Application and its children are the windows, so
// this side opens one for every window described, applies each node to its own
// window, and closes whatever the list no longer names. MAUI's own
// OpenWindow/CloseWindow are how it asks the platform - both are virtual, which
// is what lets a test watch the asking without a platform underneath.
//
// What Swift puts on the wire is next door, in the Swift MultiWindowTests.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class MultiWindowTests
{
    /// <summary>
    /// A MAUI application that records what it was asked to open and close.
    /// </summary>
    /// <remarks>
    /// Constructing one makes it <c>Application.Current</c>, which is where the
    /// host looks - and both methods are <c>public virtual</c>, so a subclass
    /// sees the request that would have reached the platform. Nothing is opened
    /// or closed for real: headless, MAUI's own OpenWindow only remembers the
    /// window for the scene that never connects.
    /// </remarks>
    private sealed class Platform : Application
    {
        internal List<Window> Opened { get; } = [];

        internal List<Window> Closed { get; } = [];

        /// <summary>
        /// The page each window was showing at the moment it was opened - what
        /// a platform that reads content inside OpenWindow would have found.
        /// </summary>
        internal List<Page?> Showing { get; } = [];

        /// <summary>
        /// What to throw instead of opening, for a platform that refuses.
        /// </summary>
        internal Exception? Refuses { get; set; }

        public override void OpenWindow(Window window)
        {
            Opened.Add(window);
            Showing.Add(window.Page);

            if (Refuses is Exception refusal)
            {
                throw refusal;
            }

            base.OpenWindow(window);
        }

        public override void CloseWindow(Window window) => Closed.Add(window);
    }

    /// <summary>One window's node, with a page under it.</summary>
    private static string Window(string identity, string title) => $$$"""
        {"id":{{{identity}}},"type":"Window","props":{"title":"{{{title}}}"},"arranged":true,"children":[
          {"id":{{{identity}}}0,"type":"ContentPage","props":{"title":"{{{title}}}"},"arranged":true,
           "children":[{"id":{{{identity}}}1,"type":"Label","props":{"text":"{{{title}}}"}}]}]}
        """;

    /// <summary>An application node over whatever windows are given.</summary>
    private static string Tree(params string[] windows) =>
        $$"""{"id":1,"type":"Application","arranged":true,"children":[{{string.Join(",", windows)}}]}""";

    /// <summary>Applies one message to an application, the way the session does.</summary>
    private static StateUIApplication Apply(
        StateUIApplication application, string json, bool complete = true)
    {
        ((IStateUITarget)application).Apply(Host.Parse(json), complete);
        return application;
    }

    /// <summary>The titles of the windows an application is showing.</summary>
    private static string[] Titles(StateUIApplication application) =>
        [.. application.Windows.Select(window => window.Title ?? "")];

    // ---- Opening -----------------------------------------------------------

    [Fact]
    public void AnApplicationOpensAWindowForEveryOneDescribed()
    {
        StateUIApplication application = Apply(
            new StateUIApplication(), Tree(Window("2", "Main"), Window("3", "Inspector")));

        Assert.Equal(["Main", "Inspector"], Titles(application));
        Assert.Equal(
            ["Main", "Inspector"],
            application.Windows.Select(window => window.Page?.Title ?? ""));
    }

    /// <summary>
    /// The platform is ASKED for a window rather than given one: MAUI remembers
    /// the instance and hands it back when the new scene connects, so what this
    /// side builds is what appears.
    /// </summary>
    [Fact]
    public void OpeningAWindowAsksThePlatformForIt()
    {
        var platform = new Platform();

        StateUIApplication application = Apply(
            new StateUIApplication(), Tree(Window("2", "Main"), Window("3", "Inspector")));

        Assert.Equal(2, platform.Opened.Count);
        Assert.Equal(application.Windows, platform.Opened);
    }

    /// <summary>
    /// A window is opened only once it holds the page the tree described.
    /// </summary>
    /// <remarks>
    /// WinUI reads a window's content INSIDE OpenWindow -
    /// <c>NavigationRootManager.Connect</c> asks for it before the call returns
    /// - and throws "No page was set on the window" when there is none.
    /// Measured on Windows 2026-08-15: every inspector window the gallery
    /// opened came up on the library's error page. Apple connects its scene
    /// later and never asked, which is why nothing here saw it.
    /// </remarks>
    [Fact]
    public void AWindowIsOpenedOnlyOnceItHasThePageTheTreeDescribed()
    {
        var platform = new Platform();

        Apply(new StateUIApplication(), Tree(Window("2", "Main"), Window("3", "Inspector")));

        Assert.Equal(["Main", "Inspector"], platform.Showing.Select(page => page?.Title ?? ""));
    }

    /// <summary>
    /// A window the platform refuses to open is asked for ONCE.
    /// </summary>
    /// <remarks>
    /// The slot is recorded before the ask, so the render after a refusal finds
    /// the window already built and applies into it. Without that, a node whose
    /// window cannot be opened has no slot, every render decides it needs a
    /// window, and the process fills with blank ones - measured on Windows
    /// 2026-08-15 as eight windows from one press and a FailFast.
    /// </remarks>
    [Fact]
    public void AWindowThePlatformRefusesToOpenIsNotAskedForAgain()
    {
        var platform = new Platform
        {
            Refuses = new InvalidOperationException("No page was set on the window."),
        };

        var application = new StateUIApplication();

        Assert.Throws<InvalidOperationException>(
            () => Apply(application, Tree(Window("2", "Main"))));

        // The render after it asks the platform for nothing at all.
        Apply(application, Tree(Window("2", "Main")));

        Assert.Single(platform.Opened);
        Assert.Single(application.Windows);
    }

    /// <summary>
    /// A message about one window says nothing about the other, and touches
    /// nothing of it: the page it is showing is the same object afterwards.
    /// </summary>
    [Fact]
    public void APatchAboutOneWindowLeavesTheOtherAlone()
    {
        StateUIApplication application = Apply(
            new StateUIApplication(), Tree(Window("2", "Main"), Window("3", "Inspector")));

        StateUIWindow main = application.Windows.First();
        StateUIWindow inspector = application.Windows.Last();
        Page? page = main.Page;

        Apply(
            application,
            """
            {"id":1,"type":"Application","children":[
              {"id":3,"type":"Window","props":{"title":"Renamed"}}]}
            """,
            complete: false);

        Assert.Equal("Renamed", inspector.Title);
        Assert.Equal("Main", main.Title);
        Assert.Same(page, main.Page);
    }

    // ---- Closing -----------------------------------------------------------

    /// <summary>
    /// A window the tree no longer names is closed through the platform, and
    /// the ones that stay keep their windows - the survivors are not rebuilt
    /// because a sibling left.
    /// </summary>
    [Fact]
    public void AWindowTheTreeNoLongerDescribesIsClosed()
    {
        var platform = new Platform();

        StateUIApplication application = Apply(
            new StateUIApplication(),
            Tree(Window("2", "Main"), Window("3", "Colours"), Window("4", "Layers")));

        StateUIWindow main = application.Windows.First();
        StateUIWindow colours = application.Windows.Skip(1).First();
        StateUIWindow layers = application.Windows.Last();

        Apply(application, Tree(Window("2", "Main"), Window("4", "Layers")));

        Assert.Equal([colours], platform.Closed);
        Assert.Equal([main, layers], application.Windows);
    }

    /// <summary>
    /// An application that ends up describing no windows closes the last one -
    /// a document application whose last document was closed, on a Mac that
    /// keeps the process alive.
    /// </summary>
    [Fact]
    public void AnEmptyListClosesEverything()
    {
        var platform = new Platform();

        StateUIApplication application = Apply(
            new StateUIApplication(), Tree(Window("2", "Notes")));

        Apply(application, """{"id":1,"type":"Application","arranged":true,"children":[]}""");

        Assert.Single(platform.Closed);
        Assert.Empty(application.Windows);
    }

    /// <summary>
    /// A window the READER closed is gone, and stays gone while the tree goes
    /// on describing it: an application that does not fold the report back into
    /// its own state would otherwise have the window reopened under it.
    /// </summary>
    [Fact]
    public void AWindowThePlatformDestroyedIsNotOpenedAgain()
    {
        var platform = new Platform();
        string tree = Tree(Window("2", "Main"), Window("3", "Inspector"));

        StateUIApplication application = Apply(new StateUIApplication(), tree);
        StateUIWindow inspector = application.Windows.Last();

        // What the platform does when the reader closes a window - measured:
        // it is IWindow.Destroying that MAUI raises, and that takes the window
        // out of Application.Windows too.
        ((IWindow)inspector).Destroying();

        Apply(application, tree);

        Assert.Single(application.Windows);
        Assert.Equal(2, platform.Opened.Count);
    }

    /// <summary>
    /// And once the tree stops describing it, the slot goes with it - so the
    /// same window can be opened again later, which is what reopening a
    /// document means.
    /// </summary>
    [Fact]
    public void AWindowDescribedAgainAfterItsNodeLeftIsOpenedAgain()
    {
        var platform = new Platform();
        string both = Tree(Window("2", "Main"), Window("3", "Inspector"));

        StateUIApplication application = Apply(new StateUIApplication(), both);
        ((IWindow)application.Windows.Last()).Destroying();

        Apply(application, Tree(Window("2", "Main")));
        Apply(application, both);

        Assert.Equal(2, application.Windows.Count());
        Assert.Equal(3, platform.Opened.Count);
    }

    /// <summary>
    /// A relaunch keeps the windows the platform has already handed over.
    /// </summary>
    /// <remarks>
    /// The relaunch path means nothing of OURS is on screen, so the slots are
    /// dropped and the whole tree described again - but a window waiting for an
    /// answer is on screen already, blank, and the platform knows about it.
    /// Forgetting it leaks a window nothing describes and nothing closes, and
    /// its answer then finds nothing free and OPENS one, which the platform
    /// remembers: the growth the queue was written to stop, reached from the
    /// other side.
    /// </remarks>
    [Fact]
    public void ARelaunchKeepsTheWindowsThePlatformAlreadyHandedOver()
    {
        var platform = new Platform();
        StateUIApplication application = Apply(
            new StateUIApplication(),
            $$"""
            {"id":1,"type":"Application","arranged":true,
             "events":{"creatingWindow":77},
             "children":[{{Window("2", "Main")}}]}
            """);

        // One handed over and waiting for an answer.
        var waiting = new StateUIWindow(application, adopt: true);

        // Then the one that was showing goes, which empties the slots...
        ((IWindow)application.Windows.First()).Destroying();

        // ...and the next window the platform makes takes the relaunch path.
        _ = new StateUIWindow(application, adopt: true);

        // The window that was waiting is still waiting, so the tree described
        // again appears IN it rather than in one more the platform is asked for.
        Apply(application, Tree(Window("2", "Main")));

        Assert.Equal([waiting], application.Windows);
        Assert.Single(platform.Opened);
    }

    // ---- Where a page-level act goes ---------------------------------------

    /// <summary>
    /// An alert belongs to the window the reader is working in, and activation
    /// is what says which that is - MAUI has nothing else to ask.
    /// </summary>
    [Fact]
    public void TheWindowAnActReachesIsTheOneActivatedLast()
    {
        StateUIApplication application = Apply(
            new StateUIApplication(), Tree(Window("2", "Main"), Window("3", "Inspector")));

        StateUIWindow main = application.Windows.First();
        StateUIWindow inspector = application.Windows.Last();

        Assert.Same(main, application.Active);

        ((IWindow)inspector).Activated();
        Assert.Same(inspector, application.Active);

        // And a window that has gone hands the answer back rather than keeping
        // it: a dialog cannot open over a window that is not there.
        ((IWindow)inspector).Destroying();
        Assert.Same(main, application.Active);
    }

    // ---- The windows the platform makes -------------------------------------

    /// <summary>
    /// An application that declares no answer shows the windows it lists, so a
    /// window the platform opened by itself is closed again.
    /// </summary>
    /// <remarks>
    /// The reader used their own system's gesture - <i>File ▸ New Window</i>, an
    /// iPad's window controls - and did nothing wrong; an error page in their
    /// face would say otherwise, and a blank window says nothing at all.
    /// </remarks>
    [Fact]
    public void AWindowNothingDescribesIsClosedAgain()
    {
        var platform = new Platform();
        StateUIApplication application = Apply(
            new StateUIApplication(), Tree(Window("2", "Main")));

        var extra = new StateUIWindow(application, adopt: true);

        Assert.Equal([extra], platform.Closed);
        Assert.Single(application.Windows);
    }

    /// <summary>
    /// A window the platform made carries a page from the moment it is adopted,
    /// before anything has described one.
    /// </summary>
    /// <remarks>
    /// The platform hands the window straight to the scene that asked for it
    /// and reads the content there, and MAUI throws "No page was set on the
    /// window" when there is none. The tree's answer cannot be synchronous - a
    /// Swift handler runs on the Swift executor - so the window waits behind an
    /// empty page for the one render it takes. Measured on Mac Catalyst:
    /// <i>Cmd+N</i> took the whole application down.
    /// </remarks>
    [Fact]
    public void AWindowThePlatformMadeCarriesAPageAtOnce()
    {
        _ = new Platform();
        StateUIApplication application = Apply(
            new StateUIApplication(),
            $$"""
            {"id":1,"type":"Application","arranged":true,
             "events":{"creatingWindow":77},
             "children":[{{Window("2", "Main")}}]}
            """);

        var extra = new StateUIWindow(application, adopt: true);

        Assert.NotNull(extra.Page);
    }

    /// <summary>
    /// And so does one nothing will ever describe, which is on its way to being
    /// closed: the scene connects either way, and the close is not instant.
    /// </summary>
    [Fact]
    public void AWindowOnItsWayToBeingClosedCarriesAPageToo()
    {
        var platform = new Platform();
        StateUIApplication application = Apply(
            new StateUIApplication(), Tree(Window("2", "Main")));

        var extra = new StateUIWindow(application, adopt: true);

        Assert.Equal([extra], platform.Closed);
        Assert.NotNull(extra.Page);
    }

    /// <summary>
    /// An application that DOES answer is told, and the window the platform
    /// opened is the one the new node gets - not a second one beside it.
    /// </summary>
    [Fact]
    public void ThePlatformsRequestIsHeldUntilTheTreeAnswers()
    {
        var platform = new Platform();
        StateUIApplication application = Apply(
            new StateUIApplication(),
            $$"""
            {"id":1,"type":"Application","arranged":true,
             "events":{"creatingWindow":77},
             "children":[{{Window("2", "Main")}}]}
            """);

        var extra = new StateUIWindow(application, adopt: true);

        // Held, not closed: the tree has been told and has not answered yet.
        Assert.Empty(platform.Closed);

        // The answer: one more window described. It gets the window the reader
        // already has on screen, so nothing opens a second time.
        Apply(application, $$"""
            {"id":1,"type":"Application","arranged":true,
             "children":[{{Window("2", "Main")}},{{Window("3", "Document 1")}}]}
            """);

        Assert.Equal(["Main", "Document 1"], Titles(application));
        Assert.Equal([extra], application.Windows.Skip(1));
        Assert.Empty(platform.Closed);

        // Only the main window was ever ASKED for. The document's window was
        // the one the platform had already opened, which is the whole point:
        // the reader gets the window they asked for, not a second one beside
        // it and not a flash of one being closed.
        Assert.Single(platform.Opened);
        Assert.DoesNotContain(extra, platform.Opened);
    }

    /// <summary>
    /// A tree that is asked and goes on describing the same windows has
    /// DECLINED, and the window the platform opened is closed.
    /// </summary>
    /// <remarks>
    /// Only an ARRANGED list decides it: that is the message in which an
    /// application says what its windows are. One that changes a label inside a
    /// window says nothing about the list, and closing on it would race the
    /// handler that is about to append.
    /// </remarks>
    [Fact]
    public void AnUnansweredRequestClosesTheWindowAgain()
    {
        var platform = new Platform();
        StateUIApplication application = Apply(
            new StateUIApplication(),
            $$"""
            {"id":1,"type":"Application","arranged":true,
             "events":{"creatingWindow":77},
             "children":[{{Window("2", "Main")}}]}
            """);

        var extra = new StateUIWindow(application, adopt: true);
        Assert.Empty(platform.Closed);

        // A message about what is INSIDE the window says nothing about the list.
        Apply(application, $$"""
            {"id":1,"type":"Application","children":[{{Window("2", "Renamed")}}]}
            """, complete: false);

        Assert.Empty(platform.Closed);

        // And the list, described again with nothing new in it, is the decline.
        Apply(application, Tree(Window("2", "Main")));

        Assert.Equal([extra], platform.Closed);
        Assert.Single(application.Windows);
    }

    /// <summary>
    /// Several windows handed over before the tree has answered for any of them
    /// are each claimed in turn, oldest first, and the platform is asked for
    /// none of them.
    /// </summary>
    /// <remarks>
    /// A Mac restoring the scene sessions of a session that ended with four
    /// windows open connects them about 13 ms apart, and a render is slower than
    /// that - so the questions overlap. Holding ONE window would leak every one
    /// but the last, and the answers meant for the leaked ones would find
    /// nothing waiting and OPEN A WINDOW EACH. The platform remembers those, so
    /// the next launch restores more than this one did: measured on Mac Catalyst
    /// 2026-08-16, a bundle grew from two windows to 138 and went on growing.
    /// </remarks>
    [Fact]
    public void WindowsHandedOverTogetherAreEachClaimedInTurn()
    {
        var platform = new Platform();
        StateUIApplication application = Apply(
            new StateUIApplication(),
            $$"""
            {"id":1,"type":"Application","arranged":true,
             "events":{"creatingWindow":77},
             "children":[{{Window("2", "Main")}}]}
            """);

        // Two, before either has been answered for.
        var first = new StateUIWindow(application, adopt: true);
        var second = new StateUIWindow(application, adopt: true);

        Assert.Empty(platform.Closed);

        // One answer per question, each a render of its own.
        Apply(application, $$"""
            {"id":1,"type":"Application","arranged":true,
             "children":[{{Window("2", "Main")}},{{Window("3", "Document 1")}}]}
            """);

        Apply(application, $$"""
            {"id":1,"type":"Application","arranged":true,
             "children":[{{Window("2", "Main")}},{{Window("3", "Document 1")}},
                         {{Window("4", "Document 2")}}]}
            """);

        Assert.Equal(["Main", "Document 1", "Document 2"], Titles(application));

        // Oldest first, so the window the reader asked for first is the one the
        // first answer appears in.
        Assert.Equal([first, second], application.Windows.Skip(1));

        // And the platform was asked for the main window and nothing else -
        // neither of these was opened a second time, and neither was closed.
        Assert.Single(platform.Opened);
        Assert.Empty(platform.Closed);
    }

    /// <summary>
    /// A decline closes ONE window - the one that message was about - and leaves
    /// the others waiting for the answers still to come.
    /// </summary>
    [Fact]
    public void ADeclineClosesOneWindowAndLeavesTheRestWaiting()
    {
        var platform = new Platform();
        StateUIApplication application = Apply(
            new StateUIApplication(),
            $$"""
            {"id":1,"type":"Application","arranged":true,
             "events":{"creatingWindow":77},
             "children":[{{Window("2", "Main")}}]}
            """);

        var first = new StateUIWindow(application, adopt: true);
        var second = new StateUIWindow(application, adopt: true);

        // The first answer takes one; nothing is closed, because the second
        // question has not been answered yet.
        Apply(application, $$"""
            {"id":1,"type":"Application","arranged":true,
             "children":[{{Window("2", "Main")}},{{Window("3", "Document 1")}}]}
            """);

        Assert.Empty(platform.Closed);
        Assert.Equal([first], application.Windows.Skip(1));

        // The second is declined - the list, described again with nothing new.
        Apply(application, $$"""
            {"id":1,"type":"Application","arranged":true,
             "children":[{{Window("2", "Main")}},{{Window("3", "Document 1")}}]}
            """);

        Assert.Equal([second], platform.Closed);
    }

    // ---- The embedded host --------------------------------------------------

    /// <summary>
    /// A Swift tree embedded in someone else's page is one window's worth,
    /// because a view has nowhere to put a second one.
    /// </summary>
    [Fact]
    public void AHostShowsOneWindowAndSaysSoAboutMore()
    {
        var host = new StateUIHost();

        ((IStateUITarget)host).Apply(
            Host.Parse(Tree(Window("2", "Main"), Window("3", "Inspector"))), true);

        Assert.Contains("shows one window", Host.TextOf(host));
    }

    // ---- The fixtures, which are the contract -------------------------------

    /// <summary>
    /// The two messages the Swift tests wrote: three windows opened, then the
    /// middle one closed. The survivors keep their windows, which is what the
    /// author's <c>.id()</c> buys on this side.
    /// </summary>
    [Fact]
    public void TheFixtureOpensThreeWindowsAndClosesOne()
    {
        var platform = new Platform();
        var names = new SwiftWireDictionary();
        var application = new StateUIApplication();

        SwiftMessage opened = SwiftWire.ReadMessage(Fixtures.ReadBytes("windows/1-opens.bin"), names);
        ((IStateUITarget)application).Apply(opened.Root!, opened.Complete);

        Assert.Equal(["Main", "colours", "layers"], Titles(application));

        StateUIWindow main = application.Windows.First();
        StateUIWindow layers = application.Windows.Last();

        SwiftMessage closed = SwiftWire.ReadMessage(Fixtures.ReadBytes("windows/2-closes.bin"), names);
        ((IStateUITarget)application).Apply(closed.Root!, closed.Complete);

        Assert.Equal([main, layers], application.Windows);
        Assert.Equal("layers", layers.Page?.Title);
        Assert.Single(platform.Closed);
    }
}
