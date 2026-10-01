// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The shape an element's own box follows: its background is painted to it,
/// its outline drawn on it, and - where it clips - what it holds cut to it.
/// What `.shape` takes.
///
///     VStack { … }.shape(.roundedRectangle(12))
public enum ContainerShape: Equatable, Sendable, HostRepresentable {
    /// Square corners.
    case rectangle

    /// Rounded corners, by this many device units.
    case roundedRectangle(Double)

    /// An oval filling the element's bounds.
    case ellipse

    /// Which shape this is, as the number that crosses ahead of its parts.
    /// Design: docs/design/types/vocabularies.md#a-kind-first
    enum Kind: Int32, Sendable {
        case rectangle = 0
        case roundedRectangle = 1
        case ellipse = 2
    }

    /// The kind, then what that kind is made of.
    public var propValue: PropValue {
        switch self {
        case .rectangle:
            return .values([.enumeration(Kind.rectangle.rawValue)])
        case .roundedRectangle(let radius):
            return .values([.enumeration(Kind.roundedRectangle.rawValue), .number(radius)])
        case .ellipse:
            return .values([.enumeration(Kind.ellipse.rawValue)])
        }
    }

    /// The shape a kind and its parts name - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, case .enumeration(let number)? = parts.first,
              let kind = Kind(rawValue: number)
        else { return nil }

        switch (kind, parts.count) {
        case (.rectangle, 1):
            self = .rectangle
        case (.roundedRectangle, 2):
            guard case .number(let radius) = parts[1] else { return nil }
            self = .roundedRectangle(radius)
        case (.ellipse, 1):
            self = .ellipse
        default:
            return nil
        }
    }
}
