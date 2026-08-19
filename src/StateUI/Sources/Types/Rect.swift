// Rect, as MAUI defines it.
//
// Where a view is and how big it is, in one value - which is what an
// AbsoluteLayout positions its children with. The four-value initializer takes
// them in MAUI's own order: x, y, width, height.
//
// A size of `AbsoluteLayout.autoSize` means "whatever the view asks for", which
// is MAUI's `AbsoluteLayout.AutoSize` and travels as the -1 it is.

/// A rectangle: a position and a size, in one value. MAUI: Rect.
///
///     Label("Corner").absoluteLayoutBounds(Rect(0, 0, 120, 40))
///
/// What an `AbsoluteLayout` places a child with, and what a frame report
/// carries back. The numbers are device units unless the thing reading them
/// says otherwise - `absoluteLayoutFlags` is where that is said.
public struct Rect: Equatable, Sendable {
    /// The left edge, in device units - or a fraction of the layout's width when
    /// the bounds are proportional.
    public var x: Double

    /// The top edge, read the same way.
    public var y: Double

    /// How wide.
    public var width: Double

    /// How tall.
    public var height: Double

    /// In MAUI's order: x, y, width, height. What `Rect(0, 0, 120, 40)` means.
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The same, said out loud - which a rectangle of four bare numbers usually
    /// wants:
    ///
    ///     Rect(x: 0, y: 0, width: 1, height: 0.5)
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(x, y, width, height)
    }

    /// The wire form: an array, in the order MAUI's constructor takes them.
    var propValue: PropValue {
        .numbers([x, y, width, height])
    }
}
