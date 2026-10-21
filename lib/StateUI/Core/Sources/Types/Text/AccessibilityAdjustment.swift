// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Which way a screen reader steps an adjustable view - what `.onAccessibilityAdjusted` hears.
public enum AccessibilityAdjustment: Int32, Sendable, CaseIterable {
    /// A step up.
    case increment = 1

    /// A step down.
    case decrement = 2
}

extension AccessibilityAdjustment: HostRepresentable {}
