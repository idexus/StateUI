// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which numbers of a view's presentation a press moves: what it does not name stays as the layout has it, whatever
/// its effect answers.
///
///     .press(values: [.translation, .rotation]) { press in … }
///
/// Design: docs/design/views/interaction.md#a-views-own-press-and-drag
public struct PresentationValues: OptionSet, Hashable, Sendable {
    /// The set's bits, one a number.
    public let rawValue: UInt8

    /// Makes a set from its bits.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// How far the view is moved across.
    public static let translationX = PresentationValues(rawValue: 1 << 0)

    /// How far it is moved down.
    public static let translationY = PresentationValues(rawValue: 1 << 1)

    /// How far it is turned.
    public static let rotation = PresentationValues(rawValue: 1 << 2)

    /// How many times as wide it is drawn.
    public static let scaleX = PresentationValues(rawValue: 1 << 3)

    /// How many times as tall it is drawn.
    public static let scaleY = PresentationValues(rawValue: 1 << 4)

    /// Moved either way.
    public static let translation: PresentationValues = [.translationX, .translationY]

    /// Scaled either way.
    public static let scale: PresentationValues = [.scaleX, .scaleY]

    /// Every number.
    public static let all: PresentationValues = [.translation, .rotation, .scale]
}
