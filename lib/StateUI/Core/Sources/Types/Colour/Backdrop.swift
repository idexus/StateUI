// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What lets what lies behind a view, or behind a window, show through it: a
/// material, or the platform's glass. A background lies over it, so a colour
/// with an alpha tints it.
///
///     VStack { … }.backdrop(.material(.thin))
///     window.backdrop = .material(.regular)
///
/// A platform with no glass draws a material in its place, and one with no
/// materials a colour of the theme, let through as the material is.
/// Design: docs/design/types/colour-and-theme.md#a-backdrop
public enum Backdrop: Equatable, Sendable, HostRepresentable {
    /// A material, which lets what lies behind through, blurred.
    case material(Material)

    /// The platform's glass.
    case glass(Glass)

    /// The material a host with no glass draws: the material itself, or the
    /// glass's, as clear as the glass is.
    @_spi(Host) public var material: Material {
        switch self {
        case .material(let material): material
        case .glass(let glass): glass.material
        }
    }

    /// The kind first, then what the kind takes, and last what a host with
    /// nothing of the kind draws in its place.
    public var propValue: PropValue {
        switch self {
        case .material(let material):
            .values([.enumeration(1), material.propValue, material.standIn.propValue])
        case .glass(let glass):
            .values([
                .enumeration(2), glass.clarity.propValue, glass.tint?.propValue ?? .nothing,
                .bool(glass.isInteractive), glass.material.propValue, glass.material.standIn.propValue,
            ])
        }
    }

    /// A backdrop back - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let parts = propValue.values, let kind = parts.first?.enumeration else { return nil }
        switch kind {
        case 1:
            guard parts.count > 1, let material = Material(propValue: parts[1]) else { return nil }
            self = .material(material)
        case 2:
            guard parts.count > 3, let clarity = Glass.Clarity(propValue: parts[1]) else { return nil }
            self = .glass(Glass(clarity: clarity, tint: Color(propValue: parts[2]), isInteractive: parts[3].bool == true))
        default:
            return nil
        }
    }
}
