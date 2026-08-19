// The navigation stack, as the renderer builds it.
//
// Swift describes the whole stack - the root and one page per route, as an
// ARRANGED children list - and this side brings MAUI's NavigationPage to it.
// There is no push command and no pop command on the wire: the arrangement is
// the instruction, and the only thing that travels the other way is a pop the
// reader completed.
//
// What Swift puts on the wire is next door, in the Swift NavigationPageTests.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class NavigationPageTests
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

    /// <summary>One page of the stack, as Swift writes it.</summary>
    private static string PageAt(int id, string title) =>
        $"{{\"id\":{id},\"type\":\"ContentPage\",\"props\":{{\"title\":\"{title}\"}},"
        + $"\"arranged\":true,\"children\":"
        + $"[{{\"id\":{id + 100},\"type\":\"Label\",\"props\":{{\"text\":\"{title}\"}}}}]}}";

    /// <summary>A NavigationPage over the pages named, root first.</summary>
    private static string Stack(params string[] pages) =>
        "{\"id\":1,\"type\":\"NavigationPage\",\"events\":{\"popped\":7},"
        + $"\"arranged\":true,\"children\":[{string.Join(",", pages)}]}}";

    /// <summary>The titles the native stack is showing, bottom first.</summary>
    private static string[] Showing(NavigationPage navigation) =>
        [.. navigation.Navigation.NavigationStack.Select(page => page.Title ?? "")];

    // ---- What an arrangement does ------------------------------------------

    [Fact]
    public void TheRootIsTheFirstChild()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home")))));

        Assert.Equal(["Home"], Showing(navigation));
    }

    /// <summary>
    /// The whole stack arrives at once on the first message, so an application
    /// restored three pages deep opens three pages deep.
    /// </summary>
    [Fact]
    public void AStackArrivesWholeAndIsBuiltWhole()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(
                Stack(PageAt(2, "Home"), PageAt(3, "Group"), PageAt(4, "Sample")))));

        Assert.Equal(["Home", "Group", "Sample"], Showing(navigation));
    }

    /// <summary>
    /// A longer arrangement is a push, and the pages that were already there
    /// are the SAME pages - which is what keeps their controls, their scroll
    /// offsets and their state.
    /// </summary>
    [Fact]
    public void ALongerArrangementPushesAndKeepsWhatWasThere()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home")))));

        Page home = navigation.Navigation.NavigationStack[0];

        pages.Render(navigation, Host.Parse(Stack(PageAt(2, "Home"), PageAt(3, "Detail"))));

        Assert.Equal(["Home", "Detail"], Showing(navigation));
        Assert.Same(home, navigation.Navigation.NavigationStack[0]);
    }

    /// <summary>A shorter arrangement is a pop, however many pages it drops.</summary>
    [Fact]
    public void AShorterArrangementPopsAsFarAsItSays()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(
                Stack(PageAt(2, "Home"), PageAt(3, "One"), PageAt(4, "Two")))));

        pages.Render(navigation, Host.Parse(Stack(PageAt(2, "Home"))));

        Assert.Equal(["Home"], Showing(navigation));
    }

    /// <summary>
    /// The page the reader is LOOKING AT is the one that leaves through the
    /// pop, however deep the jump - so the platform draws one transition, from
    /// what is on screen to what was asked for.
    /// </summary>
    /// <remarks>
    /// Measured on Catalyst 2026-08-14: removing the topmost page first - which
    /// MAUI does not support for the page that is showing - snapped to the page
    /// underneath and then animated away from THAT, so going home from a sample
    /// flashed the group page the reader had never asked for. The pages that go
    /// silently are the ones nobody can see going.
    /// </remarks>
    [Fact]
    public void ThePageTheReaderIsOnIsTheOneThatIsPopped()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(
                Stack(PageAt(2, "Home"), PageAt(3, "One"), PageAt(4, "Two")))));

        List<string?> seen = [];
        navigation.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(NavigationPage.CurrentPage))
            {
                seen.Add(navigation.CurrentPage?.Title);
            }
        };

        pages.Render(navigation, Host.Parse(Stack(PageAt(2, "Home"))));

        Assert.Equal(["Home"], Showing(navigation));
        // One move, and it is the page the reader was on going away: with the
        // visible page removed instead, "One" would appear here first.
        Assert.Equal(["Home"], seen);
    }

    /// <summary>
    /// A message that says nothing about the arrangement changes nothing about
    /// it - a patch that carries one page's new title is not a navigation.
    /// </summary>
    [Fact]
    public void APatchThatIsNotAnArrangementLeavesTheStackAlone()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home"), PageAt(3, "Detail")))));

        pages.Render(navigation, Host.Parse("""
            {"id":1,"type":"NavigationPage","children":[
              {"id":3,"type":"ContentPage","props":{"title":"Renamed"}}]}
            """));

        Assert.Equal(["Home", "Renamed"], Showing(navigation));
    }

    // ---- What a rebuilt page does to the stack ------------------------------

    /// <summary>
    /// A page REBUILT under an unchanged identity - which is what
    /// <c>replace</c> means, and what Swift sends when a page loses a property
    /// - is swapped onto the native stack, not merely into the page map.
    /// </summary>
    /// <remarks>
    /// MEASURED, and the reason the settle loop has a bottom-of-the-stack arm
    /// at all: MAUI refuses to pop a one-page stack, so a loop that tried to
    /// pop its way to a new root span the UI thread at 100% instead. Nothing
    /// failed - it hung.
    /// </remarks>
    [Fact]
    public void ARebuiltRootIsSwappedOntoTheStack()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home")))));

        Page first = navigation.Navigation.NavigationStack[0];

        pages.Render(navigation, Host.Parse(
            "{\"id\":1,\"type\":\"NavigationPage\",\"children\":["
            + "{\"id\":2,\"type\":\"ContentPage\",\"replace\":true,\"props\":{\"title\":\"Fresh\"},"
            + "\"children\":[{\"id\":102,\"type\":\"Label\",\"props\":{\"text\":\"fresh\"}}]}]}"));

        Assert.Equal(["Fresh"], Showing(navigation));
        Assert.NotSame(first, navigation.Navigation.NavigationStack[0]);
    }

    /// <summary>And the same for a page part-way up the stack.</summary>
    [Fact]
    public void ARebuiltPageOnTopIsSwappedOntoTheStack()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home"), PageAt(3, "Detail")))));

        Page detail = navigation.Navigation.NavigationStack[1];

        pages.Render(navigation, Host.Parse(
            "{\"id\":1,\"type\":\"NavigationPage\",\"children\":["
            + "{\"id\":3,\"type\":\"ContentPage\",\"replace\":true,\"props\":{\"title\":\"Rebuilt\"},"
            + "\"children\":[{\"id\":103,\"type\":\"Label\",\"props\":{\"text\":\"rebuilt\"}}]}]}"));

        Assert.Equal(["Home", "Rebuilt"], Showing(navigation));
        Assert.NotSame(detail, navigation.Navigation.NavigationStack[1]);
    }

    /// <summary>
    /// Two stacks in one application keep their own pages, even though both
    /// call their root by the same name.
    /// </summary>
    /// <remarks>
    /// Identity is unique among SIBLINGS, not in the tree: every
    /// <c>NavigationPage</c> identifies its root "root". One flat page map
    /// would hand the second stack the first one's root page - measured, when
    /// there was one.
    /// </remarks>
    [Fact]
    public void TwoStacksDoNotShareARootPage()
    {
        (SwiftPages pages, _) = Renderer();

        string outer =
            "{\"id\":1,\"type\":\"NavigationPage\",\"arranged\":true,\"children\":["
            + "{\"id\":2,\"type\":\"ContentPage\",\"props\":{\"title\":\"Outer home\"},\"arranged\":true,"
            + "\"children\":[{\"id\":102,\"type\":\"Label\",\"props\":{\"text\":\"outer\"}}]},"
            + "{\"id\":3,\"type\":\"NavigationPage\",\"arranged\":true,\"children\":["
            + "{\"id\":4,\"type\":\"ContentPage\",\"props\":{\"title\":\"Inner home\"},\"arranged\":true,"
            + "\"children\":[{\"id\":104,\"type\":\"Label\",\"props\":{\"text\":\"inner\"}}]}]}]}";

        var navigation = Assert.IsType<NavigationPage>(pages.Render(null, Host.Parse(outer)));

        Assert.Equal(2, navigation.Navigation.NavigationStack.Count);

        var inner = Assert.IsType<NavigationPage>(navigation.Navigation.NavigationStack[1]);

        Assert.Equal(["Inner home"], Showing(inner));
        Assert.NotSame(
            navigation.Navigation.NavigationStack[0], inner.Navigation.NavigationStack[0]);
    }

    /// <summary>
    /// A child that is not a page is REPORTED. Dropped silently, it would
    /// leave a stack shorter than the one Swift described and a settle loop
    /// with nothing to reach.
    /// </summary>
    [Fact]
    public void AChildThatIsNotAPageIsReported()
    {
        var host = new Host();
        List<string> failures = [];
        var pages = new SwiftPages(host.Renderer, (message, _) => failures.Add(message));

        pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"NavigationPage\",\"arranged\":true,\"children\":["
            + "{\"id\":2,\"type\":\"ContentPage\",\"props\":{\"title\":\"Home\"},\"arranged\":true,"
            + "\"children\":[{\"id\":102,\"type\":\"Label\",\"props\":{\"text\":\"home\"}}]},"
            + "{\"id\":3,\"type\":\"Label\",\"props\":{\"text\":\"not a page\"}}]}"));

        Assert.Contains(failures, message => message.Contains("Label"));
    }

    /// <summary>And a stack with nothing under it at all says so.</summary>
    [Fact]
    public void AStackWithNoPageUnderItIsReported()
    {
        var host = new Host();
        List<string> failures = [];
        var pages = new SwiftPages(host.Renderer, (message, _) => failures.Add(message));

        pages.Render(null, Host.Parse("{\"id\":1,\"type\":\"NavigationPage\"}"));

        Assert.Contains(failures, message => message.Contains("no page under it"));
    }

    // ---- The bar ------------------------------------------------------------

    /// <summary>
    /// The bar is repainted by a later message, which is what lets a theme
    /// change reach it: the properties arrive on a patch that says nothing
    /// about the arrangement.
    /// </summary>
    [Fact]
    public void ALaterPatchRepaintsTheBar()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(
                "{\"id\":1,\"type\":\"NavigationPage\",\"arranged\":true,"
                + "\"props\":{\"barBackgroundColor\":\"#512BD4\"},"
                + "\"children\":[" + PageAt(2, "Home") + "]}")));

        Assert.Equal(Color.FromArgb("#512BD4"), navigation.BarBackgroundColor);

        pages.Render(navigation, Host.Parse(
            "{\"id\":1,\"type\":\"NavigationPage\",\"props\":{\"barBackgroundColor\":\"#FF0000\"}}"));

        Assert.Equal(Colors.Red, navigation.BarBackgroundColor);
    }

    /// <summary>A bar painted with a BRUSH, which is the gradient case.</summary>
    [Fact]
    public void TheBarCanBeABrush()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(
                "{\"id\":1,\"type\":\"NavigationPage\",\"arranged\":true,"
                + "\"props\":{\"barBackground\":["
                + Host.Member(SwiftBrushKind.LinearGradient)
                + ",[0,0,0,1],0,\"#000000\",1,\"#FFFFFF\"]},"
                + "\"children\":[" + PageAt(2, "Home") + "]}")));

        var brush = Assert.IsType<LinearGradientBrush>(navigation.BarBackground);

        Assert.Equal(2, brush.GradientStops.Count);
    }

    // ---- What the renderer forgets ------------------------------------------

    /// <summary>
    /// Forgetting drops every page, so the message after it builds again -
    /// what a window does when the tree it was showing is replaced wholesale.
    /// </summary>
    [Fact]
    public void ForgettingBuildsThePagesAgain()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home")))));

        pages.Forget();

        var again = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home")))));

        Assert.NotSame(navigation, again);
    }

    // ---- The fixture, which is the contract --------------------------------

    /// <summary>
    /// The bytes the Swift tests wrote, applied here: the whole of what a
    /// NavigationPage can say, in one message, read by the code an application
    /// runs.
    /// </summary>
    /// <remarks>
    /// Under <c>fixtures/pages/</c> rather than <c>fixtures/controls/</c>: a
    /// fixture in <c>controls/</c> is walked by <see cref="StyleTests"/>, which
    /// insists every property in it can be set by a Style - and a page's cannot,
    /// there being no page arm in <c>SwiftStyles</c> at all.
    /// </remarks>
    [Fact]
    public void TheFixtureBuildsTheWholeStack()
    {
        (SwiftPages pages, _) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Fixtures.ReadBytes("pages/NavigationPage.bin"))));

        Assert.Equal(["Home", "one", "Level 2"], Showing(navigation));

        // The bar is the STACK's - all three of it.
        Assert.Equal(Color.FromArgb("#512BD4"), navigation.BarBackgroundColor);
        Assert.Equal(Colors.White, navigation.BarTextColor);
        Assert.Equal(2, Assert.IsType<LinearGradientBrush>(navigation.BarBackground).GradientStops.Count);

        // And what one page asks OF the stack is attached to that page. Every
        // one of these says the opposite of MAUI's own default, so an assert
        // that stopped being applied would fail rather than agree by accident.
        Page top = navigation.Navigation.NavigationStack[2];

        Assert.False(NavigationPage.GetHasNavigationBar(top));
        Assert.False(NavigationPage.GetHasBackButton(top));
        Assert.Equal("Up", NavigationPage.GetBackButtonTitle(top));
        Assert.Equal(Colors.White, NavigationPage.GetIconColor(top));
        Assert.Equal("mark.png", (NavigationPage.GetTitleIconImageSource(top) as FileImageSource)?.File);

        var titleView = Assert.IsType<Label>(NavigationPage.GetTitleView(top));
        Assert.Equal("on the bar", titleView.Text);

        // A page that asked for none of it is left alone, so MAUI's own
        // defaults stand rather than being overwritten with themselves.
        Page plain = navigation.Navigation.NavigationStack[1];

        Assert.True(NavigationPage.GetHasNavigationBar(plain));
        Assert.True(NavigationPage.GetHasBackButton(plain));
        Assert.Null(NavigationPage.GetTitleView(plain));
        Assert.Null(NavigationPage.GetIconColor(plain));
    }

    /// <summary>
    /// Every page fixture at least PARSES and builds a page here - the hole
    /// from the other end, where a message the Swift side writes reaches
    /// nothing on this one.
    /// </summary>
    /// <remarks>
    /// A walk rather than a list of names, deliberately: a hardcoded list
    /// proves a file is spelled somewhere, not that anything read its bytes.
    /// </remarks>
    [Fact]
    public void EveryPageFixtureBuildsAPage()
    {
        string[] files = Directory.GetFiles(Path.Combine(Fixtures.Directory, "pages"), "*.bin");

        Assert.NotEmpty(files);

        foreach (string file in files)
        {
            SwiftNode root = Host.Parse(File.ReadAllBytes(file));

            // A fixture rooted in a WINDOW describes something a page renderer
            // cannot be handed on its own: the modal stack hangs off the
            // window's navigation, not off any page. It goes through a real
            // window instead, which is what an application does with it.
            if (root.Type == SwiftNodeType.Window)
            {
                Assert.True(Host.Window().Apply(root, true));
                continue;
            }

            (SwiftPages pages, _) = Renderer();

            Assert.IsAssignableFrom<Page>(pages.Render(null, root));
        }
    }

    // ---- The pop protocol ---------------------------------------------------

    /// <summary>
    /// The reader's own way back - the arrow, a swipe, Android's gesture - is
    /// reported with the depth that SURVIVED, so Swift can truncate its path to
    /// what is actually on screen.
    /// </summary>
    /// <remarks>
    /// The depth counts the pages ABOVE the root, which is what the bound path
    /// holds: a stack showing the root alone is nought deep, and the root is
    /// not on the path at all.
    /// </remarks>
    [Fact]
    public async Task APopTheReaderMadeIsReported()
    {
        (SwiftPages pages, Host host) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home"), PageAt(3, "Detail")))));

        host.Dispatched.Clear();

        await navigation.Navigation.PopAsync(animated: false);

        Assert.Equal([(7, "0")], host.Dispatched);
    }

    /// <summary>
    /// And a pop THIS side performed says nothing: Swift asked for it, so
    /// telling Swift about it would be an echo - the guard the flyout's binding
    /// has always had, written here as a comparison rather than a flag because
    /// the pops finish after the message that asked for them.
    /// </summary>
    [Fact]
    public void APopSwiftAskedForIsNotReportedBack()
    {
        (SwiftPages pages, Host host) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home"), PageAt(3, "Detail")))));

        host.Dispatched.Clear();

        pages.Render(navigation, Host.Parse(Stack(PageAt(2, "Home"))));

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// A reader who goes several levels back at once ends on the root, and the
    /// last thing said is where they ended.
    /// </summary>
    /// <remarks>
    /// MEASURED: MAUI takes the pages off one at a time, so a multi-level pop
    /// raises a removal per page. Each of those is a depth the stack really was
    /// at, the reports only ever shorten the path, and the last one is the
    /// truth. Several arrive here because the test dispatcher runs a dispatched
    /// action at once; what a device does with the same removals is
    /// <see cref="AMultiLevelPopSaysOnlyTheDepthThatSurvived"/>.
    /// </remarks>
    [Fact]
    public async Task APopToTheRootEndsUpSayingZero()
    {
        (SwiftPages pages, Host host) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(
                Stack(PageAt(2, "Home"), PageAt(3, "One"), PageAt(4, "Two")))));

        host.Dispatched.Clear();

        await navigation.Navigation.PopToRootAsync(animated: false);

        Assert.Equal((7, "0"), host.Dispatched[^1]);
        Assert.All(host.Dispatched, report => Assert.Equal(7, report.Id));
    }

    // ---- And the turn the report waits ---------------------------------------

    /// <summary>
    /// The report is made a TURN after the pop, which is what every
    /// arrangement does.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Held and then drained, because with the dispatcher running inline - the
    /// default here - a deferred report and an inline one are the same thing
    /// and no test could tell them apart. That is why the whole suite passed
    /// unchanged when this moved.
    /// </para>
    /// <para>
    /// What the delay is FOR: raising it inline meant a whole Swift render ran
    /// from inside MAUI's own child-removal notification, the re-entrancy that
    /// crashed Android from inside a MAUI setter.
    /// </para>
    /// </remarks>
    [Fact]
    public async Task APopTheReaderMadeIsReportedATurnLater()
    {
        (SwiftPages pages, Host host) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home"), PageAt(3, "Detail")))));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        await navigation.Navigation.PopAsync(animated: false);

        // Read now, assert after draining: an assertion that throws BETWEEN
        // Hold and Drain leaves the dispatcher held for every test after this
        // one - it is a static with no per-test reset - and one failure would
        // become a whole class of them.
        int beforeTheTurn = host.Dispatched.Count;

        TestDispatcher.Drain();

        Assert.Equal(0, beforeTheTurn);
        Assert.Equal([(7, "0")], host.Dispatched);
    }

    /// <summary>
    /// And what Swift asked for says nothing a turn later either - the deferral
    /// must not turn every arrangement into a report.
    /// </summary>
    /// <remarks>
    /// This is the guard that survives the delay: <c>Desired</c> is written
    /// before the settle begins, so a settle that converged compares equal to
    /// it however late the report drains. <c>Settling</c> cannot do this job
    /// any more - it is false by the time a queued report runs - which is
    /// exactly the arrangement modals has always been in.
    /// </remarks>
    [Fact]
    public void APopSwiftAskedForIsNotReportedBackATurnLaterEither()
    {
        (SwiftPages pages, Host host) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home"), PageAt(3, "Detail")))));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            pages.Render(navigation, Host.Parse(Stack(PageAt(2, "Home"))));
        }

        TestDispatcher.Drain();

        Assert.Equal(["Home"], Showing(navigation));
        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// A back press that lands while a message is being applied is still
    /// reported, once the message is done with.
    /// </summary>
    /// <remarks>
    /// The bug the delay fixes, and the reason the rule is absolute:
    /// <see cref="StateUIRenderer.Raise(object?, string, byte[])"/> DROPS a
    /// report made from inside an apply - rendering there is a resync - while
    /// <c>Report</c> has by then written down that Swift was told. Raised
    /// inline, this press was swallowed and the stack's <c>Desired</c> left
    /// saying a depth Swift had never heard of, so nothing would ever correct
    /// it. A turn later there is nothing to swallow it.
    /// </remarks>
    [Fact]
    public async Task APopThatLandsInsideAMessageIsReportedAfterIt()
    {
        (SwiftPages pages, Host host) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(Stack(PageAt(2, "Home"), PageAt(3, "Detail")))));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            await navigation.Navigation.PopAsync(animated: false);
        }

        TestDispatcher.Drain();

        Assert.Equal([(7, "0")], host.Dispatched);
    }

    /// <summary>
    /// Several removals in one turn say one thing: the depth that survived.
    /// </summary>
    /// <remarks>
    /// What the deferral buys, beyond the re-entrancy it removes. A queued
    /// report reads the stack when it RUNS, not when it was queued, so both
    /// removals of a pop to the root off a three-page stack read nought - the
    /// first says so and writes <c>Desired</c>, the second compares equal and
    /// stays quiet. Inline, each was a separate report and a separate Swift
    /// render.
    /// </remarks>
    [Fact]
    public async Task AMultiLevelPopSaysOnlyTheDepthThatSurvived()
    {
        (SwiftPages pages, Host host) = Renderer();

        var navigation = Assert.IsType<NavigationPage>(
            pages.Render(null, Host.Parse(
                Stack(PageAt(2, "Home"), PageAt(3, "One"), PageAt(4, "Two")))));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        await navigation.Navigation.PopToRootAsync(animated: false);

        TestDispatcher.Drain();

        Assert.Equal([(7, "0")], host.Dispatched);
    }
}
