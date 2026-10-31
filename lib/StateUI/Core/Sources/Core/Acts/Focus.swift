// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Focus and the keyboard, as acts: a view's own aim, or whatever has the keyboard.
// Design: docs/design/core/acts.md#focus-and-the-keyboard

extension Aim where Target: FocusElement {
    /// Puts the keyboard on this view.
    ///
    ///     @Aim(TextField.self) private var email
    ///
    ///     TextField($address).aim(email)
    ///     Button("Edit").onClicked(.ignoreWhileRunning) { try await email.focus() }
    ///
    /// - Returns: true when the view took the focus. False is an ordinary
    ///   answer, not a failure: a view that is disabled, or not on screen, or
    ///   has nothing to focus refuses it.
    /// - Throws: `StateUIError` when the aim is on no view or on two, or its view is no longer shown.
    @discardableResult
    public func focus() async throws -> Bool {
        try await call(FocusElementContract.focus)
    }

    /// Takes the focus off this view, which is what closes the keyboard it
    /// opened.
    ///
    ///     Button("Done").onClicked(.ignoreWhileRunning) { try await email.unfocus() }
    ///
    /// For a keyboard whose view is not known here - a Done button above a form
    /// of several fields - use `WindowSession.hideOnScreenKeyboard()`, which asks the window.
    ///
    /// - Throws: `StateUIError` when the aim is on no view or on two, or its view is no longer shown.
    public func unfocus() async throws {
        try await call(FocusElementContract.unfocus)
    }
}
