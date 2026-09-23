// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What is drawn behind a view: one colour, or a brush.
///
///     Label("Total").background(.tomato)
///     Border { … }.background(.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]))
///
/// Design: docs/design/types/colour-and-theme.md#a-background-is-a-colour-or-a-brush
public enum Background: Equatable, Sendable, HostRepresentable {
    /// One colour.
    case color(Color)

    /// A brush: a gradient, or a colour said as a brush.
    case brush(Brush)

    /// The colour's form, or the brush's.
    public var propValue: PropValue {
        switch self {
        case .color(let color): color.propValue
        case .brush(let brush): brush.propValue
        }
    }

    /// A colour back, or a brush - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        if let color = Color(propValue: propValue) {
            self = .color(color)
            return
        }

        guard let brush = Brush(propValue: propValue) else { return nil }

        self = .brush(brush)
    }
}
