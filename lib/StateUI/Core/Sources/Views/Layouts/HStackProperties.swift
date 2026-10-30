// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `HStack`'s own properties, shared by the control and its `Style<HStack>`.
public protocol HStackProperties: PropertyContainer {}

extension HStackProperties {
    /// Whether the row goes on onto a further line where its room ends: each
    /// line as many children as it has room for, at least one, the lines
    /// `rowSpacing` apart.
    ///
    ///     HStack {
    ///         ForEach(["Swift", "Layout", "State", "Motion"], id: \.self) { Text($0) }
    ///     }
    ///     .wraps(true)
    ///     .spacing(8)
    ///     .rowSpacing(8)
    ///
    /// A row told nothing stands on one line, its words giving up width where
    /// it is short of room.
    public func wraps(_ value: Bool) -> Modified { setValue(HStackContract.wraps, value) }

    /// The gap between one line and the next of a row that wraps, in device
    /// units; `.spacing` is the gap between children on a line.
    public func rowSpacing(_ value: Double) -> Modified { setValue(HStackContract.rowSpacing, value) }
}

extension HStack {
    /// `wraps` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func wraps(_ state: Binding<Bool>) -> Modified {
        twin(HStackContract.wraps, by: state)
    }

    /// `rowSpacing` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func rowSpacing(_ state: Binding<Double>) -> Modified {
        twin(HStackContract.rowSpacing, by: state)
    }
}
