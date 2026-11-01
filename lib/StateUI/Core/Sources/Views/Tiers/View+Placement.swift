// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a view sits in a Grid or a ZStack, written on the view.
// Design: docs/design/views/modifiers.md#placement-is-written-on-the-child

extension ViewProperties {
    /// Which row of the enclosing Grid the view sits in, counting from 0.
    ///
    ///     Text("Name").gridRow(0).gridColumn(0)
    ///     TextField($name).gridRow(0).gridColumn(1)
    public func gridRow(_ value: Int) -> Modified {
        setValue(ViewContract.gridRow, gridIndex(value, "gridRow", "rows"))
    }

    /// Which column of the enclosing Grid the view sits in, counting from 0.
    public func gridColumn(_ value: Int) -> Modified {
        setValue(ViewContract.gridColumn, gridIndex(value, "gridColumn", "columns"))
    }

    /// How many rows the view covers, starting at its own.
    public func gridRowSpan(_ value: Int) -> Modified {
        setValue(ViewContract.gridRowSpan, gridSpan(value, "gridRowSpan", "row"))
    }

    /// How many columns the view covers, starting at its own.
    public func gridColumnSpan(_ value: Int) -> Modified {
        setValue(ViewContract.gridColumnSpan, gridSpan(value, "gridColumnSpan", "column"))
    }
}

extension ViewProperties {
    /// `value`, said once where it names no row or column: a grid stands such a view in its first.
    /// Design: docs/design/host/layout.md#grids
    private func gridIndex(_ value: Int, _ modifier: String, _ tracks: String) -> Int {
        if value < 0 {
            complain("`\(modifier)(\(value))` names none of a grid's \(tracks), which count from 0: the view stands in "
                + "the first.")
        }
        return value
    }

    /// `value`, said once where it spans nothing: a grid spans one track for it.
    private func gridSpan(_ value: Int, _ modifier: String, _ track: String) -> Int {
        if value < 1 { complain("`\(modifier)(\(value))` spans no \(track): the view spans one.") }
        return value
    }
}

extension ViewProperties {
    /// The part of the enclosing ZStack's room the view stands in, in device
    /// units or in fractions of the room; the whole room without it.
    ///
    ///     Text("Right half").area(.proportional(Rect(0.5, 0, 0.5, 1)))
    public func area(_ value: Area) -> Modified { setValue(ViewContract.area, value) }
}

extension View {
    /// `gridColumn` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridColumn(_ state: Binding<Int>) -> Modified {
        twin(ViewContract.gridColumn, by: state)
    }

    /// `gridColumnSpan` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridColumnSpan(_ state: Binding<Int>) -> Modified {
        twin(ViewContract.gridColumnSpan, by: state)
    }

    /// `gridRow` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func gridRow(_ state: Binding<Int>) -> Modified {
        twin(ViewContract.gridRow, by: state)
    }

    /// `gridRowSpan` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridRowSpan(_ state: Binding<Int>) -> Modified {
        twin(ViewContract.gridRowSpan, by: state)
    }
}
