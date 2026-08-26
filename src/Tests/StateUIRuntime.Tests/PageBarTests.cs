// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a page hangs on its bars, and what a page says about the keyboard.
//
// The toolbar and the desktop menu bar are lists of things that are NOT views -
// a ToolbarItem is an Element, a MenuFlyoutItem is a menu entry - so they have
// no control fixture and this is where the host's side of them is checked.
using StateUI.Runtime.Protocol;
using iOSPage = Microsoft.Maui.Controls.PlatformConfiguration.iOSSpecific.Page;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class PageBarTests
{
    /// <summary>A window showing one page, which is what a window is now.</summary>
    private static ContentPage Page(string page)
    {
        var window = Host.Window();

        window.Apply(Host.Parse($$"""
            {"id":1,"type":"Window","props":{"title":"StateUI"},"children":[{{page}}]}
            """), true);

        return Assert.IsType<ContentPage>(window.Page);
    }

    /// <summary>
    /// A page's toolbar and its menus: lists of things that are not views, kept
    /// by identity the way rows are.
    /// </summary>
    [Fact]
    public void APageCarriesItsToolbarItemsAndMenus()
    {
        ContentPage page = Page($$$"""
            {"id":5,"type":"ContentPage","props":{"title":"Counter"},"children":[
              {"id":6,"type":"Label","props":{"text":"one"}},
              {"id":7,"type":"ToolbarItems","arranged":true,"children":[
                {"id":"save","type":"ToolbarItem",
                 "props":{"text":"Save","priority":1,"isEnabled":true,
                          "iconImageSource":"nav_media.png"},
                 "events":{"clicked":11}},
                {"id":"delete","type":"ToolbarItem",
                 "props":{"order":{{{Host.Member(SwiftToolbarItemOrder.Secondary)}}},
                          "text":"Delete","isDestructive":true}}]},
              {"id":8,"type":"MenuBarItems","arranged":true,"children":[
                {"id":"file","type":"MenuBarItem","props":{"text":"File"},"arranged":true,"children":[
                  {"id":"new","type":"MenuFlyoutItem",
                   "props":{"text":"New","isDestructive":false,
                            "iconImageSource":"nav_media.png"},
                   "events":{"clicked":12}},
                  {"id":"sep","type":"MenuFlyoutSeparator"},
                  {"id":"recent","type":"MenuFlyoutSubItem","props":{"text":"Recent"},
                   "arranged":true,"children":[
                    {"id":"a","type":"MenuFlyoutItem","props":{"text":"a.txt"}}]}]}]}]}
            """);

        Assert.Equal(["Save", "Delete"], page.ToolbarItems.Select(item => item.Text));
        Assert.Equal("nav_media.png",
            Assert.IsType<FileImageSource>(page.ToolbarItems[0].IconImageSource).File);
        Assert.True(page.ToolbarItems[0].IsEnabled);
        Assert.Equal(ToolbarItemOrder.Secondary, page.ToolbarItems[1].Order);
        Assert.Equal(1, page.ToolbarItems[0].Priority);
        Assert.True(page.ToolbarItems[1].IsDestructive);

        MenuBarItem file = Assert.Single(page.MenuBarItems);
        Assert.Equal("File", file.Text);
        Assert.Equal(3, file.Count);
        var entry = Assert.IsType<MenuFlyoutItem>(file[0]);
        Assert.Equal("New", entry.Text);
        Assert.Equal("nav_media.png", Assert.IsType<FileImageSource>(entry.IconImageSource).File);
        Assert.False(entry.IsDestructive);
        Assert.IsType<MenuFlyoutSeparator>(file[1]);

        var recent = Assert.IsType<MenuFlyoutSubItem>(file[2]);
        Assert.Equal("Recent", recent.Text);
        Assert.Equal("a.txt", Assert.IsType<MenuFlyoutItem>(Assert.Single(recent)).Text);

        // The content is still the content: the slots are read by TYPE, and a
        // toolbar taken for one would leave the page showing a button.
        Assert.Equal("one", Assert.IsType<Label>(page.Content).Text);
    }

    /// <summary>
    /// And they run: a toolbar item reports with the id the message gave it,
    /// and so does a menu entry.
    /// </summary>
    /// <remarks>
    /// Applied through the renderer rather than through a window, because what
    /// is being checked is the reporting - and a window builds a session of its
    /// own, whose dispatch goes to the native side.
    /// </remarks>
    [Fact]
    public void AToolbarItemAndAMenuEntryReportWhatTheyWereGiven()
    {
        var host = new Host();
        var page = new ContentPage();

        host.Renderer.ApplyList(page.ToolbarItems, Host.Parse("""
            {"id":7,"type":"ToolbarItems","arranged":true,"children":[
              {"id":"save","type":"ToolbarItem","props":{"text":"Save"},
               "events":{"clicked":11}}]}
            """), host.Renderer.ApplyToolbarItem);

        host.Renderer.ApplyList(page.MenuBarItems, Host.Parse("""
            {"id":8,"type":"MenuBarItems","arranged":true,"children":[
              {"id":"file","type":"MenuBarItem","props":{"text":"File"},"arranged":true,"children":[
                {"id":"new","type":"MenuFlyoutItem","props":{"text":"New"},
                 "events":{"clicked":12}}]}]}
            """), host.Renderer.ApplyMenuBarItem);

        ((IMenuItemController)page.ToolbarItems[0]).Activate();
        Assert.Equal((11, (string?)null), host.Dispatched[^1]);

        ((IMenuItemController)page.MenuBarItems[0][0]).Activate();
        Assert.Equal((12, (string?)null), host.Dispatched[^1]);

        // An entry that leaves is simply no longer in the arranged list.
        host.Renderer.ApplyList(page.ToolbarItems, Host.Parse("""
            {"id":7,"type":"ToolbarItems","arranged":true,"children":[]}
            """), host.Renderer.ApplyToolbarItem);

        Assert.Empty(page.ToolbarItems);
    }

    /// <summary>
    /// A ToolbarItem is an Element and not a View, and the handler ids are
    /// recorded on it all the same - which is what generalizing Track past View
    /// was for.
    /// </summary>
    [Fact]
    public void AnObjectThatIsNotAViewReportsEventsToo()
    {
        var host = new Host();
        var item = new ToolbarItem();

        host.Renderer.Track(item, Host.Parse("""
            {"id":"t","type":"ToolbarItem","events":{"clicked":4}}
            """));

        host.Renderer.Raise(item, SwiftEvent.Clicked);

        Assert.Equal((4, (string?)null), host.Dispatched[^1]);
    }

    /// <summary>
    /// MAUI's own tap-to-dismiss, which is why this library lays no
    /// touch-catching view over the content: MAUI recognizes the tap alongside
    /// whatever else is listening, so a scroll, a button and a gesture on the
    /// same page all go on working.
    /// </summary>
    [Fact]
    public void APageCanGiveTheKeyboardBackOnATapBesideTheField()
    {
        ContentPage page = Page("""
            {"id":5,"type":"ContentPage","props":{"hideSoftInputOnTapped":true},"children":[
              {"id":6,"type":"Entry","props":{"text":""}}]}
            """);

        Assert.True(page.HideSoftInputOnTapped);
    }

    /// <summary>
    /// A page whose top is a picture runs UNDER the bars, which is the PAGE's
    /// own inset rather than a layout's - measured on Mac Catalyst, where a
    /// layout asking for no safe area still began below the window's title bar,
    /// with the page's own colour showing above the picture in a strip.
    /// </summary>
    [Fact]
    public void APageCanRunUnderTheBars()
    {
        ContentPage page = Page("""
            {"id":5,"type":"ContentPage","props":{"useSafeArea":false},"children":[
              {"id":6,"type":"Label","props":{"text":"banner"}}]}
            """);

        // The renderer writes the deprecated platform-specific on purpose -
        // the reason is beside the write in SwiftPages - so the read here is
        // the same deliberate exception.
#pragma warning disable CS0618
        Assert.False((bool)page.GetValue(iOSPage.UseSafeAreaProperty));
#pragma warning restore CS0618
    }

    /// <summary>
    /// A page that says nothing leaves MAUI's default, which is a keyboard that
    /// stays up - an absent property is not a property set to false.
    /// </summary>
    [Fact]
    public void APageThatSaysNothingLeavesTheKeyboardAlone()
    {
        ContentPage page = Page("""
            {"id":5,"type":"ContentPage","props":{"title":"Plain"}}
            """);

        Assert.False(page.HideSoftInputOnTapped);
    }
}
