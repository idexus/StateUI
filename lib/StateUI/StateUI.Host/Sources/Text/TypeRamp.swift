// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension FontWeight {
    /// The weight's number on the scale fonts are weighed by: 400, 500, 600 or 700.
    public var number: Int { 400 + Int(rawValue) * 100 }

    /// The weight whose number stands nearest `number` - what a font drawn at `number` reads as; the lighter of two
    /// as near, and regular or bold beyond them.
    public init(nearest number: Double) {
        let step = ((number - 400) / 100 - 0.5).rounded(.up)
        self = FontWeight(rawValue: Int32(min(max(step, 0), 3))) ?? .regular
    }
}

extension TextLook {
    /// The size and the weight words stand at: the tree's where it gives them, else their style's on the platform -
    /// `styleSize` and `styleWeight` - else nil for the host's own.
    /// Design: docs/design/host/tree.md#a-text-style
    public func standing(styleSize: Double?, styleWeight: FontWeight?) -> (size: Double?, weight: FontWeight?) {
        (size ?? styleSize, weight ?? styleWeight)
    }
}
