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
