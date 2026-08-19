// The tabs, as the renderer builds them.
//
// Swift describes the tabs as an ARRANGED children list and which of them is
// showing as an index into it. Nothing here is asynchronous - a TabbedPage's
// children are an ordinary list and its current page an ordinary property - so
// what Swift described is reached within the message, unlike a navigation
// stack, which is settled towards afterwards.
//
// What Swift puts on the wire is next door, in the Swift TabbedPageTests.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class TabbedPageTests
{
    /// <summary>A page renderer whose failures fail the test.</summary>
    private static (SwiftPages Pages, Host Host) Renderer()
    {
        var host = new Host();
        var pages = new SwiftPages(
            host.Renderer,
            (message, exception) => Assert.Fail($"{message}\n{exception}"));

        return (pages, host);
    }

    /// <summary>One tab's page, as Swift writes it - identified by its tab.</summary>
    private static string TabAt(string tab, string title) =>
        $"{{\"id\":\"{tab}\",\"type\":\"ContentPage\","
        + $"\"props\":{{\"title\":\"{title}\",\"iconImageSource\":\"{tab}.png\"}},"
        + $"\"arranged\":true,\"children\":"
        + $"[{{\"id\":1,\"type\":\"Label\",\"props\":{{\"text\":\"{title}\"}}}}]}}";

    /// <summary>A TabbedPage over the tabs named, with one of them showing.</summary>
    private static string Bar(int? current, params string[] tabs)
    {
        string selection = current is int index ? $"\"props\":{{\"currentPage\":{index}}}," : "";

        return "{\"id\":1,\"type\":\"TabbedPage\",\"events\":{\"currentPageChanged\":9},"
            + selection
            + $"\"arranged\":true,\"children\":[{string.Join(",", tabs)}]}}";
    }

    /// <summary>The captions the tab bar is showing, in order.</summary>
    private static string[] Showing(TabbedPage tabbed) =>
        [.. tabbed.Children.Select(page => page.Title ?? "")];

    // ---- What an arrangement does ------------------------------------------

    /// <summary>The tabs ARE the children, in the order Swift described.</summary>
    [Fact]
    public void TheTabsAreTheChildren()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        Assert.Equal(["Home", "Browse"], Showing(tabbed));
        Assert.Equal("Home", tabbed.CurrentPage.Title);
    }

    /// <summary>A tab's picture is its page's, which is where MAUI reads it.</summary>
    [Fact]
    public void ATabsIconIsItsPages()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home")))));

        Assert.Equal("home.png", (tabbed.Children[0].IconImageSource as FileImageSource)?.File);
    }

    /// <summary>Which tab is showing is the index Swift sent, and nothing else.</summary>
    [Fact]
    public void TheSelectionIsTheIndexSwiftSent()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(2, TabAt("home", "Home"), TabAt("browse", "Browse"), TabAt("settings", "Settings")))));

        Assert.Equal("Settings", tabbed.CurrentPage.Title);
    }

    /// <summary>
    /// A later message that moves the selection moves it, and says nothing about
    /// the arrangement because nothing was rearranged.
    /// </summary>
    [Fact]
    public void ALaterPatchMovesTheSelection()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        pages.Render(tabbed, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"props\":{\"currentPage\":1}}"));

        Assert.Equal("Browse", tabbed.CurrentPage.Title);
        Assert.Equal(["Home", "Browse"], Showing(tabbed));
    }

    /// <summary>
    /// Reordering the tabs reorders the children and keeps the pages - which is
    /// what identifying a tab by its VALUE rather than its position buys.
    /// </summary>
    [Fact]
    public void ReorderingKeepsThePages()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        Page home = tabbed.Children[0];

        pages.Render(tabbed, Host.Parse(
            Bar(1, TabAt("browse", "Browse"), TabAt("home", "Home"))));

        Assert.Equal(["Browse", "Home"], Showing(tabbed));
        Assert.Same(home, tabbed.Children[1]);
        Assert.Equal("Home", tabbed.CurrentPage.Title);
    }

    /// <summary>
    /// A reorder AROUND the showing tab keeps it showing, though the message
    /// says nothing about the selection.
    /// </summary>
    /// <remarks>
    /// The differ sends a property only when its VALUE changed, so a tab that
    /// keeps its index across a reorder is described with no
    /// <c>currentPage</c> at all - and the tab bar is nonetheless rebuilt
    /// underneath it. MAUI's own <c>MultiPage.OnChildrenChanged</c> moves
    /// <c>CurrentPage</c> to <c>Children[0]</c> the moment the showing page
    /// leaves the collection, which the arranging loop does to every page it
    /// has to move.
    /// </remarks>
    [Fact]
    public void AReorderAroundTheShowingTabKeepsIt()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(1, TabAt("home", "Home"), TabAt("browse", "Browse"), TabAt("saved", "Saved")))));

        Assert.Equal("Browse", tabbed.CurrentPage.Title);

        // The ends swap and Browse stays second: its index is 1 both times, so
        // no selection is sent.
        pages.Render(tabbed, Host.Parse(
            Bar(null, TabAt("saved", "Saved"), TabAt("browse", "Browse"), TabAt("home", "Home"))));

        Assert.Equal(["Saved", "Browse", "Home"], Showing(tabbed));
        Assert.Equal("Browse", tabbed.CurrentPage.Title);
    }

    /// <summary>
    /// A tab inserted BEFORE the showing one moves it along, and the tab that
    /// was showing is still the tab showing.
    /// </summary>
    [Fact]
    public void ATabInsertedBeforeTheShowingOneMovesItAlong()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(1, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        // Swift's own index moved with it, so this message carries one.
        pages.Render(tabbed, Host.Parse(
            Bar(2, TabAt("saved", "Saved"), TabAt("home", "Home"), TabAt("browse", "Browse"))));

        Assert.Equal(["Saved", "Home", "Browse"], Showing(tabbed));
        Assert.Equal("Browse", tabbed.CurrentPage.Title);
    }

    /// <summary>A tab described away leaves the tab bar.</summary>
    [Fact]
    public void ATabDescribedAwayGoes()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        pages.Render(tabbed, Host.Parse(Bar(0, TabAt("home", "Home"))));

        Assert.Equal(["Home"], Showing(tabbed));
    }

    /// <summary>
    /// A page REBUILT under an unchanged identity - which is what
    /// <c>replace</c> means - is swapped into the tab bar, not merely into the
    /// page map. The stack had this defect and it was invisible to every test
    /// until one was written for it.
    /// </summary>
    [Fact]
    public void ARebuiltTabIsSwappedIntoTheBar()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        Page first = tabbed.Children[0];

        pages.Render(tabbed, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"children\":["
            + "{\"id\":\"home\",\"type\":\"ContentPage\",\"replace\":true,"
            + "\"props\":{\"title\":\"Fresh\"},\"children\":["
            + "{\"id\":1,\"type\":\"Label\",\"props\":{\"text\":\"fresh\"}}]}]}"));

        Assert.Equal(["Fresh", "Browse"], Showing(tabbed));
        Assert.NotSame(first, tabbed.Children[0]);
    }

    /// <summary>
    /// Two tab bars in one application keep their own pages, even where both
    /// name a tab the same - identity is unique among SIBLINGS, not in the tree.
    /// </summary>
    [Fact]
    public void TwoTabBarsDoNotShareAPage()
    {
        (SwiftPages pages, _) = Renderer();

        string outer =
            "{\"id\":1,\"type\":\"TabbedPage\",\"arranged\":true,\"children\":["
            + TabAt("home", "Outer home") + ","
            + "{\"id\":\"nested\",\"type\":\"TabbedPage\",\"arranged\":true,\"children\":["
            + TabAt("home", "Inner home") + "]}]}";

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(outer)));
        var inner = Assert.IsType<TabbedPage>(tabbed.Children[1]);

        Assert.Equal(["Inner home"], Showing(inner));
        Assert.NotSame(tabbed.Children[0], inner.Children[0]);
    }

    /// <summary>
    /// The ordinary shape of a tabbed application: each tab holds a navigation
    /// stack, and the CAPTION is the stack's own - which is why a constructed
    /// page can be given one at all.
    /// </summary>
    [Fact]
    public void ATabCanHoldAWholeStack()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"arranged\":true,\"children\":["
            + "{\"id\":\"home\",\"type\":\"NavigationPage\",\"arranged\":true,"
            + "\"props\":{\"title\":\"Home\",\"iconImageSource\":\"house.png\"},"
            + "\"children\":[" + TabAt("root", "Root") + "]}]}")));

        var stack = Assert.IsType<NavigationPage>(tabbed.Children[0]);

        Assert.Equal("Home", stack.Title);
        Assert.Equal("house.png", (stack.IconImageSource as FileImageSource)?.File);
        Assert.Equal("Root", stack.Navigation.NavigationStack[0].Title);
    }

    /// <summary>
    /// A tab bar with nothing in it builds - MAUI's own TabbedPage is empty
    /// until something is put in it, so an application whose tabs are loaded
    /// has somewhere to start.
    /// </summary>
    [Fact]
    public void AnEmptyTabBarIsLegal()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"arranged\":true,\"children\":[]}")));

        Assert.Empty(tabbed.Children);
    }

    /// <summary>
    /// And the last tab can go too - a tab bar whose tabs are data can be
    /// emptied, which is the boundary MAUI is least likely to have been asked
    /// about.
    /// </summary>
    [Fact]
    public void TheLastTabCanGo()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home")))));

        pages.Render(tabbed, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"arranged\":true,\"children\":[]}"));

        Assert.Empty(tabbed.Children);
    }

    /// <summary>A child that is not a page is REPORTED rather than dropped.</summary>
    [Fact]
    public void AChildThatIsNotAPageIsReported()
    {
        var host = new Host();
        List<string> failures = [];
        var pages = new SwiftPages(host.Renderer, (message, _) => failures.Add(message));

        pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"arranged\":true,\"children\":["
            + TabAt("home", "Home") + ","
            + "{\"id\":2,\"type\":\"Label\",\"props\":{\"text\":\"not a page\"}}]}"));

        Assert.Contains(failures, message => message.Contains("Label"));
    }

    // ---- The bar ------------------------------------------------------------

    /// <summary>
    /// The bar's three, plus the two only a tab bar has - repainted by a later
    /// message, which is what lets a theme change reach them.
    /// </summary>
    [Fact]
    public void ALaterPatchRepaintsTheBar()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"arranged\":true,"
            + "\"props\":{\"barBackgroundColor\":\"#512BD4\",\"barTextColor\":\"#FFFFFF\","
            + "\"selectedTabColor\":\"#FFFFFF\",\"unselectedTabColor\":\"#B0A6E0\"},"
            + "\"children\":[" + TabAt("home", "Home") + "]}")));

        Assert.Equal(Color.FromArgb("#512BD4"), tabbed.BarBackgroundColor);
        Assert.Equal(Colors.White, tabbed.BarTextColor);
        Assert.Equal(Colors.White, tabbed.SelectedTabColor);
        Assert.Equal(Color.FromArgb("#B0A6E0"), tabbed.UnselectedTabColor);

        pages.Render(tabbed, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"props\":{\"barBackgroundColor\":\"#FF0000\"}}"));

        Assert.Equal(Colors.Red, tabbed.BarBackgroundColor);
    }

    /// <summary>A bar painted with a BRUSH, which is the gradient case.</summary>
    [Fact]
    public void TheBarCanBeABrush()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"arranged\":true,"
            + "\"props\":{\"barBackground\":["
            + Host.Member(SwiftBrushKind.LinearGradient)
            + ",[0,0,0,1],0,\"#000000\",1,\"#FFFFFF\"]},"
            + "\"children\":[" + TabAt("home", "Home") + "]}")));

        Assert.Equal(2, Assert.IsType<LinearGradientBrush>(tabbed.BarBackground).GradientStops.Count);
    }

    // ---- What the renderer forgets ------------------------------------------

    /// <summary>Forgetting drops the tab bar, so the next message builds again.</summary>
    [Fact]
    public void ForgettingBuildsTheTabsAgain()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home")))));

        pages.Forget();

        var again = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home")))));

        Assert.NotSame(tabbed, again);
    }

    // ---- The fixture, which is the contract --------------------------------

    /// <summary>
    /// The bytes the Swift tests wrote, applied here: a tab bar with its
    /// colours, a tab holding a whole navigation stack that carries its own
    /// caption, and a plain page beside it - with the second one showing.
    /// </summary>
    [Fact]
    public void TheFixtureBuildsTheWholeTabBar()
    {
        (SwiftPages pages, _) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(
            pages.Render(null, Host.Parse(Fixtures.ReadBytes("pages/TabbedPage.bin"))));

        Assert.Equal(["Home", "settings"], Showing(tabbed));
        Assert.Equal("settings", tabbed.CurrentPage.Title);

        // All five of the bar's colours, each said in the fixture.
        Assert.Equal(Color.FromArgb("#512BD4"), tabbed.BarBackgroundColor);
        Assert.Equal(Colors.White, tabbed.BarTextColor);
        Assert.Equal(Colors.White, tabbed.SelectedTabColor);
        Assert.Equal(Color.FromArgb("#B0A6E0"), tabbed.UnselectedTabColor);

        // The first tab is a stack, named by modifier; the second a page,
        // named by its own property. Both arrive as the same two keys.
        var stack = Assert.IsType<NavigationPage>(tabbed.Children[0]);

        Assert.Equal("house.png", (stack.IconImageSource as FileImageSource)?.File);
        Assert.Equal("home", stack.Navigation.NavigationStack[0].Title);
        Assert.Equal("settings.png", (tabbed.Children[1].IconImageSource as FileImageSource)?.File);
    }

    // ---- The selection protocol ---------------------------------------------

    /// <summary>
    /// The reader choosing a tab is reported as the INDEX that is now showing,
    /// so the bound selection can be written to match.
    /// </summary>
    [Fact]
    public void TheReaderChoosingATabIsReported()
    {
        (SwiftPages pages, Host host) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        host.Dispatched.Clear();

        // What a finger does, in the one way a headless test can do it.
        tabbed.CurrentPage = tabbed.Children[1];

        Assert.Equal([(9, "1")], host.Dispatched);
    }

    /// <summary>
    /// And a selection THIS side made says nothing: Swift asked for it, so
    /// telling Swift about it would be an echo - and an echo is a render nobody
    /// asked for.
    /// </summary>
    [Fact]
    public void ASelectionSwiftAskedForIsNotReportedBack()
    {
        (SwiftPages pages, Host host) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        host.Dispatched.Clear();

        pages.Render(tabbed, Host.Parse(
            "{\"id\":1,\"type\":\"TabbedPage\",\"props\":{\"currentPage\":1}}"));

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// Building the tab bar says nothing either, even though MAUI picks a
    /// current page the moment the first child arrives.
    /// </summary>
    [Fact]
    public void BuildingTheTabsSaysNothing()
    {
        (SwiftPages pages, Host host) = Renderer();

        pages.Render(null, Host.Parse(
            Bar(1, TabAt("home", "Home"), TabAt("browse", "Browse"))));

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// The tab that was showing is described AWAY: the platform moves to
    /// another, and that is reported - otherwise the bound selection would name
    /// a tab that no longer exists and nothing would ever correct it.
    /// </summary>
    /// <remarks>
    /// Applied inside the scope the WINDOW holds over a whole message, which is
    /// the whole point of this test: reporting is suppressed for the length of
    /// an apply so that Swift never hears its own writes back, and a report
    /// made there would be swallowed. Measured - this test passed without the
    /// scope while a device would have said nothing. What arrives, arrives a
    /// turn later, which is why the dispatcher is held and then drained.
    /// </remarks>
    [Fact]
    public void LosingTheShowingTabIsReportedAfterTheMessage()
    {
        (SwiftPages pages, Host host) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(1, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        Assert.Equal("Browse", tabbed.CurrentPage.Title);

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        // Swift says nothing about the selection here - its own selection named
        // the tab that is going away, so it had no index to send.
        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            pages.Render(tabbed, Host.Parse(Bar(null, TabAt("home", "Home"))));
        }

        Assert.Equal("Home", tabbed.CurrentPage.Title);
        Assert.Empty(host.Dispatched);

        TestDispatcher.Drain();

        Assert.Equal([(9, "0")], host.Dispatched);
    }

    /// <summary>
    /// And the tabs Swift itself moved say nothing a turn later either - the
    /// deferral above must not turn every message into a report.
    /// </summary>
    [Fact]
    public void ASelectionSwiftAskedForSaysNothingATurnLaterEither()
    {
        (SwiftPages pages, Host host) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(0, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            pages.Render(tabbed, Host.Parse(
                "{\"id\":1,\"type\":\"TabbedPage\",\"props\":{\"currentPage\":1}}"));
        }

        TestDispatcher.Drain();

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// And an index Swift sends that no tab answers to is not obeyed blindly:
    /// the first tab shows and Swift is told, rather than the tab bar being
    /// left showing nothing.
    /// </summary>
    [Fact]
    public void AnIndexOutsideTheTabsFallsBackToTheFirst()
    {
        (SwiftPages pages, Host host) = Renderer();

        var tabbed = Assert.IsType<TabbedPage>(pages.Render(null, Host.Parse(
            Bar(5, TabAt("home", "Home"), TabAt("browse", "Browse")))));

        Assert.Equal("Home", tabbed.CurrentPage.Title);
        Assert.Empty(host.Dispatched);
    }
}
