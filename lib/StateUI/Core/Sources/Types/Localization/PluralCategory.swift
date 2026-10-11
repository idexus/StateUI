// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The plural form a count takes in a language: which of a message's forms `MessageContext.plural` says.
/// Design: docs/design/types/localization.md#messages
enum PluralCategory: Sendable {
    case zero
    case one
    case two
    case few
    case many
    case other
}
