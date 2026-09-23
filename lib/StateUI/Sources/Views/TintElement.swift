// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A control's accent: the colour the platform draws what is chosen, filled
/// or under way in - a switch that is on, the covered part of a slider, a
/// ticked box, the filled part of a bar, a spinner.
///
/// A host with no way to tint a control draws the platform's own accent.
public protocol TintElement: PropertyContainer {}

extension TintElement {
    /// The colour the control is accented in.
    ///
    ///     Switch($isOn).tint(.orange)
    ///     Slider($volume).tint(.orange)
    public func tint(_ value: Color) -> Modified {
        setValue(TintElementContract.tint, value)
    }
}
