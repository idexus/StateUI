// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// When the scroll indicators are drawn - what `.verticalScrollIndicator` and
/// `.horizontalScrollIndicator` take.
public enum ScrollIndicatorVisibility: Int32, Sendable {
    /// As the platform sees fit.
    case automatic = 0

    /// Always shown.
    case visible = 1

    /// Never shown, though it still scrolls.
    case never = 2
}

extension ScrollIndicatorVisibility: HostRepresentable {}
extension ScrollIndicatorVisibility: StateChoice {}
