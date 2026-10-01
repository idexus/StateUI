// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a view sits in a Grid or a ZStack, written on the view.
// Design: docs/design/views/modifiers.md#placement-is-written-on-the-child

extension ViewProperties {
    /// Which row of the enclosing Grid the view sits in, counting from 0.
    ///
    ///     Label("Name").gridRow(0).gridColumn(0)
    ///     TextField($name).gridRow(0).gridColumn(1)
    public func gridRow(_ value: Int) -> Modified { setValue(ViewContract.gridRow, value) }

    /// Which column of the enclosing Grid the view sits in, counting from 0.
    public func gridColumn(_ value: Int) -> Modified { setValue(ViewContract.gridColumn, value) }

    /// How many rows the view covers, starting at its own.
    public func gridRowSpan(_ value: Int) -> Modified { setValue(ViewContract.gridRowSpan, value) }

    /// How many columns the view covers, starting at its own.
    public func gridColumnSpan(_ value: Int) -> Modified { setValue(ViewContract.gridColumnSpan, value) }
}

extension ViewProperties {
    /// The part of the enclosing ZStack's room the view stands in, in device
    /// units or in fractions of the room; the whole room without it.
    ///
    ///     Label("Right half").area(.proportional(0.5, 0, 0.5, 1))
    public func area(_ value: Area) -> Modified { setValue(ViewContract.area, value) }
}

extension View {
    /// `gridColumn` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridColumn(_ state: Binding<Int>) -> Modified {
        plain(ViewContract.gridColumn, by: state)
    }

    /// `gridColumnSpan` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridColumnSpan(_ state: Binding<Int>) -> Modified {
        plain(ViewContract.gridColumnSpan, by: state)
    }

    /// `gridRow` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func gridRow(_ state: Binding<Int>) -> Modified {
        plain(ViewContract.gridRow, by: state)
    }

    /// `gridRowSpan` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridRowSpan(_ state: Binding<Int>) -> Modified {
        plain(ViewContract.gridRowSpan, by: state)
    }
}
