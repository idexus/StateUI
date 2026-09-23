// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if MAUI

/// Which way an `ItemsView` runs, and which way the user scrolls it.
public enum ItemsOrientation: Sendable {
    /// Down. The default.
    case vertical

    /// Across.
    case horizontal
}

#endif
