// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A button's picture beside its words, the two together in the middle of the room inside its padding - the same
/// on every host.
/// Design: docs/design/host/layout.md#a-buttons-picture-and-words
@_spi(Host) public enum ButtonArithmetic {
    /// The room each side of a picture `position` of words leaves inside `room`: half of what the picture, the gap
    /// and the words do not fill - what a control standing its picture at its edge adds to its padding. None where
    /// they fill the room, and none for a picture above or below the words, the two already in the middle together.
    public static func sideRoom(
        _ room: Double, picture: Double, gap: Double, words: Double, position: IconPosition
    ) -> Double {
        guard position == .leading || position == .trailing else { return 0 }
        return max(0, (room - picture - gap - words) / 2)
    }
}
