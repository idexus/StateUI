// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How a control that shows artwork fills the room it is given.
//
// Its own file, for the reason BarElement.swift gives: Elements.swift is the
// tier every VIEW shares and is checked against one fixture, and only two
// controls show a picture.

/// The artwork half shared by `Image` and `Button`.
///
/// The picture ITSELF is not here. `Image(_:)` and `Button(icon:)` take it in
/// their initializer, because there it is the value that gives the control its
/// purpose; beside a caption it is a button's `.icon(_:)`.
public protocol ImageElement: PropertyContainer {}

extension ImageElement {
    /// How the picture fills the space - the choice between showing all of it
    /// and filling every corner.
    ///
    /// `.fit` shows the whole picture and leaves empty room on two sides;
    /// `.fill` fills the room and crops what will not fit. `.stretch`
    /// stretches, which distorts, and `.center` draws the picture at its own
    /// size in the middle, scaling nothing.
    public func aspect(_ value: Aspect) -> Modified {
        setValue(.aspect, value.propValue)
    }

}
