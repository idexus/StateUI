// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The window itself: what a Window node does to the MAUI Window.
//
// A MAUI Window is an ordinary managed object, so it can be given a message here
// and asked what it now says - no device, no native library. What this cannot
// prove is that a desktop platform HONOURS a width of 1200; only that 1200
// reaches Window.Width, which is the line this side is responsible for.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class WindowTests
{
    /// <summary>Applies one window's node, the way the application does.</summary>
    private static StateUIWindow Apply(StateUIWindow window, string json, bool complete = true)
    {
        window.Apply(Host.Parse(json), complete);
        return window;
    }

    private static StateUIWindow Window(string json) => Apply(Host.Window(), json);

    /// <summary>A window carrying whatever properties are given, over one page.</summary>
    private static string Tree(string props) => $$$"""
        {"id":1,"type":"Window","props":{{{{props}}}},"arranged":true,"children":[
          {"id":2,"type":"ContentPage","props":{"title":"Home"},"arranged":true,"children":[
            {"id":3,"type":"Label","props":{"text":"one"}}]}]}
        """;

    [Fact]
    public void AWindowIsGivenItsTitlePositionAndSize()
    {
        StateUIWindow window = Window(Tree("""
            "title":"My Application","width":1200,"height":800,
            "minimumWidth":600,"minimumHeight":400,"x":100,"y":100
            """));

        Assert.Equal("My Application", window.Title);
        Assert.Equal(1200, window.Width);
        Assert.Equal(800, window.Height);
        Assert.Equal(600, window.MinimumWidth);
        Assert.Equal(400, window.MinimumHeight);
        Assert.Equal(100, window.X);
        Assert.Equal(100, window.Y);
    }

    [Fact]
    public void AWindowIsGivenItsMaximumToo()
    {
        StateUIWindow window = Window(Tree("""
            "maximumWidth":1600,"maximumHeight":1200
            """));

        Assert.Equal(1600, window.MaximumWidth);
        Assert.Equal(1200, window.MaximumHeight);
    }

    /// <summary>
    /// The two controls the window's own chrome carries, which are a different
    /// question from the sizes: a window may be resizable and still refuse to
    /// go full-screen.
    /// </summary>
    [Fact]
    public void AWindowSaysWhichOfItsControlsWork()
    {
        StateUIWindow window = Window(Tree("""
            "isMaximizable":false,"isMinimizable":true
            """));

        Assert.False(window.IsMaximizable);
        Assert.True(window.IsMinimizable);
    }

    /// <summary>
    /// A property nobody wrote is not assigned, which is what leaves MAUI's own
    /// default standing. Writing every property with whatever it already holds
    /// would look harmless and is not: it turns an unset value into a set one.
    /// </summary>
    [Fact]
    public void AWindowKeepsWhateverMauiDefaultsToWhereSwiftSaidNothing()
    {
        var fresh = new Microsoft.Maui.Controls.Window();
        StateUIWindow window = Window(Tree("""
            "title":"Plain"
            """));

        Assert.Equal("Plain", window.Title);
        Assert.Equal(fresh.Width, window.Width);
        Assert.Equal(fresh.MinimumWidth, window.MinimumWidth);
        Assert.Equal(fresh.X, window.X);
    }

    /// <summary>
    /// The whole point of the patch protocol, at the window: a later message
    /// naming one property changes that one and leaves the rest of the window -
    /// and the page under it - exactly as they were.
    /// </summary>
    [Fact]
    public void ResizingTheWindowLeavesEverythingElseAlone()
    {
        StateUIWindow window = Window(Tree("""
            "title":"My Application","width":1200,"height":800
            """));

        Page? page = window.Page;

        Apply(window, """
            {"id":1,"type":"Window","props":{"width":1400}}
            """, complete: false);

        Assert.Equal(1400, window.Width);
        Assert.Equal(800, window.Height);
        Assert.Equal("My Application", window.Title);
        Assert.Same(page, window.Page);
    }

    // ---- The title bar -----------------------------------------------------

    /// <summary>A window carrying its own chrome beside the page.</summary>
    private const string TreeWithTitleBar = """
        {"id":1,"type":"Window","props":{"title":"App"},"arranged":true,"children":[
          {"id":2,"type":"ContentPage","arranged":true,"children":[
            {"id":3,"type":"Label","props":{"text":"one"}}]},
          {"id":4,"type":"TitleBar","props":{"title":"App","subtitle":"Home"},"arranged":true,"children":[
            {"id":5,"type":"TrailingContent","arranged":true,"children":[
              {"id":6,"type":"Button","props":{"text":"act"}}]}]}]}
        """;

    [Fact]
    public void AWindowShowsTheTitleBarTheTreeCarries()
    {
        StateUIWindow window = Window(TreeWithTitleBar);

        var bar = Assert.IsType<TitleBar>(window.TitleBar);
        Assert.Equal("App", bar.Title);
        Assert.Equal("Home", bar.Subtitle);
        Assert.Equal("act", Assert.IsType<Button>(bar.TrailingContent).Text);

        // What makes the button press rather than drag the window.
        Assert.Contains(bar.TrailingContent, bar.PassthroughElements);
    }

    /// <summary>
    /// A patch naming only the bar reaches the SAME bar - the sample types a
    /// subtitle on every keystroke, and a bar rebuilt each time would flicker.
    /// </summary>
    [Fact]
    public void APatchAboutTheTitleBarAloneReachesIt()
    {
        StateUIWindow window = Window(TreeWithTitleBar);
        var bar = Assert.IsType<TitleBar>(window.TitleBar);
        Page? page = window.Page;

        Apply(window, """
            {"id":1,"type":"Window","children":[
              {"id":4,"type":"TitleBar","props":{"subtitle":"Media"}}]}
            """, complete: false);

        Assert.Same(bar, window.TitleBar);
        Assert.Equal("Media", bar.Subtitle);
        Assert.Equal("App", bar.Title);
        Assert.Same(page, window.Page);
    }

    /// <summary>
    /// A slot that leaves is a WRAPPER the arranged list no longer names,
    /// and the view it held has to leave the chrome - the gallery's sample
    /// toggles its trailing button off, and a button with nothing behind it
    /// would stay drawn.
    /// </summary>
    [Fact]
    public void ASlotThatLeavesTheBarLeavesTheChrome()
    {
        StateUIWindow window = Window(TreeWithTitleBar);
        var bar = Assert.IsType<TitleBar>(window.TitleBar);
        Assert.NotNull(bar.TrailingContent);

        Apply(window, """
            {"id":1,"type":"Window","children":[
              {"id":4,"type":"TitleBar","arranged":true,"children":[]}]}
            """, complete: false);

        Assert.Same(bar, window.TitleBar);
        Assert.Null(bar.TrailingContent);
        Assert.Empty(bar.PassthroughElements);
    }

    /// <summary>
    /// A slot is recognized BY TYPE, never by its wrapper's key: the key is
    /// positional identity, so a sibling slot appearing and leaving shifts
    /// it - matched by key, the leading slot's leaving nulled the TRAILING
    /// slot and left the leading view standing in the chrome, dead, its
    /// handler gone with the node.
    /// </summary>
    [Fact]
    public void ASlotLeavingBesideASurvivorEmptiesTheRightOne()
    {
        StateUIWindow window = Window(TreeWithTitleBar);
        var bar = Assert.IsType<TitleBar>(window.TitleBar);

        // The leading slot arrives, and the trailing wrapper's positional key
        // shifts under it.
        Apply(window, """
            {"id":1,"type":"Window","children":[
              {"id":4,"type":"TitleBar","arranged":true,"children":[
                {"id":10,"type":"LeadingContent","arranged":true,"children":[
                  {"id":11,"type":"Button","props":{"text":"menu"}}]},
                {"id":12,"type":"TrailingContent","arranged":true,"children":[
                  {"id":13,"type":"Button","props":{"text":"act"}}]}]}]}
            """, complete: false);

        Assert.NotNull(bar.LeadingContent);
        Assert.NotNull(bar.TrailingContent);

        // The leading slot leaves, and the trailing key shifts once more.
        Apply(window, """
            {"id":1,"type":"Window","children":[
              {"id":4,"type":"TitleBar","arranged":true,"children":[
                {"id":14,"type":"TrailingContent","arranged":true,"children":[
                  {"id":15,"type":"Button","props":{"text":"act"}}]}]}]}
            """, complete: false);

        Assert.Null(bar.LeadingContent);
        Assert.NotNull(bar.TrailingContent);
    }

    /// <summary>
    /// A bar written under an `if` that turned false leaves the window, not
    /// just the tree - the one window child that can go.
    /// </summary>
    [Fact]
    public void ATitleBarThatLeavesTheTreeLeavesTheWindow()
    {
        StateUIWindow window = Window(TreeWithTitleBar);
        Assert.NotNull(window.TitleBar);

        Apply(window, """
            {"id":1,"type":"Window","arranged":true,"children":[
              {"id":2,"type":"ContentPage"}]}
            """, complete: false);

        Assert.Null(window.TitleBar);
    }

    // ---- The embedded host -------------------------------------------------

    /// <summary>
    /// A host is a view inside somebody else's page, so it reaches the window by
    /// walking up - and there is nothing above it until it is placed. What
    /// arrived has to wait, and then be applied in full.
    /// </summary>
    [Fact]
    public void AHostAppliesTheWindowOnceItIsInOne()
    {
        var host = new StateUIHost();
        var window = new Microsoft.Maui.Controls.Window();

        ((IStateUITarget)host).Apply(Host.Parse(Host.Application(Tree("""
            "title":"Embedded","width":1200,"minimumWidth":600
            """))), complete: true);

        // Nothing to write to yet: the host has no parent.
        Assert.Null(window.Title);

        window.Page = new ContentPage { Content = host };

        Assert.Equal("Embedded", window.Title);
        Assert.Equal(1200, window.Width);
        Assert.Equal(600, window.MinimumWidth);
    }

    /// <summary>
    /// And a patch arriving before it is placed cannot lose what the first
    /// message said: a message carries only what changed, so the properties
    /// accumulate until there is a window to put them on.
    /// </summary>
    [Fact]
    public void AHostKeepsWhatEarlierMessagesSaidUntilThereIsAWindow()
    {
        var host = new StateUIHost();
        var window = new Microsoft.Maui.Controls.Window();

        ((IStateUITarget)host).Apply(Host.Parse(Host.Application(Tree("""
            "title":"Embedded","width":1200
            """))), complete: true);

        ((IStateUITarget)host).Apply(
            Host.Parse(Host.Application("""{"id":1,"type":"Window","props":{"title":"Renamed"}}""")),
            complete: false);

        window.Page = new ContentPage { Content = host };

        Assert.Equal("Renamed", window.Title);
        Assert.Equal(1200, window.Width);
    }

    /// <summary>
    /// A page property reaches the page ABOVE an embedded host, the way the
    /// title does - and waits for it the same way.
    /// </summary>
    /// <remarks>
    /// MAUI declares HideSoftInputOnTapped on ContentPage rather than on Page,
    /// so this walks to a narrower ancestor than the title does. Without it a
    /// hosted app asking for tap-to-dismiss would get silence, which is the one
    /// failure this boundary cannot see: an unrecognized property is ignored.
    /// </remarks>
    [Fact]
    public void AHostedPagesKeyboardPropertyReachesTheRealPage()
    {
        var host = new StateUIHost();
        var page = new ContentPage();

        ((IStateUITarget)host).Apply(
            Host.Parse(Host.Application("""
                {"id":1,"type":"Window","arranged":true,"children":[
                  {"id":2,"type":"ContentPage","props":{"hideSoftInputOnTapped":true},"arranged":true,
                   "children":[{"id":3,"type":"Label","props":{"text":"one"}}]}]}
                """)),
            complete: true);

        Assert.False(page.HideSoftInputOnTapped, "nothing to write to before the host is placed");

        page.Content = host;

        Assert.True(page.HideSoftInputOnTapped);
    }

    // ---- Lifecycle ---------------------------------------------------------

    /// <summary>
    /// The fixture the Swift side writes for a window with all six lifecycle
    /// handlers: applying it leaves the handler ids ON the window, which is
    /// what its events report with.
    /// </summary>
    [Fact]
    public void TheWindowNodeCarriesItsHandlersToTheWindow()
    {
        // The whole message, applied where a message is applied: the fixture is
        // rooted in the Application, and the window it describes is one this
        // side opens for it.
        var application = new StateUIApplication();
        ((IStateUITarget)application).Apply(
            Host.Parse(Fixtures.ReadBytes("window-lifecycle.bin")), true);

        StateUIWindow window = Assert.Single(application.Windows);
        IReadOnlyDictionary<SwiftEvent, int>? events = StateUIRenderer.EventsOf(window);

        Assert.NotNull(events);
        Assert.Equal(
            new[]
            {
                SwiftEvent.Activated, SwiftEvent.Created, SwiftEvent.Deactivated,
                SwiftEvent.Destroying, SwiftEvent.Resumed, SwiftEvent.Stopped,
            },
            events!.Keys.OrderBy(name => name.ToString(), StringComparer.Ordinal));
    }

    /// <summary>
    /// The lifecycle raised the way the platform raises it - through
    /// <see cref="IWindow"/>, which is public and is how a headless test can
    /// raise it at all, measured - reports each event with the handler id the
    /// node named, in the order it happened.
    /// </summary>
    [Fact]
    public void AWindowEventReportsWithTheHandlerTheNodeNamed()
    {
        var host = new Host();
        var window = new Window();

        host.Renderer.WireWindow(window);
        host.Renderer.Track(window, Host.Parse("""
            {"id":1,"type":"Window","events":{
              "created":11,"activated":12,"deactivated":13,
              "stopped":14,"resumed":15,"destroying":16}}
            """));

        IWindow raised = window;
        raised.Created();
        raised.Activated();
        raised.Deactivated();
        raised.Stopped();
        raised.Resumed();
        raised.Destroying();

        Assert.Equal(
            new[] { 11, 12, 13, 14, 15, 16 },
            host.Dispatched.Select(dispatched => dispatched.Id));
    }

    /// <summary>
    /// A window coming back reads the ZONE again, rather than trusting the one
    /// .NET cached at startup.
    /// </summary>
    /// <remarks>
    /// The locale is the one standard provider no platform raises a change
    /// event for, so resuming is when it is looked at - the reader has had the
    /// whole time in the background to cross a border or turn the clock over.
    /// <see cref="TimeZoneInfo.Local"/> is held in a static from its first
    /// read, which is what makes the clearing the observable half: the zone
    /// answered after a resume is a fresh object, so a zone that MOVED would
    /// now be seen. Nothing else here can see a native push.
    /// </remarks>
    [Fact]
    public void AWindowComingBackReadsTheZoneAgain()
    {
        var host = new Host();
        var window = new Window();

        host.Renderer.WireWindow(window);

        TimeZoneInfo before = TimeZoneInfo.Local;
        Assert.Same(before, TimeZoneInfo.Local);

        ((IWindow)window).Resumed();

        Assert.NotSame(before, TimeZoneInfo.Local);
    }

    /// <summary>
    /// And nothing else in the lifecycle does: a window merely losing and
    /// regaining the keyboard re-reads nothing, the zone being a thing that
    /// moves while the app is AWAY.
    /// </summary>
    [Fact]
    public void ActivationAloneDoesNotReadTheZoneAgain()
    {
        var host = new Host();
        var window = new Window();

        host.Renderer.WireWindow(window);

        TimeZoneInfo before = TimeZoneInfo.Local;

        ((IWindow)window).Activated();
        ((IWindow)window).Deactivated();

        Assert.Same(before, TimeZoneInfo.Local);
    }

    /// <summary>
    /// A window whose tree says nothing about its lifetime reports nothing:
    /// the subscription is unconditional, and <c>Raise</c> finds no id to
    /// quote.
    /// </summary>
    [Fact]
    public void AWindowNobodyListensToReportsNothing()
    {
        var host = new Host();
        var window = new Window();

        host.Renderer.WireWindow(window);

        IWindow raised = window;
        raised.Created();
        raised.Stopped();

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// A sparse patch naming a child this side does not have is REFUSED, which
    /// is what the session turns into a whole-tree resync.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A new child always arrives in an ARRANGED list, so a sparse message
    /// about an identity nobody here holds means the two sides have lost their
    /// common baseline. Taking the control in anyway would leave a tree that
    /// differs from the one the next patch is computed against, permanently
    /// and silently.
    /// </para>
    /// <para>
    /// Refusing rather than THROWING an <see cref="InvalidDataException"/> is
    /// the whole point: the session reads that exception as a malformed
    /// message and gives up on the interface, while a refusal drops the
    /// generation and asks Swift for everything - the recovery this condition
    /// has always wanted. Drift is a correct message read against the wrong
    /// baseline, which is not the same failure as bad bytes.
    /// </para>
    /// </remarks>
    [Fact]
    public void ASparsePatchNamingAChildThisSideLacksIsRefusedRatherThanFatal()
    {
        // Applied where a message is applied - the boundary the session calls,
        // and therefore the boundary that has to answer for this.
        var target = (IStateUITarget)new StateUIApplication();

        Assert.True(target.Apply(Host.Parse(Host.Application("""
            {"id":1,"type":"Window","arranged":true,"children":[
              {"id":2,"type":"ContentPage","arranged":true,"children":[
                {"id":3,"type":"VerticalStackLayout","arranged":true,"children":[
                  {"id":4,"type":"Label","props":{"text":"one"}}]}]}]}
            """)), true));

        // Sparse - no `arranged` anywhere - and it names a label that was
        // never described. Only a side that had lost the tree could be sent
        // this.
        bool applied = target.Apply(Host.Parse(Host.Application("""
            {"id":1,"type":"Window","children":[
              {"id":2,"type":"ContentPage","children":[
                {"id":3,"type":"VerticalStackLayout","children":[
                  {"id":9,"type":"Label","props":{"text":"ghost"}}]}]}]}
            """)), false);

        Assert.False(applied, "refused, which is what the session turns into a whole-tree resync");
    }

    /// <summary>
    /// Drift is not malformed bytes, and nothing may quietly make it so.
    /// </summary>
    /// <remarks>
    /// The target above turns drift into a refusal, so the session normally
    /// never sees the exception at all. What this pins is the escape route:
    /// drift raised somewhere no target wraps falls into the session's general
    /// catch, which retries. Deriving this from
    /// <see cref="InvalidDataException"/> - tempting, both being about data -
    /// would put it in the catch above that one instead, where the session says
    /// "the tree could not be read" and stops. The recoverable case would be
    /// fatal again, and every other test here would still pass.
    /// </remarks>
    [Fact]
    public void DriftIsNotReadAsMalformedBytes()
    {
        Assert.IsNotAssignableFrom<InvalidDataException>(new SwiftTreeDriftException("drifted"));
    }
}
