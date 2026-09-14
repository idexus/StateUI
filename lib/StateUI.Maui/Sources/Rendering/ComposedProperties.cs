// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

/// <summary>
/// The StateUI properties that land on more than one MAUI property, or on one
/// that MAUI reads the other way round.
/// </summary>
/// <remarks>
/// <para>
/// Each is ONE attached property on the control, so it behaves like every
/// other property here: a style sets it, a patch that stops describing it
/// clears it, and a transition walks it. The MAUI properties behind it are
/// derived in one place, from the attached value, whenever it changes.
/// </para>
/// <para>
/// Written straight onto the MAUI properties instead, a patch clearing one
/// half of a pair would have nothing to put back, and a style would have to
/// know which MAUI property a control calls its accent.
/// </para>
/// </remarks>
internal static class ComposedProperties
{
    /// <summary>
    /// The colour a control is accented in: a switch's on colour, a slider's
    /// filled track, a check box's and a spinner's colour, a bar's progress, a
    /// refresh spinner, a picker's title and a search field's two icons.
    /// </summary>
    internal static readonly BindableProperty TintProperty =
        BindableProperty.CreateAttached(
            "StateUITint", typeof(Color), typeof(ComposedProperties), defaultValue: null,
            propertyChanged: (bindable, _, value) => Tint(bindable, value as Color));

    /// <summary>The view and everything in it take no input.</summary>
    internal static readonly BindableProperty IgnoresInputProperty =
        BindableProperty.CreateAttached(
            "StateUIIgnoresInput", typeof(bool), typeof(ComposedProperties), defaultValue: false,
            propertyChanged: (bindable, _, _) => Input(bindable));

    /// <summary>A layout's own empty area takes no input, while its children still do.</summary>
    internal static readonly BindableProperty LetsInputThroughProperty =
        BindableProperty.CreateAttached(
            "StateUILetsInputThrough", typeof(bool), typeof(ComposedProperties), defaultValue: false,
            propertyChanged: (bindable, _, _) => Input(bindable));

    /// <summary>
    /// Whether a screen reader skips the view - MAUI's IsInAccessibleTree read
    /// the other way round. Absent is the platform's own answer.
    /// </summary>
    internal static readonly BindableProperty IsAccessibilityHiddenProperty =
        BindableProperty.CreateAttached(
            "StateUIIsAccessibilityHidden", typeof(bool?), typeof(ComposedProperties), defaultValue: null,
            propertyChanged: (bindable, _, value) => Hidden(bindable, value as bool?));

    /// <summary>Which side of a button's caption its icon is on.</summary>
    internal static readonly BindableProperty IconPositionProperty =
        BindableProperty.CreateAttached(
            "StateUIIconPosition", typeof(Button.ButtonContentLayout.ImagePosition),
            typeof(ComposedProperties), defaultValue: Button.ButtonContentLayout.ImagePosition.Left,
            propertyChanged: (bindable, _, _) => Icon(bindable));

    /// <summary>
    /// How far a button's icon stands from its caption - ten points unless
    /// told, which is MAUI's own default.
    /// </summary>
    internal static readonly BindableProperty IconSpacingProperty =
        BindableProperty.CreateAttached(
            "StateUIIconSpacing", typeof(double), typeof(ComposedProperties), defaultValue: 10.0,
            propertyChanged: (bindable, _, _) => Icon(bindable));

    private static void Tint(BindableObject bindable, Color? tint)
    {
        switch (bindable)
        {
            case Switch control:
                Assign(control, Switch.OnColorProperty, tint);
                break;

            case Slider slider:
                Assign(slider, Slider.MinimumTrackColorProperty, tint);
                break;

            case CheckBox box:
                Assign(box, CheckBox.ColorProperty, tint);
                break;

            case ActivityIndicator spinner:
                Assign(spinner, ActivityIndicator.ColorProperty, tint);
                break;

            case ProgressBar bar:
                Assign(bar, ProgressBar.ProgressColorProperty, tint);
                break;

            case RefreshView refresh:
                Assign(refresh, RefreshView.RefreshColorProperty, tint);
                break;

            case Picker picker:
                Assign(picker, Picker.TitleColorProperty, tint);
                break;

            case SearchBar search:
                Assign(search, SearchBar.CancelButtonColorProperty, tint);
                Assign(search, SearchBar.SearchIconColorProperty, tint);
                break;
        }
    }

    /// <summary>
    /// The two input properties as MAUI's one transparency: either makes the
    /// view transparent, and only ignoring input takes the children with it.
    /// </summary>
    private static void Input(BindableObject bindable)
    {
        if (bindable is not VisualElement view)
        {
            return;
        }

        bool ignores = (bool)view.GetValue(IgnoresInputProperty);
        bool through = (bool)view.GetValue(LetsInputThroughProperty);
        bool transparent = ignores || through;

        view.SetValue(StateUIRenderer.TakesTouchProperty, !transparent);
        view.InputTransparent = transparent;

        if (view is Layout layout)
        {
            layout.CascadeInputTransparent = ignores || !through;
        }
    }

    private static void Hidden(BindableObject bindable, bool? hidden)
    {
        if (hidden is bool skipped)
        {
            AutomationProperties.SetIsInAccessibleTree(bindable, !skipped);
        }
        else
        {
            bindable.ClearValue(AutomationProperties.IsInAccessibleTreeProperty);
        }
    }

    private static void Icon(BindableObject bindable)
    {
        if (bindable is Button button)
        {
            button.ContentLayout = new Button.ButtonContentLayout(
                (Button.ButtonContentLayout.ImagePosition)button.GetValue(IconPositionProperty),
                (double)button.GetValue(IconSpacingProperty));
        }
    }

    private static void Assign(BindableObject target, BindableProperty property, object? value)
    {
        if (value is null)
        {
            target.ClearValue(property);
        }
        else
        {
            target.SetValue(property, value);
        }
    }
}
