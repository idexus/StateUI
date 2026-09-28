// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The part of a `ZStack`'s room a child stands in: x, y, width and height,
/// in device units or in fractions of the room.
///
///     Label("Badge").area(.absolute(16, 16, 120, 40))
///     ColorBox(.red).area(.proportional(0.5, 0, 0.5, 1))
///
/// A child that names no area stands in the whole room.
public enum Area: Equatable, Sendable, HostRepresentable {
    /// Device units from the room's top left: x, y, width, height.
    case absolute(Double, Double, Double, Double)

    /// Fractions of the room: `.proportional(0.5, 0, 0.5, 1)` is its right half.
    case proportional(Double, Double, Double, Double)

    /// Which of the two kinds an area is, as the number that crosses.
    /// Design: docs/design/types/vocabularies.md#a-kind-first
    enum Kind: Int32, Sendable {
        case absolute = 0
        case proportional = 1
    }

    /// The kind, then the four numbers.
    public var propValue: PropValue {
        switch self {
        case let .absolute(x, y, width, height):
            return .values([.enumeration(Kind.absolute.rawValue), .numbers([x, y, width, height])])
        case let .proportional(x, y, width, height):
            return .values([.enumeration(Kind.proportional.rawValue), .numbers([x, y, width, height])])
        }
    }

    /// The area a kind and its four numbers name - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, parts.count == 2,
              case .enumeration(let number) = parts[0], let kind = Kind(rawValue: number),
              case .numbers(let numbers) = parts[1], numbers.count == 4
        else { return nil }

        switch kind {
        case .absolute: self = .absolute(numbers[0], numbers[1], numbers[2], numbers[3])
        case .proportional: self = .proportional(numbers[0], numbers[1], numbers[2], numbers[3])
        }
    }
}
