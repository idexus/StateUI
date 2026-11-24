// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a write of the program does to a value the user's hand holds.
///
///     .value($page, input: .swipe(.horizontal, unit: .containerLength))
///         .range(0...4).snaps(.every(1))
///         .programWrites(.deferLatest)      // a timer turning the pages waits for the hand
///
/// Design: docs/design/views/interaction.md#a-write-of-the-program
public enum InteractionProgramWrites: Equatable, Sendable {
    /// The write takes the value from the hand: it travels to where the program sent it from where the hand held
    /// it, and the gesture moves it no more until it ends; the gesture's other values stay under the hand.
    case interrupt

    /// The hand keeps the value: the state is going where the program sent it at once, the value stays under the
    /// hand, and let go it travels to where the program sent it last.
    case deferLatest
}
