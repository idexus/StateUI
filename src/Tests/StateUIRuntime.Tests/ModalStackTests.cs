// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What is presented over the window, as the renderer does it.
//
// Swift describes the whole modal stack as an ARRANGED children list under one
// wrapper node, and this side brings MAUI's own modal stack to it - pushing
// what is described and dismissing what is not, top first, because the top is
// the only end of a modal stack any platform lets go of. The one thing that
// travels back is a dismissal the reader made.
//
// What Swift puts on the wire is next door, in the Swift ModalStackTests.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

// The one name out of the iOS platform-specific namespace this file reads.
using iOSPage = Microsoft.Maui.Controls.PlatformConfiguration.iOSSpecific.Page;
using UIModalPresentationStyle =
    Microsoft.Maui.Controls.PlatformConfiguration.iOSSpecific.UIModalPresentationStyle;

namespace StateUI.Runtime.Tests;

public class ModalStackTests
{
    /// <summary>The handler id the window's node says a dismissal reports to.</summary>
    private const int Popped = 9;

    /// <summary>
    /// A window with a page, a page renderer over it, and the subscription
    /// <see cref="StateUIWindow"/> makes - which is where MAUI raises a
    /// modal's departure, the modal stack being the window's own.
    /// </summary>
    /// <remarks>
    /// A plain MAUI window rather than a StateUIWindow, so that the reports
    /// land in a test double: a StateUIWindow builds a session of its own,
    /// whose dispatch goes to the native side. The fixture at the bottom is
    /// the one test that wants the real thing.
    /// </remarks>
    private static (SwiftPages Pages, Host Host, Window Window) Renderer()
    {
        var host = new Host();
        var pages = new SwiftPages(
            host.Renderer,
            (message, exception) => Assert.Fail($"{message}\n{exception}"));

        var window = new Window { Page = new ContentPage { Title = "Home" } };

        // What Apply does for the window's own node: the handler ids a
        // dismissal is reported with are the window's, so the window has to be
        // tracked before anything can be said about it.
        host.Renderer.Track(window, Host.Parse(
            $"{{\"id\":1,\"type\":\"Window\",\"events\":{{\"modalPopped\":{Popped}}}}}"));

        window.ModalPopped += (_, _) => pages.ModalWasPopped();

        return (pages, host, window);
    }

    /// <summary>One presented page, as Swift writes it.</summary>
    /// <remarks>
    /// The style is a member of a closed vocabulary, so it goes on as a number
    /// - <see cref="Host.Member"/> spells one - and the parameter is the mirror
    /// itself, which is what stops a sheet asking for a style no member names.
    /// </remarks>
    private static string Sheet(
        string identity, string title, SwiftUIModalPresentationStyle? style = null) =>
        $"{{\"id\":\"{identity}\",\"type\":\"ContentPage\",\"props\":{{\"title\":\"{title}\""
        + (style is null ? "" : $",\"modalPresentationStyle\":{Host.Member(style.Value)}")
        + "},\"arranged\":true,\"children\":"
        + $"[{{\"id\":1,\"type\":\"Label\",\"props\":{{\"text\":\"{title}\"}}}}]}}";

    /// <summary>The modal stack node over the sheets named, innermost first.</summary>
    private static SwiftNode Stack(params string[] sheets) => Host.Parse(
        $"{{\"id\":2,\"type\":\"ModalStack\",\"arranged\":true,\"children\":[{string.Join(",", sheets)}]}}");

    /// <summary>The titles of what is presented, innermost first.</summary>
    private static string[] Presented(Window window) =>
        [.. window.Navigation.ModalStack.Select(page => page.Title ?? "")];

    // ---- What an arrangement does ------------------------------------------

