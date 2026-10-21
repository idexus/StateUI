// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A color a screen shows where StateUI draws. It answers whether it shows a color, within the few steps an edge's
/// smoothing takes from a color drawn whole, and is never compared with one whole: that may never match, and a
/// `settle` waiting on it runs out without a word.
/// Design: docs/design/host/conformance.md#a-color-drawn
public struct ShownColor: Equatable, Sendable, CustomStringConvertible {
    private let color: Color

    init(_ color: Color) {
        self.color = color
    }

    /// Whether this is `expected` but for the last few steps of each channel.
    public func shows(_ expected: Color) -> Bool {
        guard case .color(let red, let green, let blue, let alpha) = color.propValue,
              case .color(let shownRed, let shownGreen, let shownBlue, let shownAlpha) = expected.propValue
        else { return false }
        return zip([red, green, blue, alpha], [shownRed, shownGreen, shownBlue, shownAlpha])
            .allSatisfy { abs(Int($0) - Int($1)) <= 4 }
    }

    public var description: String { String(describing: color) }
}
