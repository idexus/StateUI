// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A menu on the view itself, and the arrangement it must not disturb.
//
// A ContextFlyout is the first child that can arrive under ANY view, so half of
// what matters here is what it does NOT do: a layout's children keep their
// places, a Border keeps its content, and a ScrollView does not wrap a single
// child because it thinks it has two.
//
// What a platform makes of the menu is not testable here - MAUI implements it on
// iOS, Mac Catalyst and Windows and leaves Android's handler empty - so what
// these check is that the MenuFlyout is attached, filled, and kept.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class ContextMenuTests
{
    /// <summary>The menu a view is carrying, or null.</summary>
    private static MenuFlyout? MenuOn(View view) =>
        FlyoutBase.GetContextFlyout(view) as MenuFlyout;

    [Fact]
    public void AMenuIsAttachedToTheViewAndFilledWithItsEntries()
    {
        var host = new Host();

        var label = Assert.IsType<Label>(host.Apply("""
            {"id":1,"type":"Label","props":{"text":"row"},"children":[
              {"id":2,"type":"ContextFlyout","arranged":true,"children":[
                {"id":3,"type":"MenuFlyoutItem","props":{"text":"Rename"},"events":{"clicked":7}},
                {"id":4,"type":"MenuFlyoutSeparator"},
                {"id":5,"type":"MenuFlyoutSubItem","props":{"text":"Move"},"arranged":true,"children":[
                  {"id":6,"type":"MenuFlyoutItem","props":{"text":"Up"}}]}]}]}
            """));

        var menu = Assert.IsType<MenuFlyout>(MenuOn(label));

        Assert.Equal(3, menu.Count);
        Assert.Equal("Rename", Assert.IsType<MenuFlyoutItem>(menu[0]).Text);
        Assert.IsType<MenuFlyoutSeparator>(menu[1]);

        var submenu = Assert.IsType<MenuFlyoutSubItem>(menu[2]);

        Assert.Equal("Move", submenu.Text);
        Assert.Equal("Up", Assert.IsType<MenuFlyoutItem>(submenu[0]).Text);

        // The entry reports through the id the tree issued, like every event.
        ((IMenuItemController)menu[0]).Activate();

        Assert.Equal((7, null), host.Dispatched[^1]);
    }

    /// <summary>
    /// A patch about one entry carries that entry alone, so the menu and the
    /// entries it did not mention are kept.
    /// </summary>
    [Fact]
    public void AMenuIsKeptAndPatchedRatherThanBuiltAgain()
    {
        var host = new Host();

        var label = Assert.IsType<Label>(host.Apply("""
            {"id":1,"type":"Label","props":{"text":"row"},"children":[
              {"id":2,"type":"ContextFlyout","arranged":true,"children":[
                {"id":3,"type":"MenuFlyoutItem","props":{"text":"Rename"}},
                {"id":4,"type":"MenuFlyoutItem","props":{"text":"Delete"},"events":{"clicked":9}}]}]}
            """));

        var menu = Assert.IsType<MenuFlyout>(MenuOn(label));
        var rename = menu[0];
        var delete = menu[1];

        host.Apply("""
            {"id":1,"type":"Label","children":[
              {"id":2,"type":"ContextFlyout","children":[
                {"id":4,"type":"MenuFlyoutItem","props":{"text":"Remove"}}]}]}
            """);

        Assert.Same(menu, MenuOn(label));
        Assert.Same(rename, menu[0]);
        Assert.Same(delete, menu[1]);

        Assert.Equal("Rename", Assert.IsType<MenuFlyoutItem>(menu[0]).Text);
        Assert.Equal("Remove", Assert.IsType<MenuFlyoutItem>(menu[1]).Text);

        // The handler the patch did not repeat is still the one it had.
        ((IMenuItemController)menu[1]).Activate();

        Assert.Equal((9, null), host.Dispatched[^1]);
    }

    [Fact]
    public void AnEntryThatLeavesIsTheOnlyOneThatGoes()
    {
        var host = new Host();

        var label = Assert.IsType<Label>(host.Apply("""
            {"id":1,"type":"Label","children":[
              {"id":2,"type":"ContextFlyout","arranged":true,"children":[
                {"id":3,"type":"MenuFlyoutItem","props":{"text":"Rename"}},
                {"id":4,"type":"MenuFlyoutItem","props":{"text":"Delete"}}]}]}
            """));

        var menu = Assert.IsType<MenuFlyout>(MenuOn(label));
        var rename = menu[0];

        host.Apply("""
            {"id":1,"type":"Label","children":[
              {"id":2,"type":"ContextFlyout","arranged":true,"children":[
                {"id":3,"type":"MenuFlyoutItem"}]}]}
            """);

        Assert.Single(menu);
        Assert.Same(rename, menu[0]);
    }

    /// <summary>
    /// The slot is not one of the layout's children.
    /// </summary>
    /// <remarks>
    /// It travels as one - the differ counts it like anything else - and what
    /// keeps it out of the arrangement is this side. Getting that wrong puts a
    /// red marker where a control should be, or leaves a gap at the end of every
    /// stack that carries a menu.
    /// </remarks>
    [Fact]
    public void TheSlotIsNotOneOfTheLayoutsChildren()
    {
        var host = new Host();

        var stack = Assert.IsType<VerticalStackLayout>(host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":2,"type":"Label","props":{"text":"one"}},
              {"id":3,"type":"Label","props":{"text":"two"}},
              {"id":4,"type":"ContextFlyout","arranged":true,"children":[
                {"id":5,"type":"MenuFlyoutItem","props":{"text":"Copy"}}]}]}
            """));

        Assert.Equal(2, stack.Children.Count);
        Assert.Equal("one", Assert.IsType<Label>(stack.Children[0]).Text);
        Assert.Equal("two", Assert.IsType<Label>(stack.Children[1]).Text);
        Assert.NotNull(MenuOn(stack));

        // And a later message about the arrangement still names the slot,
        // while this side still keeps it out of the layout.
        host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":2,"type":"Label"},
              {"id":4,"type":"ContextFlyout"}]}
            """);

        Assert.Single(stack.Children);
        Assert.Equal("one", Assert.IsType<Label>(stack.Children[0]).Text);
    }

    /// <summary>A Border holds ONE view, and the menu is not it.</summary>
    [Fact]
    public void ASingleContentViewKeepsItsContent()
    {
        var host = new Host();

        var border = Assert.IsType<Border>(host.Apply("""
            {"id":1,"type":"Border","arranged":true,"children":[
              {"id":2,"type":"Label","props":{"text":"inside"}},
              {"id":3,"type":"ContextFlyout","arranged":true,"children":[
                {"id":4,"type":"MenuFlyoutItem","props":{"text":"Copy"}}]}]}
            """));

        Assert.Equal("inside", Assert.IsType<Label>(border.Content).Text);
        Assert.NotNull(MenuOn(border));
    }

    /// <summary>
    /// A ScrollView with one child and a menu still holds that child directly.
    /// </summary>
    /// <remarks>
    /// It wraps several children in a stack of its own, and counting the slot as
    /// one of them would wrap a single child for no reason - a stack in the tree
    /// that nothing described.
    /// </remarks>
    [Fact]
    public void AScrollViewDoesNotWrapOneChildBecauseOfAMenu()
    {
        var host = new Host();

        var scroll = Assert.IsType<ScrollView>(host.Apply("""
            {"id":1,"type":"ScrollView","arranged":true,"children":[
              {"id":2,"type":"Label","props":{"text":"inside"}},
              {"id":3,"type":"ContextFlyout","arranged":true,"children":[
                {"id":4,"type":"MenuFlyoutItem","props":{"text":"Copy"}}]}]}
            """));

        Assert.Equal("inside", Assert.IsType<Label>(scroll.Content).Text);
        Assert.NotNull(MenuOn(scroll));
    }
}
