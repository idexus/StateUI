// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties every stack has, shared by the control and its `Style`.
public protocol StackBaseProperties: LayoutProperties {}

/// A layout that stacks its children in one direction.
public protocol StackBase: Layout, StackBaseProperties {}

extension StackBaseProperties {
    /// The gap left between children, in device units - not before the first
    /// or after the last, which is what padding is for.
    public func spacing(_ value: Double) -> Modified { setValue(StackBaseContract.spacing, value) }
}

extension StackBase {
    /// `spacing` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func spacing(_ state: Binding<Double>) -> Modified {
        journey(StackBaseContract.spacing, by: state)
    }
}
