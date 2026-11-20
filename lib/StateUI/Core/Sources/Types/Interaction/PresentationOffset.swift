// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How far a view is drawn from where its layout puts it while the user's hand is on it: moved, turned and scaled
/// about its middle.
///
///     .interaction(.press(values: .scale) { press in
///         PresentationOffset(scaleX: 0.96, scaleY: 0.96)
///     })
///
/// It changes nothing a layout measures and nothing of a state: the view's place stays its layout's.
/// Design: docs/design/views/interaction.md#a-views-own-press-and-drag
public struct PresentationOffset: Equatable, Sendable {
    /// How far the view is moved, across and down, in points.
    public var translation: Point

    /// How far it is turned, in degrees clockwise.
    public var rotation: Double

    /// How many times as wide it is drawn.
    public var scaleX: Double

    /// How many times as tall it is drawn.
    public var scaleY: Double

    /// An offset moving the view by `translation`, turning it `rotation` degrees and scaling it `scaleX` by
    /// `scaleY`; each left out leaves the view as its layout has it.
    public init(translation: Point = .zero, rotation: Double = 0, scaleX: Double = 1, scaleY: Double = 1) {
        self.translation = translation
        self.rotation = rotation
        self.scaleX = scaleX
        self.scaleY = scaleY
    }

    /// No offset: the view where its layout puts it.
    public static let identity = PresentationOffset()

    /// The offset with only what `values` names, the rest as the layout has it - and a number that is none left
    /// out, so no hand draws a view nowhere.
    @_spi(Host) public func kept(_ values: PresentationValues) -> PresentationOffset {
        func held(_ number: Double, _ value: PresentationValues, else rest: Double) -> Double {
            values.contains(value) && number.isFinite ? number : rest
        }
        return PresentationOffset(
            translation: Point(
                x: held(translation.x, .translationX, else: 0), y: held(translation.y, .translationY, else: 0)),
            rotation: held(rotation, .rotation, else: 0),
            scaleX: held(scaleX, .scaleX, else: 1), scaleY: held(scaleY, .scaleY, else: 1))
    }
}
