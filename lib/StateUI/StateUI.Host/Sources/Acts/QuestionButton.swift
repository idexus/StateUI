// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A button of a question for the user, by what pressing it answers - the way a host draws one and a driver presses
/// one, whatever its caption.
/// Design: docs/design/host/runtime.md#questions-for-the-user
public enum QuestionButton: Equatable, Sendable {
    /// The one accepting it: an alert's only, a confirmation's or a prompt's yes.
    case accept
    /// The one cancelling it.
    case cancel
    /// A choice's action at this place among those it offers.
    case action(Int)
}
