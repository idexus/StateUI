// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An application's scenes, as the host keeps them.
//
// The root of a message is the Application and its children are SCENES - one
// per session - whose children are its windows, the main one first. This side
// opens a window for every window described, applies each node to its own
// window, closes whatever a scene no longer names, tells a scene what the
// reader did to its windows, and hands the platform what it keeps for the
// system to restore. MAUI's own OpenWindow/CloseWindow are how it asks the
// platform - both are virtual, which is what lets a test watch the asking
// without a platform underneath.
//
// What Swift puts on the wire is next door, in the Swift SceneTests.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class SceneTests
{
    /// <summary>
    /// A session one test noted and handed to no window is no business of the
    /// next one, and neither is a hold on the dispatcher a failed test never
    /// drained.
    /// </summary>
    public SceneTests()
    {
        _ = SceneSessions.Take();
        TestDispatcher.Forget();
    }

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

        /// <summary>What to throw instead of opening, for a platform that refuses.</summary>
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

    /// <summary>
    /// An application with no Swift behind it, and what it said: the reports
    /// its scenes were sent, and the payload each window handed over was
    /// announced with.
    /// </summary>
    private sealed class Heard
    {
        internal Heard()
        {
            Application = new StateUIApplication(
                (id, payload) => Reports.Add((id, Host.Describe(payload))),
                payload =>
                {
                    // No kept values cross as no bytes at all, which the
                    // describer - reading a version first - has no spelling for.
                    Connected.Add(payload.Length == 0 ? "" : Host.Describe(payload) ?? "");
                    return 1;
                });
        }

        internal StateUIApplication Application { get; }

        internal List<(int Id, string? Payload)> Reports { get; } = [];

        internal List<string> Connected { get; } = [];

        /// <summary>Applies one message, the way the session does.</summary>
        internal Heard Apply(string json, bool complete = true)
        {
            ((IStateUITarget)Application).Apply(Host.Parse(json), complete);
            return this;
        }

        /// <summary>
        /// A window the platform made, the way it makes one: the session says
        /// what it is, then the app builds the window.
        /// </summary>
        internal StateUIWindow Adopted(SceneOrigin? origin = null)
        {
            if (origin is not null)
            {
                SceneSessions.Connecting(origin);
            }

            return new StateUIWindow(Application, adopt: true);
        }
    }

    /// <summary>An application node over whatever scenes are given.</summary>
    private static string Tree(params string[] scenes) =>
        $$"""{"id":1,"type":"Application","arranged":true,"children":[{{string.Join(",", scenes)}}]}""";

    /// <summary>
    /// A scene: its number, and its windows - with a handler for everything a
    /// scene hears, numbered from ten times the scene's own: windowClosed +1,
    /// windowRestored +2, destroying +3, activated +4, deactivated +5,
    /// stopped +6.
    /// </summary>
    private static string Scene(int number, params string[] windows)
    {
        int at = number * 10;

        return $$$"""
            {"id":"{{{number}}}","type":"Scene","arranged":true,
             "events":{"windowClosed":{{{at + 1}}},"windowRestored":{{{at + 2}}},"destroying":{{{at + 3}}},
                       "activated":{{{at + 4}}},"deactivated":{{{at + 5}}},"stopped":{{{at + 6}}} },
             "children":[{{{string.Join(",", windows)}}}]}
            """;
    }

    /// <summary>A scene's main window - known by "main", as every scene's is.</summary>
    private static string Main(int page, string title) =>
        Window("\"main\"", "\"title\":\"" + title + "\"", page, title);

    /// <summary>
    /// One of a scene's other windows: the name the tree knows it by, its
    /// group's kind, its value where it has one, whether it hides and whether
    /// it floats on top.
    /// </summary>
    private static string Beside(
        string name, int page, string kind, string? value = null, bool hides = false, bool floats = false) =>
        Window(
            "\"" + name + "\"",
            "\"title\":\"" + name + "\",\"windowType\":{\"name\":\"" + kind + "\"}"
                + (value is null ? "" : ",\"windowValue\":\"" + value + "\"")
                + (hides ? ",\"autoHide\":true" : "")
                + (floats ? ",\"floatsOnTop\":true" : ""),
            page,
            name);

    /// <summary>
    /// One of a scene's other windows, hearing its own lifecycle: every window
    /// node carries a handler for each of MAUI's six moments, which is what
    /// moves that window's session phase - see Views/Application.swift. They
    /// are numbered from seventy, clear of what a scene's own handlers take.
    /// </summary>
    private static string Watched(string name, int page, string kind) =>
        Window(
            "\"" + name + "\"",
            "\"title\":\"" + name + "\",\"windowType\":{\"name\":\"" + kind + "\"}",
            page,
            name,
            """
            "events":{"created":70,"activated":71,"deactivated":72,
                      "stopped":73,"resumed":74,"destroying":75},
            """);

    /// <summary>A window with a page and a label under it.</summary>
    private static string Window(string identity, string props, int page, string title, string events = "") => $$$"""
        {"id":{{{identity}}},"type":"Window","props":{ {{{props}}} },{{{events}}}"arranged":true,"children":[
          {"id":{{{page}}},"type":"ContentPage","props":{"title":"{{{title}}}"},"arranged":true,
           "children":[{"id":{{{page + 1}}},"type":"Label","props":{"text":"{{{title}}}"}}]}]}
        """;

    /// <summary>A name - what a scene's number and a key travel as.</summary>
    private static SwiftWireValue Name(string name) => new(SwiftWireValue.TagName, name);

    /// <summary>The titles of the windows an application is showing, in order.</summary>
    private static string[] Titles(StateUIApplication application) =>
        [.. application.Windows.Select(window => window.Title ?? "")];

    // ---- Opening -----------------------------------------------------------

    /// <summary>
    /// A scene's main window opens first and the windows it has open beside it
    /// after, each ASKED of the platform - which remembers the instance and
    /// hands it back as the new scene connects - with the page the tree
    /// described already in it.
    /// </summary>
    /// <remarks>
    /// WinUI reads a window's content INSIDE OpenWindow and throws "No page
    /// was set on the window" when there is none - measured on Windows
    /// 2026-08-15, where every window the gallery opened came up on the
    /// library's error page.
    /// </remarks>
    [Fact]
    public void ASceneOpensItsMainWindowAndTheOnesBesideIt()
    {
        var platform = new Platform();

        Heard heard = new Heard().Apply(Tree(Scene(1, Main(100, "Gallery"), Beside("fonts 1", 110, "fonts"))));

        Assert.Equal(["Gallery", "fonts 1"], Titles(heard.Application));
        Assert.Equal(heard.Application.Windows, platform.Opened);
        Assert.Equal(["Gallery", "fonts 1"], platform.Showing.Select(page => page?.Title ?? ""));
    }

    /// <summary>
    /// Two scenes are two main windows, each with its own windows, in the
    /// order the scenes opened.
    /// </summary>
    [Fact]
    public void EachSceneHasAMainWindowOfItsOwn()
    {
        Heard heard = new Heard().Apply(Tree(
            Scene(1, Main(100, "One"), Beside("fonts 1", 110, "fonts")),
            Scene(2, Main(200, "Two"))));

        Assert.Equal(["One", "fonts 1", "Two"], Titles(heard.Application));
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

        var heard = new Heard();

        Assert.Throws<InvalidOperationException>(() => heard.Apply(Tree(Scene(1, Main(100, "Main")))));

        heard.Apply(Tree(Scene(1, Main(100, "Main"))));

        Assert.Single(platform.Opened);
        Assert.Single(heard.Application.Windows);
    }

    /// <summary>
    /// A message about one window says nothing about the others, and touches
    /// nothing of them: the page the main window shows is the same object
    /// afterwards.
    /// </summary>
    [Fact]
    public void APatchAboutOneWindowLeavesTheOthersAlone()
    {
        Heard heard = new Heard().Apply(Tree(Scene(1, Main(100, "Main"), Beside("fonts 1", 110, "fonts"))));

        StateUIWindow main = heard.Application.Windows.First();
        StateUIWindow fonts = heard.Application.Windows.Last();
        Page? page = main.Page;

        heard.Apply(
            """
            {"id":1,"type":"Application","children":[
              {"id":"1","type":"Scene","children":[
                {"id":"fonts 1","type":"Window","props":{"title":"Renamed"}}]}]}
            """,
            complete: false);

        Assert.Equal("Renamed", fonts.Title);
        Assert.Equal("Main", main.Title);
        Assert.Same(page, main.Page);
    }

    // ---- Closing -----------------------------------------------------------

    /// <summary>
    /// A window its scene no longer names is closed through the platform, and
    /// the ones that stay keep their windows.
    /// </summary>
    [Fact]
    public void AWindowItsSceneStopsDescribingIsClosed()
    {
        var platform = new Platform();

        Heard heard = new Heard().Apply(Tree(Scene(
            1,
            Main(100, "Main"),
            Beside("fonts 1", 110, "fonts"),
            Beside("document 2", 120, "document", value: "42"))));

        StateUIWindow[] before = [.. heard.Application.Windows];

        heard.Apply(Tree(Scene(1, Main(100, "Main"), Beside("document 2", 120, "document", value: "42"))));

        Assert.Equal([before[1]], platform.Closed);
        Assert.Equal([before[0], before[2]], heard.Application.Windows);
    }

    /// <summary>
    /// A scene the tree no longer describes has ended, and every window of it
    /// goes - the other scenes keep theirs.
    /// </summary>
    [Fact]
    public void ASceneThatEndsClosesEveryWindowOfIt()
    {
        var platform = new Platform();

        Heard heard = new Heard().Apply(Tree(
            Scene(1, Main(100, "One"), Beside("fonts 1", 110, "fonts")),
            Scene(2, Main(200, "Two"))));

        StateUIWindow[] before = [.. heard.Application.Windows];

        heard.Apply(Tree(Scene(2, Main(200, "Two"))));

        Assert.Equal([before[0], before[1]], platform.Closed);
        Assert.Equal([before[2]], heard.Application.Windows);
    }

    /// <summary>
    /// An application that ends up with no scenes closes the last window - on
    /// a Mac that keeps the process alive.
    /// </summary>
    [Fact]
    public void AnEmptyListClosesEverything()
    {
        var platform = new Platform();

        Heard heard = new Heard().Apply(Tree(Scene(1, Main(100, "Notes"))));

        heard.Apply("""{"id":1,"type":"Application","arranged":true,"children":[]}""");

        Assert.Single(platform.Closed);
        Assert.Empty(heard.Application.Windows);
    }

    /// <summary>
    /// And once a scene stops describing a window, the slot goes with it - so
    /// the same window can be opened again later, which is what reopening a
    /// document means.
    /// </summary>
    [Fact]
    public void AWindowDescribedAgainAfterItsNodeLeftIsOpenedAgain()
    {
        var platform = new Platform();
        string both = Tree(Scene(1, Main(100, "Main"), Beside("fonts 1", 110, "fonts")));

        Heard heard = new Heard().Apply(both);
        ((IWindow)heard.Application.Windows.Last()).Destroying();

        heard.Apply(Tree(Scene(1, Main(100, "Main"))));
        heard.Apply(both);

        Assert.Equal(2, heard.Application.Windows.Count());
        Assert.Equal(3, platform.Opened.Count);
    }

    /// <summary>
    /// A window the TREE closes reports nothing of its own lifecycle: it left
    /// the tree in the render that asked for the close, so the handlers on its
    /// node went with it.
    /// </summary>
    /// <remarks>
    /// Every platform raises Deactivated, Stopped and Destroying as it closes
    /// a window, and the ids the window's node carried are quoted at the
    /// moment each arrives - so without this the Swift side is handed three
    /// handlers it has already forgotten. Measured on Linux, closing the
    /// inspector's own window: two of <c>a control reported to handler N,
    /// which the Swift side does not know</c> every time.
    /// </remarks>
    [Fact]
    public void AWindowTheTreeClosesReportsNothingOfItsOwn()
    {
        _ = new Platform();

        Heard heard = new Heard().Apply(Tree(Scene(1, Main(100, "Main"), Watched("fonts 1", 110, "fonts"))));

        // Up and in front, which is the state a window is closed FROM - and
        // what MAUI's own lifecycle insists on before it will be deactivated.
        IWindow closing = heard.Application.Windows.Last();
        closing.Created();
        closing.Activated();

        heard.Apply(Tree(Scene(1, Main(100, "Main"))));
        heard.Reports.Clear();

        closing.Deactivated();
        closing.Stopped();
        closing.Destroying();

        Assert.Empty(heard.Reports);
    }

    // ---- What the reader does ----------------------------------------------

    /// <summary>
    /// A window the READER closed is reported to its scene by the name the
    /// tree knows it by - and stays closed while the tree goes on describing
    /// it, until the scene has heard.
    /// </summary>
    [Fact]
    public void TheReaderClosingAWindowTellsItsSceneWhichOne()
    {
        var platform = new Platform();
        string tree = Tree(Scene(1, Main(100, "Main"), Beside("fonts 1", 110, "fonts")));

        Heard heard = new Heard().Apply(tree);
        StateUIWindow fonts = heard.Application.Windows.Last();

        // What the platform does when the reader closes a window - measured:
        // it is IWindow.Destroying that MAUI raises.
        ((IWindow)fonts).Destroying();

        Assert.Equal([(11, "\"fonts 1\"")], heard.Reports);

        heard.Apply(tree);

        Assert.Single(heard.Application.Windows);
        Assert.Equal(2, platform.Opened.Count);
    }

    /// <summary>
    /// The reader closing a scene's main window is the scene ending: the scene
    /// is told, and the tree's answer - the scene gone - closes the window
    /// beside it.
    /// </summary>
    [Fact]
    public void TheReaderClosingTheMainWindowEndsItsScene()
    {
        var platform = new Platform();

        Heard heard = new Heard().Apply(Tree(
            Scene(1, Main(100, "One"), Beside("fonts 1", 110, "fonts")),
            Scene(2, Main(200, "Two"))));

        StateUIWindow[] before = [.. heard.Application.Windows];

        ((IWindow)before[0]).Destroying();

        Assert.Equal([(13, (string?)null)], heard.Reports);

        heard.Apply(Tree(Scene(2, Main(200, "Two"))));

        Assert.Equal([before[1]], platform.Closed);
        Assert.Equal([before[2]], heard.Application.Windows);
    }

    /// <summary>
    /// The scene the reader comes to is told it is active, and the one they
    /// left that it is not.
    /// </summary>
    [Fact]
    public void TheSceneTheReaderComesToIsActiveAndTheOneTheyLeftIsNot()
    {
        Heard heard = new Heard().Apply(Tree(Scene(1, Main(100, "One")), Scene(2, Main(200, "Two"))));

        StateUIWindow one = heard.Application.Windows.First();
        StateUIWindow two = heard.Application.Windows.Last();

        heard.Application.CameToFront(one);
        heard.Application.CameToFront(two);

        Assert.Equal([(14, (string?)null), (15, null), (24, null)], heard.Reports);
    }

    /// <summary>
    /// Moving between two windows of one scene - one deactivated, the other
    /// come to - tells the scene nothing: it was active and it still is.
    /// </summary>
    [Fact]
    public void MovingBetweenTheWindowsOfOneSceneTellsItNothing()
    {
        Heard heard = new Heard().Apply(Tree(Scene(1, Main(100, "Main"), Beside("fonts 1", 110, "fonts"))));

        StateUIWindow main = heard.Application.Windows.First();
        StateUIWindow fonts = heard.Application.Windows.Last();

        // Raised the way the platform raises them: a window is deactivated
        // only once it has been activated, which MAUI checks.
        ((IWindow)main).Activated();
        heard.Reports.Clear();

        TestDispatcher.Hold();
        ((IWindow)main).Deactivated();
        ((IWindow)fonts).Activated();
        TestDispatcher.Drain();

        Assert.Empty(heard.Reports);
    }

    /// <summary>
    /// A window its scene hid says it was activated as it is shown again -
    /// which is not the reader coming to it: the reader is in another window
    /// of the same scene, and acts go on reaching that one.
    /// </summary>
    [Fact]
    public void AWindowShownAgainIsNotTheReaderComingToIt()
    {
        Heard heard = new Heard().Apply(Tree(Scene(
            1, Main(100, "Main"), Beside("fonts 1", 110, "fonts", hides: true))));

        StateUIWindow main = heard.Application.Windows.First();
        StateUIWindow fonts = heard.Application.Windows.Last();

        heard.Application.CameToFront(main);

        fonts.HiddenByScene = true;
        ((IWindow)fonts).Activated();

        Assert.Same(main, heard.Application.Active);
        Assert.False(fonts.HiddenByScene);
    }

    /// <summary>
    /// The platform's list of the application's windows - the Window menu, the
    /// Dock's - names the scenes by their main windows, and never a window
    /// beside one, whether its group hides it or not: chosen there, it would
    /// come forward while its scene stays where it is.
    /// </summary>
    [Fact]
    public void OnlyAMainWindowIsListed()
    {
        Heard heard = new Heard().Apply(Tree(Scene(
            1,
            Main(100, "Main"),
            Beside("fonts 1", 110, "fonts"),
            Beside("colours 2", 120, "colours", hides: true))));

        Assert.Equal([true, false, false], heard.Application.Windows.Select(heard.Application.Listed));
    }

    /// <summary>
    /// A window whose group floats on top is kept above the application's
    /// other windows; the rest take their place among them.
    /// </summary>
    [Fact]
    public void AWindowWhoseGroupFloatsIsKeptOnTop()
    {
        Heard heard = new Heard().Apply(Tree(Scene(
            1,
            Main(100, "Main"),
            Beside("fonts 1", 110, "fonts", floats: true),
            Beside("colours 2", 120, "colours"))));

        Assert.Equal([false, true, false], heard.Application.Windows.Select(heard.Application.FloatsOnTop));
    }

    /// <summary>
    /// An alert belongs to the window the reader is working in, and coming to
    /// a window is what says which that is.
    /// </summary>
    [Fact]
    public void TheWindowAnActReachesIsTheOneTheReaderCameToLast()
    {
        Heard heard = new Heard().Apply(Tree(Scene(1, Main(100, "Main"), Beside("fonts 1", 110, "fonts"))));

        StateUIWindow main = heard.Application.Windows.First();
        StateUIWindow fonts = heard.Application.Windows.Last();

        Assert.Same(main, heard.Application.Active);

        ((IWindow)fonts).Activated();
        Assert.Same(fonts, heard.Application.Active);

        // And a window that has gone hands the answer back rather than keeping
        // it: a dialog cannot open over a window that is not there.
        ((IWindow)fonts).Destroying();
        Assert.Same(main, heard.Application.Active);
    }

    // ---- The windows the platform makes -------------------------------------

    /// <summary>
    /// A window the platform makes is a scene's main window: Swift is told as
    /// it arrives, and the scene the tree then describes appears IN it rather
    /// than in a window the platform is asked for.
    /// </summary>
    [Fact]
    public void AWindowThePlatformMakesIsASceneMainWindow()
    {
        var platform = new Platform();
        var heard = new Heard();

        StateUIWindow window = heard.Adopted();

        Assert.Equal([""], heard.Connected);
        Assert.NotNull(window.Page);

        heard.Apply(Tree(Scene(1, Main(100, "Gallery"))));

        Assert.Equal([window], heard.Application.Windows);
        Assert.Empty(platform.Opened);
    }

    /// <summary>
    /// The application is registered BEFORE a window the platform made is
    /// announced to it.
    /// </summary>
    /// <remarks>
    /// Registering gives Swift its application and the one scene waiting for
    /// the platform's first window, and starts the scenes over. Announced
    /// before that, the first window was announced to nothing: the second took
    /// the waiting scene - which had a window already - and a restored session
    /// of three windows came up as two galleries and a blank window. Measured
    /// on Mac Catalyst, 2026-09-11.
    /// <para>
    /// What a test can see of it is the first step, the session claiming the
    /// process: everything registering goes on to do - the wire check, the
    /// standard environment, the application's own registration, the kept
    /// state - reaches the native library, which a test has none of.
    /// </para>
    /// </remarks>
    [Fact]
    public void TheApplicationIsRegisteredBeforeAWindowIsAnnouncedToIt()
    {
        Action? had = StateUIHost.RegisterApp;
        List<string> said = [];
        StateUISession.Release();
        StateUIHost.RegisterApp = () => { };

        try
        {
            var application = new StateUIApplication(
                (_, _) => { },
                _ =>
                {
                    said.Add(StateUIEvents.Session is null ? "announced first" : "announced to a registration");
                    return 1;
                });

            _ = new StateUIWindow(application, adopt: true);

            Assert.Equal(["announced to a registration"], said.Take(1));
        }
        finally
        {
            StateUISession.Release();
            StateUIHost.RegisterApp = had;
        }
    }

    /// <summary>
    /// What the platform kept for a session crosses as its window arrives -
    /// before the render that builds the scene, so a kept state reads it from
    /// its first build - as names and values, in name order.
    /// </summary>
    [Fact]
    public void WhatThePlatformKeptCrossesAsTheWindowArrives()
    {
        _ = new Platform();
        var heard = new Heard();

        heard.Adopted(new SceneOrigin(
            "S1", null, null, null, [("accent", SwiftWireValue.Of("teal")), ("size", SwiftWireValue.Of(3.0))]));

        Assert.Equal(["\"accent\", \"teal\", \"size\", 3"], heard.Connected);
    }

    /// <summary>
    /// A scene's kept values are written down for its main window's session -
    /// what the platform handed back, and every value the scene keeps after.
    /// </summary>
    [Fact]
    public void ASceneKeepsItsValuesOnItsMainWindowsSession()
    {
        _ = new Platform();
        var heard = new Heard();

        StateUIWindow main = heard.Adopted(
            new SceneOrigin("S1", null, null, null, [("accent", SwiftWireValue.Of("teal"))]));

        heard.Apply(Tree(Scene(1, Main(100, "Main"))));

        heard.Application.Keep(new SwiftCommand(
            SwiftAct.PersistSceneValue,
            "persistSceneValue",
            [Name("1"), Name("shade"), SwiftWireValue.Of("dusk")],
            null));

        SceneOrigin kept = Assert.IsType<SceneOrigin>(heard.Application.Remembered(main));

        Assert.Equal(["accent teal", "shade dusk"], kept.Kept.Select(pair => $"{pair.Name} {pair.Value.Text}"));
        Assert.Null(kept.Owner);
    }

    /// <summary>
    /// A window beside the main one is written down as its scene's - by the
    /// main window's session - with its kind and its value: what the system
    /// hands back to put it where it was.
    /// </summary>
    [Fact]
    public void AWindowBesideTheMainOneIsWrittenDownAsItsScenes()
    {
        _ = new Platform();
        var heard = new Heard();

        heard.Adopted(new SceneOrigin("S1", null, null, null, []));
        heard.Apply(Tree(Scene(1, Main(100, "Main"), Beside("document 2", 120, "document", value: "42"))));

        SceneOrigin kept = Assert.IsType<SceneOrigin>(
            heard.Application.Remembered(heard.Application.Windows.Last()));

        Assert.Equal(("S1", "document", "42"), (kept.Owner, kept.Kind, kept.Value));
    }

    /// <summary>A window made about another value is written down with that one.</summary>
    [Fact]
    public void AWindowMadeAboutAnotherValueIsWrittenDownWithIt()
    {
        _ = new Platform();
        var heard = new Heard();

        heard.Adopted(new SceneOrigin("S1", null, null, null, []));
        heard.Apply(Tree(Scene(1, Main(100, "Main"), Beside("document 2", 120, "document", value: "42"))));

        heard.Apply(
            """
            {"id":1,"type":"Application","children":[
              {"id":"1","type":"Scene","children":[
                {"id":"document 2","type":"Window","props":{"windowValue":"7"}}]}]}
            """,
            complete: false);

        SceneOrigin kept = Assert.IsType<SceneOrigin>(
            heard.Application.Remembered(heard.Application.Windows.Last()));

        Assert.Equal("7", kept.Value);
    }

    /// <summary>
    /// A window the system restored as one of a scene's other windows is
    /// offered to that scene - its kind and its value - and the node the scene
    /// then describes is shown IN it: the platform is asked for nothing.
    /// </summary>
    [Fact]
    public void ARestoredWindowIsOfferedToItsSceneAndShownWhereItSaysSo()
    {
        var platform = new Platform();
        var heard = new Heard();

        StateUIWindow main = heard.Adopted(new SceneOrigin("S1", null, null, null, []));
        heard.Apply(Tree(Scene(1, Main(100, "Main"))));

        StateUIWindow document = heard.Adopted(new SceneOrigin("S2", "S1", "document", "42", []));

        Assert.Equal([(12, "\"document\", \"42\"")], heard.Reports);
        Assert.Single(heard.Connected);

        heard.Apply(Tree(Scene(1, Main(100, "Main"), Beside("document 2", 120, "document", value: "42"))));

        Assert.Equal([main, document], heard.Application.Windows);
        Assert.Empty(platform.Opened);
        Assert.Empty(platform.Closed);
    }

    /// <summary>
    /// A restored window the scene does not describe in the render after the
    /// question is one it does not take - a kind it no longer declares - and
    /// it is closed.
    /// </summary>
    [Fact]
    public void ARestoredWindowItsSceneDoesNotTakeIsClosed()
    {
        var platform = new Platform();
        var heard = new Heard();

        heard.Adopted(new SceneOrigin("S1", null, null, null, []));
        heard.Apply(Tree(Scene(1, Main(100, "Main"))));

        StateUIWindow fonts = heard.Adopted(new SceneOrigin("S2", "S1", "fonts", null, []));

        Assert.Equal([(12, "\"fonts\"")], heard.Reports);

        heard.Apply(Tree(Scene(1, Main(100, "Main"))));

        Assert.Equal([fonts], platform.Closed);
        Assert.Single(heard.Application.Windows);
    }

    /// <summary>
    /// A restored window can arrive before the scene that owns it - the system
    /// restores a session's scenes in no promised order - and it waits, to be
    /// offered once that scene has its main window.
    /// </summary>
    [Fact]
    public void ARestoredWindowWaitsForTheSceneThatOwnsIt()
    {
        var platform = new Platform();
        var heard = new Heard();

        StateUIWindow fonts = heard.Adopted(new SceneOrigin("S2", "S1", "fonts", null, []));

        Assert.Empty(heard.Reports);
        Assert.Empty(heard.Connected);

        StateUIWindow main = heard.Adopted(new SceneOrigin("S1", null, null, null, []));
        heard.Apply(Tree(Scene(1, Main(100, "Main"))));

        Assert.Equal([(12, "\"fonts\"")], heard.Reports);

        heard.Apply(Tree(Scene(1, Main(100, "Main"), Beside("fonts 1", 110, "fonts"))));

        Assert.Equal([main, fonts], heard.Application.Windows);
        Assert.Empty(platform.Opened);
        Assert.Empty(platform.Closed);
    }

    /// <summary>
    /// A restored window whose scene never came back - its session discarded -
    /// is closed when the wait runs out, rather than standing blank for good.
    /// </summary>
    [Fact]
    public void ARestoredWindowWhoseSceneNeverCameIsClosed()
    {
        var platform = new Platform();
        var heard = new Heard();

        StateUIWindow orphan = heard.Adopted(new SceneOrigin("S2", "S7", "fonts", null, []));

        heard.Application.Abandon();

        Assert.Equal([orphan], platform.Closed);
    }

    /// <summary>
    /// A kept value comes back as the KIND it went as: a whole number is not
    /// text, and true is not one.
    /// </summary>
    [Fact]
    public void AKeptValueComesBackAsTheKindItWentAs()
    {
        static string Said(SwiftWireValue value) => $"{value.Tag} {value.Number} {value.Text}";

        foreach (SwiftWireValue value in new[]
        {
            SwiftWireValue.Of(true), SwiftWireValue.Of(false), SwiftWireValue.Of(0.25),
            SwiftWireValue.Of(7.0), SwiftWireValue.Of("s1, with a letter first"),
        })
        {
            string? text = SceneOrigin.Write(value);

            Assert.NotNull(text);
            Assert.True(SceneOrigin.Read(text) is SwiftWireValue back && Said(back) == Said(value), text);
        }

        Assert.Null(SceneOrigin.Read(""));
        Assert.Null(SceneOrigin.Read("x1"));
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
            Host.Parse(Tree(Scene(1, Main(100, "Main"), Beside("fonts 1", 110, "fonts")))), true);

        Assert.Contains("shows one window", Host.TextOf(host));
    }

    // ---- The fixtures, which are the contract -------------------------------

    /// <summary>
    /// The two messages the Swift tests wrote: two scenes, the first with a
    /// window beside its main one, then that window closed. The others keep
    /// their windows, which is what a window's name buys on this side.
    /// </summary>
    [Fact]
    public void TheFixtureOpensTwoScenesAndClosesAWindow()
    {
        var platform = new Platform();
        var names = new SwiftWireDictionary();
        var heard = new Heard();

        SwiftMessage opened = SwiftWire.ReadMessage(Fixtures.ReadBytes("scenes/1-opens.bin"), names);
        ((IStateUITarget)heard.Application).Apply(opened.Root!, opened.Complete);

        Assert.Equal(["Studio", "Fonts", "Studio 2"], Titles(heard.Application));

        StateUIWindow[] before = [.. heard.Application.Windows];

        SwiftMessage closed = SwiftWire.ReadMessage(Fixtures.ReadBytes("scenes/2-closes.bin"), names);
        ((IStateUITarget)heard.Application).Apply(closed.Root!, closed.Complete);

        Assert.Equal([before[0], before[2]], heard.Application.Windows);
        Assert.Equal([before[1]], platform.Closed);
    }
}
