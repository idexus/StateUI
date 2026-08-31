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
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class FlyoutPageTests
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

    /// <summary>One half of the layout, as Swift writes it.</summary>
    private static string Half(string identity, string title) =>
        $"{{\"id\":\"{identity}\",\"type\":\"ContentPage\",\"props\":{{\"title\":\"{title}\"}},"
        + $"\"arranged\":true,\"children\":"
        + $"[{{\"id\":1,\"type\":\"Label\",\"props\":{{\"text\":\"{title}\"}}}}]}}";

    /// <summary>A FlyoutPage over the two halves, open or shut.</summary>
    private static string Flyout(bool? presented = false, string? extra = null) =>
        "{\"id\":1,\"type\":\"FlyoutPage\",\"events\":{\"isPresentedChanged\":5},"
        + "\"props\":{"
        + (presented is bool open ? $"\"isPresented\":{(open ? "true" : "false")}" : "")
        + (extra is null ? "" : (presented is null ? "" : ",") + extra)
        + "},\"arranged\":true,\"children\":["
        + Half("flyout", "Sections") + "," + Half("detail", "Today") + "]}";

    // ---- What the two halves are -------------------------------------------

    /// <summary>Each child goes to its own half, by IDENTITY.</summary>
    [Fact]
    public void TheTwoHalvesAreTheChildren()
    {
        (SwiftPages pages, _) = Renderer();

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
        (SwiftPages pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"FlyoutPage\",\"arranged\":true,\"children\":["
            + Half("flyout", "Sections") + ","
            + "{\"id\":\"detail\",\"type\":\"NavigationPage\",\"arranged\":true,"
            + "\"props\":{\"title\":\"Diary\"},\"children\":[" + Half("root", "Today") + "]}]}")));

        var stack = Assert.IsType<NavigationPage>(flyout.Detail);

        Assert.Equal("Diary", stack.Title);
        Assert.Equal("Today", stack.Navigation.NavigationStack[0].Title);
    }

    /// <summary>
    /// A later message swaps a half without touching the other - and keeps the
    /// page it did not talk about, which is what identity is for.
    /// </summary>
    [Fact]
    public void APatchAboutOneHalfLeavesTheOtherAlone()
    {
        (SwiftPages pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));
        Page pane = flyout.Flyout;

        pages.Render(flyout, Host.Parse(
            "{\"id\":1,\"type\":\"FlyoutPage\",\"children\":["
            + "{\"id\":\"detail\",\"type\":\"ContentPage\",\"props\":{\"title\":\"Archive\"}}]}"));

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
        var pages = new SwiftPages(host.Renderer, (message, _) => failures.Add(message));

        pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"FlyoutPage\",\"arranged\":true,\"children\":["
            + "{\"id\":\"flyout\",\"type\":\"ContentPage\",\"arranged\":true,\"children\":[]},"
            + Half("detail", "Today") + "]}"));

        Assert.Contains(failures, message => message.Contains("must have a title"));
    }

    /// <summary>And a child that is neither half says so.</summary>
    [Fact]
    public void AChildThatIsNeitherHalfIsReported()
    {
        var host = new Host();
        List<string> failures = [];
        var pages = new SwiftPages(host.Renderer, (message, _) => failures.Add(message));

        pages.Render(null, Host.Parse(
            "{\"id\":1,\"type\":\"FlyoutPage\",\"arranged\":true,\"children\":["
            + Half("flyout", "Sections") + "," + Half("detail", "Today") + ","
            + Half("extra", "Nowhere") + "]}"));

        Assert.Contains(failures, message => message.Contains("extra"));
    }

    // ---- How the halves are laid out ---------------------------------------

    [Fact]
    public void TheLayoutBehaviourAndTheGestureArrive()
    {
        (SwiftPages pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(
            Flyout(false, "\"flyoutLayoutBehavior\":" + Host.Member(SwiftFlyoutLayoutBehavior.Split)
                + ",\"isGestureEnabled\":false"))));

        Assert.Equal(FlyoutLayoutBehavior.Split, flyout.FlyoutLayoutBehavior);
        Assert.False(flyout.IsGestureEnabled);
    }

    /// <summary>
    /// A SPLIT layout keeps the flyout open whatever Swift asks - MAUI refuses
    /// the property outright - and Swift is told what is true instead.
    /// </summary>
    /// <remarks>
    /// MEASURED: assigning <c>IsPresented</c> on a FlyoutPage showing both
    /// halves throws <c>"Can't change IsPresented when setting Split"</c> from
    /// MAUI's own property-changing callback. So this side does not fight it -
    /// the refusal is the platform answering, and the answer goes back into the
    /// binding, which is how an application learns there is nothing to open.
    /// </remarks>
    [Fact]
    public void ASplitLayoutKeepsItOpenAndSaysSo()
    {
        (SwiftPages pages, Host host) = Renderer();

        host.Dispatched.Clear();

        // Swift describes it shut, and split.
        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(
            Flyout(false,
                "\"flyoutLayoutBehavior\":" + Host.Member(SwiftFlyoutLayoutBehavior.Split)))));

        Assert.True(flyout.IsPresented, "the layout keeps both halves showing");
        Assert.Equal([(5, "true")], host.Dispatched);
    }

    // ---- Opening and closing ------------------------------------------------

    /// <summary>Swift says it is open, so it opens.</summary>
    [Fact]
    public void SwiftCanOpenIt()
    {
        (SwiftPages pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        pages.Render(flyout, Host.Parse(
            "{\"id\":1,\"type\":\"FlyoutPage\",\"props\":{\"isPresented\":true}}"));

        Assert.True(flyout.IsPresented);
    }

    /// <summary>
    /// And what Swift asked for is not reported back to it - not during the
    /// message, and not a turn later either.
    /// </summary>
    [Fact]
    public void WhatSwiftAskedForIsNotReportedBack()
    {
        (SwiftPages pages, Host host) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            pages.Render(flyout, Host.Parse(
                "{\"id\":1,\"type\":\"FlyoutPage\",\"props\":{\"isPresented\":true}}"));
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
        (SwiftPages pages, Host host) = Renderer();

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
        (SwiftPages pages, Host host) = Renderer();

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
        (SwiftPages pages, Host host) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(pages.Render(null, Host.Parse(Flyout())));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            // Swift says nothing about IsPresented in this message; the
            // platform has moved it since the last one.
            flyout.IsPresented = true;

            pages.Render(flyout, Host.Parse(
                "{\"id\":1,\"type\":\"FlyoutPage\",\"props\":{\"isGestureEnabled\":true}}"));
        }

        Assert.Empty(host.Dispatched);

        TestDispatcher.Drain();

        Assert.Equal([(5, "true")], host.Dispatched);
    }

    // ---- What the renderer forgets ------------------------------------------

    [Fact]
    public void ForgettingBuildsTheFlyoutAgain()
    {
        (SwiftPages pages, _) = Renderer();

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
        (SwiftPages pages, _) = Renderer();

        var flyout = Assert.IsType<FlyoutPage>(
            pages.Render(null, Host.Parse(Fixtures.ReadBytes("pages/FlyoutPage.bin"))));

        Assert.True(flyout.IsPresented);
        Assert.Equal(FlyoutLayoutBehavior.Popover, flyout.FlyoutLayoutBehavior);
        Assert.False(flyout.IsGestureEnabled);

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
