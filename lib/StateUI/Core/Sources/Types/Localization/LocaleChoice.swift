// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A choice that follows the system, or holds one value whatever the system says.
///
///     localization.language = .fixed(.polish)
///     localization.formatLocale = .system
///
/// Design: docs/design/types/localization.md#three-choices
public enum LocaleChoice<Value: Hashable & Sendable>: Hashable, Sendable {
    /// What the system says, as it says it, changes included.
    case system

    /// This value, whatever the system says.
    case fixed(Value)
}
