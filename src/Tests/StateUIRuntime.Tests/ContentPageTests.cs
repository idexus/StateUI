// A CONTENT PAGE, as the renderer builds it - and the two events it grew on
// 2026-08-15.
//
// A content page was the one page kind the renderer never TRACKED: it carried
// no handlers, so nothing had ever needed the RenderedElement that an event id
// is read from. Both halves are pinned here - the properties that arrive, and
// the handler ids the page must be carrying afterwards for its own events to
// report at all.
//
// What Swift puts on the wire is next door, in the Swift PageTests.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class ContentPageTests
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

    /// <summary>The page the Swift fixture describes, built.</summary>
    private static (ContentPage Page, Host Host) Fixture()
    {
        (SwiftPages pages, Host host) = Renderer();

        var page = Assert.IsType<ContentPage>(
            pages.Render(null, Host.Parse(Fixtures.ReadBytes("pages/ContentPage.bin"))));

        return (page, host);
    }

    /// <summary>
    /// The whole of what a written page can say, in one message, read by the
    /// code an application runs.
    /// </summary>
    /// <remarks>
    /// Under <c>fixtures/pages/</c> rather than <c>fixtures/controls/</c>: a
    /// fixture in <c>controls/</c> is walked by <see cref="StyleTests"/>, which
    /// insists every property in it can be set by a Style - and a page is not
    /// a style target, however well the table knows its properties.
    /// </remarks>
    [Fact]
    public void TheFixtureBuildsTheWholePage()
    {
        (ContentPage page, _) = Fixture();

        Assert.Equal("Everything", page.Title);
        Assert.Equal("tab.png", (page.IconImageSource as FileImageSource)?.File);
        Assert.Equal(new Thickness(4, 8, 12, 16), page.Padding);
        Assert.Equal(Colors.WhiteSmoke, page.BackgroundColor);
        Assert.True(page.HideSoftInputOnTapped);

        Assert.Equal("content", Assert.IsType<Label>(page.Content).Text);
    }

    /// <summary>
    /// A page that stops answering one of its optional properties has it
    /// cleared, and keeps everything under it.
    /// </summary>
    /// <remarks>
    /// The case the whole cleared field exists for. Every optional property a
    /// page declares is written <c>title.map { … }</c>, so answering nil after
    /// a value is the ORDINARY shape of a page - and it used to replace the
    /// page, which rebuilt its content and, for the top of a navigation stack,
    /// popped and re-pushed an animated copy of it.
    /// </remarks>
    [Fact]
    public void APageThatStopsAnsweringItsTitleHasItClearedAndKeepsItsContent()
    {
        (SwiftPages pages, _) = Renderer();

        var page = Assert.IsType<ContentPage>(pages.Render(null, Host.Parse("""
            {"id":1,"type":"ContentPage","props":{"title":"Named"},
             "children":[{"id":2,"type":"Label","props":{"text":"body"}}]}
            """)));

        Assert.Equal("Named", page.Title);

        Label body = Assert.IsType<Label>(page.Content);

        var again = Assert.IsType<ContentPage>(pages.Render(page, Host.Parse("""
            {"id":1,"type":"ContentPage","cleared":["title"]}
            """)));

        Assert.Same(page, again);
        Assert.Null(again.Title);
        Assert.Same(body, again.Content);
    }

    /// <summary>
    /// Applying the page leaves the handler ids ON it, which is what its two
    /// events report with - and what a content page never had, never having
    /// been tracked.
    /// </summary>
    [Fact]
    public void ThePageNodeCarriesItsHandlersToThePage()
    {
        (ContentPage page, _) = Fixture();

        IReadOnlyDictionary<SwiftEvent, int>? events = StateUIRenderer.EventsOf(page);

        Assert.NotNull(events);
        Assert.Equal(
            new[] { SwiftEvent.Appearing, SwiftEvent.Disappearing },
            events!.Keys.Order());
    }

    /// <summary>
    /// The arrival raised the way the platform raises it, reported with the
    /// handler id the node named.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The page is hung in a WINDOW WITH A PARENT, and that is not ceremony.
    /// MAUI 10.0.20's <c>Page.SendAppearing</c> begins
    /// <c>FindParentOfType&lt;IWindow&gt;()</c> and returns at once unless that
    /// window's own Parent is set - measured, after a first version of this
    /// test raised the event on a page standing on its own and nothing
    /// happened at all. So this is the shortest arrangement in which the
    /// platform will raise it, and anything less proves nothing.
    /// </para>
    /// <para>
    /// The report goes through the dispatcher, which is the whole point of the
    /// delay: MAUI raises Appearing while the page is being put on screen -
    /// inside the message that described it - and a report made from inside an
    /// apply is dropped. The test dispatcher runs a dispatched action at once,
    /// so it lands here in the same call.
    /// </para>
    /// </remarks>
    [Fact]
    public void AnArrivalReportsToTheHandlerTheNodeNamed()
    {
        (SwiftPages pages, Host host) = Renderer();

        var page = Assert.IsType<ContentPage>(pages.Render(
            null,
            Host.Parse("""
                {"id":1,"type":"ContentPage","props":{"title":"Feed"},
                 "events":{"appearing":11,"disappearing":12},"arranged":true,
                 "children":[{"id":2,"type":"Label","props":{"text":"feed"}}]}
                """)));

        var window = new Window { Page = page };
        window.Parent = new Application();

        page.SendAppearing();
        Assert.Equal(11, host.Dispatched[^1].Id);

        page.SendDisappearing();
        Assert.Equal(12, host.Dispatched[^1].Id);
    }

    /// <summary>
    /// A page nobody listens to reports nothing - the subscription is made
    /// where the page is created, once, and the id is read at fire time, so an
    /// absent handler is an absent entry rather than an absent subscription.
    /// </summary>
    [Fact]
    public void APageNobodyListensToReportsNothing()
    {
        (SwiftPages pages, Host host) = Renderer();

        var page = Assert.IsType<ContentPage>(pages.Render(
            null,
            Host.Parse("{\"id\":1,\"type\":\"ContentPage\",\"props\":{\"title\":\"Plain\"},"
                + "\"children\":[{\"id\":2,\"type\":\"Label\",\"props\":{\"text\":\"plain\"}}]}")));

        page.SendAppearing();

        Assert.Empty(host.Dispatched);
    }
}
