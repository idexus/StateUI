// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Why a page tree is shown or hidden: a change of what an arrangement shows, a move on a stack, or its window's
/// coming and going.
/// Design: docs/design/host/pages.md#a-pages-phases
@_spi(Host) public enum PagePresentationReason: Sendable {
    /// What an arrangement shows changed: another tab, the sidebar shown or hidden.
    case appearance

    /// A page was pushed or popped, or a sheet presented or dismissed.
    case navigation

    /// The window the pages stand in came or went.
    case window
}
