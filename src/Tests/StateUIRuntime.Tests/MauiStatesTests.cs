// WHICH states MAUI drives, and on WHICH control, pinned against MAUI itself.
//
// The Swift side names every one of them by hand - a VisualState is matched by
// its NAME, so there is no enum to read and nothing to convert - which makes
// this the sister of MauiNumbersTests: a MAUI release that renamed a state, or
// stopped driving one, fails a test here instead of an application in the
// field, where a state nobody enters looks exactly like a style that was never
// applied.
//
// Every one of these drives the state for REAL - a property is set and the
// group is read back - rather than reading a name out of the metadata. What is
// being pinned is the behaviour, not the spelling.

using Microsoft.Maui.Graphics;

namespace StateUI.Runtime.Tests;

public class MauiStatesTests
{
    /// <summary>
    /// The group nearly everything is in, and the names in it.
    /// </summary>
    /// <remarks>
    /// <c>Unfocused</c> is missing here on purpose: MAUI drives it - the test
    /// below enters it - and keeps the constant INTERNAL, so the only way to
    /// name it is to spell it, which is what the Swift side does with all six.
    /// </remarks>
    [Fact]
    public void TheCommonStatesAreTheOnesThisLibraryNames()
    {
        Assert.Equal("Normal", VisualStateManager.CommonStates.Normal);
        Assert.Equal("Disabled", VisualStateManager.CommonStates.Disabled);
        Assert.Equal("Focused", VisualStateManager.CommonStates.Focused);
        Assert.Equal("PointerOver", VisualStateManager.CommonStates.PointerOver);
        Assert.Equal("Selected", VisualStateManager.CommonStates.Selected);
    }

    // ---- What every view has -----------------------------------------------

    [Fact]
    public void AnyViewEntersDisabledAndComesBack()
    {
        var label = new Label();

        Declare(label, "Normal", "Disabled");

        label.IsEnabled = false;

        Assert.Equal("Disabled", In(label));

        label.IsEnabled = true;

        Assert.Equal("Normal", In(label));
    }

    [Fact]
    public void AnyViewEntersFocusedAndUnfocused()
    {
        var entry = new Entry();

        Declare(entry, "Normal", "Focused", "Unfocused");

        Focus(entry, true);

        Assert.Equal("Focused", In(entry));

        Focus(entry, false);

        Assert.Equal("Unfocused", In(entry));
    }

    /// <summary>
    /// Unfocused is applied AFTER Normal, so declaring it shadows Normal for
    /// every view that is enabled and not focused.
    /// </summary>
    /// <remarks>
    /// <c>VisualElement.ChangeVisualState</c> goes to Disabled, PointerOver or
    /// Normal, and THEN to Focused or Unfocused - two calls, one group. So a
    /// group that declares both Normal and Unfocused sits in Unfocused at rest,
    /// and the Normal it also declares is only ever passed through. Worth
    /// knowing before writing one: Unfocused is not the pair of Focused so much
    /// as a second spelling of Normal.
    /// </remarks>
    [Fact]
    public void UnfocusedIsWhereAnEnabledViewRestsWhenBothAreDeclared()
    {
        var entry = new Entry();

        Declare(entry, "Normal", "Unfocused");

        // Nothing is focused, and the view is enabled: Normal, then Unfocused.
        entry.IsEnabled = false;
        entry.IsEnabled = true;

        Assert.Equal("Unfocused", In(entry));
    }

    /// <summary>
    /// And a state no group declares leaves the group exactly where it was.
    /// </summary>
    /// <remarks>
    /// Which is what makes the walk in <c>StateUIWindow.FlyoutRow</c>
    /// harmless - it moves every view in a row into the row's state, and a view
    /// that says nothing about it is not touched.
    /// </remarks>
    [Fact]
    public void AStateNoGroupDeclaresLeavesTheViewWhereItWas()
    {
        var label = new Label();

        Declare(label, "Normal", "Disabled");

        label.IsEnabled = false;

        Assert.False(VisualStateManager.GoToState(label, "PointerOver"));
        Assert.Equal("Disabled", In(label));
    }

    /// <summary>
    /// A group with no Normal can be ENTERED and never LEFT, which is the whole
    /// reason an empty Normal is put in front of every group that wrote none.
    /// </summary>
    /// <remarks>
    /// A state is left by entering another one, so a group whose only state is
    /// Disabled has no way back: the view is disabled once and stays drawn that
    /// way for the rest of its life, with nothing anywhere reporting it. What a
    /// fresh group does before anything drives it is a separate fact - it enters
    /// nothing at all and applies nothing, headlessly - so the trap is not the
    /// opening, it is the return.
    /// </remarks>
    [Fact]
    public void AGroupWithNoNormalIsEnteredAndNeverLeft()
    {
        var label = new Label();

        Declare(label, ("Disabled", Colors.Red));

        // Nothing has driven it yet: no state, and no setter applied.
        Assert.Null(In(label));
        Assert.Null(label.TextColor);

        label.IsEnabled = false;

        Assert.Equal("Disabled", In(label));
        Assert.Equal(Colors.Red, label.TextColor);

        // And back - except there is no back.
        label.IsEnabled = true;

        Assert.Equal("Disabled", In(label));
        Assert.Equal(Colors.Red, label.TextColor);
    }

    /// <summary>And a Normal to return to is all it takes.</summary>
    [Fact]
    public void AGroupWithANormalRestsInIt()
    {
        var label = new Label();

        Declare(label, ("Disabled", Colors.Red), ("Normal", Colors.Green));

        Assert.Equal("Normal", In(label));
        Assert.Equal(Colors.Green, label.TextColor);
    }

    // ---- What one control has and another does not -------------------------

