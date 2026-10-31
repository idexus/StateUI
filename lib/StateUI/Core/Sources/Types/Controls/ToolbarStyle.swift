// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How the buttons on a bar stand where the host draws them itself - the
/// Web; every native bar keeps its platform's own.
///
///     SplitView {
///         MenuPage()
///     } detail: {
///         DetailPage()
///     }
///     .showsSidebar($showsMenu)
///     .toolbarStyle(.rounded)
public enum ToolbarStyle: Int32, Sendable, CaseIterable {
    /// The platform's own: on the Web, `.plain`.
    case system = 0

    /// Each button on a round glass of its own, a group of them sharing one.
    case glass = 1

    /// No background at rest, one under the pointer.
    case plain = 2

    /// A flat rounded rectangle behind each button, a group of them sharing
    /// one.
    case rounded = 3
}

extension ToolbarStyle: HostRepresentable {}
