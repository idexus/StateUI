// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One colour in a gradient, and where along it that colour sits.
///
///     GradientStop(.cornflowerBlue, 0)
///     GradientStop(Color(light: .white, dark: .black), 1)
///
/// The offset runs from 0 at the start of the gradient to 1 at its end, where
/// "start" and "end" are the points the gradient itself was given.
public struct GradientStop: Equatable, Sendable {
    /// What colour the gradient is at this point.
    public let color: Color

    /// Where along the gradient it is, from 0 to 1.
    public let offset: Double

    /// A stop: the colour, then how far along it sits.
    public init(_ color: Color, _ offset: Double) {
        self.color = color
        self.offset = offset
    }
}
