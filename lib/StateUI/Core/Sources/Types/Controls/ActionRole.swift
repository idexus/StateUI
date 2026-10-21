// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an action a user chooses does beyond its words: an ordinary one, or one that destroys something, which each
/// platform marks its own way - a menu's entry, a bar's item.
///
///     MenuItem("Delete").role(.destructive)
public enum ActionRole: Int32, Sendable, HostRepresentable {
    /// An ordinary action.
    case normal = 0

    /// An action that destroys something: drawn in the platform's color for one, where it has one. The look only:
    /// a confirmation is still the handler's to put up.
    case destructive = 1
}
