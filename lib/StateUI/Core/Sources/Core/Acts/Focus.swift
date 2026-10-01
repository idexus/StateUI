// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Focus and the keyboard, as acts: a view's own aim, or whatever has the keyboard.
// Design: docs/design/core/acts.md#focus-and-the-keyboard

extension Aim {
    /// Puts the keyboard on this view.
    ///
    ///     @Aim(TextField.self) private var email
    ///
    ///     TextField($address).aim(email)
    ///     Button("Edit").onClicked { try await email.focus() }
    ///
    /// - Returns: true when the view took the focus. False is an ordinary
    ///   answer, not a failure: a view that is disabled, or not on screen, or
    ///   has nothing to focus refuses it.
    /// - Throws: `StateUIError` when no view of that id is being shown.
    @discardableResult
    public nonisolated(nonsending) func focus() async throws -> Bool {
        try await call(VisualElementContract.focus)
    }

    /// Takes the focus off this view, which is what closes the keyboard it
    /// opened.
    ///
    ///     Button("Done").onClicked { try await email.unfocus() }
    ///
    /// For a keyboard whose view is not known here - a Done button above a form
    /// of several fields - use `OnScreenKeyboard.hide()`, which asks the page.
    ///
    /// - Throws: `StateUIError` when no view of that id is being shown.
    public nonisolated(nonsending) func unfocus() async throws {
        try await call(VisualElementContract.unfocus)
    }
}

/// The on-screen keyboard, as the page it is over sees it - reached without
/// naming the view that opened it. A known view is released with `Aim.unfocus()`.
public enum OnScreenKeyboard {
    /// Closes the keyboard by taking the focus off whatever has it.
    ///
    ///     Button("Done").onClicked { try await OnScreenKeyboard.hide() }
    ///
    /// The host looks at the page that is showing and walks it for whatever
    /// holds the focus - a search box in the navigation bar is an ordinary
    /// view, a page's title view, so the same walk reaches it. Unfocusing the
    /// search box is also what brings back the navigation bar on iOS, which
    /// shows the search field in its place while it is focused.
    ///
    /// - Returns: true when something was focused and is not any more. False
    ///   means the keyboard was already down - an answer, not a failure.
    @discardableResult
    public static nonisolated(nonsending) func hide() async throws -> Bool {
        try await stateUICall(ApplicationContract.hideOnScreenKeyboard)
    }
}
