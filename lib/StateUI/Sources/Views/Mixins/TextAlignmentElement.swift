// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a control's text sits inside the control - not where the control
/// sits in its parent, which is `horizontalAlignment` and `verticalAlignment`.
public protocol TextAlignmentElement: VisualElementProperties {}

extension TextAlignmentElement {
    /// Where the text sits within the control's own width.
    public func horizontalTextAlignment(_ value: TextAlignment) -> Modified {
        setValue(TextAlignmentElementContract.horizontalTextAlignment, value)
    }

    /// Where the text sits within the control's own height.
    public func verticalTextAlignment(_ value: TextAlignment) -> Modified {
        setValue(TextAlignmentElementContract.verticalTextAlignment, value)
    }
}

extension TextAlignmentElement where Self: VisualElement {
    /// `horizontalTextAlignment` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func horizontalTextAlignment(_ state: Binding<TextAlignment>) -> Modified {
        plain(TextAlignmentElementContract.horizontalTextAlignment, by: state)
    }

    /// `verticalTextAlignment` from a state, `$x`: the host sets each new value
    /// as it stands, and no view is rebuilt for it.
    public func verticalTextAlignment(_ state: Binding<TextAlignment>) -> Modified {
        plain(TextAlignmentElementContract.verticalTextAlignment, by: state)
    }
}
