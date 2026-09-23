// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where a toolbar item goes in the platform's native action surface.
public enum ToolbarItemPlacement: Int32, Sendable {
    /// Wherever the platform normally puts an item.
    case automatic = 0

    /// On the bar itself, where it can be chosen straight away.
    case bar = 1

    /// Behind the native overflow menu.
    case overflow = 2
}

extension ToolbarItemPlacement: HostRepresentable {}
