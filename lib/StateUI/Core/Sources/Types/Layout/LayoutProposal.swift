// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The room a layout is offered as it measures itself: a width, a height, either or neither.
///
///     .measure { context, _ in
///         LayoutSize(width: context.proposal.width ?? 320, height: 48)
///     }
///
/// A side left out offers nothing: what is measured answers the size it takes by itself along it.
/// Design: docs/design/views/motion-layout.md#measuring-a-view
public struct LayoutProposal: Hashable, Sendable {
    /// The width offered; nil for none.
    public let width: Double?

    /// The height offered; nil for none.
    public let height: Double?

    /// A room `width` by `height`. A side below nought is nought; one that is no number offers nothing, and is
    /// said once.
    public init(width: Double? = nil, height: Double? = nil) {
        self.width = Self.held(width)
        self.height = Self.held(height)
    }

    private static func held(_ side: Double?) -> Double? {
        guard let side else { return nil }
        guard side.isFinite else {
            complain("A LayoutProposal was given a side that is no number - a division by nothing, an infinity: it "
                + "offers nothing along it.")
            return nil
        }
        return max(0, side)
    }
}
