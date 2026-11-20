// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What of the user's hand moves a value: a hand one way, two fingers spreading, or two fingers turning.
///
///     .value($turn, input: .translation(.horizontal, unit: .frontItem))
///     .value($table, axis: \.zoom, input: .magnification)
///     .value($table, axis: \.turn, input: .rotation(degreesPerUnit: 45))
///
/// Design: docs/design/views/interaction.md#the-input
public struct InteractionInput: Equatable, Sendable {
    /// How far the hand travels for one unit of the value.
    enum Travel: Equatable, Sendable {
        /// So many device units.
        case length(Double)

        /// As far as the view drawn in front moves for one unit.
        case front

        /// The room's length along the hand's way: a page.
        case room
    }

    /// What moves the value: a hand one way, two fingers spreading or two fingers turning.
    enum Gesture: Equatable, Sendable {
        /// A finger or a pointer dragged, a trackpad's two fingers and a wheel one way, so far for a unit, one snap a
        /// hand where it `swipes`.
        case hand(Orientation, Travel, swipes: Bool)

        /// Two fingers spreading: the value multiplied by how far they spread.
        case magnification

        /// Two fingers turning: a unit every so many degrees.
        case rotation(degreesPerUnit: Double)
    }

    /// What moves the value.
    let gesture: Gesture

    /// What is wrong with the input as it was written; nil for one that stands.
    let complaint: String?

    /// The hand moving the value with it: a finger or a pointer dragged, a trackpad's two fingers and a wheel. The
    /// value grows as the hand moves right, or down; `Interaction.reversed(_:)` turns it.
    ///
    /// - Parameters:
    ///   - orientation: the way the hand moves it: across or down.
    ///   - unit: how far the hand travels for one unit of the value; a point unless said.
    /// - Returns: the input.
    public static func translation(_ orientation: Orientation, unit: InteractionUnit = .points(1)) -> InteractionInput {
        hand(orientation, unit, swipes: false)
    }

    /// One snap a hand: the hand moves the value with it, one snap at most either way from where it took it, and let
    /// go with speed the value goes on to the next snap that way and no farther; a wheel's notch moves it one snap.
    /// Cards swiped one by one; a page at a time. Its value needs snaps.
    ///
    /// - Parameters:
    ///   - orientation: the way the hand moves it: across or down.
    ///   - unit: how far the hand travels for one unit of the value; a point unless said.
    /// - Returns: the input.
    public static func swipe(_ orientation: Orientation, unit: InteractionUnit = .points(1)) -> InteractionInput {
        hand(orientation, unit, swipes: true)
    }

    /// Two fingers spreading or pinching - on a touch screen, or a trackpad's pinch: the value is multiplied by how
    /// far the fingers spread, so their distance doubled doubles it. Its range, where it has one, stands above
    /// nought.
    public static let magnification = InteractionInput(gesture: .magnification, complaint: nil)

    /// Two fingers turning - on a touch screen, or a trackpad's rotation: the value moves a unit for every
    /// `degreesPerUnit` the fingers turn, growing as they turn clockwise.
    ///
    /// - Parameter degreesPerUnit: how far the fingers turn for one unit of the value, in degrees; above nought. A
    ///   whole turn unless said.
    /// - Returns: the input.
    public static func rotation(degreesPerUnit: Double = 360) -> InteractionInput {
        guard degreesPerUnit.isFinite, degreesPerUnit > 0 else {
            return InteractionInput(
                gesture: .rotation(degreesPerUnit: 360),
                complaint: "An interaction's rotation was given degrees a unit that are not above nought.")
        }
        return InteractionInput(gesture: .rotation(degreesPerUnit: degreesPerUnit), complaint: nil)
    }

    private static func hand(_ orientation: Orientation, _ unit: InteractionUnit, swipes: Bool) -> InteractionInput {
        switch unit {
        case .frontItem:
            return InteractionInput(gesture: .hand(orientation, .front, swipes: swipes), complaint: nil)
        case .containerLength:
            return InteractionInput(gesture: .hand(orientation, .room, swipes: swipes), complaint: nil)
        case .points(let points):
            guard points.isFinite, points > 0 else {
                return InteractionInput(
                    gesture: .hand(orientation, .length(1), swipes: swipes),
                    complaint: "An interaction's input was given points a unit that are not above nought.")
            }
            return InteractionInput(gesture: .hand(orientation, .length(points), swipes: swipes), complaint: nil)
        }
    }

    /// Whether the hand moves the value one snap at most.
    var swipes: Bool {
        if case .hand(_, _, true) = gesture { return true }
        return false
    }
}
