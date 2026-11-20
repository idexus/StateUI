// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A press on a view, as its `press(values:_:)` effect is handed it on a frame: how far along it is, where it
/// stands, how far it has gone and how fast.
///
///     .press(values: .translation) { press in
///         PresentationOffset(translation: Point(x: press.normalizedLocation.x * 6, y: press.normalizedLocation.y * 6))
///     }
///
/// Everything is measured in the view as its layout places it, never as the press itself draws it: an effect
/// moving the view moves nothing it is handed.
/// Design: docs/design/views/interaction.md#a-views-own-press-and-drag
public struct PressInput: Equatable, Sendable {
    /// Whether the press went down, moves or stands, lifted, or was taken away.
    public let phase: GesturePhase

    /// Where the press stands, in the view's points from its top left corner.
    public let location: Point

    /// Where it stands about the view's middle: -1 at the left and top edges, 1 at the right and bottom, held
    /// there for a press that went past them.
    public let normalizedLocation: Point

    /// How far it has gone since it went down, in points.
    public let displacement: Point

    /// How fast it goes, in points a second; nought as it goes down.
    public let velocity: Point

    /// The view's own rectangle, its corner at the origin.
    public let bounds: Rect

    /// A press at `phase` standing at `location` of a view `bounds` large, gone `displacement` at `velocity`.
    @_spi(Host) public init(phase: GesturePhase, location: Point, displacement: Point, velocity: Point, bounds: Rect) {
        self.phase = phase
        self.location = location
        self.displacement = displacement
        self.velocity = velocity
        self.bounds = bounds
        func share(_ at: Double, of length: Double) -> Double {
            length > 0 && at.isFinite ? min(max(at / length * 2 - 1, -1), 1) : 0
        }
        normalizedLocation = Point(x: share(location.x, of: bounds.width), y: share(location.y, of: bounds.height))
    }
}
