// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Whether a screen reader meets a view, and what is inside it.
///
///     Rectangle().fill(.silver).accessibilityPresence(.hidden)
///     VStack { … }.accessibilityPresence(.hiddenWithContents)
///
/// Left unsaid, the platform decides, which is nearly always right.
public enum AccessibilityPresence: Int32, Sendable, CaseIterable {
    /// Met as an element of its own - where a platform would leave the view
    /// out.
    case element = 0

    /// Skipped, what is inside it still met: decoration - a rule, a shadow, a
    /// picture repeating the words beside it. Never hide a view the user has to
    /// act on.
    case hidden = 1

    /// Skipped with everything inside it: a panel on screen that is not the
    /// user's business - a decorative header, a card standing behind the one in
    /// front.
    case hiddenWithContents = 2
}

extension AccessibilityPresence: HostRepresentable {}
extension AccessibilityPresence: StateChoice {}
