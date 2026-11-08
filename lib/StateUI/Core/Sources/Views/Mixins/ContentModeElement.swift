// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How what an element draws fills its room - an `Image`'s and a `Button`'s
/// picture, a shape's drawing. A picture itself goes in the initializer, or in
/// a button's `.icon(_:)`.
public protocol ContentModeElement: PropertyContainer {}

extension ContentModeElement {
    /// How the drawing fills the space - the choice between showing all of it
    /// and filling every corner.
    ///
    /// `.fit`, the default, shows all of it and leaves empty room on two
    /// sides; `.fill` fills the room and crops what will not fit. `.stretch`
    /// stretches, which distorts, and `.center` draws it at its own size in
    /// the middle, scaling nothing - a shape at the size its own numbers say.
    public func contentMode(_ value: ContentMode) -> Modified {
        setValue(ContentModeElementContract.contentMode, value)
    }

}

extension ContentModeElement where Self: VisualElement {
    /// `contentMode` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func contentMode(_ state: Binding<ContentMode>) -> Modified {
        twin(ContentModeElementContract.contentMode, by: state)
    }
}
