// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host's half of a CHANNEL: a value the platform moves many times a second,
// the layouts that follow it, and the ground a follower's write stands on.
//
// The arithmetic itself is Swift's, so what can be asked here is everything
// AROUND it - where a value stands, what a described layout owes, and what this
// side is allowed to remember. A host with no Swift module registered answers
// no placements at all, which is exactly the state these run in.

using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class ChannelTests
{
    /// <summary>
    /// Where a value stands is kept whether or not anything follows it: a drag
    /// MOVES a value rather than setting it, so where it began has to be known,
    /// and a render that happens later describes the views where the reader
    /// left them.
    /// </summary>
    [Fact]
    public void AValueThatMovedIsWhereItWasLastSaidToBe()
    {
        var channels = new Channels(new MotionEngine());

        Assert.Equal(0, channels.Standing(7));

        channels.Moved(7, 12.5);
        Assert.Equal(12.5, channels.Standing(7));

        channels.Moved(7, -3);
        Assert.Equal(-3, channels.Standing(7));

        Assert.Equal(0, channels.Standing(8));
    }

    /// <summary>
    /// A DESCRIBED LAYOUT'S DELTA IS SPENT. The tree has just said where
    /// everything is, and what it said already holds wherever the reader has
    /// moved the run to - the arithmetic reads the channels. So each placed
    /// view goes back to the translation the TREE wrote, never to the one this
    /// side wrote on top of it.
    /// </summary>
    [Fact]
    public void ADescribedLayoutGoesBackToTheTranslationTheTreeWrote()
    {
        var channels = new Channels(new MotionEngine());
        var layout = new AbsoluteLayout();
        var card = new BoxView();

        layout.Children.Add(card);
        channels.Follows(layout, [4.0], rule: 9);

        // What the tree said, as it said it.
        channels.Authored(card, x: 12);
        channels.Authored(card, y: -5);

        // And where this side then moved it, following the reader's hand.
        card.TranslationX = 240;
        card.TranslationY = 60;

        channels.Applied(layout);

        Assert.Equal(12, card.TranslationX);
        Assert.Equal(-5, card.TranslationY);
    }

    /// <summary>
    /// A view the tree never gave a translation goes back to nothing, which is
    /// MAUI's own answer for a property nobody set.
    /// </summary>
    [Fact]
    public void AViewTheTreeNeverMovedGoesBackToNothing()
    {
        var channels = new Channels(new MotionEngine());
        var layout = new AbsoluteLayout();
        var card = new BoxView { TranslationX = 88, TranslationY = 4 };

        layout.Children.Add(card);
        channels.Follows(layout, [4.0], rule: 9);
        channels.Applied(layout);

        Assert.Equal(0, card.TranslationX);
        Assert.Equal(0, card.TranslationY);
    }

    /// <summary>
    /// A layout nobody registered is left alone: an apply reaches every layout
    /// on the page, and only a FOLLOWED one owes an alignment.
    /// </summary>
    [Fact]
    public void ALayoutThatFollowsNothingIsLeftWhereItIs()
    {
        var channels = new Channels(new MotionEngine());
        var layout = new AbsoluteLayout();
        var card = new BoxView { TranslationX = 88 };

        layout.Children.Add(card);
        channels.Applied(layout);

        Assert.Equal(88, card.TranslationX);
    }

    /// <summary>
    /// A FOLLOWED LAYOUT SAYS SO, which is what the arranger's measure reads:
    /// such a layout is the size it is GIVEN, its children standing where
    /// arithmetic over the room puts them.
    /// </summary>
    [Fact]
    public void AFollowedLayoutIsMarkedAsOne()
    {
        var channels = new Channels(new MotionEngine());
        var layout = new AbsoluteLayout();

        Assert.False(layout.GetValue(Channels.FollowedProperty) is true);

        channels.Follows(layout, [1.0, 2.0], rule: 5);

        Assert.True(layout.GetValue(Channels.FollowedProperty) is true);
    }

    /// <summary>
    /// A render RE-REGISTERS what it already had, and the rule id is the one
    /// thing that can move - so a layout is followed once per value however
    /// many times it is described.
    /// </summary>
    [Fact]
    public void ALayoutDescribedAgainIsFollowedOnce()
    {
        var channels = new Channels(new MotionEngine());
        var layout = new AbsoluteLayout();
        var card = new BoxView();

        layout.Children.Add(card);

        channels.Follows(layout, [1.0], rule: 5);
        channels.Follows(layout, [1.0], rule: 5);
        channels.Follows(layout, [1.0], rule: 6);

        // The alignment an apply owes still finds exactly one registration -
        // it would throw or double-write if the list had grown.
        channels.Authored(card, x: 3);
        channels.Applied(layout);

        Assert.Equal(3, card.TranslationX);
    }

    /// <summary>
    /// NOTHING HERE OUTLIVES A PAGE. A session lasts for the process and every
    /// page is left eventually, so a layout that once followed a value - and
    /// every view the tree ever gave a translation - must be collectable the
    /// moment the tree stops holding it.
    /// </summary>
    [Fact]
    public void AFollowerAndItsViewsAreLetGoOfWhenThePageIs()
    {
        var channels = new Channels(new MotionEngine());

        (WeakReference Layout, WeakReference Card) held = Registered(channels);

        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();

        Assert.False(held.Layout.IsAlive, "the layout is the page's, not the session's");
        Assert.False(held.Card.IsAlive, "and so is every view it placed");
    }

    /// <summary>Registers a layout and lets go of it, keeping only a watch.</summary>
    private static (WeakReference Layout, WeakReference Card) Registered(Channels channels)
    {
        var layout = new AbsoluteLayout();
        var card = new BoxView();

        layout.Children.Add(card);

        channels.Follows(layout, [11.0], rule: 2);
        channels.Authored(card, x: 7);
        channels.Applied(layout);

        return (new WeakReference(layout), new WeakReference(card));
    }
}
