// Who has the keyboard, and how to take it away.
//
// Focus is not a shape, so it is not in the tree - it is an ACT, and it goes
// through Command.swift exactly as a dialog or a scroll does. MAUI declares
// `Focus` a method rather than a settable property, and a method here is what a
// method is there. Two levels of it, because the question has two forms:
//
//     try await field.focus()      // this view, by the id it was given
//     try await SoftInput.hide()   // whatever has the keyboard, whatever it is
//
// WHY THE SECOND ONE EXISTS. MAUI has no method for it: its own routes are
// `Unfocus` on the control you are holding and `HideSoftInputOnTapped` on the
// page, and both are here - `.unfocus()` below and `hideSoftInputOnTapped` on
// every page. What neither covers is a Done button that has to close a keyboard
// it did not open, since the control that has the focus is whichever one the
// reader touched last. The host answers that by ASKING the page which of its
// views is focused, so nothing on this side has to track it - and the name is
// MAUI's own word for the on-screen keyboard, the one in `HideSoftInputOnTapped`
// and `HideSoftInputAsync`.
//
// THE TRAP, measured on an iPhone XS: a search box on the navigation bar takes
// the focus and iOS gives the whole bar to the search field - the back button
// goes with it. A reader who has nothing to tap has no way out of the search
// and no way back to the previous page. `SoftInput.hide()` is what puts the bar
// back, and the gallery's Search sample offers it as a button beside the box.

extension ControlState {
    /// Puts the keyboard on this view. MAUI: VisualElement.Focus.
    ///
    ///     @State private var email = ControlState<Entry>()
    ///
    ///     Entry($address).assign(email)
    ///     Button("Edit").onClicked { try await email.focus() }
    ///
    /// - Returns: true when the view took the focus. False is an ordinary
    ///   answer, not a failure: a view that is disabled, or not on screen, or
    ///   has nothing to focus refuses it, exactly as it does in MAUI.
    /// - Throws: `StateUIError` when no view of that id is being shown.
    @discardableResult
    public nonisolated(nonsending) func focus() async throws -> Bool {
        try await stateUICall(.focus, [try target]).value()?.bool == true
    }

    /// Takes the focus off this view, which is what closes the keyboard it
    /// opened. MAUI: VisualElement.Unfocus.
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
/// This library's own name, for the one question MAUI has no method for: close
/// the keyboard, whichever view opened it. MAUI's word for the thing, though -
/// `HideSoftInputOnTapped` and `HideSoftInputAsync` are both MAUI's, and both of
/// those routes are here too, the first as a page property and the second as
/// `ControlState.unfocus()`.
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
