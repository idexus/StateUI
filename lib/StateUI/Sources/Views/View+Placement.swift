// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a view sits in a Grid or an AbsoluteLayout, written on the view.
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
    /// Where the view sits and how big it is.
    ///
    /// Read as device units unless the proportions say otherwise:
    ///
    ///     .absoluteLayoutBounds(Rect(0.5, 0, 0.5, 1))
    ///     .absoluteLayoutProportions(.all)
    public func absoluteLayoutBounds(_ value: Rect) -> Modified {
        setValue(ViewContract.absoluteLayoutBounds, value)
    }

    /// Which of those four numbers are fractions of the layout rather than
    /// device units.
    public func absoluteLayoutProportions(_ value: AbsoluteLayoutProportions) -> Modified {
        setValue(ViewContract.absoluteLayoutProportions, value)
    }
}

extension View {
    /// `absoluteLayoutProportions` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func absoluteLayoutProportions(_ state: Binding<AbsoluteLayoutProportions>) -> Modified {
        plain(ViewContract.absoluteLayoutProportions, by: state)
    }

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
