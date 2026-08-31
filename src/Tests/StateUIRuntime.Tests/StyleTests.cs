// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Styles: the other half of the contract in fixtures/styled.bin.
//
// There is no Style object on this side any more. A style is resolved in the
// differ, into the control it applies to, so what the Swift tests WRITE is a
// tree of ordinary controls already carrying their styles' values - and what
// these check is that those values reach the real MAUI properties, which is the
// only thing that proves a name was resolved rather than dropped.
//
// What DID stay is the property table, because a visual state still needs it: a
// Setter names its property as an object, and a name SwiftStyles does not know
// produces no setter at all - the state would be entered and simply not do that
// thing. So the last test here reads every control fixture and insists that
// each property a control accepts is one a state can set, which is also what
// makes it animatable.
//
// A state's `group` and `name` are NAMES on the wire, not text - written here as
// {"name":"Disabled"}, which is what the notation spells a session-dictionary
// name as. An author invents them, so they are not a closed vocabulary; they
// also repeat on every state of every control, so they are numbered once and
// cost two bytes thereafter, exactly as a property key does. Written as plain
// strings they read back null, and every state would land in CommonStates under
// the empty name - which is to say every state would be the same state.

using Microsoft.Maui.Controls.Shapes;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class StyleTests
{
    // ---- What a styled control arrives as ----------------------------------

    /// <summary>
    /// The values a style gave a control reach the real MAUI properties. Read
    /// off the fixture the Swift side writes, which is the whole contract now:
    /// a stack of four controls, each carrying what its style resolved to.
    /// </summary>
    private static VerticalStackLayout Styled() =>
        (VerticalStackLayout)new Host().ApplyMessage(Fixtures.ReadBytes("styled.bin"));

    /// <summary>
    /// An implicit style's values land on every control of the type, and there
    /// is nothing to look them up in: they arrived as the control's own.
    /// </summary>
    [Fact]
    public void AnImplicitStylesValuesLandOnTheControl()
    {
        var body = (Label)Styled().Children[1];

        Assert.Equal(14, body.FontSize);
        Assert.Equal(Color.Parse("#212121"), body.TextColor);
        Assert.Null(body.Style);
    }

    /// <summary>
    /// Every setter of a bigger one reaches the property it names, structured
    /// values included - a Thickness, and MAUI's own converters where it has a
    /// syntax.
    /// </summary>
    [Fact]
    public void TheSettersReachTheProperties()
    {
        VerticalStackLayout stack = Styled();

        var button = (Button)stack.Children[2];

        // It ARRIVES disabled, so its Disabled state has already won - see
        // AVisualStateChangesTheControlWhenItEntersIt. What the style set is
        // underneath that.
        button.IsEnabled = true;

        Assert.Equal(Colors.White, button.TextColor);
        Assert.Equal(Color.Parse("#512BD4"), button.BackgroundColor);
        Assert.Equal(8, button.CornerRadius);
        Assert.Equal(new Thickness(14, 10, 14, 10), button.Padding);
        Assert.Equal(44, button.MinimumHeightRequest);

        var border = (Border)stack.Children[3];

        Assert.Equal(Color.Parse("#C8C8C8"), Assert.IsType<SolidColorBrush>(border.Stroke).Color);
        Assert.Equal(1, border.StrokeThickness);
        Assert.Equal(12, Assert.IsType<RoundRectangle>(border.StrokeShape).CornerRadius.TopLeft);
    }

    /// <summary>
    /// A keyed style REPLACES the implicit one for the type, and what it is
    /// based on is already under it - flattened where the sheet was built, so
    /// nothing on this side walks a chain.
    /// </summary>
    [Fact]
    public void AKeyedStyleArrivesFlattenedAndWithoutTheImplicitOne()
    {
        var headline = (Label)Styled().Children[0];

        Assert.Equal(32, headline.FontSize);
        Assert.Equal(FontAttributes.Bold, headline.FontAttributes);
        Assert.Equal(TextAlignment.Center, headline.HorizontalTextAlignment);

        // The implicit Label style's colour is not on it: a keyed style is
        // asked for, so it says everything it needs.
        Assert.Null(headline.TextColor);
    }

    /// <summary>
    /// A Setter list is applied in order, and a DatePicker's Date is clamped
    /// into the range AS IT IS SET - so the bounds must run first. Sorting by
    /// name almost said that (Maximum before Value), and for a DatePicker said
    /// the opposite: "date" sorts before "maximumDate", and a date set in a
    /// state was clamped to 2100 before its own bound ran.
    /// </summary>
    [Fact]
    public void ADateBeyondTheDefaultRangeSurvivesItsOwnBounds()
    {
        var host = new Host();

        var picker = (DatePicker)host.Apply("""
            {"id":1,"type":"DatePicker","children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}},
               "children":[{"id":3,"type":"Setters","props":{
                 "date":[2150,6,15],"maximumDate":[2200,12,31]}}]}]}
            """);

        Assert.Equal(new DateTime(2200, 12, 31), picker.MaximumDate);
        Assert.Equal(new DateTime(2150, 6, 15), picker.Date);
    }

    // ---- Colours -----------------------------------------------------------

    /// <summary>
    /// A colour arrives as its four channels and becomes MAUI's own, which
    /// holds the same four over 0-1.
    /// </summary>
    /// <remarks>
    /// One colour, always. A <c>Color(light:dark:)</c> picked its half on the
    /// Swift side as the value was written onto the node, so nothing here asks
    /// what theme is in force and nothing is bound - see Types/Color.swift.
    /// </remarks>
    [Fact]
    public void AColourArrivesAsItsFourChannels()
    {
        var host = new Host();
        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"Hi","textColor":"#000000"}}
            """);

        Assert.Equal(Colors.Black, label.TextColor);
    }

    /// <summary>Alpha included, which is the fourth channel and not an afterthought.</summary>
    [Fact]
    public void AColourCarriesItsAlpha()
    {
        var host = new Host();
        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"Hi","textColor":"#80FF0000"}}
            """);

        Assert.Equal(1f, label.TextColor.Red);
        Assert.Equal(0f, label.TextColor.Green);
        Assert.Equal(128 / 255f, label.TextColor.Alpha, 3);
    }

    /// <summary>
    /// A Brush property takes one too - MAUI turns a colour into a
    /// SolidColorBrush on the way in.
    /// </summary>
    [Fact]
    public void AColourReachesABrushProperty()
    {
        var host = new Host();
        var border = (Border)host.Apply("""
            {"id":1,"type":"Border","props":{"stroke":"#C8C8C8","strokeThickness":1}}
            """);

        Assert.Equal(Color.Parse("#C8C8C8"), Assert.IsType<SolidColorBrush>(border.Stroke).Color);
    }

    /// <summary>
    /// And the navigation bar's, which belongs to the ARRANGEMENT drawing it
    /// rather than to the page - MAUI's own IBarElement.
    /// </summary>
    [Fact]
    public void AColourReachesTheBarOfTheStackDrawingIt()
    {
        var window = Host.Window();

        window.Apply(Host.Parse("""
            {"id":1,"type":"Window","children":[
              {"id":2,"type":"NavigationPage","arranged":true,
               "props":{"barBackgroundColor":"#512BD4","barTextColor":"#FFFFFF"},"children":[
                {"id":"root","type":"ContentPage","props":{"backgroundColor":"#FFFFFF"},
                 "children":[{"id":3,"type":"Label","props":{"text":"one"}}]}]}]}
            """), complete: true);

        var stack = Assert.IsType<NavigationPage>(window.Page);

        Assert.Equal(Color.Parse("#512BD4"), stack.BarBackgroundColor);
        Assert.Equal(Colors.White, stack.BarTextColor);
        Assert.Equal(Colors.White, Assert.IsType<ContentPage>(stack.CurrentPage).BackgroundColor);
    }

    /// <summary>And a state's setters, where it is an ordinary value.</summary>
    /// <remarks>
    /// A two-colour value resolves in Swift as it is written - the read is
    /// recorded, and a theme change rebuilds exactly the views that asked - so
    /// by the time a Setter sees it, it is four channels like any other value.
    /// MAUI's AppThemeBinding is internal, and nothing here needs it.
    /// </remarks>
    [Fact]
    public void AColourInAStateIsAnOrdinarySetterValue()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"Hi"},"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}},
               "children":[{"id":3,"type":"Setters",
                            "props":{"textColor":"#212121"}}]}]}
            """);

        Assert.Equal(Color.Parse("#212121"), label.TextColor);
    }

    /// <summary>
    /// A colour written over another wins, which is what makes it safe for the
    /// renderer to write over whatever the last render left.
    /// </summary>
    [Fact]
    public void AColourWrittenOverAnotherWins()
    {
        var host = new Host();

        host.Apply("""
            {"id":1,"type":"Label","props":{"text":"Hi","textColor":"#000000"}}
            """);

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"textColor":"#FF0000"}}
            """);

        Assert.Equal(Colors.Red, label.TextColor);
    }

    // ---- Pictures ----------------------------------------------------------

    /// <summary>
    /// A picture is one file name, for the reason a colour is one colour:
    /// artwork drawn once per theme picked its half on the Swift side.
    /// </summary>
    [Fact]
    public void APictureIsTheFileTheTreeNamed()
    {
        var host = new Host();
        var image = (Image)host.Apply("""
            {"id":1,"type":"Image","props":{"source":"nav_home.png"}}
            """);

        Assert.Equal("nav_home.png", Assert.IsType<FileImageSource>(image.Source).File);
    }

    /// <summary>And a tab's picture, which is an image source as well.</summary>
    [Fact]
    public void APictureReachesATabsIcon()
    {
        var window = Host.Window();

        window.Apply(Host.Parse("""
            {"id":1,"type":"Window","children":[
              {"id":2,"type":"TabbedPage","arranged":true,"props":{"currentPage":0},"children":[
                {"id":"home","type":"ContentPage",
                 "props":{"title":"Home","iconImageSource":"nav_home.png"},"children":[
                  {"id":3,"type":"Label","props":{"text":"one"}}]}]}]}
            """), complete: true);

        var tabs = Assert.IsType<TabbedPage>(window.Page);

        Assert.Equal("nav_home.png",
            Assert.IsType<FileImageSource>(tabs.Children[0].IconImageSource).File);
    }

    // ---- Visual states on the control itself -------------------------------

    /// <summary>
    /// A control can carry its own states, and they reach the manager exactly as
    /// a style's do.
    /// </summary>
    [Fact]
    public void AControlsOwnStatesReachTheVisualStateManager()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},"arranged":true,"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}},
               "children":[{"id":4,"type":"Setters","props":{"textColor":"#FF0000"}}]}]}
            """);

        IList<VisualStateGroup> groups = VisualStateManager.GetVisualStateGroups(label);

        Assert.Equal("CommonStates", Assert.Single(groups).Name);
        Assert.Equal(["Normal", "Disabled"], groups[0].States.Select(state => state.Name));

        // And the proof is what happens, not what is on the list.
        label.IsEnabled = false;

        Assert.Equal(Color.Parse("#FF0000"), label.TextColor);
    }

    /// <summary>
    /// A control that ARRIVES in a state is drawn in it, which is an ordering
    /// fact rather than a lucky one.
    /// </summary>
    /// <remarks>
    /// The properties are assigned before the states are, so <c>IsEnabled</c>
    /// goes false while there is no group to hear it. What saves it is that
    /// setting the group list evaluates it - measured, in
    /// <c>MauiStatesTests.AGroupWithANormalRestsInIt</c>, where a fresh group
    /// enters Normal with nothing having driven it. Which is also why the list
    /// is assigned only when it changed: assigning it again puts a hovered
    /// control back to resting.
    /// </remarks>
    [Fact]
    public void AControlThatArrivesInAStateIsDrawnInIt()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one","isEnabled":false},"arranged":true,
             "children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}},
               "children":[{"id":4,"type":"Setters","props":{"textColor":"#FF0000"}}]}]}
            """);

        Assert.Equal(Color.Parse("#FF0000"), label.TextColor);
    }

    /// <summary>
    /// The states are NOT among the children the control lays out.
    /// </summary>
    /// <remarks>
    /// The <c>ContextFlyout</c> rule: a slot is appended after whatever the
    /// control arranges, and every arrangement leaves it alone. Getting this
    /// wrong shows as a state drawn as an empty row in the middle of a stack.
    /// </remarks>
    [Fact]
    public void AControlsStatesAreNoneOfTheChildrenItLaysOut()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.Apply("""
            {"id":1,"type":"VerticalStackLayout","arranged":true,"children":[
              {"id":2,"type":"Label","props":{"text":"one"}},
              {"id":3,"type":"Label","props":{"text":"two"}},
              {"id":4,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":5,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}},
               "children":[{"id":6,"type":"Setters","props":{"opacity":0.5}}]}]}
            """);

        Assert.Equal(2, stack.Children.Count);
        Assert.Equal(2, VisualStateManager.GetVisualStateGroups(stack).Single().States.Count);
    }

    /// <summary>
    /// A patch about one state leaves the others exactly as they were.
    /// </summary>
    /// <remarks>
    /// The states are the first children here that are DATA rather than views,
    /// and a group list is assigned in one go - so the described states are kept
    /// per control and an arrival is merged into them. Built from the patch
    /// alone, the state it does not mention would simply vanish.
    /// </remarks>
    [Fact]
    public void APatchAboutOneStateKeepsTheOthers()
    {
        var host = new Host();

        host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},"arranged":true,"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}},
               "children":[{"id":4,"type":"Setters","props":{"textColor":"#FF0000"}}]},
              {"id":5,"type":"VisualState",
               "props":{"name":{"name":"Focused"},"group":{"name":"CommonStates"}},
               "children":[{"id":6,"type":"Setters","props":{"textColor":"#00FF00"}}]}]}
            """);

        // Only the Disabled state changed, and only its colour within it.
        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","children":[
              {"id":3,"type":"VisualState",
               "children":[{"id":4,"type":"Setters","props":{"textColor":"#0000FF"}}]}]}
            """);

        IList<VisualStateGroup> groups = VisualStateManager.GetVisualStateGroups(label);

        Assert.Equal(["Normal", "Disabled", "Focused"], groups.Single().States.Select(one => one.Name));

        label.IsEnabled = false;

        Assert.Equal(Color.Parse("#0000FF"), label.TextColor);

        label.IsEnabled = true;
        label.SetValue(VisualElement.IsFocusedPropertyKey, true);

        Assert.Equal(Color.Parse("#00FF00"), label.TextColor);
    }

    /// <summary>
    /// And a state that LEAVES is absent from an arranged list, the way every
    /// slot's leaving is said.
    /// </summary>
    [Fact]
    public void AStateThatLeavesIsTakenOffTheControl()
    {
        var host = new Host();

        host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},"arranged":true,"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}},
               "children":[{"id":4,"type":"Setters","props":{"textColor":"#FF0000"}}]}]}
            """);

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","arranged":true,"children":[]}
            """);

        Assert.Empty(VisualStateManager.GetVisualStateGroups(label));

        label.IsEnabled = false;

        Assert.Null(label.TextColor);
    }

    // ---- Hearing which state it entered ------------------------------------

    /// <summary>
    /// A control that asked hears the state it entered, and the state's NAME is
    /// what crosses.
    /// </summary>
    /// <remarks>
    /// A VisualStateGroup announces what it entered in no other way - MAUI gives
    /// <c>CurrentState</c> no event - so the announcement is a setter the
    /// renderer adds to every declared state, and the property being written is
    /// what it listens to. The trick <c>FlyoutRow</c> has always used.
    /// </remarks>
    [Fact]
    public void AControlThatAskedHearsWhichStateItEntered()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},
             "events":{"visualStateChanged":7},"arranged":true,"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}}}]}
            """);

        label.IsEnabled = false;

        Assert.Equal((7, "\"Disabled\""), host.Dispatched[^1]);

        label.IsEnabled = true;

        Assert.Equal((7, "\"Normal\""), host.Dispatched[^1]);
    }

    /// <summary>
    /// LEAVING a state is not a report, and neither is entering the one it is
    /// already in.
    /// </summary>
    /// <remarks>
    /// MAUI puts the announcing property back before the next state sets it, so
    /// the raw property changes twice per transition and once with nothing in
    /// it. What crosses is the state actually entered - the frame report's
    /// dedupe, one level up.
    /// </remarks>
    [Fact]
    public void LeavingAStateIsNotAReportAndNeitherIsEnteringItTwice()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},
             "events":{"visualStateChanged":7},"arranged":true,"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}}}]}
            """);

        label.IsEnabled = false;
        label.IsEnabled = true;

        Assert.Equal(2, host.Dispatched.Count);

        // Already Normal: MAUI writes the property, and nothing crosses.
        VisualStateManager.GoToState(label, "Normal");

        Assert.Equal(2, host.Dispatched.Count);
    }

    /// <summary>
    /// A control nobody asked about announces nothing - the <c>Watch</c> rule,
    /// which is what keeps a setter off every state in the tree.
    /// </summary>
    [Fact]
    public void AControlNobodyAskedAboutCarriesNoAnnouncement()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},"arranged":true,"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}},
               "children":[{"id":4,"type":"Setters","props":{"textColor":"#FF0000"}}]}]}
            """);

        IList<VisualStateGroup> groups = VisualStateManager.GetVisualStateGroups(label);

        // A COLOUR IS NOT A SETTER: a value with a half-way is carried by the
        // engine instead, so what is left in the state is the announcement the
        // engine listens for - and nothing else. See StateUIRenderer.Settle.
        Assert.Equal(
            ["SwiftVisualState"],
            groups[0].States[1].Setters.Select(setter => setter.Property.PropertyName));

        label.IsEnabled = false;

        // The announcement is the ENGINE's, and it reaches Swift only where the
        // tree asked to hear it - which nobody here did.
        Assert.Equal(Color.Parse("#FF0000"), label.TextColor);
        Assert.Empty(host.Dispatched);
    }

    /// <summary>
    /// And a handler that arrives LATER gets the announcement, even though the
    /// states themselves did not change.
    /// </summary>
    /// <remarks>
    /// The states are assigned again only when something about them changed;
    /// being asked to announce is one of those things, or a control would go on
    /// silently for as long as its states stood still.
    /// </remarks>
    [Fact]
    public void AHandlerThatArrivesLaterIsStillAnnouncedTo()
    {
        var host = new Host();

        host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},"arranged":true,"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}}}]}
            """);

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","events":{"visualStateChanged":9}}
            """);

        label.IsEnabled = false;

        Assert.Equal((9, "\"Disabled\""), host.Dispatched[^1]);
    }

    /// <summary>
    /// A state entered because the RENDERER assigned a property is reported
    /// too, and that takes the deferral to be true.
    /// </summary>
    /// <remarks>
    /// Disabling a control from Swift is the ordinary way to enter a state, and
    /// it happens inside a render - where <c>Raise</c> answers nothing, the
    /// guard that stops the renderer reporting its own writes. So the report
    /// waits one dispatcher turn, by which time the render is over. Reporting
    /// from inside it would start a handler mid-render, which is the
    /// re-entrancy that crashed Android from MAUI's own property setter once.
    /// </remarks>
    [Fact]
    public void AStateEnteredWhileRenderingIsStillReported()
    {
        var host = new Host();

        host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},
             "events":{"visualStateChanged":7},"arranged":true,"children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}}},
              {"id":3,"type":"VisualState",
               "props":{"name":{"name":"Disabled"},"group":{"name":"CommonStates"}}}]}
            """);

        TestDispatcher.Hold();

        // The renderer assigns IsEnabled, MAUI enters Disabled, and the report
        // is armed while nothing can be raised.
        host.Apply("""
            {"id":1,"type":"Label","props":{"isEnabled":false}}
            """);

        Assert.Empty(host.Dispatched);

        TestDispatcher.Drain();

        Assert.Equal((7, "\"Disabled\""), host.Dispatched[^1]);
    }

    /// <summary>
    /// A control that declares no states reports nothing, which is what the
    /// modifier's doc comment says out loud.
    /// </summary>
    /// <remarks>
    /// There is nowhere to put the announcing setter: a state has to be declared
    /// before MAUI will enter it at all.
    /// </remarks>
    [Fact]
    public void AControlWithNoStatesOfItsOwnReportsNothing()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":1,"type":"Label","props":{"text":"one"},"events":{"visualStateChanged":7}}
            """);

        label.IsEnabled = false;

        Assert.Empty(host.Dispatched);
    }

    // ---- Visual states a style gave the control ----------------------------

    /// <summary>
    /// The states a style declared arrive as the control's own, which is the
    /// one shape this side knows - and the proof is what happens, not what is
    /// on the list: MAUI moves the control into Disabled by itself.
    /// </summary>
    [Fact]
    public void AVisualStateChangesTheControlWhenItEntersIt()
    {
        var button = (Button)Styled().Children[2];

        IList<VisualStateGroup> groups = VisualStateManager.GetVisualStateGroups(button);

        Assert.Equal("CommonStates", Assert.Single(groups).Name);

        // Normal first, and it changes nothing: a control starts in the first
        // state its group declares, so a style with only a Disabled would draw
        // everything disabled. The Swift side adds it where one was not written.
        Assert.Equal(["Normal", "Disabled"], groups[0].States.Select(state => state.Name));

        // Normal changes nothing of its own; what it carries is the
        // announcement, which is how the engine hears that a state was left.
        Assert.Equal(
            ["SwiftVisualState"],
            groups[0].States[0].Setters.Select(setter => setter.Property.PropertyName));

        // The fixture's button arrives disabled, so it is drawn in that state
        // already: the properties are assigned before the states, and setting
        // the group list evaluates it.
        Assert.Equal(Color.Parse("#C8C8C8"), button.BackgroundColor);
        Assert.Equal(Color.Parse("#141414"), button.TextColor);

        button.IsEnabled = true;

        Assert.Equal(Color.Parse("#512BD4"), button.BackgroundColor);
    }

    // ---- The table, kept honest --------------------------------------------

    /// <summary>
    /// Properties that belong to something else, and so are not a control's to
    /// style.
    /// </summary>
    /// <remarks>
    /// The gesture keys configure a recognizer rather than the view carrying it;
    /// and a Picker's items
    /// are data, which MAUI types as an untyped IList and nobody would put in a
    /// style. A selection is the same: an index points INTO those items, and
    /// MAUI's SelectedItem holds one of them.
    /// </remarks>
    private static readonly HashSet<string> NotTheControls =
    [
        "numberOfTapsRequired", "swipeDirection", "swipeThreshold", "panTouchCount",
        "dragText", "canDrag", "allowDrop",
        "itemsSource",
        "selectedIndex",

        // Where a Map opens. MAUI has no region property to put in a style -
        // MoveToRegion is a method - so the wire's `region` lands through the
        // method and no style can name it, in MAUI either.
        "region",
    ];

    /// <summary>
    /// Node types that are not controls, and so are not style targets either.
    /// </summary>
    /// <remarks>
    /// MAUI's SwipeItem is a MenuItem and SwipeItems the collection holding
    /// them: neither is a View, neither has a Style MAUI would apply to it, and
    /// the Swift side cannot write one - a StyleTarget is a VisualElement. Named
    /// here for the same reason Fixtures.notViews names them on the Swift side.
    /// </remarks>
    private static readonly HashSet<string> NotControls =
    [
        "SwipeItem", "SwipeItems",
        "FormattedString", "Span",
        "ToolbarItem", "MenuBarItem",
        "MenuFlyoutItem", "MenuFlyoutSubItem", "MenuFlyoutSeparator",
        "ContextFlyout",
        "Pin",
    ];

    /// <summary>
    /// The properties Swift will not ask this side to clear, read from its own
    /// declaration so the two halves cannot drift.
    /// </summary>
    /// <remarks>
    /// Swift sends the whole element again for one of these - so a key named
    /// here needs no BindableProperty, and a key NOT named here needs one.
    /// </remarks>
    private static HashSet<string> NotCleared()
    {
        string source = File.ReadAllText(
            System.IO.Path.Combine(SwiftEnums.Sources, "Core", "Tokens.swift"));

        int start = source.IndexOf("static let notCleared", StringComparison.Ordinal);
        Assert.True(start >= 0, "Prop.notCleared is not declared in Core/Tokens.swift any more");

        int open = source.IndexOf('[', start);
        int close = source.IndexOf(']', open);

        HashSet<string> named = System.Text.RegularExpressions.Regex
            .Matches(source[(open + 1)..close], @"\.([A-Za-z][A-Za-z0-9]*)")
            .Select(match => match.Groups[1].Value)
            .ToHashSet(StringComparer.Ordinal);

        Assert.NotEmpty(named);

        // Every one of them is a property this side knows by that spelling. A
        // name that is not - one renamed on the Swift side, or one left behind
        // by a property that went away - would silently stop excluding
        // anything, and the list would read as covering more than it does.
        foreach (string name in named.OrderBy(name => name, StringComparer.Ordinal))
        {
            Assert.True(
                SwiftTokenNames<SwiftProp>.Parse(name) != SwiftProp.None,
                $"Prop.notCleared names '{name}', which is not a property this side has");
        }

        return named;
    }

    [Fact]
    public void EveryPropertyThatCannotBeClearedIsNamedOnBothSides()
    {
        var missing = new List<string>();
        HashSet<string> notCleared = NotCleared();
        int checkedProperties = 0;

        // Every page fixture is a session of its own, so each gets a fresh
        // dictionary. The window fixtures are ONE session in two messages -
        // the second reads names the first announced - so they share theirs
        // and are read in order.
        foreach ((string directory, bool oneSession) in
            new[] { ("controls", false), ("pages", false), ("windows", true) })
        {
            var names = new SwiftWireDictionary();

            foreach (string path in Directory
                .EnumerateFiles(System.IO.Path.Combine(Fixtures.Directory, directory), "*.bin")
                .OrderBy(name => name, StringComparer.Ordinal))
            {
                if (!oneSession)
                {
                    names = new SwiftWireDictionary();
                }

                SwiftMessage message = SwiftWire.ReadMessage(File.ReadAllBytes(path), names);

                if (message.Root is SwiftNode root)
                {
                    Check(root);
                }
            }
        }

        Assert.True(checkedProperties > 20, $"only {checkedProperties} properties were read");

        Assert.True(missing.Count == 0,
            "SwiftStyles has no BindableProperty for " + string.Join(", ", missing) +
            ".\n\nA property with none is one the renderer cannot CLEAR when the tree " +
            "stops describing it, so the old value would stand on a page the author no " +
            "longer wrote it on. Add it to the arm for that type, or name it in " +
            "Prop.notCleared on the Swift side so the element is sent again instead.");

        void Check(SwiftNode node)
        {
            foreach (SwiftProp prop in node.Props?.Keys ?? Enumerable.Empty<SwiftProp>())
            {
                string key = SwiftTokenNames<SwiftProp>.Spelling(prop);

                if (notCleared.Contains(key))
                {
                    continue;
                }

                checkedProperties++;

                if (SwiftStyles.Property(node.Type, node.TypeName, prop) is null)
                {
                    missing.Add($"{node.TypeName}.{key}");
                }
            }

            foreach (SwiftNode child in node.Children ?? [])
            {
                Check(child);
            }
        }
    }

    [Fact]
    public void EveryPropertyAControlAcceptsCanBeSetInAState()
    {
        var missing = new List<string>();
        int checkedProperties = 0;

        foreach (string path in Directory.EnumerateFiles(
            System.IO.Path.Combine(Fixtures.Directory, "controls"), "*.bin").OrderBy(name => name))
        {
            Check(Host.Parse(File.ReadAllBytes(path)));
        }

        // Not vacuous: there really are that many properties behind this.
        Assert.True(checkedProperties > 100, $"only {checkedProperties} properties were read");

        Assert.True(missing.Count == 0,
            "SwiftStyles has no BindableProperty for " + string.Join(", ", missing) +
            ".\n\nA property no BindableProperty is known for is one a visual " +
            "state silently will not set, and one an animation cannot walk. Add " +
            "it to the arm for that control, beside the same name in the renderer.");

        void Check(SwiftNode node)
        {
            // The keys come back as MEMBERS, and this reports what is MISSING -
            // so each spelling is derived from its member, which is what
            // SwiftTokenNames answers and what a reader of the failure needs.
            foreach (SwiftProp prop in NotControls.Contains(node.TypeName)
                ? Enumerable.Empty<SwiftProp>()
                : node.Props?.Keys ?? Enumerable.Empty<SwiftProp>())
            {
                string key = SwiftTokenNames<SwiftProp>.Spelling(prop);

                if (NotTheControls.Contains(key))
                {
                    continue;
                }

                checkedProperties++;

                if (SwiftStyles.Property(node.Type, node.TypeName, prop)
                    is not BindableProperty property)
                {
                    missing.Add($"{node.TypeName}.{key}");
                }
                else if (SwiftStyles.Value(property, node, prop) is null)
                {
                    // The name resolved and the VALUE did not - the hole the
                    // nullable DatePicker.Date sat in: the setter is built
                    // from both halves, and either missing drops it silently.
                    missing.Add($"{node.TypeName}.{key} (the value did not convert)");
                }
            }

            foreach (SwiftNode child in node.Children ?? [])
            {
                Check(child);
            }
        }
    }

}
