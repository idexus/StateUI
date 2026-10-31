// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The on-screen keyboard over a window, as an act: whatever in the window has the keyboard.
// Design: docs/design/core/acts.md#focus-and-the-keyboard

extension WindowSession {
    /// Closes the on-screen keyboard over this window by taking the focus off whatever in it has it - reached
    /// without naming the view that opened it. A known view is released with `Aim.unfocus()`.
    ///
    ///     Button("Done").onClicked(.ignoreWhileRunning) { try await window.hideOnScreenKeyboard() }
    ///
    /// The host walks the window's page for whatever holds the focus - a search box in the navigation bar is an
    /// ordinary view, a page's title view, so the same walk reaches it. Unfocusing the search box is also what
    /// brings back the navigation bar on iOS, which shows the search field in its place while it is focused.
    ///
    /// - Returns: true when something was focused and is not any more. False means the keyboard was already
    ///   down - an answer, not a failure.
    /// - Throws: `WindowError` for a window no longer open.
    @discardableResult
    public func hideOnScreenKeyboard() async throws -> Bool {
        let (scene, window) = try address
        return try await stateUICall(ApplicationContract.hideOnScreenKeyboard, scene, window)
    }
}
