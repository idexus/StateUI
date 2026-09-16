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
    }

    /// <summary>
    /// The two-state controls a reader operates: one value each, reported back
    /// as the reader leaves it.
    /// </summary>
    /// <remarks>
    /// A radio button is one of these too, and moves with the family that can
    /// carry its text, its group and its border.
    /// </remarks>
    private static void Toggles()
    {
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
