// How a control that shows artwork fills the room it is given.
//
// Its own file, for the reason BarElement.swift gives: Elements.swift is the
// tier every VIEW shares and is checked against one fixture, and only two
// controls show a picture.

/// The artwork half of a control that draws one.
/// MAUI: IImageElement - the interface `Image` and `ImageButton` both
/// implement.
///
/// The picture ITSELF is not here. MAUI declares `Source` on this interface
/// too, but both controls take it in their initializer - it is the value that
/// gives either one its purpose, and this library puts that in the initializer
/// and everything else on a modifier.
public protocol ImageElement: PropertyContainer {}

extension ImageElement {
    /// How the picture fills the space - the choice between showing all of it
    /// and filling every corner. MAUI: IImageElement.Aspect.
    ///
    /// `.aspectFit` shows the whole picture and leaves empty room on two sides;
    /// `.aspectFill` fills the room and crops what will not fit. `.fill`
    /// stretches, which distorts, and `.center` draws the picture at its own
    /// size in the middle, scaling nothing.
    public func aspect(_ value: Aspect) -> Modified {
        setValue(.aspect, value.propValue)
    }

    /// Whether the platform may skip drawing what is behind it - true only for
    /// a picture with no transparency anywhere, where it saves a pass.
    /// MAUI: IImageElement.IsOpaque.
    public func isOpaque(_ value: Bool) -> Modified {
        setValue(.isOpaque, .bool(value))
    }
}
