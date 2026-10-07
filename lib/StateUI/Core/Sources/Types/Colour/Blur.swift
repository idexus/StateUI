// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A blur of what lies behind a surface, in the platform's own look: how thick
/// it is - the thinnest lets the most through - and a colour laid over it.
///
///     VStack { … }.background(.blur(.thin))
///     VStack { … }.background(.blur(.thick.tint(.indigo.opacity(0.15))))
///
/// A platform that blurs nothing draws a colour of the theme in its place, let
/// through as the blur is, the tint over it.
/// Design: docs/design/types/colour-and-theme.md#a-blur
public struct Blur: Equatable, Sendable {
    // A closed vocabulary, numbered by StateUI: append a case, never insert one.
    // Design: docs/design/types/vocabularies.md#written-out-and-appended
    /// How thick a blur is.
    public enum Thickness: Int32, Sendable, CaseIterable {
        /// The thinnest: most of what lies behind shows.
        case ultraThin = 0

        /// Thin.
        case thin = 1

        /// The platform's ordinary blur.
        case regular = 2

        /// Thick.
        case thick = 3

        /// The thickest: what lies behind shows faintly.
        case ultraThick = 4

    }

    /// How thick the blur is.
    public let thickness: Thickness

    /// The colour laid over the blur; nil for none.
    public let tint: Color?

    /// A blur of `thickness`, untinted - the one a host reads back.
    @_spi(Host) public init(_ thickness: Thickness) {
        self.init(thickness: thickness, tint: nil)
    }

    init(thickness: Thickness, tint: Color?) {
        self.thickness = thickness
        self.tint = tint
    }

    /// The thinnest blur: most of what lies behind shows.
    public static let ultraThin = Blur(thickness: .ultraThin, tint: nil)

    /// A thin blur.
    public static let thin = Blur(thickness: .thin, tint: nil)

    /// The platform's ordinary blur.
    public static let regular = Blur(thickness: .regular, tint: nil)

    /// A thick blur.
    public static let thick = Blur(thickness: .thick, tint: nil)

    /// The thickest blur: what lies behind shows faintly.
    public static let ultraThick = Blur(thickness: .ultraThick, tint: nil)

    /// This blur with `color` laid over it - a colour with an alpha tints it.
    public func tint(_ color: Color) -> Blur {
        Blur(thickness: thickness, tint: color)
    }
}

extension Blur.Thickness: HostRepresentable {
    /// How much of what lies behind a blur this thick hides, from 0 to 1 - what
    /// a platform that sets a blur's opacity itself gives it.
    @_spi(Host) public var opacity: Double {
        switch self {
        case .ultraThin: 0.45
        case .thin: 0.6
        case .regular: 0.75
        case .thick: 0.88
        case .ultraThick: 0.95
        }
    }

    /// What a platform that blurs nothing draws in its place: a colour of the
    /// theme, let through as much as the blur lets.
    var standIn: Color {
        Color(light: .white, dark: Color("#1C1C1E")).opacity(opacity)
    }
}
