// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The tabs a window shows beneath its chrome - those of the tabbed view on the visible page path - and the split
/// view whose detail they stand across, if any: beside a sidebar, never over it.
@MainActor
struct WinUIWindowTabs {
    let titles: [String]
    let selected: Int
    let select: (Int) -> Void
    weak var split: WinUISplitView?
}
