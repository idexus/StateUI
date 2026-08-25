// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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
    // The CROSSING is one point of the grid every 0.3 seconds, whatever the
    // point is worth - so a phone's card and a desktop's card are crossed in the
    // same time.
    [InlineData(300, 1000)]
    [InlineData(252, 840)]
    [InlineData(1022, 3406.6666666666665)]
    // A scroller with no grid has nothing to measure a speed against.
    [InlineData(0, 0)]
    public void TheCrossingIsOnePointOfTheGridEveryThirdOfASecond(double interval, double expected)
    {
        Assert.Equal(expected, ScrollGlide.Speed(interval), 6);
    }

    [Theory]
    // A whole point of the grid: 300ms crossing it, 200 landing on it.
    [InlineData(300, 300, 500)]
    // Half of one crosses in half the time and lands in the same, so it is 350
    // rather than 250 - the landing is not shared out.
    [InlineData(150, 300, 350)]
    [InlineData(30, 300, 230)]
    // And the smallest movement there is still takes the landing.
    [InlineData(1, 300, 201)]
    // Backwards is the same movement the other way.
    [InlineData(-150, 300, 350)]
    public void AMovementIsItsCrossingPlusItsLanding(
        double distance, double interval, double expected)
    {
        Assert.Equal(expected, ScrollGlide.Length(distance, interval), 6);
    }

    [Fact]
    public void ONLYTheCrossingFollowsTheDistanceLeftToGo()
    {
        // Take the landing off both and what is left is proportional: a third of
        // a point crosses in a third of the time a whole one does. That is the
        // half of the model a fixed time would take away.
        double landing = ScrollGlide.Landing * 1000;
        double whole = ScrollGlide.Length(300, 300) - landing;

        Assert.Equal(whole / 2, ScrollGlide.Length(150, 300) - landing, 6);
        Assert.Equal(whole / 3, ScrollGlide.Length(100, 300) - landing, 6);
        Assert.Equal(whole / 10, ScrollGlide.Length(30, 300) - landing, 6);
    }

    [Fact]
    public void EveryMovementKeepsTheWholeLandingHoweverShortItIs()
    {
        // The other half, and the one a reader notices as the difference between
        // settling and snapping: no movement is ever shorter than the landing.
        double landing = ScrollGlide.Landing * 1000;

        foreach (double distance in new[] { 0.5, 2, 20, 90, 300 })
        {
            Assert.True(
                ScrollGlide.Length(distance, 300) >= landing,
                $"a movement of {distance} keeps its landing");
        }
    }

    [Theory]
    // No limit asked for, so a throw of any length is left alone.
    [InlineData(1500, 0, 300, 0, 0, 1500)]
    // One point: a throw across five is brought back to one.
    [InlineData(1500, 0, 300, 0, 1, 300)]
    // Backwards too.
    [InlineData(-1500, 0, 300, 0, 1, -300)]
    // Under the limit, nothing is taken away.
    [InlineData(300, 0, 300, 0, 1, 300)]
    [InlineData(0, 0, 300, 0, 1, 0)]
    // COUNTED FROM WHERE THE RELEASE STARTED: a finger that landed on 0 and
    // dragged to 250 - most of the way to the next point - still gets one
    // point, not the two a throw counted from 250 would allow.
    [InlineData(900, 0, 300, 0, 1, 300)]
    // And two allowed is two, from wherever the drag began.
    [InlineData(1500, 0, 300, 0, 2, 600)]
    // A grid that starts somewhere else counts from there.
    [InlineData(950, 50, 300, 50, 1, 350)]
    public void AReleaseIsHeldToTheMostPointsItMayCross(
        double to, double from, double interval, double origin, int most, double expected)
    {
        Assert.Equal(expected, ScrollGlide.Held(to, from, interval, origin, most), 6);
    }

    [Theory]
    // A TURN WORTH A NOTCH STILL MOVES A POINT: the wheel is worth 139 and the
    // card 705, so rounding alone would leave a carousel refusing to turn
    // however long the reader spun it - and a touchpad's swipe of a fifth of a
    // card falling back onto the card it left.
    [InlineData(139, 0, 0, 705, 0, 139, 705)]
    [InlineData(-139, 0, 0, 705, 0, 139, -705)]
    // UNDER that, nothing is forced and the nearest point wins - which is where
    // it started, so a jiggle moves nothing.
    [InlineData(40, 0, 0, 705, 0, 139, 0)]
    // Over it and going further, the rounding is the whole of the answer.
    [InlineData(1600, 0, 0, 705, 0, 139, 1410)]
    // A turn worth MORE than a point over rows of 44 is three of them, and the
    // floor has nothing to add.
    [InlineData(139, 0, 0, 44, 0, 139, 132)]
    // THE NOTCH AFTER IT STEPS ON FROM WHERE THE FIRST WAS AIMED, not from
    // where the content has got to - so a wheel turned twice moves two cards.
    [InlineData(376, 705, 45, 705, 0, 1, 1410)]
    // And WHICH WAY it turned is read off the scroller's own offset, which is
    // what the platform worked its destination out from: 376 is behind the 705
    // already aimed at and is still a notch FORWARD.
    [InlineData(376, 705, 376.1, 705, 0, 1, 705)]
    // An axis nothing moved is left on the point it is nearest.
    [InlineData(0, 705, 0, 705, 0, 1, 0)]
    // A grid that starts somewhere else steps from there.
    [InlineData(100, 50, 50, 300, 50, 1, 350)]
    // No grid, nothing to step: the platform's own destination stands.
    [InlineData(139, 0, 0, 0, 0, 1, 139)]
    public void AWheelNotchStepsTheGridAndAlwaysMoves(
        double going, double aim, double at, double interval, double origin, double least,
        double expected)
    {
        Assert.Equal(expected, ScrollGlide.Step(going, aim, at, interval, origin, least), 6);
    }

    [Fact]
    public void AWheelIsNotAThrowAndIsNotShortenedLikeOne()
    {
        // The two rules side by side on the same numbers: a THROW predicted 139
        // over a grid of 705 is going nowhere and is rounded back to where it
        // started, which is what a wheel must not do.
        Assert.Equal(0, ScrollGlide.Cells(0, 0, 705, 0));
        Assert.Equal(705, ScrollGlide.Step(139, 0, 0, 705, 0, 139), 6);
    }

    [Fact]
    public void AHeldReleaseBecomesThisSidesMovement()
    {
        // The point of the limit, and why it needs nothing else: a throw brought
        // back to one point is a jump of one point, which is the settle any
        // other one-point swipe gets.
        double held = ScrollGlide.Held(1500, 0, 300, 0, 1);

        Assert.Equal(1, ScrollGlide.Cells(0, held, 300, 0));
        Assert.True(ScrollGlide.Cells(0, held, 300, 0) <= ScrollGlide.Reach);
    }

    [Fact]
    public void OnlyAnAskedForMoveEverReachesTheCeiling()
    {
        Assert.Equal(ScrollGlide.Most, ScrollGlide.Length(3000, 300), 6);

        // The longest settle there is - a point and a half - is well under it,
        // so nothing a reader does is ever clipped.
        Assert.True(ScrollGlide.Length(450, 300) < ScrollGlide.Most);
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
