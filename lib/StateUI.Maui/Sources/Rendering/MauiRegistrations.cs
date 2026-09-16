// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// How this host realizes the library's own elements - one registration per
/// element contract, through the road an application's own control takes.
/// </summary>
/// <remarks>
/// <para>
/// There is no second mechanism here: a <c>ProgressBar</c> is registered
/// exactly as a <c>Gallery.TrafficLight</c> is, so what the library can say
/// about an element is what an application can say about its own. A family
/// still served by the renderer's own <c>Reconcile…</c> method is simply one
/// that has not moved yet - the dispatch reaches the registry through its
/// default arm, so the two roads stand side by side while the move goes on.
/// </para>
/// <para>
/// The shared tier - margins, opacity, tint, gestures, focus, frame reports -
/// is applied around every registration by the renderer, exactly as it is for
/// an application's control, so no registration here writes one of those.
/// </para>
/// </remarks>
internal static class MauiRegistrations
{
    /// <summary>Registers every family that has moved.</summary>
    internal static void Install()
    {
        Indicators();
        Toggles();
        Values();
    }

    /// <summary>
    /// The controls a reader moves a number with: a slider dragged along its
    /// track, a stepper stepped through its range.
    /// </summary>
    /// <remarks>
    /// The range is declared before the value it holds, and a registration's
    /// members are applied in the order they are declared. MAUI clamps a value
    /// into the range as it is set - but it keeps what it was given and clamps
    /// again whenever a bound moves, so a value that arrived first comes back
    /// once the range widens. Measured both ways, on both controls: the order
    /// reads as the range holding the value, which is what it means, rather
    /// than standing between a reader and their number.
    /// </remarks>
    private static void Values()
    {
        StateUIControls.Add("Slider",
            create: _ => new Slider(),
            realize: slider => slider
                .Property<double>(HostProp.Maximum, (view, maximum) => view.Maximum = maximum)
                .Property<double>(HostProp.Minimum, (view, minimum) => view.Minimum = minimum)
                .Property<double>(HostProp.Value, (view, value) => view.Value = value)
                .Moves(Slider.ValueProperty, HostEvent.ValueChanged,
                    (view, moved) => view.ValueChanged += (_, e) => moved(e.NewValue))
                .Raises(HostEvent.DragStarted,
                    (view, began) => view.DragStarted += (_, _) => began())
                .Raises(HostEvent.DragCompleted,
                    (view, ended) => view.DragCompleted += (_, _) => ended()));

        StateUIControls.Add("Stepper",
            create: _ => new Stepper(),
            realize: stepper => stepper
                .Property<double>(HostProp.Maximum, (view, maximum) => view.Maximum = maximum)
                .Property<double>(HostProp.Minimum, (view, minimum) => view.Minimum = minimum)
                .Property<double>(HostProp.Step, (view, step) => view.Increment = step)
                .Property<double>(HostProp.Value, (view, value) => view.Value = value)
                .Moves(Stepper.ValueProperty, HostEvent.ValueChanged,
                    (view, moved) => view.ValueChanged += (_, e) => moved(e.NewValue)));
    }

    /// <summary>
    /// The two-state controls a reader operates: one value each, reported back
    /// as the reader leaves it.
    /// </summary>
    /// <remarks>
    /// A radio button is one of these too, and carries far more with it: a
    /// caption, a group, a border and a font.
    /// </remarks>
    private static void Toggles()
    {
        // THE GROUP BEFORE THE STATE, and the order here is the order the
        // members are applied in: MAUI clears the others in the group as a
        // button becomes checked, and it can only do that once it knows which
        // group this is. The group is a NAME - written by an author and
        // repeated across a tree - so it rides the session's dictionary.
        StateUIControls.Add("RadioButton",
            create: _ => new RadioButton(),
            realize: radio => radio
                .Held(HostProp.GroupName,
                    static (node, member) => node.GetName(member),
                    (view, group) => view.GroupName = group)
                .Property<string>(HostProp.Text, (view, text) => view.Content = text)
                .Property<bool>(HostProp.IsOn, (view, on) => view.IsChecked = on)
                .Held(HostProp.TextColor,
                    static (node, member) => node.GetColor(member),
                    (view, colour) => view.TextColor = colour)
                .Property<double>(HostProp.CharacterSpacing,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .Property(HostProp.TextCase,
                    static (node, member) => node.GetTextTransform(member),
                    (view, transform) => view.TextTransform = transform)
                .Held(HostProp.BorderColor,
                    static (node, member) => node.GetColor(member),
                    (view, colour) => view.BorderColor = colour)
                .Property<double>(HostProp.BorderWidth,
                    (view, width) => view.BorderWidth = width)
                .Property(HostProp.CornerRadius,
                    static (node, member) => node.GetInt(member),
                    (view, radius) => view.CornerRadius = radius)
                .Property(HostProp.Padding,
                    static (node, member) => node.GetThickness(member),
                    (view, padding) => view.Padding = padding)
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling)
                .Reports<bool>(RadioButton.IsCheckedProperty, HostEvent.Toggled,
                    (view, reported) => view.CheckedChanged += (_, e) => reported(e.Value)));

        StateUIControls.Add("Switch",
            create: _ => new Switch(),
            realize: toggle => toggle
                .Property<bool>(HostProp.IsOn, (view, on) => view.IsToggled = on)
                .Reports<bool>(Switch.IsToggledProperty, HostEvent.Toggled,
                    (view, reported) => view.Toggled += (_, e) => reported(e.Value)));

        StateUIControls.Add("CheckBox",
            create: _ => new CheckBox(),
            realize: box => box
                .Property<bool>(HostProp.IsOn, (view, on) => view.IsChecked = on)
                .Reports<bool>(CheckBox.IsCheckedProperty, HostEvent.Toggled,
                    (view, reported) => view.CheckedChanged += (_, e) => reported(e.Value)));
    }

    /// <summary>
    /// What something says while it is happening: how far along, and whether
    /// anything is happening at all.
    /// </summary>
    /// <remarks>
    /// Their colour is the shared tier's <c>tint</c>, which
    /// <c>ComposedProperties</c> puts on whichever property each control keeps
    /// it in - so neither registration mentions it.
    /// </remarks>
    private static void Indicators()
    {
        StateUIControls.Add("ProgressBar",
            create: _ => new ProgressBar(),
            realize: bar => bar
                .Property<double>(HostProp.Progress, (view, progress) => view.Progress = progress));

        StateUIControls.Add("ActivityIndicator",
            create: _ => new ActivityIndicator(),
            realize: indicator => indicator
                .Property<bool>(HostProp.IsRunning, (view, running) => view.IsRunning = running));
    }
}
