// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What one edge of a layout stays clear of on the screen's unsafe strip -
/// the notch, the bars, the on-screen keyboard.
///
/// Only iOS has such a strip; the other platforms ignore this. A layout there
/// defaults to `.container` - see `avoidsSafeArea`.
public enum SafeArea: Int32, Sendable {
    /// Edge to edge: content may run under the notch, the bars and the
    /// keyboard.
    case none = 0

    /// Clear of the on-screen keyboard, under everything else.
    case keyboard = 1

    /// Clear of the bars and the notch, under the keyboard. What an iOS
    /// layout does when nothing is said.
    case container = 2

    /// Clear of everything - bars, notch and keyboard alike.
    case all = 3
}

extension SafeArea: HostRepresentable {}
extension SafeArea: StateChoice {}
