// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// A material: a surface that lets what lies behind it through, blurred, in
/// the platform's own look - from the thinnest, which lets the most through,
/// to the thickest.
///
///     VStack { … }.backdrop(.material(.thin))
///
/// A platform with no materials draws a flat colour in its place.
/// Design: docs/design/types/colour-and-theme.md#a-material
public enum Material: Int32, Sendable, CaseIterable {
    /// The thinnest: most of what lies behind shows.
    case ultraThin = 0

    /// Thin.
    case thin = 1

    /// The platform's ordinary material.
    case regular = 2

    /// The thickest: what lies behind shows faintly.
    case thick = 3

    /// What a platform with no materials draws in its place: a colour of the
    /// theme, let through as much as the material lets.
    var standIn: Color {
        let alpha: Double = switch self {
        case .ultraThin: 0.45
        case .thin: 0.6
        case .regular: 0.75
        case .thick: 0.88
        }
        return Color(light: .white, dark: Color("#1C1C1E")).opacity(alpha)
    }
}

extension Material: HostRepresentable {}