    /// <summary>A window with nothing presented over it is the ordinary one.</summary>
    [Fact]
    public void AnEmptyListPresentsNothing()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack());

        Assert.Empty(window.Navigation.ModalStack);
    }

    [Fact]
    public void AListOfOnePresentsIt()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/settings", "Settings")));

        Assert.Equal(["Settings"], Presented(window));
    }

    /// <summary>
    /// Modals stack, which is why this is a list and not a page: a sheet may
    /// present a sheet, and the platforms all allow it.
    /// </summary>
    [Fact]
    public void ALongerListPresentsOverWhatIsAlreadyThere()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A")));
        Page first = window.Navigation.ModalStack[0];

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A"), Sheet("1/b", "B")));

        Assert.Equal(["A", "B"], Presented(window));
        Assert.Same(first, window.Navigation.ModalStack[0]);
    }

    /// <summary>A shorter list dismisses, from the top.</summary>
    [Fact]
    public void AShorterListDismissesTheTop()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A"), Sheet("1/b", "B")));
        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A")));

        Assert.Equal(["A"], Presented(window));
    }

    /// <summary>And an empty one dismisses everything there is.</summary>
    [Fact]
    public void AnEmptyListDismissesAllOfThem()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A"), Sheet("1/b", "B")));
        pages.ApplyModals(window.Navigation, window, Stack());

        Assert.Empty(window.Navigation.ModalStack);
    }

    /// <summary>
    /// A sheet SWAPPED for another at the same depth: the one that was there
    /// goes and the new one is presented, which the loop reaches by dismissing
    /// down to the common part and pushing back up.
    /// </summary>
    [Fact]
    public void ADifferentSheetAtTheSameDepthReplacesIt()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A")));
        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/b", "B")));

        Assert.Equal(["B"], Presented(window));
    }

    /// <summary>
    /// A patch about a presented page keeps the PAGE - its controls, its scroll
    /// offset, whatever the reader typed into it - the way every other
    /// arrangement keeps what it was not told to change.
    /// </summary>
    [Fact]
    public void APatchAboutASheetKeepsThePage()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/settings", "Settings")));
        Page sheet = window.Navigation.ModalStack[0];

        pages.ApplyModals(window.Navigation, window, Host.Parse(
            "{\"id\":2,\"type\":\"ModalStack\",\"children\":["
            + "{\"id\":\"0/settings\",\"type\":\"ContentPage\",\"props\":{\"title\":\"Options\"}}]}"));

        Assert.Same(sheet, window.Navigation.ModalStack[0]);
        Assert.Equal(["Options"], Presented(window));
    }

    /// <summary>
    /// A page REBUILT under an unchanged identity - which is what
    /// <c>replace</c> means - is presented in place of the one that was there,
    /// even though no arrangement arrived to say so.
    /// </summary>
    [Fact]
    public void ARebuiltSheetIsPresentedInPlaceOfTheOldOne()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/settings", "Settings")));
        Page sheet = window.Navigation.ModalStack[0];

        pages.ApplyModals(window.Navigation, window, Host.Parse(
            "{\"id\":2,\"type\":\"ModalStack\",\"children\":["
            + "{\"id\":\"0/settings\",\"type\":\"ContentPage\",\"replace\":true,"
            + "\"props\":{\"title\":\"Settings\"}}]}"));

        Assert.NotSame(sheet, window.Navigation.ModalStack[0]);
        Assert.Single(window.Navigation.ModalStack);
    }

    /// <summary>A child that is not a page is reported, not skipped.</summary>
    [Fact]
    public void AChildThatIsNotAPageIsReported()
    {
        var host = new Host();
        List<string> failures = [];
        var pages = new SwiftPages(host.Renderer, (message, _) => failures.Add(message));
        var window = new Window { Page = new ContentPage() };

        pages.ApplyModals(window.Navigation, window, Host.Parse(
            "{\"id\":2,\"type\":\"ModalStack\",\"arranged\":true,\"children\":["
            + "{\"id\":3,\"type\":\"Label\",\"props\":{\"text\":\"not a page\"}}]}"));

        Assert.Contains(failures, message => message.Contains("modal stack"));
    }

    // ---- How it is drawn ----------------------------------------------------

    /// <summary>
    /// The presentation style is the PAGE's own property, so it reaches the
    /// page through the same chrome every page goes through.
    /// </summary>
    /// <remarks>
    /// UIKit is the only platform that reads it. Setting it here on a test
    /// machine is what the renderer does on Android too: an ordinary bindable
    /// property of MAUI's shared assembly, which nothing looks at there.
    /// </remarks>
    [Fact]
    public void TheStyleReachesThePresentedPage()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window,
            Stack(Sheet("0/settings", "Settings", SwiftUIModalPresentationStyle.PageSheet)));

        Assert.Equal(
            UIModalPresentationStyle.PageSheet,
            iOSPage.GetModalPresentationStyle(window.Navigation.ModalStack[0]));
    }

    /// <summary>
    /// Every style the Swift side can write is a style this side knows - a
    /// number no member names leaves MAUI's own default standing.
    /// </summary>
    /// <remarks>
    /// The member arrives as an <c>int</c> because the mirror is internal and a
    /// public test method cannot take one; the cast back at the top of the body
    /// is where it becomes a member again.
    /// </remarks>
    /// <param name="member">The style's number, as <c>SwiftUIModalPresentationStyle</c>.</param>
    /// <param name="expected">The UIKit style it has to reach.</param>
    [Theory]
    [InlineData((int)SwiftUIModalPresentationStyle.FullScreen, UIModalPresentationStyle.FullScreen)]
    [InlineData((int)SwiftUIModalPresentationStyle.FormSheet, UIModalPresentationStyle.FormSheet)]
    [InlineData((int)SwiftUIModalPresentationStyle.Automatic, UIModalPresentationStyle.Automatic)]
    [InlineData((int)SwiftUIModalPresentationStyle.PageSheet, UIModalPresentationStyle.PageSheet)]
    [InlineData(
        (int)SwiftUIModalPresentationStyle.OverFullScreen, UIModalPresentationStyle.OverFullScreen)]
    [InlineData((int)SwiftUIModalPresentationStyle.Popover, UIModalPresentationStyle.Popover)]
    public void EveryStyleIsUnderstood(int member, UIModalPresentationStyle expected)
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window,
            Stack(Sheet("0/settings", "Settings", (SwiftUIModalPresentationStyle)member)));

        Assert.Equal(expected, iOSPage.GetModalPresentationStyle(window.Navigation.ModalStack[0]));
    }

    // ---- What comes back ----------------------------------------------------

    /// <summary>
    /// The reader's own way out - an iOS sheet dragged down, Android's system
    /// back - is reported as what SURVIVED, so the bound array can be truncated
    /// to it.
    /// </summary>
    [Fact]
    public async Task AReaderDismissingIsReported()
    {
        (SwiftPages pages, Host host, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/settings", "Settings")));

        host.Dispatched.Clear();

        // What a drag down does, in the one way a headless test can do it.
        await window.Navigation.PopModalAsync();

        Assert.Equal([(Popped, "0")], host.Dispatched);
    }

    /// <summary>
    /// And what SWIFT asked for is not reported back - not during the message,
    /// and not a turn later either, which is when every report is made.
    /// </summary>
    [Fact]
    public void WhatSwiftAskedForIsNotReportedBack()
    {
        (SwiftPages pages, Host host, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/settings", "Settings")));

        host.Dispatched.Clear();
        TestDispatcher.Hold();

        using (StateUIRenderer.Suppressed applying = host.Renderer.Applying())
        {
            pages.ApplyModals(window.Navigation, window, Stack());
        }

        TestDispatcher.Drain();

        Assert.Empty(window.Navigation.ModalStack);
        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// A dismissal that lands where Swift already believes says nothing - the
    /// same guard the navigation stack's depth has, and what keeps a sheet
    /// closed by its own button to exactly one render.
    /// </summary>
    [Fact]
    public async Task ADismissalOfWhatSwiftAlreadyClosedSaysNothing()
    {
        (SwiftPages pages, Host host, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/settings", "Settings")));
        pages.ApplyModals(window.Navigation, window, Stack());

        host.Dispatched.Clear();

        // Nothing left to dismiss, and nothing to say about it.
        await Task.Yield();

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// Only the top of a stack of two: what is reported is the DEPTH that
    /// survived, so an application that presented two sheets learns it still
    /// has one.
    /// </summary>
    [Fact]
    public async Task ADismissalOverAStackReportsWhatSurvived()
    {
        (SwiftPages pages, Host host, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A"), Sheet("1/b", "B")));

        host.Dispatched.Clear();

        await window.Navigation.PopModalAsync();

        Assert.Equal([(Popped, "1")], host.Dispatched);
    }

    // ---- What the renderer forgets ------------------------------------------

    [Fact]
    public void ForgettingBuildsThemAgain()
    {
        (SwiftPages pages, _, Window window) = Renderer();

        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A")));
        Page sheet = window.Navigation.ModalStack[0];

        pages.Forget();
        pages.ApplyModals(window.Navigation, window, Stack(Sheet("0/a", "A")));

        Assert.NotSame(sheet, window.Navigation.ModalStack[^1]);
    }

    // ---- The fixture, which is the contract --------------------------------

    /// <summary>
    /// The bytes the Swift tests wrote, through a real window: a navigation
    /// stack pushed one deep, with two sheets presented over all of it.
    /// </summary>
    /// <remarks>
    /// The whole path, which is what this one is for - the window recognizing
    /// the modal stack among its children, and reaching it AFTER the page it
    /// also carries.
    /// </remarks>
    [Fact]
    public void TheFixturePresentsWhatSwiftDescribed()
    {
        var window = Host.Window();

        window.Apply(
            Host.Parse(Fixtures.ReadBytes("pages/ModalStack.bin")), true);

        Assert.IsType<NavigationPage>(window.Page);
        Assert.Equal(["Settings", "About"], Presented(window));

        Assert.Equal(
            UIModalPresentationStyle.PageSheet,
            iOSPage.GetModalPresentationStyle(window.Navigation.ModalStack[0]));
    }
}
