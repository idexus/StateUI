// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control the tree has let go reports nothing.
//
// Its handlers left the tree with its element, and ids are never reused, so a
// report from it reaches nobody - and says so in the log, blaming a page
// released too early. A report can arrive a turn late by design: a frame
// watcher settling, a page's lifecycle announced after an assigned pop.
using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class LetGoTests
{
    /// <summary>The control the tree still describes reports - what the others are measured against.</summary>
    [Fact]
    public void AControlTheTreeKeepsReports()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VStack","arranged":true,"children":[
              {"id":"b","type":"Button","props":{"text":"go"},"events":{"clicked":7}}]}
            """);

        host.Renderer.Raise(stack.Children[0], HostEvent.Clicked);

        Assert.Equal([7], host.Dispatched.Select(each => each.Id));
    }

    /// <summary>A control taken out of its layout reports nothing.</summary>
    [Fact]
    public void AControlTheTreeRemovedReportsNothing()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VStack","arranged":true,"children":[
              {"id":"b","type":"Button","props":{"text":"go"},"events":{"clicked":7}},
              {"id":"l","type":"Label","props":{"text":"stays"}}]}
            """);
        var button = stack.Children[0];

        host.Apply("""
            {"id":1,"type":"VStack","arranged":true,"children":[
              {"id":"l","type":"Label","props":{"text":"stays"}}]}
            """);

        host.Renderer.Raise(button, HostEvent.Clicked);

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// And one INSIDE what was taken out - which keeps its parent, so only the
    /// root of what left can say it has.
    /// </summary>
    [Fact]
    public void AControlUnderWhatTheTreeRemovedReportsNothing()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VStack","arranged":true,"children":[
              {"id":"row","type":"HStack","arranged":true,"children":[
                {"id":"b","type":"Button","props":{"text":"go"},"events":{"clicked":7}}]},
              {"id":"l","type":"Label","props":{"text":"stays"}}]}
            """);
        var button = ((HorizontalStackLayout)stack.Children[0]).Children[0];

        host.Apply("""
            {"id":1,"type":"VStack","arranged":true,"children":[
              {"id":"l","type":"Label","props":{"text":"stays"}}]}
            """);

        host.Renderer.Raise(button, HostEvent.Clicked);

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// A page an assignment took off its stack reports nothing - its lifecycle
    /// is announced a turn late, after the render that let it go.
    /// </summary>
    /// <remarks>
    /// Measured on Windows, Navigation stack's Go home: nine of twelve reports
    /// to handlers nobody held came from <c>PagePresenter.Announce</c>.
    /// </remarks>
    [Fact]
    public void APageTheTreePoppedReportsNothing()
    {
        var host = new Host();
        var pages = new PagePresenter(host.Renderer, (message, exception) => Assert.Fail($"{message}\n{exception}"));

        var navigation = Assert.IsType<NavigationPage>(pages.Render(null, Host.Parse(Stack(Page(2, "Home"), Page(3, "Detail")))));
        Page detail = navigation.Navigation.NavigationStack[^1];

        pages.Render(navigation, Host.Parse(Stack(Page(2, "Home"))));
        host.Dispatched.Clear();

        host.Renderer.Raise(detail, HostEvent.Disappearing);

        Assert.Empty(host.Dispatched);
    }

    /// <summary>And the content a Border held, once the Border holds nothing.</summary>
    [Fact]
    public void TheContentTheTreeTookOutOfABorderReportsNothing()
    {
        var host = new Host();
        var border = (Border)host.Apply("""
            {"id":1,"type":"Border","arranged":true,"children":[
              {"id":"b","type":"Button","props":{"text":"go"},"events":{"clicked":7}}]}
            """);
        View button = Assert.IsAssignableFrom<View>(border.Content);

        host.Apply("""{"id":1,"type":"Border","arranged":true,"children":[]}""");

        host.Renderer.Raise(button, HostEvent.Clicked);

        Assert.Empty(host.Dispatched);
    }

    /// <summary>A page of a stack, with a handler for its disappearing.</summary>
    private static string Page(int id, string title) =>
        $$$"""{"id":{{{id}}},"type":"Page","props":{"title":"{{{title}}}"},"events":{"disappearing":{{{id * 10}}}},"arranged":true,"children":[{"id":{{{id + 100}}},"type":"Label","props":{"text":"{{{title}}}"}}]}""";

    /// <summary>A NavigationStack over the pages named, root first.</summary>
    private static string Stack(params string[] pages) =>
        $$$"""{"id":1,"type":"NavigationStack","events":{"popped":7},"arranged":true,"children":[{{{string.Join(",", pages)}}}]}""";

    /// <summary>A control thrown away for a new one reports nothing.</summary>
    [Fact]
    public void AControlTheTreeReplacedReportsNothing()
    {
        var host = new Host();
        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VStack","arranged":true,"children":[
              {"id":"b","type":"Button","props":{"text":"go"},"events":{"clicked":7}}]}
            """);
        var button = stack.Children[0];

        host.Apply("""
            {"id":1,"type":"VStack","arranged":true,"children":[
              {"id":"b","type":"Button","replace":true,"props":{"text":"go"},"events":{"clicked":8}}]}
            """);

        host.Renderer.Raise(button, HostEvent.Clicked);

        Assert.Empty(host.Dispatched);
    }
}
