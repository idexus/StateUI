// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One action a page's header bar performs for the page.
@MainActor
struct GTKToolbarAction {
    let title: String
    let isEnabled: Bool
    let perform: () -> Void

    /// Whether two actions draw the same button. What an action performs is taken again on every composition.
    func draws(like other: GTKToolbarAction) -> Bool {
        title == other.title && isEnabled == other.isEnabled
    }
}

/// What a page's header bar shows: the page's title or its title view, the page's actions, the overflow behind the
/// bar's menu, whether the bar shows at all and whether it offers the way back.
@MainActor
struct GTKPageChrome {
    var title = ""
    var titleView: GTKView?
    var actions: [GTKToolbarAction] = []
    var overflow: [GTKToolbarAction] = []
    var showsBar = true
    var offersBack = true
}
