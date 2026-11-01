// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The part of a `ZStack`'s room a child stands in: a rectangle in device
/// units or in fractions of the room.
///
///     Text("Badge").area(.absolute(Rect(16, 16, 120, 40)))
///     Rectangle()
///         .fill(.red)
///         .area(.proportional(Rect(0.5, 0, 0.5, 1)))
///
/// A child that names no area stands in the whole room.
public enum Area: Equatable, Sendable, HostRepresentable {
    /// A rectangle in device units from the room's top left.
    case absolute(Rect)

    /// A rectangle in fractions of the room: `.proportional(Rect(0.5, 0, 0.5, 1))` is its right half.
    case proportional(Rect)

    /// Which of the two kinds an area is, as the number that crosses.
    /// Design: docs/design/types/vocabularies.md#a-kind-first
    enum Kind: Int32, Sendable {
        case absolute = 0
        case proportional = 1
    }

    /// The kind, then the four numbers.
    public var propValue: PropValue {
        switch self {
        case .absolute(let area):
            return .values([.enumeration(Kind.absolute.rawValue), .numbers([area.x, area.y, area.width, area.height])])
        case .proportional(let area):
            return .values([
                .enumeration(Kind.proportional.rawValue), .numbers([area.x, area.y, area.width, area.height]),
            ])
        }
    }

    /// The area a kind and its four numbers name - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, parts.count == 2,
              case .enumeration(let number) = parts[0], let kind = Kind(rawValue: number),
              case .numbers(let numbers) = parts[1], numbers.count == 4
        else { return nil }

        let area = Rect(numbers[0], numbers[1], numbers[2], numbers[3])
        switch kind {
        case .absolute: self = .absolute(area)
        case .proportional: self = .proportional(area)
        }
    }
}
