// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How rounded a box's corners are: one radius for all four, or one each.
///
///     ColorBox(.teal).cornerRadius(12)
///
/// One radius crosses as one number; four cross as four numbers, in StateUI's
/// declared order - top left, top right, bottom left, bottom right.
public enum CornerRadius: Equatable, Sendable, HostRepresentable {
    /// The same radius on all four corners, in device units.
    case uniform(Double)

    /// A radius for each corner, in device units.
    case corners(topLeft: Double, topRight: Double, bottomLeft: Double, bottomRight: Double)

    /// One number, or the four in their order.
    public var propValue: PropValue {
        switch self {
        case .uniform(let radius):
            .number(radius)
        case .corners(let topLeft, let topRight, let bottomLeft, let bottomRight):
            .numbers([topLeft, topRight, bottomLeft, bottomRight])
        }
    }

    /// One radius back from a number, four from a run of four - nil for
    /// anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        switch propValue {
        case .number(let radius):
            self = .uniform(radius)
        case .numbers(let radii) where radii.count == 4:
            self = .corners(topLeft: radii[0], topRight: radii[1], bottomLeft: radii[2], bottomRight: radii[3])
        default:
            return nil
        }
    }
}
