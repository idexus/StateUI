// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A width and a height, in points: what a view measures, and what a layout answers for its own size.
///
///     .measure { context, _ in LayoutSize(width: 320, height: 180) }
public struct LayoutSize: Equatable, Sendable {
    /// How wide.
    public var width: Double

    /// How tall.
    public var height: Double

    /// A size `width` wide and `height` tall.
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// No room at all.
    public static let zero = LayoutSize(width: 0, height: 0)
}