    [Fact]
    public void AButtonEntersPressed()
    {
        var button = new Button();

        Declare(button, "Normal", "Pressed");

        ((IButtonController)button).SendPressed();

        Assert.Equal("Pressed", In(button));

        ((IButtonController)button).SendReleased();

        Assert.Equal("Normal", In(button));
    }

    [Fact]
    public void AnImageButtonEntersPressed()
    {
        var button = new ImageButton();

        Declare(button, "Normal", "Pressed");

        ((IButtonController)button).SendPressed();

        Assert.Equal("Pressed", In(button));
    }

    [Fact]
    public void ASwitchEntersOnAndOff()
    {
        var toggle = new Switch();

        Declare(toggle, "Normal", "On", "Off");

        toggle.IsToggled = true;

        Assert.Equal("On", In(toggle));

        toggle.IsToggled = false;

        Assert.Equal("Off", In(toggle));
    }

    /// <summary>
    /// A CheckBox has ONE state of its own, and it is named for the property.
    /// </summary>
    [Fact]
    public void ACheckBoxEntersIsChecked()
    {
        var box = new CheckBox();

        Declare(box, "Normal", "IsChecked");

        box.IsChecked = true;

        Assert.Equal("IsChecked", In(box));

        box.IsChecked = false;

        Assert.Equal("Normal", In(box));
    }

    /// <summary>
    /// A RadioButton has TWO, and neither is spelled the CheckBox's way.
    /// </summary>
    /// <remarks>
    /// Note what the group does NOT declare: see below for why a Normal beside
    /// them takes both away.
    /// </remarks>
    [Fact]
    public void ARadioButtonEntersCheckedAndUnchecked()
    {
        var radio = new RadioButton();

        Declare(radio, "Unchecked", "Checked");

        radio.IsChecked = true;

        Assert.Equal("Checked", In(radio));

        radio.IsChecked = false;

        Assert.Equal("Unchecked", In(radio));
    }

    /// <summary>
    /// A RadioButton is the one control whose own states are SHADOWED by a
    /// Normal beside them, and it is the order that does it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// <c>RadioButton.ChangeVisualState</c> calls <c>ApplyIsCheckedState</c>
    /// FIRST - which enters Checked or Unchecked - and the base
    /// <c>ChangeVisualState</c> after it, which enters Normal. So a group that
    /// declares Normal ends every transition there and the pair is never seen;
    /// a group without one keeps what ApplyIsCheckedState chose, the move to
    /// Normal finding nothing.
    /// </para>
    /// <para>
    /// Read from the IL and then driven: RadioButton is the only control this
    /// way round - a Switch and a CheckBox call the base first, so their own
    /// states win over the Normal beside them. Which is why the resting state a
    /// style is given when it wrote none is the TARGET's, not always Normal.
    /// </para>
    /// </remarks>
    [Fact]
    public void ANormalBesideARadioButtonsOwnStatesTakesThemAway()
    {
        var radio = new RadioButton();

        Declare(radio, "Normal", "Checked", "Unchecked");

        radio.IsChecked = true;

        Assert.Equal("Normal", In(radio));
    }

    /// <summary>
    /// A Switch is the other way round, which is what makes the pair worth
    /// pinning: its own states win over a Normal declared beside them.
    /// </summary>
    [Fact]
    public void ASwitchesOwnStatesWinOverANormalBesideThem()
    {
        var toggle = new Switch();

        Declare(toggle, "Normal", "On", "Off");

        toggle.IsToggled = true;

        Assert.Equal("On", In(toggle));
    }

    /// <summary>
    /// And a control's own state is its own: a Button never enters On, whatever
    /// a style says about it.
    /// </summary>
    /// <remarks>
    /// The reason the states are offered per target rather than as one list -
    /// <c>Style&lt;Button&gt;().visualState(.on)</c> describes a state nothing
    /// will ever drive, and a style that quietly does nothing is the failure
    /// this library refuses everywhere else.
    /// </remarks>
    [Fact]
    public void AButtonNeverEntersASwitchesState()
    {
        var button = new Button();

        Declare(button, "Normal", "On", "Off");

        button.IsEnabled = false;
        button.IsEnabled = true;

        Assert.Equal("Normal", In(button));
    }

    // ---- Saying it -----------------------------------------------------------

    /// <summary>Gives the view a CommonStates group with these states in it.</summary>
    private static void Declare(VisualElement view, params string[] names) =>
        Declare(view, names.Select(name => (name, (Color?)null)).ToArray());

    /// <summary>The same, each state setting the text colour so it can be seen.</summary>
    private static void Declare(VisualElement view, params (string Name, Color? Colour)[] states)
    {
        var group = new VisualStateGroup { Name = "CommonStates" };

        foreach ((string name, Color? colour) in states)
        {
            var state = new VisualState { Name = name };

            if (colour is not null)
            {
                state.Setters.Add(new Setter { Property = Label.TextColorProperty, Value = colour });
            }

            group.States.Add(state);
        }

        VisualStateManager.SetVisualStateGroups(view, new VisualStateGroupList { group });
    }

    /// <summary>The state the view's one group is in.</summary>
    private static string? In(VisualElement view) =>
        VisualStateManager.GetVisualStateGroups(view).Single().CurrentState?.Name;

    /// <summary>
    /// Focus, without a platform to give it.
    /// </summary>
    /// <remarks>
    /// <c>Focus()</c> goes through a handler that is not there headlessly, so
    /// the property is set the way MAUI's own platform code sets it - the key
    /// is public for exactly this.
    /// </remarks>
    private static void Focus(VisualElement view, bool focused) =>
        view.SetValue(VisualElement.IsFocusedPropertyKey, focused);
}
