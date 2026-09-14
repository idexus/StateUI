// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How a control that shows artwork fills the room it is given.
//
// Its own file, for the reason BarElement.swift gives: Elements.swift is the
// tier every VIEW shares and is checked against one fixture, and only two
// controls show a picture.

/// The artwork half shared by `Image` and `ImageButton`.
///
/// The picture ITSELF is not here. Both controls take it in their initializer,
/// because it is the value that gives either one its purpose, and this library
/// puts that in the initializer and everything else on a modifier.
public protocol ImageElement: PropertyContainer {}

extension ImageElement {
    /// How the picture fills the space - the choice between showing all of it
    /// and filling every corner.
    ///
    /// `.aspectFit` shows the whole picture and leaves empty room on two sides;
    /// `.aspectFill` fills the room and crops what will not fit. `.fill`
    /// stretches, which distorts, and `.center` draws the picture at its own
    /// size in the middle, scaling nothing.
    public func aspect(_ value: Aspect) -> Modified {
        setValue(.aspect, value.propValue)
    }

}
