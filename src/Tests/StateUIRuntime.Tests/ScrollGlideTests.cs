// How a released scroller comes to rest, which is arithmetic and nothing else.
//
// The platform decides ONE thing - how far its own deceleration was going - and
// everything after that is here: how many points of the grid that crosses, and
// therefore whose movement takes it there and how long this side's own one
// lasts. So the part that decides how a settle LOOKS is ordinary code that can
// be asked what it answers.
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class ScrollGlideTests
{
    [Theory]
    // One point of the grid every 0.3 seconds, whatever the point is worth - so
    // a phone's card and a desktop's card are each crossed in the same time.
    [InlineData(300, 1000)]
    [InlineData(252, 840)]
    [InlineData(1022, 3406.6666666666665)]
    // A scroller with no grid has nothing to measure a speed against.
    [InlineData(0, 0)]
    public void TheSpeedIsOnePointOfTheGridEveryThirdOfASecond(double interval, double expected)
    {
        Assert.Equal(expected, ScrollGlide.Speed(interval), 6);
    }

    [Theory]
    // A whole point of the grid is the 0.3 seconds that speed says it is.
    [InlineData(300, 300, 300)]
    // And half of one is half as long, which is what makes the shortest
    // corrections the quickest.
    [InlineData(150, 300, 150)]
    [InlineData(120, 300, 120)]
    // Backwards is the same movement the other way.
    [InlineData(-150, 300, 150)]
    public void AMovementTakesItsDistanceAtThatSpeed(
        double distance, double interval, double expected)
    {
        Assert.Equal(expected, ScrollGlide.Length(distance, interval), 6);
    }

    [Fact]
    public void NoMovementIsQuickerThanLeastNorSlowerThanMost()
    {
        // A correction of nothing would be a single frame, which reads as the
        // offset jumping; a run the stated speed would spend seconds crossing
        // would be a slide.
        Assert.Equal(ScrollGlide.Least, ScrollGlide.Length(2, 300), 6);
        Assert.Equal(ScrollGlide.Most, ScrollGlide.Length(3000, 300), 6);
    }

    [Fact]
    public void AMovementOnAScrollerWithNoGridTakesTheLongest()
    {
        // Nothing to derive a speed from, and only a scroller that asked for a
        // shorter throw can get here at all.
        Assert.Equal(ScrollGlide.Most, ScrollGlide.Length(500, 0), 6);
    }

    [Fact]
    public void HowLongAMovementTakesFollowsItsDistanceAndNothingElse()
    {
        // THE CRAWL IS THIS TEST. Nothing about how the reader let go reaches
        // this arithmetic, so one distance is one time - where a platform sent
        // somewhere its own throw was not going stretches its curve to arrive,
        // and stretches it further the more gently it was released.
        Assert.Equal(
            ScrollGlide.Length(120, 300),
            ScrollGlide.Length(120, 300),
            6);

        Assert.True(
            ScrollGlide.Length(60, 300) < ScrollGlide.Length(240, 300),
            "a shorter movement is a quicker one");
    }

    [Theory]
    // On the grid already, going one point on.
    [InlineData(0, 300, 300, 0, 1)]
    [InlineData(600, 300, 300, 0, 1)]
    // Nowhere, which is a release that came back to the card it started on.
    [InlineData(320, 300, 300, 0, 0)]
    // Two and three points on, which is what a throw crosses.
    [InlineData(0, 600, 300, 0, 2)]
    [InlineData(0, 900, 300, 0, 3)]
    // FROM BETWEEN TWO POINTS, which is where a finger actually leaves it: the
    // count is in points of the grid and not in distance, so a jump of 0.6 of a
    // point is still one point and a jump of 1.6 is still two.
    [InlineData(120, 300, 300, 0, 1)]
    [InlineData(120, 600, 300, 0, 2)]
    // Backwards counts the same.
    [InlineData(900, 600, 300, 0, 1)]
    // A grid that starts somewhere else counts from there.
    [InlineData(50, 350, 300, 50, 1)]
    // And with no grid there is nothing to count.
    [InlineData(0, 900, 0, 0, 0)]
    public void AJumpIsCountedInPointsOfTheGrid(
        double from, double to, double interval, double origin, int expected)
    {
        Assert.Equal(expected, ScrollGlide.Cells(from, to, interval, origin));
    }

    [Fact]
    public void OnePointOrLessIsWhereTheMovementBecomesThisSides()
    {
        // The line the whole design turns on, in the terms a reader sees: the
        // number of cards a release was going to cross.
        Assert.Equal(1, ScrollGlide.Reach);

        Assert.True(ScrollGlide.Cells(120, 300, 300, 0) <= ScrollGlide.Reach, "the next card is ours");
        Assert.True(ScrollGlide.Cells(120, 600, 300, 0) > ScrollGlide.Reach, "two cards on is the platform's");
    }

    [Fact]
    public void TheSettleArrivesWithoutPassingItsLanding()
    {
        // The curve every movement here is drawn on. It has to arrive AT the
        // card and stop: overshooting and coming back was tried and rejected -
        // over the short distances this curve is used for it reads as a wobble.
        Assert.Equal(0, Easing.CubicOut.Ease(0), 3);
        Assert.Equal(1, Easing.CubicOut.Ease(1), 3);

        foreach (double t in new[] { 0.25, 0.5, 0.75, 0.9 })
        {
            Assert.True(Easing.CubicOut.Ease(t) <= 1, $"a settle never passes its landing, at {t}");
            Assert.True(Easing.CubicOut.Ease(t) > t, $"and it leaves faster than it arrives, at {t}");
        }
    }
}
