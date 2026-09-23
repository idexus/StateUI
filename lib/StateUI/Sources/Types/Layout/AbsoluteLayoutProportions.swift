// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// Which parts of a child's bounds an AbsoluteLayout reads as fractions rather
/// than as device units.
///
///     .absoluteLayoutBounds(Rect(0.5, 0, 0.5, 1))
///     .absoluteLayoutProportions(.all)
///
/// A fraction is of the layout's size, so 0.5 is half of it however big it
/// turns out to be.
public struct AbsoluteLayoutProportions: OptionSet, Sendable {
    /// The flag bits.
    public let rawValue: Int32

    /// From the raw bits. The members below are the ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Every number is device units. The default.
    public static let none = AbsoluteLayoutProportions([])

    /// The position across as a fraction.
    public static let x = AbsoluteLayoutProportions(rawValue: 1 << 0)

    /// The position down as a fraction.
    public static let y = AbsoluteLayoutProportions(rawValue: 1 << 1)

    /// Both edges as fractions, the size still in device units.
    public static let position: AbsoluteLayoutProportions = [.x, .y]

    /// The width as a fraction.
    public static let width = AbsoluteLayoutProportions(rawValue: 1 << 2)

    /// The height as a fraction.
    public static let height = AbsoluteLayoutProportions(rawValue: 1 << 3)

    /// Both lengths as fractions, the position still in device units.
    public static let size: AbsoluteLayoutProportions = [.width, .height]

    /// All four as fractions.
    public static let all: AbsoluteLayoutProportions = [.position, .size]
}

extension AbsoluteLayoutProportions: HostRepresentable {}
extension AbsoluteLayoutProportions: StateChoice {}
