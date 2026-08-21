// The half of the bridge that turns a message into controls.
//
// A member of a closed vocabulary is written Host.Member(SwiftSwipeDirection.Left)
// rather than as a bare number, because the number is the whole of what crosses
// and a digit in a JSON blob says nothing about which member - or which
// vocabulary - it belongs to. A bit set is the members ORed.
//
// The trap: a value of the wrong SHAPE fails silently. Every accessor answers
// null for one, the renderer assigns only what it was given, and the test then
// proves the DEFAULT path while reading as though it proved the one it names.
using System.ComponentModel;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class RendererTests
{
    /// <summary>
    /// A view that says where its pivot is has the anchor written AGAIN once
    /// the platform has given it a size.
    /// </summary>
    /// <remarks>
    /// The point a rotation turns about is the anchor times the FRAME, and a
    /// control being made has no frame - so the pivot of a view built with both
    /// an anchor and an angle is worked out against nothing and never
    /// revisited, the platform recomputing it when the ANCHOR moves and not
    /// when the rotation does. Measured on Android with the gallery's clock:
    /// hands that swung around their own tops. What the fix is contractually
    /// about is this - the anchor reaches the platform again after the first
    /// layout, and stands where the message put it.
    /// </remarks>
    [Fact]
    public void AnAnchorIsWrittenAgainOnceTheViewHasASize()
    {
        var host = new Host();

        var box = (BoxView)host.Apply("""
            {"id":1,"type":"BoxView","props":{"anchorY":1,"rotation":45,"widthRequest":2,"heightRequest":96}}
            """);

        int written = 0;
        box.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == VisualElement.AnchorYProperty.PropertyName) { written++; }
        };

        // What the platform does when it finally lays the view out.
        ((IView)box).Arrange(new Rect(0, 0, 2, 96));

        Assert.True(written > 0, "the anchor never reached the platform again");
        Assert.Equal(1, box.AnchorY);
        Assert.Equal(45, box.Rotation);
    }

    /// <summary>
    /// And a view that already had a size when the anchor arrived asks for
    /// nothing: its pivot was worked out against a real frame the first time.
    /// </summary>
    [Fact]
    public void AnAnchorOnAViewThatAlreadyHasASizeIsLeftAlone()
    {
        var host = new Host();

        var box = (BoxView)host.Apply("""
            {"id":1,"type":"BoxView","props":{"widthRequest":2,"heightRequest":96}}
            """);

        ((IView)box).Arrange(new Rect(0, 0, 2, 96));

        host.Apply("""
            {"id":1,"type":"BoxView","props":{"anchorY":1,"rotation":45}}
            """);

        int written = 0;
        box.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == VisualElement.AnchorYProperty.PropertyName) { written++; }
        };

        ((IView)box).Arrange(new Rect(0, 0, 2, 120));

        Assert.Equal(0, written);
        Assert.Equal(1, box.AnchorY);
    }

    [Fact]
    public void AControlIsKeptWhenTheMessageDescribesTheSameElement()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":"a","type":"Label","props":{"text":"one"}}]}
            """);

        var label = (Label)stack.Children[0];

        host.Apply("""
            {"id":1,"type":"VerticalStackLayout","children":[
              {"id":"a","type":"Label","props":{"text":"two"}}]}
            """);

        Assert.Same(label, stack.Children[0]);
        Assert.Equal("two", label.Text);

        // The identity lives in the attached element - the one place the
        // renderer keeps what a control stands for - and nowhere else.
        Assert.Equal("\"a\"", Tree.Identity(label));
    }

    [Fact]
    public void ReplaceThrowsTheControlAway()
    {
        var host = new Host();

        var label = (Label)host.Apply("""{"id":"a","type":"Label","props":{"text":"one"}}""");

        var replaced = host.Apply("""
            {"id":"a","type":"Label","replace":true,"props":{"text":"one"}}
            """);

        Assert.NotSame(label, replaced);
        Assert.Equal("one", ((Label)replaced).Text);
    }

    [Fact]
    public void AChangedTypeIsRebuiltEvenWithoutBeingTold()
    {
        var host = new Host();

        host.Apply("""{"id":"a","type":"Label","props":{"text":"one"}}""");
        var button = host.Apply("""{"id":"a","type":"Button","props":{"text":"one"}}""");

        Assert.IsType<Button>(button);
    }

    /// <summary>
    /// A branch of an <c>if</c> that comes back is built afresh, properties and
    /// all.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The messages here are the ones the differ really writes for
    /// <c>if showing { Border { BoxView… } } else { ScrollView { Label } }</c>
    /// - a removal and a new element each time, never an element edited into
    /// the other branch's shape. Which is what makes this side's job simple:
    /// there is nothing to un-apply.
    /// </para>
    /// <para>
    /// The properties checked are the ones a control gets from its OWN
    /// reconcile - a BoxView's colour and corner - rather than the ones every
    /// view shares, because those come from a different method and would pass
    /// while these did not.
    /// </para>
    /// </remarks>
    [Fact]
    public void ABranchThatComesBackIsBuiltWithItsProperties()
    {
        var host = new Host();

        var grid = (Grid)host.Apply("""
            {"id":1,"type":"Grid","arranged":true,"children":[
              {"id":2,"type":"Label","props":{"gridRow":0,"text":"tabs"}},
              {"id":3,"type":"Border","props":{"gridRow":1},"arranged":true,"children":[
                {"id":4,"type":"BoxView","props":{"color":"#512BD4","cornerRadius":10,"translationX":81}}]}]}
            """);

        var first = Tree.OfType<BoxView>(grid).Single();

        host.Apply("""
            {"id":1,"type":"Grid","arranged":true,"children":[
              {"id":2,"type":"Label"},
              {"id":5,"type":"ScrollView","props":{"gridRow":1},"arranged":true,"children":[
                {"id":6,"type":"Label","props":{"text":"code"}}]}]}
            """);

        Assert.Empty(Tree.OfType<BoxView>(grid));
        Assert.Single(Tree.OfType<ScrollView>(grid));

        host.Apply("""
            {"id":1,"type":"Grid","arranged":true,"children":[
              {"id":2,"type":"Label"},
              {"id":7,"type":"Border","props":{"gridRow":1},"arranged":true,"children":[
                {"id":8,"type":"BoxView","props":{"color":"#512BD4","cornerRadius":10,"translationX":81}}]}]}
            """);

        var again = Tree.OfType<BoxView>(grid).Single();

        Assert.NotSame(first, again);
        Assert.Equal(Color.FromArgb("#512BD4"), again.Color);
        Assert.Equal(10, again.CornerRadius.TopLeft);
        Assert.Equal(81, again.TranslationX);
        Assert.Empty(Tree.OfType<ScrollView>(grid));

        // And the view beside the conditional is the one it always was.
        Assert.Equal(2, grid.Children.Count);
        Assert.Equal("tabs", Tree.OfType<Label>(grid).Single().Text);
    }

    [Fact]
    public void RowsMoveRatherThanBeingRewritten()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":"a","type":"Label","props":{"text":"a"}},
              {"id":"b","type":"Label","props":{"text":"b"}}]}
            """);

        var a = stack.Children[0];
        var b = stack.Children[1];

        // One inserted at the top; the other two only carry their new positions.
        host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":"z","type":"Label","props":{"text":"z"}},
              {"id":"a","type":"Label"},
              {"id":"b","type":"Label"}]}
            """);

        Assert.Equal(3, stack.Children.Count);
        Assert.Equal("z", ((Label)stack.Children[0]).Text);
        Assert.Same(a, stack.Children[1]);
        Assert.Same(b, stack.Children[2]);
    }

    /// <summary>
    /// `VStack { view1; if ok { a } else { b }; view3 }`: switching the branch
    /// swaps the MIDDLE control in place, and the neighbours' controls are the
    /// very objects they were - not rebuilt, not re-assigned, not moved.
    /// </summary>
    [Fact]
    public void ABranchSwapLeavesTheNeighboursControlsUntouched()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":2,"type":"Label","props":{"text":"one"}},
              {"id":3,"type":"Label","props":{"text":"branch a"}},
              {"id":4,"type":"Label","props":{"text":"three"}}]}
            """);

        var first = stack.Children[0];
        var third = stack.Children[2];

        // The other branch: a new element in the middle, the neighbours as
        // stubs - identity and type, nothing else.
        host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":2,"type":"Label"},
              {"id":5,"type":"Button","props":{"text":"branch b"}},
              {"id":4,"type":"Label"}]}
            """);

        Assert.Equal(3, stack.Children.Count);
        Assert.Same(first, stack.Children[0]);
        Assert.Same(third, stack.Children[2]);
        Assert.Equal("branch b", Assert.IsType<Button>(stack.Children[1]).Text);
    }

    /// <summary>
    /// 1..8 becomes [10], 2, 3, 5, 6, 7, 8, [4]: one leaves, one arrives, one
    /// moves - and the list hears exactly those four operations, nothing for
    /// the six that stayed in their relative order.
    /// </summary>
    [Fact]
    public void AnArrangedListTouchesOnlyWhatMoved()
    {
        var host = new Host();
        var items = new System.Collections.ObjectModel.ObservableCollection<View>();

        string rows = string.Join(",", Enumerable.Range(1, 8).Select(n =>
            $"{{\"id\":\"r{n}\",\"type\":\"Label\",\"props\":{{\"text\":\"{n}\"}}}}"));

        host.Renderer.ApplyList(items, Host.Parse(
            $"{{\"id\":1,\"type\":\"VerticalStackLayout\",\"arranged\":true,\"children\":[{rows}]}}"),
            (child, match) => host.Renderer.Render(match as View, child));

        List<View> before = [.. items];
        var heard = new List<System.Collections.Specialized.NotifyCollectionChangedAction>();
        items.CollectionChanged += (_, e) => heard.Add(e.Action);

        host.Renderer.ApplyList(items, Host.Parse("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":"r10","type":"Label","props":{"text":"10"}},
              {"id":"r2","type":"Label"},
              {"id":"r3","type":"Label"},
              {"id":"r5","type":"Label"},
              {"id":"r6","type":"Label"},
              {"id":"r7","type":"Label"},
              {"id":"r8","type":"Label"},
              {"id":"r4","type":"Label"}]}
            """), (child, match) => host.Renderer.Render(match as View, child));

        Assert.Equal(["10", "2", "3", "5", "6", "7", "8", "4"],
            items.Cast<Label>().Select(label => label.Text));

        // The six that kept their relative order are the same objects, never
        // detached: the removal of 1, the arrival of 10, and the one move of
        // 4 - two operations, being a RemoveAt and an Insert - are ALL the
        // list heard.
        Assert.Same(before[1], items[1]);
        Assert.Same(before[7], items[6]);
        Assert.Same(before[3], items[7]);
        Assert.Equal([
            System.Collections.Specialized.NotifyCollectionChangedAction.Remove,
            System.Collections.Specialized.NotifyCollectionChangedAction.Remove,
            System.Collections.Specialized.NotifyCollectionChangedAction.Add,
            System.Collections.Specialized.NotifyCollectionChangedAction.Add,
        ], heard);
    }

    [Fact]
    public void RemovedRowsLeaveAndTheRestKeepTheirControls()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":"a","type":"Label","props":{"text":"a"}},
              {"id":"b","type":"Label","props":{"text":"b"}},
              {"id":"c","type":"Label","props":{"text":"c"}}]}
            """);

        var a = stack.Children[0];
        var c = stack.Children[2];

        host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":"a","type":"Label"},
              {"id":"c","type":"Label"}]}
            """);

        Assert.Equal(2, stack.Children.Count);
        Assert.Same(a, stack.Children[0]);
        Assert.Same(c, stack.Children[1]);
    }

    [Fact]
    public void APropertyThatDidNotArriveIsLeftAlone()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":"a","type":"Label","props":{"text":"one","fontSize":20}}
            """);

        host.Apply("""{"id":"a","type":"Label","props":{"text":"two"}}""");

        Assert.Equal("two", label.Text);
        Assert.Equal(20, label.FontSize);
    }

    [Fact]
    public void AnEventReportsTheHandlerIdTheControlWasLastGiven()
    {
        var host = new Host();

        var button = (Button)host.Apply("""
            {"id":"b","type":"Button","props":{"text":"go"},"events":{"clicked":7}}
            """);

        ((IButtonController)button).SendClicked();
        Assert.Equal((7, (string?)null), host.Dispatched[^1]);

        // A message that says nothing about events leaves the ids alone.
        host.Apply("""{"id":"b","type":"Button","props":{"text":"stop"}}""");
        ((IButtonController)button).SendClicked();
        Assert.Equal((7, (string?)null), host.Dispatched[^1]);

        // And one that changes them is obeyed.
        host.Apply("""{"id":"b","type":"Button","events":{"clicked":9}}""");
        ((IButtonController)button).SendClicked();
        Assert.Equal((9, (string?)null), host.Dispatched[^1]);
    }

    [Fact]
    public void AnEmptyEventSetClearsTheHandlersInsteadOfLeavingThemStale()
    {
        var host = new Host();

        var button = (Button)host.Apply("""
            {"id":"b","type":"Button","props":{"text":"go"},"events":{"clicked":7}}
            """);

        Assert.Equal(7, StateUIRenderer.EventsOf(button)?[SwiftEvent.Clicked]);

        // The element survives but its last handler went - Swift sends an EMPTY
        // event map, and the renderer replaces its map with an empty one. Were
        // this read as "unchanged", the control would still resolve a clicked
        // to id 7, a handler the Swift side has forgotten.
        host.Apply("""{"id":"b","type":"Button","props":{"text":"go"},"events":{}}""");

        Assert.Empty(StateUIRenderer.EventsOf(button)!);

        ((IButtonController)button).SendClicked();
        Assert.Empty(host.Dispatched);
    }

    [Fact]
    public void ASparsePatchNamingAnUnknownChildIsRefusedSoTheSessionCanResync()
    {
        var host = new Host();

        host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":"a","type":"Label","props":{"text":"one"}}]}
            """);

        // A NON-arranged message names a child this list has never had. A new
        // child always arrives in an arranged message, so this is drift - C#
        // and Swift disagree about what is here. It is refused rather than
        // taken in at the wrong end, and the throw is what the session turns
        // into a whole-tree resync.
        InvalidDataException error = Assert.Throws<InvalidDataException>(() =>
            host.Apply("""
                {"id":1,"type":"VerticalStackLayout","children":[
                  {"id":"b","type":"Label","props":{"text":"two"}}]}
                """));

        Assert.Contains("\"b\"", error.Message);
    }

    [Fact]
    public void WritingAPropertyDoesNotReportItBackAsIfTheUserHadDoneIt()
    {
        var host = new Host();

        host.Apply("""
            {"id":"e","type":"Entry","props":{"text":"one"},"events":{"textChanged":3}}
            """);

        // Assigning Entry.Text raises TextChanged; that is the renderer talking
        // to itself, and it must not travel.
        host.Apply("""{"id":"e","type":"Entry","props":{"text":"two"}}""");

        Assert.Empty(host.Dispatched);
    }

    [Fact]
    public void ATypedEventCarriesItsValue()
    {
        var host = new Host();

        var toggle = (Switch)host.Apply("""
            {"id":"s","type":"Switch","props":{"isToggled":false},"events":{"toggled":4}}
            """);

        toggle.IsToggled = true;

        Assert.Equal((4, "true"), host.Dispatched[^1]);
    }

    [Fact]
    public void APropertyWithNoEventOfItsOwnIsWatchedOnlyWhenAsked()
    {
        var watched = new Host();

        var asked = (Entry)watched.Apply("""
            {"id":"e","type":"Entry","events":{"isFocusedChanged":6}}
            """);

        var ignored = new Host();
        var notAsked = (Entry)ignored.Apply("""{"id":"e","type":"Entry"}""");

        // MAUI raises PropertyChanged for IsFocused; only the one that asked for
        // it should say anything.
        asked.SetValue(VisualElement.IsFocusedPropertyKey, true);
        notAsked.SetValue(VisualElement.IsFocusedPropertyKey, true);

        Assert.Equal((6, "true"), watched.Dispatched[^1]);
        Assert.Empty(ignored.Dispatched);
    }

    [Fact]
    public void ATapRecognizerIsAddedOnceAndOnlyWhenTheTreeAsksForOne()
    {
        var host = new Host();

        var tappable = (Border)host.Apply("""
            {"id":"a","type":"Border","props":{"numberOfTapsRequired":2},"events":{"tapped":3}}
            """);

        var tap = Assert.Single(tappable.GestureRecognizers.OfType<TapGestureRecognizer>());
        Assert.Equal(2, tap.NumberOfTapsRequired);

        // A second render must not hang another recognizer on the same view -
        // the same rule the controls' own events follow, subscribed once when
        // the control is created.
        host.Apply("""{"id":"a","type":"Border","props":{"numberOfTapsRequired":1}}""");

        Assert.Same(tap, Assert.Single(tappable.GestureRecognizers.OfType<TapGestureRecognizer>()));
        Assert.Equal(1, tap.NumberOfTapsRequired);
        Assert.Equal(3, StateUIRenderer.EventsOf(tappable)?[SwiftEvent.Tapped]);

        // And a view nobody wants to tap carries nothing.
        var plain = (Border)host.Apply("""{"id":"b","type":"Border"}""");
        Assert.Empty(plain.GestureRecognizers);
    }

    [Fact]
    public void EachGestureIsAskedForOnItsOwnTermsAndAddedOnlyWhenAsked()
    {
        var host = new Host();

        // Nothing asked for, nothing carried.
        Assert.Empty(((Border)host.Apply("""{"id":"none","type":"Border"}""")).GestureRecognizers);

        var swiped = (Border)host.Apply($$$"""
            {"id":"s","type":"Border","props":{
               "swipeDirection":{{{Host.Member(SwiftSwipeDirection.Left | SwiftSwipeDirection.Down)}}},
               "swipeThreshold":40
             },"events":{"swiped":1}}
            """);

        // One recognizer per direction, not one carrying both - MAUI reports the
        // direction a recognizer was CONFIGURED for, so a mask would report a
        // mask. See StateUIRenderer.ApplySwipe.
        SwipeGestureRecognizer[] swipes = [.. swiped.GestureRecognizers.OfType<SwipeGestureRecognizer>()];

        Assert.Equal(
            [SwipeDirection.Left, SwipeDirection.Down],
            swipes.Select(each => each.Direction));

        Assert.All(swipes, each => Assert.Equal(40u, each.Threshold));

        var panned = (Border)host.Apply("""
            {"id":"p","type":"Border","props":{"panTouchCount":2},"events":{"panUpdated":2}}
            """);

        Assert.Equal(2, Assert.Single(panned.GestureRecognizers.OfType<PanGestureRecognizer>()).TouchPoints);

        // Five pointer events, one recognizer: the kind is what a view carries,
        // not the handler count.
        var pointed = (Border)host.Apply("""
            {"id":"o","type":"Border","events":{"pointerEntered":3,"pointerExited":4,"pointerMoved":5}}
            """);

        Assert.Single(pointed.GestureRecognizers.OfType<PointerGestureRecognizer>());

        // Drag and drop are switched on by their own properties, because a view
        // that can be dragged says so whether or not it wants to hear about it.
        var dragged = (Border)host.Apply("""
            {"id":"d","type":"Border","props":{"canDrag":true,"dragText":"Alpha"}}
            """);

        Assert.True(Assert.Single(dragged.GestureRecognizers.OfType<DragGestureRecognizer>()).CanDrag);

        var dropped = (Border)host.Apply("""
            {"id":"r","type":"Border","props":{"allowDrop":true},"events":{"drop":6}}
            """);

        Assert.True(Assert.Single(dropped.GestureRecognizers.OfType<DropGestureRecognizer>()).AllowDrop);
    }

    [Fact]
    public void AGesturesPropertiesArePatchedWithoutASecondRecognizer()
    {
        var host = new Host();

        var view = (Border)host.Apply("""
            {"id":"s","type":"Border","props":{"panTouchCount":1},"events":{"panUpdated":1}}
            """);

        var pan = Assert.Single(view.GestureRecognizers.OfType<PanGestureRecognizer>());

        host.Apply("""{"id":"s","type":"Border","props":{"panTouchCount":2}}""");

        // The same recognizer, told something new - a second one would report
        // every gesture twice.
        Assert.Same(pan, Assert.Single(view.GestureRecognizers.OfType<PanGestureRecognizer>()));
        Assert.Equal(2, pan.TouchPoints);
    }

    [Fact]
    public void ASwipeNamesTheDirectionItWentRatherThanTheOnesItListensFor()
    {
        var host = new Host();

        var view = (Border)host.Apply($$$"""
            {"id":"s","type":"Border",
             "props":{"swipeDirection":{{{Host.Member(SwiftSwipeDirection.All)}}}},
             "events":{"swiped":7}}
            """);

        // Exactly what MAUI's iOS gesture manager does: it calls back with the
        // Direction the recognizer was CONFIGURED for, whatever the finger did -
        // `result.AddTarget(() => action(direction))`. With one recognizer per
        // direction, that IS the direction the swipe went.
        foreach (SwipeGestureRecognizer each in view.GestureRecognizers.OfType<SwipeGestureRecognizer>())
        {
            each.SendSwiped(view, each.Direction);
        }

        // One direction per swipe, never a mask - each crossing as OUR bit
        // (Right 1, Left 2, Up 4, Down 8), translated out of MAUI's by
        // `StateUIRenderer.Member` rather than cast: that the two lists agree
        // here is a coincidence this side must not spend. A single recognizer
        // listening for everything reports the whole mask on iOS and Mac
        // Catalyst, which Types/Gestures.swift refuses to read as a direction,
        // so the handler never runs - while Android, which works the direction
        // out from the fling, is fine either way.
        Assert.Equal(
            [(7, "enum 2"), (7, "enum 1"), (7, "enum 4"), (7, "enum 8")],
            host.Dispatched);
    }

    [Fact]
    public void AViewToldNothingListensEveryWay()
    {
        var host = new Host();

        // The Swift side sends swipeDirection beside the handler, so this is
        // the defensive half - and it defaults the way that side does, because
        // a recognizer listening for nothing recognizes nothing.
        var view = (Border)host.Apply("""{"id":"s","type":"Border","events":{"swiped":1}}""");

        Assert.Equal(
            [SwipeDirection.Left, SwipeDirection.Right, SwipeDirection.Up, SwipeDirection.Down],
            view.GestureRecognizers.OfType<SwipeGestureRecognizer>().Select(each => each.Direction));
    }

    [Fact]
    public void ADirectionThatStaysKeepsItsRecognizerAndOneNoLongerAskedForGoes()
    {
        var host = new Host();

        var view = (Border)host.Apply($$$"""
            {"id":"s","type":"Border","props":{
               "swipeDirection":{{{Host.Member(SwiftSwipeDirection.Left)}}},
               "swipeThreshold":40
             },"events":{"swiped":1}}
            """);

        var left = Assert.Single(view.GestureRecognizers.OfType<SwipeGestureRecognizer>());

        host.Apply($$$"""
            {"id":"s","type":"Border","props":{
               "swipeDirection":{{{Host.Member(SwiftSwipeDirection.Left | SwiftSwipeDirection.Up)}}}
             }}
            """);

        SwipeGestureRecognizer[] both = [.. view.GestureRecognizers.OfType<SwipeGestureRecognizer>()];

        // The direction that stayed keeps the recognizer it had: a patch adds
        // what arrived rather than rebuilding what did not change.
        Assert.Same(left, both[0]);
        Assert.Equal([SwipeDirection.Left, SwipeDirection.Up], both.Select(each => each.Direction));

        // And the one that arrived joins with the threshold its sibling already
        // carries, though this message never mentioned it - or it would be the
        // single direction that wanted a longer finger, for no visible reason.
        Assert.All(both, each => Assert.Equal(40u, each.Threshold));

        host.Apply($$$"""
            {"id":"s","type":"Border","props":{
               "swipeDirection":{{{Host.Member(SwiftSwipeDirection.Up)}}}
             }}
            """);

        // Narrowing takes the rest away, or the view goes on listening for
        // directions the tree stopped asking about.
        Assert.Equal(
            SwipeDirection.Up,
            Assert.Single(view.GestureRecognizers.OfType<SwipeGestureRecognizer>()).Direction);
    }

    [Fact]
    public void GridPlacementIsWrittenOnTheChild()
    {
        var host = new Host();

        var grid = (Grid)host.Apply($$$"""
            {"id":1,"type":"Grid","arranged":true,
             "props":{
               "rowDefinitions":[
                 [{{{Host.Member(SwiftGridLengthKind.Absolute)}}},70],
                 [{{{Host.Member(SwiftGridLengthKind.Auto)}}},1]],
               "columnDefinitions":[
                 [{{{Host.Member(SwiftGridLengthKind.Star)}}},1],
                 [{{{Host.Member(SwiftGridLengthKind.Star)}}},2]],
               "rowSpacing":12
             },"children":[
               {"id":"a","type":"Label","props":{"text":"a"}},
               {"id":"b","type":"Label",
                "props":{"text":"b","gridRow":1,"gridColumnSpan":2}}]}
            """);

        Assert.Equal(2, grid.RowDefinitions.Count);
        Assert.Equal(GridUnitType.Auto, grid.RowDefinitions[1].Height.GridUnitType);
        Assert.Equal(2, grid.ColumnDefinitions[1].Width.Value);
        Assert.Equal(12, grid.RowSpacing);

        var b = (Label)grid.Children[1];
        Assert.Equal(1, Grid.GetRow(b));
        Assert.Equal(2, Grid.GetColumnSpan(b));
    }

    [Fact]
    public void SeveralChildrenInAScrollViewAreWrappedRatherThanDropped()
    {
        var host = new Host();

        var scroll = (ScrollView)host.Apply("""
            {"id":1,"type":"ScrollView","arranged":true,"children":[
              {"id":"a","type":"Label","props":{"text":"a"}},
              {"id":"b","type":"Label","props":{"text":"b"}}]}
            """);

        var wrapper = Assert.IsType<VerticalStackLayout>(scroll.Content);
        Assert.Equal(2, wrapper.Children.Count);
        Assert.Null(wrapper.StyleId);
    }

    /// <summary>
    /// A swipe's items are patched like anything else: kept by identity, and
    /// only what the message names is written.
    /// </summary>
    /// <remarks>
    /// Their list is not a list of views, so it has a method of its own rather
    /// than <c>ApplyChildren</c> - which is the reason to check it here. A
    /// control test proves the first render; this one proves the second.
    /// </remarks>
    [Fact]
    public void SwipeItemsAreKeptBetweenRendersAndOnlyWhatChangedIsWritten()
    {
        var host = new Host();

        var swipe = (SwipeView)host.Apply($$$"""
            {"id":1,"type":"SwipeView","children":[
              {"id":2,"type":"Label","props":{"text":"Row"}},
              {"id":3,"type":"SwipeItems","props":{
                 "side":{{{Host.Member(SwiftSwipeSide.Right)}}},
                 "mode":{{{Host.Member(SwiftSwipeMode.Reveal)}}}
               },"arranged":true,"children":[
                 {"id":4,"type":"SwipeItem","props":{"text":"Star"}},
                 {"id":5,"type":"SwipeItem","props":{"text":"Delete"},
                  "events":{"invoked":7}}]}]}
            """);

        var star = (SwipeItem)swipe.RightItems[0];
        var delete = (SwipeItem)swipe.RightItems[1];

        // One item's caption changed, and the message says nothing else.
        host.Apply("""
            {"id":1,"type":"SwipeView","children":[
              {"id":3,"type":"SwipeItems","children":[
                {"id":5,"type":"SwipeItem","props":{"text":"Remove"}}]}]}
            """);

        Assert.Equal([star, delete], swipe.RightItems);
        Assert.Equal("Star", star.Text);
        Assert.Equal("Remove", delete.Text);
        Assert.Equal("Row", Assert.IsType<Label>(swipe.Content).Text);

        // The handler id came with the first message and nothing has mentioned
        // it since, which is exactly when a control has to go on reporting it.
        ((Microsoft.Maui.Controls.ISwipeItem)delete).OnInvoked();
        Assert.Equal((7, (string?)null), host.Dispatched[^1]);

        // And one leaves: the arranged list simply no longer names it.
        host.Apply("""
            {"id":1,"type":"SwipeView","children":[
              {"id":3,"type":"SwipeItems","arranged":true,"children":[
                {"id":5,"type":"SwipeItem"}]}]}
            """);

        Assert.Same(delete, Assert.Single(swipe.RightItems));
    }

    /// <summary>
    /// The runs of a formatted Label are a KEPT list: a patch about one run
    /// carries that run and leaves every other one exactly as it was.
    /// </summary>
    /// <remarks>
    /// The control fixture builds the runs and reads them back, which says the
    /// values arrive; it cannot say what a SECOND message does. Rebuilding the
    /// collection would drop every run the patch did not repeat - a highlighted
    /// word changing colour would empty the rest of the line - and the
    /// FormattedString itself is kept for the same reason one level up.
    /// </remarks>
    [Fact]
    public void APatchAboutOneRunLeavesTheOtherRunsAlone()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","arranged":true,"children":[
              {"id":2,"type":"FormattedString","arranged":true,"children":[
                {"id":3,"type":"Span","props":{"text":"let ","textColor":"#800080"}},
                {"id":4,"type":"Span","props":{"text":"counter","textColor":"#4682B4"}}]}]}
            """);

        FormattedString formatted = Assert.IsType<FormattedString>(label.FormattedText);
        Span first = formatted.Spans[0];
        Span second = formatted.Spans[1];

        // One run changed colour. Nothing else is in the message - not the
        // other run, not the text of this one.
        host.Apply("""
            {"id":1,"type":"Label","children":[
              {"id":2,"type":"FormattedString","children":[
                {"id":4,"type":"Span","props":{"textColor":"#FF0000"}}]}]}
            """);

        Assert.Same(formatted, label.FormattedText);
        Assert.Equal(2, label.FormattedText!.Spans.Count);
        Assert.Same(first, label.FormattedText.Spans[0]);
        Assert.Same(second, label.FormattedText.Spans[1]);

        Assert.Equal(Colors.Red, second.TextColor);
        Assert.Equal("counter", second.Text);
        Assert.Equal("let ", first.Text);
        Assert.Equal(Color.FromArgb("#800080"), first.TextColor);
    }

    /// <summary>
    /// A run that leaves is named, the way a child of any kept list is - and
    /// the ones that stay keep their objects.
    /// </summary>
    [Fact]
    public void ARunThatLeavesIsTheOnlyOneThatGoes()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","arranged":true,"children":[
              {"id":2,"type":"FormattedString","arranged":true,"children":[
                {"id":3,"type":"Span","props":{"text":"Sold"}},
                {"id":4,"type":"Span","props":{"text":" out"}}]}]}
            """);

        Span kept = label.FormattedText!.Spans[0];

        host.Apply("""
            {"id":1,"type":"Label","children":[
              {"id":2,"type":"FormattedString","arranged":true,"children":[
                {"id":3,"type":"Span"}]}]}
            """);

        Assert.Same(kept, Assert.Single(label.FormattedText!.Spans));
        Assert.Equal("Sold", kept.Text);
    }

    [Fact]
    public void AnUnknownControlIsAVisibleMarkerRatherThanACrash()
    {
        var host = new Host();

        var marker = (Label)host.Apply("""{"id":"x","type":"Sparkline"}""");

        Assert.Contains("Sparkline", marker.Text);
        Assert.Equal(Colors.Firebrick, marker.TextColor);
    }

    /// <summary>
    /// A property MAUI types as a Brush takes a colour as readily as a
    /// gradient, and this is the pair that says so.
    /// </summary>
    /// <remarks>
    /// Both forms arrive under the same name, and a Border's stroke read as a
    /// colour is what shipped first: a gradient reached it as an array of
    /// records, <c>GetColor</c> made nothing of an array, and the border drew
    /// MAUI's default grey with nothing reported anywhere. The control fixtures
    /// could not see it - a Border's case sends a colour, which worked.
    /// </remarks>
    [Fact]
    public void ABrushPropertyTakesAColourAndAGradientUnderTheSameName()
    {
        var host = new Host();

        var border = (Border)host.Apply("""
            {"id":"b","type":"Border","props":{"stroke":"#FF0000"}}
            """);

        Assert.Equal(Colors.Red, Assert.IsType<SolidColorBrush>(border.Stroke).Color);

        host.Apply($$$"""
            {"id":"b","type":"Border","props":{"stroke":[
              {{{Host.Member(SwiftBrushKind.LinearGradient)}}},[0,0,1,0],0,"#FF0000",1,"#0000FF"
            ]}}
            """);

        var gradient = Assert.IsType<LinearGradientBrush>(border.Stroke);

        Assert.Equal(new Point(0, 0), gradient.StartPoint);
        Assert.Equal(new Point(1, 0), gradient.EndPoint);
        Assert.Equal([Colors.Red, Colors.Blue], gradient.GradientStops.Select(stop => stop.Color));
        Assert.Equal([0f, 1f], gradient.GradientStops.Select(stop => stop.Offset));
    }

    /// <summary>
    /// A gradient whose END POINT alone moves reaches the shape: the brush is
    /// one value, so a patch about it is a whole brush, and the shape is
    /// given a new one rather than a mutated copy of the one it holds.
    /// </summary>
    [Fact]
    public void AGradientThatOnlyMovesItsEndPointStillReachesTheShape()
    {
        var host = new Host();

        var shape = (Microsoft.Maui.Controls.Shapes.RoundRectangle)host.Apply($$$"""
            {"id":"r","type":"RoundRectangle","props":{"fill":[
              {{{Host.Member(SwiftBrushKind.LinearGradient)}}},[0,0,1,0],0,"#FF0000",1,"#0000FF"
            ]}}
            """);

        Assert.Equal(new Point(1, 0), Assert.IsType<LinearGradientBrush>(shape.Fill).EndPoint);

        host.Apply($$$"""
            {"id":"r","type":"RoundRectangle","props":{"fill":[
              {{{Host.Member(SwiftBrushKind.LinearGradient)}}},[0,0,1,1],0,"#FF0000",1,"#0000FF"
            ]}}
            """);

        Assert.Equal(new Point(1, 1), Assert.IsType<LinearGradientBrush>(shape.Fill).EndPoint);
    }

    /// <summary>
    /// The other two kinds, and the member that tells them apart.
    /// </summary>
    /// <remarks>
    /// The kind is a member of a vocabulary both sides of this repository
    /// declare - see <c>Brush.Kind</c> in Types/Brush.swift - so a renumbering
    /// on one side fails here rather than drawing the wrong brush on a device.
    /// It is the one vocabulary numbered from 1.
    /// </remarks>
    [Fact]
    public void EachKindOfBrushIsToldApartByItsNumber()
    {
        var host = new Host();

        var solid = (Border)host.Apply($$$"""
            {"id":"s","type":"Border","props":{
               "stroke":[{{{Host.Member(SwiftBrushKind.SolidColor)}}},"#FF6347"]
             }}
            """);

        Assert.Equal(Color.Parse("#FF6347"), Assert.IsType<SolidColorBrush>(solid.Stroke).Color);

        var radial = (Border)host.Apply($$$"""
            {"id":"r","type":"Border","props":{
               "stroke":[{{{Host.Member(SwiftBrushKind.RadialGradient)}}},[0.3,0.7,0.8],0.25,"#FFFFFF"]
             }}
            """);

        var brush = Assert.IsType<RadialGradientBrush>(radial.Stroke);

        Assert.Equal(new Point(0.3, 0.7), brush.Center);
        Assert.Equal(0.8, brush.Radius);
        Assert.Equal(Colors.White, Assert.Single(brush.GradientStops).Color);
        Assert.Equal(0.25f, Assert.Single(brush.GradientStops).Offset);
    }

    /// <summary>
    /// A brush value of a shape this side does not recognize leaves the
    /// property alone - the rule every unrecognized value follows.
    /// </summary>
    [Fact]
    public void ABrushThisSideCannotReadLeavesTheStrokeAlone()
    {
        var host = new Host();

        var border = (Border)host.Apply("""
            {"id":"b","type":"Border","props":{"stroke":"#FF0000"}}
            """);

        // A kind nothing declares, and a linear gradient missing its points.
        host.Apply("""{"id":"b","type":"Border","props":{"stroke":[{"enum":9},"#0000FF"]}}""");
        host.Apply($$$"""
            {"id":"b","type":"Border","props":{
               "stroke":[{{{Host.Member(SwiftBrushKind.LinearGradient)}}},0,"#0000FF"]
             }}
            """);

        Assert.Equal(Colors.Red, Assert.IsType<SolidColorBrush>(border.Stroke).Color);
    }

    /// <summary>
    /// A WebView's source takes a URL and HTML written in place under the same
    /// name - the brush rule, one level up.
    /// </summary>
    /// <remarks>
    /// The KIND says which, in front, rather than being inferred from how many
    /// parts arrived: a url is <c>[0, url]</c> and a document is
    /// <c>[1, html, base]</c>. The control fixture carries the url form, so this
    /// pair is where a document is read at all.
    /// </remarks>
    [Fact]
    public void AWebViewSourceTakesAUrlAndHtmlUnderTheSameName()
    {
        var host = new Host();

        var web = (WebView)host.Apply($$$"""
            {"id":"w","type":"WebView","props":{
               "source":[{{{Host.Member(SwiftWebViewSourceKind.Url)}}},"https://example.com/docs"]
             }}
            """);

        Assert.Equal("https://example.com/docs", Assert.IsType<UrlWebViewSource>(web.Source).Url);

        host.Apply($$$"""
            {"id":"w","type":"WebView","props":{"source":[
               {{{Host.Member(SwiftWebViewSourceKind.Html)}}},
               "<h1>Hi, you</h1>","https://example.com/"
             ]}}
            """);

        var written = Assert.IsType<HtmlWebViewSource>(web.Source);

        Assert.Equal("<h1>Hi, you</h1>", written.Html);
        Assert.Equal("https://example.com/", written.BaseUrl);

        // Nothing for links to resolve against is NOTHING - the third part is
        // always there and says so - and nothing is invented in its place.
        host.Apply($$$"""
            {"id":"w","type":"WebView","props":{"source":[
               {{{Host.Member(SwiftWebViewSourceKind.Html)}}},"<h1>Alone</h1>",null
             ]}}
            """);

        Assert.Null(Assert.IsType<HtmlWebViewSource>(web.Source).BaseUrl);
    }

    /// <summary>
    /// A frame report's window origin is the ancestors' frames added up, with
    /// a ScrollView's offset subtracted on the way through - content
    /// coordinates become viewport ones. On a plain Grid, because
    /// `.onFrameChanged` is a View-tier modifier: any view that asks reports.
    /// </summary>
    /// <remarks>
    /// Headlessly there is no platform to lay anything out, so the frames are
    /// assigned the way a layout pass would - which is also what proves the
    /// report is driven by the property and not by a platform callback. No
    /// platform also means no safe area, so its numbers agree with the
    /// window's.
    /// </remarks>
    [Fact]
    public void AWatchedFrameAnswersInWindowCoordinatesThroughItsAncestors()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":2,"type":"ScrollView","arranged":true,"children":[
                {"id":3,"type":"Grid","arranged":true,"children":[
                  {"id":4,"type":"Grid","events":{"frameChanged":7}}]}]}]}
            """);

        var scroll = (ScrollView)stack.Children[0];
        var grid = (Grid)scroll.Content;
        var reader = (Grid)grid.Children[0];

        stack.Frame = new Rect(0, 100, 400, 800);
        scroll.Frame = new Rect(10, 40, 380, 700);
        grid.Frame = new Rect(5, 300, 370, 200);

        reader.Frame = new Rect(20, 30, 100, 50);

        // 20 + 5 + 10 + 0 = 35 across, 30 + 300 + 40 + 100 = 470 down.
        Assert.Equal((7, "[20, 30, 100, 50, 35, 470, 35, 470]"), host.Dispatched[^1]);

        // The scroll moves the content out from under the viewport, and the
        // report comes WITHOUT the view's own frame moving an inch: the first
        // report attached the ancestors, and the scroll is one of them
        // changing. The window origin drops by exactly the offset.
        ((IScrollViewController)scroll).SetScrolledPosition(0, 250);

        Assert.Equal((7, "[20, 30, 100, 50, 35, 220, 35, 220]"), host.Dispatched[^1]);

        // An ANCESTOR moving reports the same way - the grid slides down and
        // the view's window origin follows, its own frame still untouched.
        grid.Frame = new Rect(5, 400, 370, 200);

        Assert.Equal((7, "[20, 30, 100, 50, 35, 320, 35, 320]"), host.Dispatched[^1]);
    }

    /// <summary>
    /// A view nobody listens to subscribes to nothing - the same rule Width
    /// and Height follow, because a frame moves at every measure.
    /// </summary>
    [Fact]
    public void AFrameNobodyListensToReportsNothing()
    {
        var host = new Host();

        var grid = (Grid)host.Apply("""
            {"id":1,"type":"Grid"}
            """);

        grid.Frame = new Rect(0, 0, 100, 100);

        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// The text tier on the controls whose caption is not a Text property. The
    /// control fixtures cannot see these reads - a tier is exercised once, by
    /// the Elements fixture, on a Label - so the four controls that joined the
    /// tier late are checked here: MAUI's Picker, DatePicker, TimePicker and
    /// RadioButton all declare TextColor and CharacterSpacing (and the first
    /// two of these once went unread), and Picker and Editor both declare the
    /// two alignments.
    /// </summary>
    [Fact]
    public void ABoxViewsCornerRadiusTakesOneNumberAndFourUnderTheSameName()
    {
        // The one converter both paths share: the reconcile read accepted a
        // single number only for a while, so the four-corner form styled and
        // the four-corner form assigned behaved differently on one wire name.
        var host = new Host();

        var box = (BoxView)host.Apply("""
            {"id":1,"type":"BoxView","props":{"cornerRadius":8}}
            """);

        Assert.Equal(new CornerRadius(8), box.CornerRadius);

        var corners = (BoxView)host.Apply("""
            {"id":2,"type":"BoxView","props":{"cornerRadius":[16,16,0,0]}}
            """);

        Assert.Equal(new CornerRadius(16, 16, 0, 0), corners.CornerRadius);
    }

    [Fact]
    public void TheInputTierLandsOnEveryInputView()
    {
        // The tier is declared once and exercised once, on the Elements
        // fixture's Entry - which covers ReconcileEntry and nothing else.
        // ReconcileEditor and ReconcileSearchBar each read the same five keys
        // separately, and this is what holds them to it.
        var host = new Host();

        var editor = (Editor)host.Apply($$$"""
            {"id":1,"type":"Editor","props":{
              "placeholder":"Notes","placeholderColor":"#D3D3D3",
              "isReadOnly":true,"maxLength":500,
              "keyboard":{{{Host.Member(SwiftKeyboard.Chat)}}}
            }}
            """);

        Assert.Equal("Notes", editor.Placeholder);
        Assert.Equal(Color.FromArgb("#D3D3D3"), editor.PlaceholderColor);
        Assert.True(editor.IsReadOnly);
        Assert.Equal(Keyboard.Chat, editor.Keyboard);
        Assert.Equal(500, editor.MaxLength);

        var search = (SearchBar)host.Apply($$$"""
            {"id":2,"type":"SearchBar","props":{
              "placeholder":"Search","placeholderColor":"#D3D3D3",
              "isReadOnly":true,"maxLength":40,
              "keyboard":{{{Host.Member(SwiftKeyboard.Plain)}}}
            }}
            """);

        Assert.Equal("Search", search.Placeholder);
        Assert.Equal(Color.FromArgb("#D3D3D3"), search.PlaceholderColor);
        Assert.True(search.IsReadOnly);
        Assert.Equal(Keyboard.Plain, search.Keyboard);
        Assert.Equal(40, search.MaxLength);
    }

    [Fact]
    public void TheTextTierLandsOnTheControlsWithoutATextProperty()
    {
        var host = new Host();

        var picker = (Picker)host.Apply($$$"""
            {"id":1,"type":"Picker","props":{
              "textColor":"#FF0000","characterSpacing":1.5,
              "horizontalTextAlignment":{{{Host.Member(SwiftTextAlignment.Center)}}},
              "verticalTextAlignment":{{{Host.Member(SwiftTextAlignment.End)}}}
            }}
            """);

        Assert.Equal(Color.FromArgb("#FF0000"), picker.TextColor);
        Assert.Equal(1.5, picker.CharacterSpacing);
        Assert.Equal(TextAlignment.Center, picker.HorizontalTextAlignment);
        Assert.Equal(TextAlignment.End, picker.VerticalTextAlignment);

        var date = (DatePicker)host.Apply("""
            {"id":2,"type":"DatePicker","props":{"textColor":"#FF0000","characterSpacing":1.5}}
            """);

        Assert.Equal(Color.FromArgb("#FF0000"), date.TextColor);
        Assert.Equal(1.5, date.CharacterSpacing);

        var time = (TimePicker)host.Apply("""
            {"id":3,"type":"TimePicker","props":{"textColor":"#FF0000","characterSpacing":1.5}}
            """);

        Assert.Equal(Color.FromArgb("#FF0000"), time.TextColor);
        Assert.Equal(1.5, time.CharacterSpacing);

        var radio = (RadioButton)host.Apply("""
            {"id":4,"type":"RadioButton","props":{"textColor":"#FF0000","characterSpacing":1.5}}
            """);

        Assert.Equal(Color.FromArgb("#FF0000"), radio.TextColor);
        Assert.Equal(1.5, radio.CharacterSpacing);

        var editor = (Editor)host.Apply($$$"""
            {"id":5,"type":"Editor","props":{
              "horizontalTextAlignment":{{{Host.Member(SwiftTextAlignment.Center)}}},
              "verticalTextAlignment":{{{Host.Member(SwiftTextAlignment.End)}}}
            }}
            """);

        Assert.Equal(TextAlignment.Center, editor.HorizontalTextAlignment);
        Assert.Equal(TextAlignment.End, editor.VerticalTextAlignment);
    }

    /// <summary>
    /// A control MAUI has no handler for on this platform is a control that
    /// cannot be made, and the renderer asks before it builds one.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The case is Map, whose handlers are an application's own opt-in and are
    /// absent on Windows outright. A Map built without one throws
    /// <c>HandlerNotFoundException</c> while the PLATFORM realizes the page -
    /// far from this renderer, and long after the render succeeded - so the
    /// page's whole content is lost and it comes up blank. Measured on Windows
    /// 2026-08-13.
    /// </para>
    /// <para>
    /// Only the DECISION is checked here. Reaching the marker headlessly would
    /// need <c>Application.Current.Handler</c> and a MauiContext behind it,
    /// which is a platform this suite deliberately does not have - so the other
    /// half is verified where it happens, on Windows, with the Map sample
    /// drawing the marker and the rest of its page.
    /// </remarks>
    [Fact]
    public void AControlWithNoHandlerRegisteredCannotBeMade()
    {
        // MAUI keeps its own factory internal, so the registry is stubbed: what
        // is under test is the DECISION, and the decision is one question -
        // does this type resolve to a handler.
        var handlers = new Registry(typeof(Label));

        Assert.True(StateUIRenderer.CanBeMade(handlers, typeof(Label)));
        Assert.False(StateUIRenderer.CanBeMade(handlers, typeof(Microsoft.Maui.Controls.Maps.Map)));

        // No registry is not an answer: a renderer that read it as "no" would
        // draw the marker over every control before the app has a context.
        Assert.True(StateUIRenderer.CanBeMade(null, typeof(Microsoft.Maui.Controls.Maps.Map)));
    }

    /// <summary>
    /// A handler registry holding exactly the types it was given, and nothing
    /// else: MAUI's own is internal, and what this test asks of one is a single
    /// question.
    /// </summary>
    private sealed class Registry(params Type[] known) : IMauiHandlersFactory
    {
        public Type? GetHandlerType(Type view) =>
            known.Contains(view) ? typeof(object) : null;

        public IElementHandler? GetHandler(Type type) => null;

        public IElementHandler? GetHandler<T>() where T : IElement => null;

        public IMauiHandlersCollection GetCollection() =>
            throw new NotSupportedException("the decision under test never asks for one");

        public object? GetService(Type serviceType) => null;
    }
}
