// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The flyout, as the renderer builds it.
//
// Two pages by identity, one bool, and the same echo discipline the other two
// arrangements follow: what Swift asked for is not reported back, what the
// reader did is - a turn later, because the window holds reporting off for the
// whole of a message.
//
// What Swift puts on the wire is next door, in the Swift FlyoutPageTests.
using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class FlyoutPageTests
{
    /// <summary>A page renderer whose failures fail the test.</summary>
    private static (PagePresenter Pages, Host Host) Renderer()
    {
        var host = new Host();
        var pages = new PagePresenter(
            host.Renderer,
            (message, exception) => Assert.Fail($"{message}\n{exception}"));

        return (pages, host);
    }

    /// <summary>One half of the layout, as Swift writes it.</summary>
    private static string Half(string identity, string title) =>
        $"{{\"id\":\"{identity}\",\"type\":\"Page\",\"props\":{{\"title\":\"{title}\"}},"
        + $"\"arranged\":true,\"children\":"
        + $"[{{\"id\":1,\"type\":\"Label\",\"props\":{{\"text\":\"{title}\"}}}}]}}";

    /// <summary>A FlyoutPage over the two halves, open or shut.</summary>
    private static string Flyout(bool? presented = false, string? extra = null) =>
        "{\"id\":1,\"type\":\"SplitView\",\"events\":{\"isSidebarVisibleChanged\":5},"
        + "\"props\":{"
        + (presented is bool open ? $"\"isSidebarVisible\":{(open ? "true" : "false")}" : "")
        + (extra is null ? "" : (presented is null ? "" : ",") + extra)
        + "},\"arranged\":true,\"children\":["
        + Half("sidebar", "Sections") + "," + Half("detail", "Today") + "]}";

    // ---- What the two halves are -------------------------------------------

    /// <summary>Each child goes to its own half, by IDENTITY.</summary>
    [Fact]
    public void TheTwoHalvesAreTheChildren()
    {
        (PagePresenter pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        Assert.Equal("Sections", flyout.Flyout.Title);
        Assert.Equal("Today", flyout.Detail.Title);
        Assert.False(flyout.IsPresented);
    }

    /// <summary>
    /// The detail page can be a whole navigation stack, which is the ordinary
    /// shape of an application with a menu.
    /// </summary>
    [Fact]
    public void TheDetailCanBeAWholeStack()
    {
        (PagePresenter pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"SplitView\",\"arranged\":true,\"children\":["
            + Half("sidebar", "Sections") + ","
            + "{\"id\":\"detail\",\"type\":\"NavigationStack\",\"arranged\":true,"
            + "\"props\":{\"title\":\"Diary\"},\"children\":[" + Half("root", "Today") + "]}]}")));

        var stack = Assert.IsType<NavigationPage>(flyout.Detail);

        Assert.Equal("Diary", stack.Title);
        Assert.Equal("Today", stack.Navigation.NavigationStack[0].Title);
    }

    /// <summary>
    /// The split layout is a page too, with a title and an icon of its own -
    /// what a tab or a window holding it shows for it.
    /// </summary>
    [Fact]
    public void AFlyoutCarriesATitleAndAnIconOfItsOwn()
    {
        (PagePresenter pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(
            Flyout(extra: "\"title\":\"Mail\",\"icon\":\"mail.png\""))));

        Assert.Equal("Mail", flyout.Title);
        Assert.Equal("mail.png", (flyout.IconImageSource as FileImageSource)?.File);
    }

    /// <summary>
    /// A later message swaps a half without touching the other - and keeps the
    /// page it did not talk about, which is what identity is for.
    /// </summary>
    [Fact]
    public void APatchAboutOneHalfLeavesTheOtherAlone()
    {
        (PagePresenter pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));
        Page pane = flyout.Flyout;

        pages.Render(flyout, Host.Parse(
            "{\"id\":1,\"type\":\"SplitView\",\"children\":["
            + "{\"id\":\"detail\",\"type\":\"Page\",\"props\":{\"title\":\"Archive\"}}]}"));

        Assert.Equal("Archive", flyout.Detail.Title);
        Assert.Same(pane, flyout.Flyout);
    }

    /// <summary>
    /// A flyout page with NO TITLE is reported rather than thrown: MAUI refuses
    /// one from the property setter, which would take the whole message down.
    /// </summary>
    [Fact]
    public void AFlyoutWithoutATitleIsReported()
    {
        var host = new Host();
        List<string> failures = [];
        var pages = new PagePresenter(host.Renderer, (message, _) => failures.Add(message));

        pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"SplitView\",\"arranged\":true,\"children\":["
            + "{\"id\":\"sidebar\",\"type\":\"Page\",\"arranged\":true,\"children\":[]},"
            + Half("detail", "Today") + "]}"));

        Assert.Contains(failures, message => message.Contains("must have a title"));
    }

    /// <summary>And a child that is neither half says so.</summary>
    [Fact]
    public void AChildThatIsNeitherHalfIsReported()
    {
        var host = new Host();
        List<string> failures = [];
        var pages = new PagePresenter(host.Renderer, (message, _) => failures.Add(message));

        pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"SplitView\",\"arranged\":true,\"children\":["
            + Half("sidebar", "Sections") + "," + Half("detail", "Today") + ","
            + Half("extra", "Nowhere") + "]}"));

        Assert.Contains(failures, message => message.Contains("extra"));
    }

    // ---- Opening and closing ------------------------------------------------

    /// <summary>Swift says it is open, so it opens.</summary>
    [Fact]
    public void SwiftCanOpenIt()
    {
        (PagePresenter pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        pages.Render(flyout, Host.Parse(
            "{\"id\":1,\"type\":\"SplitView\",\"props\":{\"isSidebarVisible\":true}}"));

        Assert.True(flyout.IsPresented);
    }

    /// <summary>
    /// And what Swift asked for is not reported back to it - not during the
    /// message, and not a turn later either.
    /// </summary>
    [Fact]
    public void WhatSwiftAskedForIsNotReportedBack()
    {
        (PagePresenter pages, Host host) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            pages.Render(flyout, Host.Parse(
                "{\"id\":1,\"type\":\"SplitView\",\"props\":{\"isSidebarVisible\":true}}"));
        }

        TestDispatcher.Drain();

        Assert.True(flyout.IsPresented);
        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// The reader's own way in - a swipe, a tap on the dimmed detail page, the
    /// platform's button - is reported, so the binding can be written to match.
    /// </summary>
    [Fact]
    public void TheReaderOpeningItIsReported()
    {
        (PagePresenter pages, Host host) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        host.Dispatched.Clear();

        // What a swipe does, in the one way a headless test can do it.
        flyout.IsPresented = true;

        Assert.Equal([(5, "true")], host.Dispatched);
    }

    /// <summary>And closing it the same way says so too.</summary>
    [Fact]
    public void TheReaderClosingItIsReported()
    {
        (PagePresenter pages, Host host) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout(true))));

        Assert.True(flyout.IsPresented);

        host.Dispatched.Clear();

        flyout.IsPresented = false;

        Assert.Equal([(5, "false")], host.Dispatched);
    }

    /// <summary>
    /// A layout that keeps the flyout open whatever anybody asks is reported
    /// too, a turn after the message - which is how the bound value comes to
    /// say "there is nothing to open" on a wide screen.
    /// </summary>
    /// <remarks>
    /// Driven here by MAUI's own answer rather than by a screen: a split layout
    /// is what makes IsPresented true by itself, and this asserts the machinery
    /// that carries it back rather than the platform's choice.
    /// </remarks>
    [Fact]
    public void WhatThePlatformDecidesIsReportedAfterTheMessage()
    {
        (PagePresenter pages, Host host) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            // Swift says nothing about IsPresented in this message; the
            // platform has moved it since the last one.
            flyout.IsPresented = true;

            pages.Render(flyout, Host.Parse(
                "{\"id\":1,\"type\":\"SplitView\",\"props\":{\"isGestureEnabled\":true}}"));
        }

        Assert.Empty(host.Dispatched);

        TestDispatcher.Drain();

        Assert.Equal([(5, "true")], host.Dispatched);
    }

    /// <summary>
    /// A close the layout refuses is answered with what the platform shows, so
    /// Swift does not go on believing the sidebar it asked to hide is hidden.
    /// </summary>
    /// <remarks>
    /// Side by side, MAUI refuses the write outright; the binding settles on
    /// the sidebar that is still there.
    /// </remarks>
    [Fact]
    public void AHideTheLayoutRefusesIsAnsweredWithTheSidebarShown()
    {
        (PagePresenter pages, Host host) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout(true))));
        flyout.FlyoutLayoutBehavior = FlyoutLayoutBehavior.Split;

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            pages.Render(flyout, Host.Parse(
                "{\"id\":1,\"type\":\"SplitView\",\"props\":{\"isSidebarVisible\":false}}"));
        }

        TestDispatcher.Drain();

        Assert.True(flyout.IsPresented);
        Assert.Equal([(5, "true")], host.Dispatched);
    }

    /// <summary>
    /// The layout the renderer builds leaves the sidebar to the application.
    /// </summary>
    /// <remarks>
    /// A split view's promise is that once both pages are showing, hiding the
    /// sidebar is the reader's and the application's to ask for. MAUI's default
    /// layout makes a wide window's flyout a locked split instead, under which
    /// IsPresented refuses every write - and the platform's OWN pane toggle
    /// writes it from a place no catch here reaches. So what is asserted is
    /// both halves: the behavior the page is built with, and that a hide
    /// written straight onto the page takes.
    /// </remarks>
    [Fact]
    public void TheBuiltLayoutLeavesTheSidebarToTheApplication()
    {
        (PagePresenter pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout(true))));

        Assert.Equal(FlyoutLayoutBehavior.Popover, flyout.FlyoutLayoutBehavior);

        flyout.IsPresented = false;

        Assert.False(flyout.IsPresented);
    }

    // ---- What the renderer forgets ------------------------------------------

    [Fact]
    public void ForgettingBuildsTheFlyoutAgain()
    {
        (PagePresenter pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        pages.Forget();

        var again = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        Assert.NotSame(flyout, again);
    }

    // ---- The fixture, which is the contract --------------------------------

    /// <summary>
    /// The bytes the Swift tests wrote: a pane with two rows, a detail page
    /// that is a whole navigation stack pushed one deep, and the pane showing.
    /// </summary>
    [Fact]
    public void TheFixtureBuildsTheWholeFlyout()
    {
        (PagePresenter pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(
            pages.Render(null, Host.Parse(Fixtures.ReadBytes("pages/SplitView.bin"))));

        Assert.True(flyout.IsPresented);

        Assert.Equal("Sections", flyout.Flyout.Title);

        var rows = Assert.IsAssignableFrom<VerticalStackLayout>(((ContentPage)flyout.Flyout).Content);
        Assert.Equal(["Today", "Archive"], rows.Children.Cast<Button>().Select(row => row.Text));

        var stack = Assert.IsType<NavigationPage>(flyout.Detail);

        Assert.Equal("Diary", stack.Title);
        Assert.Equal(
            ["today", "level 1"],
            stack.Navigation.NavigationStack.Select(page => page.Title));
    }
}
