// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How `Image` and `Button` fit their picture. The picture itself goes in
/// their initializer, or in a button's `.icon(_:)`.
public protocol ImageElement: PropertyContainer {}

extension ImageElement {
    /// How the picture fills the space - the choice between showing all of it
    /// and filling every corner.
    ///
    /// `.fit` shows the whole picture and leaves empty room on two sides;
    /// `.fill` fills the room and crops what will not fit. `.stretch`
    /// stretches, which distorts, and `.center` draws the picture at its own
    /// size in the middle, scaling nothing.
    public func contentMode(_ value: ContentMode) -> Modified {
        setValue(ImageElementContract.contentMode, value)
    }

}

extension ImageElement where Self: VisualElement {
    /// `contentMode` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func contentMode(_ state: Binding<ContentMode>) -> Modified {
        twin(ImageElementContract.contentMode, by: state)
    }
}
