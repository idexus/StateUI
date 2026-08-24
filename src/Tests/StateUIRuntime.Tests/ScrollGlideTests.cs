// What a released scroller does, which is arithmetic and nothing else.
//
// The whole reason these can be written at all is the reason they matter: the
// distance, the time and the curve are worked out from one number a platform
// states, so everything AFTER that number is ordinary code that can be asked
// what it answers. A platform supplies a speed; nothing else about it reaches
// the decision, so the decision is the same on all of them.
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class ScrollGlideTests
{
    [Theory]
    // One point of the grid every 0.3 seconds, whatever the point is worth.
    [InlineData(300, 1000)]
    [InlineData(252, 840)]
    [InlineData(1022, 3406.6666666666665)]
    // A scroller with no grid has nothing to measure a floor against.
    [InlineData(0, 0)]
    public void TheFloorIsOnePointOfTheGridEveryThirdOfASecond(double interval, double expected)
    {
        Assert.Equal(expected, ScrollGlide.Slowest(interval), 6);
    }

    [Theory]
    // The speed it was let go at, carried for the throw's own time.
    [InlineData(0, 1000, 1, 400)]
    [InlineData(500, 1000, 1, 900)]
    // Backwards is the same throw the other way.
    [InlineData(500, -1000, 1, 100)]
    // Half the momentum is half the reach, and none of it stops where it was.
    [InlineData(0, 1000, 0.5, 200)]
    [InlineData(0, 1000, 0, 0)]
    // A momentum below zero is not a throw backwards - it is no throw.
    [InlineData(0, 1000, -2, 0)]
    // And a scroller nobody threw goes nowhere, whatever it is allowed.
    [InlineData(140, 0, 1, 140)]
    public void AThrowReachesAsFarAsItsSpeedCarriesIt(
        double offset, double velocity, double momentum, double expected)
    {
        Assert.Equal(expected, ScrollGlide.Thrown(offset, velocity, momentum), 6);
    }

    [Fact]
    public void ANudgeIsTidiedUpAtTheFloorSpeedAndDoesNotSpring()
    {
        // Half a card, let go of at almost nothing: half of the 0.3 seconds a
        // whole card takes. THE CRAWL IS THIS TEST - the time follows the
        // distance, and nothing about it follows how slowly it was released.
        (double length, bool springs) = ScrollGlide.Movement(distance: 150, speed: 40, interval: 300);

        Assert.Equal(150, length, 6);
        Assert.False(springs);
    }

    [Fact]
    public void TheSameNudgeTakesTheSameTimeWhateverSpeedItWasLetGoAt()
    {
        // Every speed under the floor, over one distance: one answer. This is
        // the whole of what "the platform decides nothing" buys.
        double[] lengths =
        [
            ScrollGlide.Movement(120, 0, 300).Length,
            ScrollGlide.Movement(120, 5, 300).Length,
            ScrollGlide.Movement(120, 400, 300).Length,
            ScrollGlide.Movement(120, 999, 300).Length,
        ];

        Assert.All(lengths, length => Assert.Equal(lengths[0], length, 6));
    }

    [Fact]
    public void AThrowIsCarriedOverOneTimeHoweverFarItWent()
    {
        // Over the floor is a throw, and a throw takes what a throw takes -
        // one card or three.
        (double near, bool nearSprings) = ScrollGlide.Movement(distance: 300, speed: 1200, interval: 300);
        (double far, bool farSprings) = ScrollGlide.Movement(distance: 900, speed: 4000, interval: 300);

        Assert.Equal(ScrollGlide.Throw, near, 6);
        Assert.Equal(ScrollGlide.Throw, far, 6);
        Assert.True(nearSprings);
        Assert.True(farSprings);
    }

    [Fact]
    public void AMovementNobodyThrewIsMadeAtTheFloorSpeed()
    {
        // An author assigning a position, and a reader letting go without
        // throwing, ask for the same movement - which is why one card moves the
        // same way whoever moved it.
        (double asked, bool askedSprings) = ScrollGlide.Movement(distance: 300, speed: 0, interval: 300);

        Assert.Equal(ScrollGlide.Cell * 1000, asked, 6);
        Assert.False(askedSprings);
    }

    [Fact]
    public void AScrollerWithNoGridHasNoNudge()
    {
        // Nothing to measure a floor against, so every movement it makes is the
        // thrown one. Only a scroller asking for a shortened throw gets here.
        (double length, bool springs) = ScrollGlide.Movement(distance: 40, speed: 10, interval: 0);

        Assert.Equal(ScrollGlide.Throw, length, 6);
        Assert.True(springs);
    }

    [Fact]
    public void NoMovementIsQuickerThanLeastNorSlowerThanMost()
    {
        // A correction of nothing would be a single frame, and a run the floor
        // speed would spend seconds crossing would be a slide.
        Assert.Equal(ScrollGlide.Least, ScrollGlide.Movement(2, 0, 300).Length, 6);
        Assert.Equal(ScrollGlide.Most, ScrollGlide.Movement(3000, 0, 300).Length, 6);
    }

    [Fact]
    public void TheSpringOvershootsItsLandingAndComesBack()
    {
        // The curve a throw is drawn on has to go PAST the card and return, or
        // there is no spring - so this is a contract with MAUI's own easing and
        // not a restatement of it. It still has to start where it started and
        // end where it is going.
        Assert.Equal(0, Easing.SpringOut.Ease(0), 3);
        Assert.Equal(1, Easing.SpringOut.Ease(1), 3);
        Assert.True(Easing.SpringOut.Ease(0.6) > 1, "a spring passes its landing");
        Assert.True(Easing.SpringOut.Ease(0.6) < 1.25, "and only just");
    }

    [Fact]
    public void TheSettleArrivesWithoutPassingItsLanding()
    {
        // The other curve, and the reason there are two: a nudge that overshot
        // would wobble over a distance too short to read as a movement at all.
        Assert.Equal(0, Easing.CubicOut.Ease(0), 3);
        Assert.Equal(1, Easing.CubicOut.Ease(1), 3);

        foreach (double t in new[] { 0.25, 0.5, 0.75, 0.9 })
        {
            Assert.True(Easing.CubicOut.Ease(t) <= 1, $"a settle never passes its landing, at {t}");
        }
    }
}
