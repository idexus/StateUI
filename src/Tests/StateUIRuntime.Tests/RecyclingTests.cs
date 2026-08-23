// The pool: a control whose row scrolled away, given to the row that arrived.
//
// What every test here reads is CONTROL IDENTITY - the same object or a
// different one - because that is the whole of what recycling is. The shapes
// are written as bare numbers: the Swift side works out what a subtree looks
// like and this side only ever compares two of them, so a number here stands
// for "these two rows are alike" and nothing more.
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

    /// <summary>The row at that place, and the label under it.</summary>
    private static (View Row, Label Label) Row(AbsoluteLayout layout, int at)
    {
        var row = Assert.IsType<HorizontalStackLayout>(layout.Children[at]);
        return (row, Assert.IsType<Label>(row.Children[0]));
    }

    /// <summary>
    /// A row that leaves and a row of the same shape that arrives are one
    /// control - the whole point.
    /// </summary>
    [Fact]
    public void ARowThatArrivesTakesTheControlOfOneThatLeft()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 7), ("2", 7)));
        (View leaving, Label label) = Row(layout, 0);

        host.Apply(Run(("2", 7), ("3", 7)));

        (View arrived, Label arrivedLabel) = Row(layout, 1);

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
        (View leaving, _) = Row(layout, 0);

        host.Apply(Run(("2", 7), ("3", 99)));

        Assert.NotSame(leaving, Row(layout, 1).Row);
    }

    /// <summary>
    /// A row with no shape is one the Swift side says holds state nothing
    /// describes, so it is neither kept nor handed out.
    /// </summary>
    [Fact]
    public void ARowWithNoShapeIsNeverPooled()
    {
        var host = new Host();

        var layout = (AbsoluteLayout)host.Apply(Run(("1", 0), ("2", 0)));
        (View leaving, _) = Row(layout, 0);

        host.Apply(Run(("2", 0), ("3", 0)));

        Assert.NotSame(leaving, Row(layout, 1).Row);
    }

    /// <summary>
    /// A layout that was never told its children are rows keeps nothing -
    /// which is every layout in the library but the two this one is for.
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

        (View row, Label label) = Row(layout, 1);

        host.Apply("""
            {"id":1,"type":"AbsoluteLayout","children":[
              {"id":"3","type":"HorizontalStackLayout","children":[
                {"id":"3.a","type":"Label","props":{"text":"changed"}}]}]}
            """);

        Assert.Same(row, layout.Children[1]);
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

        var row = Assert.IsType<HorizontalStackLayout>(layout.Children[1]);
        var entry = Assert.IsType<Entry>(row.Children[0]);

        host.Dispatched.Clear();
        entry.Text = "typed";

        Assert.Single(host.Dispatched);
        Assert.Equal((5, "\"typed\""), host.Dispatched[0]);
    }

    /// <summary>
    /// A pool does not grow: a list scrolled far enough keeps a window's worth
    /// of controls and no more, which is the memory a recycler is meant to
    /// save rather than spend.
    /// </summary>
    [Fact]
    public void ThePoolIsBounded()
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

        Assert.Equal(4, layout.Children.Count);
        Assert.True(
            StateUIRenderer.PooledBy(layout) <= 32,
            $"the pool holds {StateUIRenderer.PooledBy(layout)} controls, which is past its cap");
    }
}
