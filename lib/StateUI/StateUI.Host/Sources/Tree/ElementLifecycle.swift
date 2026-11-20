// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where an element stands in its life in the mounted tree.
/// Design: docs/design/host/tree.md#leaving
@_spi(Host) public enum ElementLifecycle: Sendable {
    /// In the tree: measured, laid out, and reached by the user's input and the application's updates.
    case active

    /// Out of the tree as the application has it: its handlers, bindings, reports and input have no effect.
    case exiting

    /// Gone: nothing of the host holds its view.
    case released
}
