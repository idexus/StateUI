// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The pool: a control whose row scrolled away, given to the row that arrived.
//
// What every test here reads is CONTROL IDENTITY - the same object or a
// different one - because that is the whole of what recycling is. The shapes
// are written as bare numbers: the Swift side works out what a subtree looks
// like and this side only ever compares two of them, so a number here stands
// for "these two rows are alike" and nothing more.
//
// A row is found by its IDENTITY rather than by where it sits, because a
// recycling layout no longer keeps its children in the order the message
// describes them - see StateUIRenderer.Settle.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class RecyclingTests
{
    /// <summary>
    /// A recycling layout holding the rows named, each of the shape given.
    /// </summary>
    /// <param name="rows">the row identity and its shape, in order</param>
    private static string Run(params (string Id, ulong Shape)[] rows)
    {
        IEnumerable<string> children = rows.Select(row => $$$"""
            {"id":"{{{row.Id}}}","type":"HorizontalStackLayout","arranged":true,
             "shape":{{{row.Shape}}},
             "children":[{"id":"{{{row.Id}}}.a","type":"Label",
                          "props":{"text":"{{{row.Id}}}"}}]}
            """);

        return $$$"""
            {"id":1,"type":"AbsoluteLayout","recycles":true,"arranged":true,
             "children":[{{{string.Join(",", children)}}}]}
            """;
    }

    /// <summary>
    /// The same, for rows the AUTHOR did not name: the identity the renderer
    /// assigned is the number, and each row holds one label numbered after it.
    /// </summary>
    /// <param name="rows">the row numbers, in order</param>
    private static string Numbered(params int[] rows)
    {
        IEnumerable<string> children = rows.Select(row => $$$"""
            {"id":{{{row}}},"type":"HorizontalStackLayout","arranged":true,"shape":7,
             "children":[{"id":{{{row}}}00,"type":"Label"}]}
            """);

        return $$$"""
            {"id":1,"type":"AbsoluteLayout","recycles":true,"arranged":true,
             "children":[{{{string.Join(",", children)}}}]}
            """;
    }

    /// <summary>The row of that identity, wherever it now sits.</summary>
    private static View Find(AbsoluteLayout layout, string id) =>
        layout.Children.OfType<View>()
            .Single(child => StateUIRenderer.KeyOf(child) == $"\"{id}\"");

    /// <summary>The row of that identity, and the label under it.</summary>
    private static (View Row, Label Label) Row(AbsoluteLayout layout, string id)
    {
        View row = Find(layout, id);

        return (row, Assert.IsType<Label>(Assert.IsType<HorizontalStackLayout>(row).Children[0]));
    }

    /// <summary>The children this layout is holding for a row that has not come.</summary>
    private static List<View> Spares(AbsoluteLayout layout) =>
        [.. layout.Children.OfType<View>().Where(child => StateUIRenderer.KeyOf(child) is null)];

    /// <summary>
    /// A row that leaves and a row of the same shape that arrives are one
    /// control - the whole point.
    /// </summary>
    [Fact]
    public void ARowThatArrivesTakesTheControlOfOneThatLeft()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 7), ("2", 7)));
        (View leaving, Label label) = Row(layout, "1");

        host.Apply(Run(("2", 7), ("3", 7)));

        (View arrived, Label arrivedLabel) = Row(layout, "3");

        Assert.Same(leaving, arrived);
        Assert.Same(label, arrivedLabel);
        Assert.Equal("3", arrivedLabel.Text);
        Assert.Equal(2, layout.Children.Count);
    }

    /// <summary>
    /// A row of ANOTHER shape is built rather than adopted. Two shapes mean
    /// the two rows name different properties, so a control from one would
    /// arrive carrying a value the other never said anything about.
    /// </summary>
    [Fact]
    public void ARowOfAnotherShapeIsBuiltInstead()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 7), ("2", 7)));
        (View leaving, _) = Row(layout, "1");

        host.Apply(Run(("2", 7), ("3", 99)));

        Assert.NotSame(leaving, Row(layout, "3").Row);
    }

    /// <summary>
    /// A row with no shape is one the Swift side says holds state nothing
    /// describes, so it is neither kept nor handed out - and it LEAVES, rather
    /// than waiting among the children as a spare would.
    /// </summary>
    [Fact]
    public void ARowWithNoShapeIsNeverPooled()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 0), ("2", 0)));
        (View leaving, _) = Row(layout, "1");

        host.Apply(Run(("2", 0), ("3", 0)));

        Assert.NotSame(leaving, Row(layout, "3").Row);
        Assert.Equal(2, layout.Children.Count);
        Assert.DoesNotContain(leaving, layout.Children);
    }

    /// <summary>
    /// A layout that was never told its children are rows keeps nothing -
    /// which is every layout in the library but the two this one is for - and
    /// its children stay in the order the message describes.
    /// </summary>
    [Fact]
    public void ALayoutThatDoesNotRecycleKeepsNothing()
    {
        var host = new Host();

        string Plain(string first, string second) => $$$"""
            {"id":1,"type":"AbsoluteLayout","arranged":true,"children":[
              {"id":"{{{first}}}","type":"HorizontalStackLayout","arranged":true,"shape":7,
               "children":[{"id":"{{{first}}}.a","type":"Label"}]},
              {"id":"{{{second}}}","type":"HorizontalStackLayout","arranged":true,"shape":7,
               "children":[{"id":"{{{second}}}.a","type":"Label"}]}]}
            """;

        var layout = (AbsoluteLayout)host.Apply(Plain("1", "2"));
        var leaving = (HorizontalStackLayout)layout.Children[0];

        host.Apply(Plain("2", "3"));

        Assert.NotSame(leaving, layout.Children[1]);
        Assert.Equal("\"2\"", StateUIRenderer.KeyOf((View)layout.Children[0]));
        Assert.Equal("\"3\"", StateUIRenderer.KeyOf((View)layout.Children[1]));
    }

    /// <summary>
    /// An adopted control answers to the identity it was given, so the next
    /// message about that row finds it - the sparse form included, which is
    /// how a list of a thousand rows costs one message when one changes.
    /// </summary>
    [Fact]
    public void AnAdoptedRowIsFoundAgainByItsNewIdentity()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 7), ("2", 7)));
        host.Apply(Run(("2", 7), ("3", 7)));

        (View row, Label label) = Row(layout, "3");

        host.Apply("""
            {"id":1,"type":"AbsoluteLayout","children":[
              {"id":"3","type":"HorizontalStackLayout","children":[
                {"id":"3.a","type":"Label","props":{"text":"changed"}}]}]}
            """);

        Assert.Same(row, Row(layout, "3").Row);
        Assert.Equal("changed", label.Text);
    }

    /// <summary>
    /// An adopted control is not subscribed to its own reports twice.
    /// </summary>
    /// <remarks>
    /// Every subscription this renderer makes is made once and lives as long
    /// as the control does, guarded by what the control has already been
    /// subscribed to. That guard hangs off the element, and adopting a row
    /// gives the control a new one - so without carrying the guard across,
    /// every adoption would add another subscription and the control would
    /// report once per row it had ever been.
    /// </remarks>
    [Fact]
    public void AnAdoptedRowDoesNotReportTwice()
    {
        var host = new Host();

        string Watching(string first, string second) => $$$"""
            {"id":1,"type":"AbsoluteLayout","recycles":true,"arranged":true,"children":[
              {"id":"{{{first}}}","type":"HorizontalStackLayout","arranged":true,"shape":7,
               "children":[{"id":"{{{first}}}.a","type":"Entry","props":{"text":"a"},
                            "events":{"textChanged":5}}]},
              {"id":"{{{second}}}","type":"HorizontalStackLayout","arranged":true,"shape":7,
               "children":[{"id":"{{{second}}}.a","type":"Entry","props":{"text":"b"},
                            "events":{"textChanged":5}}]}]}
            """;

        var layout = (AbsoluteLayout)host.Apply(Watching("1", "2"));
        host.Apply(Watching("2", "3"));

        var row = Assert.IsType<HorizontalStackLayout>(Find(layout, "3"));
        var entry = Assert.IsType<Entry>(row.Children[0]);

        host.Dispatched.Clear();
        entry.Text = "typed";

        Assert.Single(host.Dispatched);
        Assert.Equal((5, "\"typed\""), host.Dispatched[0]);
    }

    // MARK: - A spare is not a child anyone can name

    /// <summary>
    /// A row whose control is being kept stays among the children and is
    /// HIDDEN, rather than being taken out of the tree and put back.
    /// </summary>
    /// <remarks>
    /// This is what the whole design buys: a platform view taken down and put
    /// up again is what one scrolled row used to cost, and it was two thirds of
    /// the message. See <see cref="StateUIRenderer.Settle{T}"/>.
    /// </remarks>
    [Fact]
    public void ARowWhoseControlIsKeptWaitsHiddenAmongTheChildren()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 7), ("2", 7)));
        (View leaving, _) = Row(layout, "1");

        host.Apply(Run(("2", 7)));

        Assert.Contains(leaving, layout.Children);
        Assert.False(leaving.IsVisible);
        Assert.Equal([leaving], Spares(layout));
    }

    /// <summary>A spare handed to an arriving row is shown again.</summary>
    [Fact]
    public void AnAdoptedSpareIsShownAgain()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 7), ("2", 7)));
        (View leaving, _) = Row(layout, "1");

        host.Apply(Run(("2", 7)));
        host.Apply(Run(("2", 7), ("3", 7)));

        Assert.Same(leaving, Row(layout, "3").Row);
        Assert.True(leaving.IsVisible);
        Assert.Empty(Spares(layout));
    }

    /// <summary>
    /// THE INVARIANT: a spare is not a child anyone can name, so a message
    /// about the row it used to be is DRIFT and not a match.
    /// </summary>
    /// <remarks>
    /// The reading this guards against is the ordinary one: a reader scrolls a
    /// row out of the window and straight back in. Were the spare still
    /// answering to the identity it had, the message would be applied to it and
    /// it would stay invisible, with nothing failing anywhere. Refused, it
    /// becomes the resync the session already knows how to make.
    /// </remarks>
    [Fact]
    public void ASpareIsNotMatchedByTheIdentityItHad()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 7), ("2", 7)));
        host.Apply(Run(("2", 7)));

        Assert.Throws<SwiftTreeDriftException>(() => host.Apply("""
            {"id":1,"type":"AbsoluteLayout","children":[
              {"id":"1","type":"HorizontalStackLayout","children":[
                {"id":"1.a","type":"Label","props":{"text":"back"}}]}]}
            """));
    }

    /// <summary>
    /// And no act can aim at one either: the name an author wrote stops
    /// answering the moment the row's control is kept for somebody else.
    /// </summary>
    [Fact]
    public void ASpareIsNotFoundByTheNameItHad()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 7), ("2", 7)));

        Assert.NotNull(host.Renderer.Named("1"));

        host.Apply(Run(("2", 7)));

        Assert.Null(host.Renderer.Named("1"));
    }

    /// <summary>
    /// The other half of the same map, for a row the AUTHOR did not name: a
    /// <c>ControlState</c> aims by the identity the renderer assigned, and that
    /// has to stop answering too.
    /// </summary>
    [Fact]
    public void ASpareIsNotFoundByTheIdentityTheRendererGaveIt()
    {
        var host = new Host();

        host.Apply(Numbered(2, 3));

        Assert.NotNull(host.Renderer.Tracked("2"));

        host.Apply(Numbered(3));

        Assert.Null(host.Renderer.Tracked("2"));
    }

    /// <summary>
    /// And a row's DESCENDANT stops answering too, once the row it was in has
    /// been given to another one.
    /// </summary>
    /// <remarks>
    /// Retiring a row empties the aiming maps of the row's own identity, which
    /// its children never had - so without a check at the answer, an act aimed
    /// at a control INSIDE a scrolled-away row would resolve to the very
    /// control another row is now showing, and land visibly on somebody else's
    /// row. <c>Named</c> and <c>Tracked</c> therefore refuse a view whose
    /// element no longer carries the identity being asked for.
    /// </remarks>
    [Fact]
    public void AControlInsideAnAdoptedSpareIsNotFoundByTheIdentityItHad()
    {
        var host = new Host();

        host.Apply(Numbered(2, 3));

        (VisualElement View, string Type)? inside = host.Renderer.Tracked("200");
        Assert.NotNull(inside);

        // Row 2 scrolls away and row 4 arrives, taking its control - label 200
        // is now label 400, on screen, in somebody else's row.
        host.Apply(Numbered(3));
        host.Apply(Numbered(3, 4));

        Assert.Same(inside!.Value.View, host.Renderer.Tracked("400")?.View);
        Assert.Null(host.Renderer.Tracked("200"));
    }

    /// <summary>
    /// A pool does not grow, and neither do the children it now waits in: a
    /// list scrolled far enough keeps a window's worth of controls and no more,
    /// which is the memory a recycler is meant to save rather than spend.
    /// </summary>
    [Fact]
    public void NeitherThePoolNorTheChildrenGrowWithoutBound()
    {
        var host = new Host();

        // Every row a shape of its own, so nothing is ever adopted and the
        // pool only ever fills.
        (string, ulong)[] Wave(int from) =>
            [.. Enumerable.Range(from, 4).Select(number => ($"r{number}", (ulong)number))];

        var layout = (AbsoluteLayout)host.Apply(Run(Wave(0)));

        for (int wave = 1; wave < 60; wave++)
        {
            host.Apply(Run(Wave(wave * 4)));
        }

        Assert.Equal(4, layout.Children.Count - Spares(layout).Count);

        Assert.True(
            StateUIRenderer.PooledBy(layout) <= 32,
            $"the pool holds {StateUIRenderer.PooledBy(layout)} controls, which is past its cap");

        Assert.True(
            layout.Children.Count <= 4 + 32,
            $"the layout has {layout.Children.Count} children, which is past the window "
                + "plus the pool's cap");
    }
}
