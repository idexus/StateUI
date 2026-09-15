// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What one scroller's movement keeps that a scroller with no platform under it
// can still be asked: what an offset is held to, and the place a relayout has
// to give back.
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class ScrollMovementTests
{
    /// <summary>
    /// WHAT AN OFFSET IS HELD TO: the start always, and the end - the content
    /// less the visible part - only once the content and the viewport have
    /// both been measured. An unmeasured viewport reads -1, and against an
    /// empty content that is an end one unit from the start - which held every
    /// offset a state landed before the first layout to 1.
    /// </summary>
    [Theory]
    // Inside the run, nothing is moved.
    [InlineData(100, 1000, 400, 100)]
    [InlineData(300, 900, 300, 300)]
    // Before the start, which is what a scroller BOUNCING past it shows.
    [InlineData(-20, 900, 300, 0)]
    [InlineData(-40, 1000, 400, 0)]
    [InlineData(-312, 1000, 400, 0)]
    // Past the end: the furthest it can go is the content less the visible
    // part.
    [InlineData(700, 900, 300, 600)]
    [InlineData(900, 1000, 400, 600)]
    // A content no longer than its viewport has no length to hold against, so
    // only the start holds.
    [InlineData(50, 100, 300, 50)]
    // And with nothing measured there is no end either.
    [InlineData(900, 0, 0, 900)]
    [InlineData(300, 0, 0, 300)]
    [InlineData(300, 0, -1, 300)]
    [InlineData(-10, 0, 0, 0)]
    public void AnOffsetIsHeldToWhatHasBeenMeasured(
        double offset, double content, double visible, double expected)
    {
        Assert.Equal(expected, StateUIRenderer.Reachable(offset, content, visible), 6);
    }

    /// <summary>
    /// A scroller reshaped after the offset's channel put it somewhere asks to
    /// go back there - which is what keeps a card, a row or a page where it was
    /// left when a window is resized or a phone turned, and why the place an
    /// application wrote is the place kept.
    /// </summary>
    /// <remarks>
    /// The place is asked for in the scroller's own terms rather than watched
    /// for: a control with no platform under it has no offset that moves, so
    /// what a platform then does with the request is the platform's, and is
    /// what the gallery is walked through by hand for.
    /// </remarks>
    [Fact]
    public void AReshapedScrollerAsksForThePlaceItWasLeftAt()
    {
        var host = new Host();

        var scroll = (ScrollView)host.Apply("""
            {"id":1,"type":"ScrollView","props":{"orientation":1},
             "events":{"scrollStopped":7},"arranged":true,"children":[
               {"id":2,"type":"ColorBox","props":{"width":900,
                "height":100}}]}
            """);

        List<Point> asked = [];

        ((IScrollViewController)scroll).ScrollToRequested +=
            (_, e) => asked.Add(new Point(e.ScrollX, e.ScrollY));

        // Laid out with a run three viewports long, and put 270 along by the
        // offset's channel - the road a written state takes.
        ((IView)scroll).Arrange(new Rect(0, 0, 300, 100));
        host.Renderer.MovementOf(scroll).Walked.Write([270, 0]);

        asked.Clear();

        // AND THEN RESHAPED, the way a turned phone or a dragged window
        // reshapes one.
        ((IView)scroll).Arrange(new Rect(0, 0, 500, 100));

        Assert.Contains(new Point(270, 0), asked);
    }

    /// <summary>
    /// And one that has never been anywhere asks for nothing: a scroller at its
    /// beginning has no place to lose, and a request out of every resize of
    /// every page is a movement nobody asked for.
    /// </summary>
    [Fact]
    public void AScrollerThatNeverMovedAsksForNothing()
    {
        var host = new Host();

        var scroll = (ScrollView)host.Apply("""
            {"id":1,"type":"ScrollView","props":{"orientation":1},
             "events":{"scrollStopped":7},"arranged":true,"children":[
               {"id":2,"type":"ColorBox","props":{"width":900,
                "height":100}}]}
            """);

        List<Point> asked = [];

        ((IScrollViewController)scroll).ScrollToRequested +=
            (_, e) => asked.Add(new Point(e.ScrollX, e.ScrollY));

        ((IView)scroll).Arrange(new Rect(0, 0, 300, 100));
        host.Renderer.MovementOf(scroll);
        ((IView)scroll).Arrange(new Rect(0, 0, 500, 100));

        Assert.Empty(asked);
    }

    /// <summary>
    /// A movement of the reader's that comes to rest is reported, once, to the
    /// handler the tree gave the scroller's rest.
    /// </summary>
    /// <remarks>
    /// A scroller arms its rest only with a platform behind it, so a stand-in
    /// handler is given; the offset moving is the report a platform raises as
    /// the reader scrolls.
    /// </remarks>
    [Fact]
    public void AMovementOfTheReadersThatComesToRestIsReported()
    {
        var host = new Host();

        var scroll = (ScrollView)host.Apply("""
            {"id":1,"type":"ScrollView","events":{"scrollStopped":7},"arranged":true,"children":[
               {"id":2,"type":"ColorBox","props":{"width":100,"height":900}}]}
            """);

        scroll.Handler = new StandInHandler();
        host.Dispatched.Clear();

        ((IScrollViewController)scroll).SetScrolledPosition(0, 120);

        Assert.Equal([(7, (string?)null)], host.Dispatched);
    }
}
