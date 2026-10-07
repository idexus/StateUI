// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Glass: a surface the platform draws as its own glass - what lies behind
/// it bent and lit through it - regular, or clear, which lets more through,
/// tinted where a colour is given, and answering the user's touch where it is
/// interactive.
///
///     VStack { … }.backdrop(.glass(.regular))
///     VStack { … }.backdrop(.glass(.clear.tint(.indigo).isInteractive(true)))
///
/// A platform with no glass draws a material in its place, as clear as the
/// glass is.
/// Design: docs/design/types/colour-and-theme.md#glass
public struct Glass: Equatable, Sendable {
    /// How much the glass lets through.
    public enum Clarity: Int32, Sendable {
        /// The platform's ordinary glass.
        case regular = 0

        /// Clearer glass, which lets more through.
        case clear = 1
    }

    /// How much the glass lets through.
    public let clarity: Clarity

    /// The colour the glass is tinted with; nil for none.
    public let tint: Color?

    /// Whether the glass answers the user's touch and pointer, as a control's
    /// does.
    public let isInteractive: Bool

    /// The platform's ordinary glass.
    public static let regular = Glass(clarity: .regular, tint: nil, isInteractive: false)

    /// Clearer glass, which lets more through.
    public static let clear = Glass(clarity: .clear, tint: nil, isInteractive: false)

    /// This glass, tinted with `color`.
    public func tint(_ color: Color) -> Glass {
        Glass(clarity: clarity, tint: color, isInteractive: isInteractive)
    }

    /// This glass, answering the user's touch and pointer where `value` is
    /// true.
    public func isInteractive(_ value: Bool) -> Glass {
        Glass(clarity: clarity, tint: tint, isInteractive: value)
    }

    /// The material a platform with no glass draws in its place.
    var material: Material {
        clarity == .clear ? .ultraThin : .regular
    }
}

extension Glass.Clarity: HostRepresentable {}
