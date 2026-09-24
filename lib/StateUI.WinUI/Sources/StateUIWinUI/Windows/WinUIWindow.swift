// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A WinUI window: its title, and the page shown in it, activated the first time it has one.
@MainActor
final class WinUIWindow {
    /// The window, held until this is released.
    let handle: StateUIObjectRef

    /// The title last given; nil before the first.
    private var title: String??

    /// The view the window shows.
    private(set) var content: WinUIView?

    private var activated = false

    init() {
        handle = stateui_winui_window_make()!
    }

    isolated deinit {
        stateui_winui_release(handle)
    }

    /// The title bar's words; nil for none.
    func setTitle(_ title: String?) {
        guard self.title != .some(title) else { return }
        self.title = .some(title)
        stateui_winui_window_set_title(handle, title ?? "")
    }

    /// Shows `view` as the window's content - the first one activates the window.
    func show(_ view: WinUIView?) {
        content = view
        stateui_winui_window_set_content(handle, view?.handle)
        guard view != nil, !activated else { return }

        activated = true
        stateui_winui_window_activate(handle)
    }

    /// Closes the window.
    func close() {
        stateui_winui_window_close(handle)
    }
}
