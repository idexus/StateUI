// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Who has the keyboard, and how to take it away.
//
// Focus is not a shape, so it is not in the tree. It is an act carried through
// Command.swift, with two forms:
//
//     try await field.focus()      // this view, by the id it was given
//     try await SoftInput.hide()   // whatever has the keyboard, whatever it is
//
// The second form lets a Done button close a keyboard it did not open. The
// focused control is whichever one the reader touched last, so the host asks
// its native focus system and StateUI does not mirror that identity as state.
//
// THE TRAP, on iOS: a search box on the navigation bar takes the focus and
// iOS gives the whole bar to the search field - the back button goes with it.
// A reader who has nothing to tap has no way out of the search and no way
// back to the previous page. `SoftInput.hide()` is what puts the bar back,
// and the gallery's Keyboard sample offers it as a button.

extension Aim {
    /// Puts the keyboard on this view.
    ///
    ///     @Aim(Entry.self) private var email
    ///
    ///     Entry($address).aim(email)
    ///     Button("Edit").onClicked { try await email.focus() }
    ///
    /// - Returns: true when the view took the focus. False is an ordinary
    ///   answer, not a failure: a view that is disabled, or not on screen, or
    ///   has nothing to focus refuses it.
    /// - Throws: `StateUIError` when no view of that id is being shown.
    @discardableResult
    public nonisolated(nonsending) func focus() async throws -> Bool {
        try await stateUICall(.focus, [try target]).value()?.bool == true
    }

    /// Takes the focus off this view, which is what closes the keyboard it
    /// opened.
    ///
    ///     Button("Done").onClicked { try await email.unfocus() }
    ///
    /// For a keyboard whose view is not known here - a Done button above a form
    /// of several fields - use `SoftInput.hide()`, which asks the page.
    ///
    /// - Throws: `StateUIError` when no view of that id is being shown.
    public nonisolated(nonsending) func unfocus() async throws {
        try await stateUICall(.unfocus, [try target])
    }
}

/// The on-screen keyboard, as the page it is over sees it.
///
/// The on-screen input surface without naming the view that opened it.
///
/// A known view is released with `Aim.unfocus()`. Use `hide()` when the native
/// focus system must identify the current input.
public enum SoftInput {
    /// Closes the keyboard by taking the focus off whatever has it.
    ///
    ///     Button("Done").onClicked { try await SoftInput.hide() }
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
        try await stateUICall(.hideSoftInput).value()?.bool == true
    }
}
