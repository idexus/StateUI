// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A run of the user's input a view hears from its beginning to its end: a press, a press dragged, a pinch, a
/// turn, a press and its mirror, the hand.
/// Design: docs/design/host/interaction.md#a-hand-taken-away
enum HeardStream: Hashable, Sendable {
    case press, drag, pinch, rotation, mirrored, hand
}

extension HeardInput {
    /// The run the input is a step of, and which step; nil for input that is no run - a tap, a wheel, a drop.
    var step: (stream: HeardStream, phase: GesturePhase)? {
        switch self {
        case .press(let phase, _, _, _): (.press, phase)
        case .drag(let phase, _, _, _): (.drag, phase)
        case .pinch(let phase, _, _): (.pinch, phase)
        case .rotation(let phase, _): (.rotation, phase)
        case .mirrored(let phase, _, _): (.mirrored, phase)
        case .hand(let phase, _, _, _, _): (.hand, phase)
        default: nil
        }
    }
}
