// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// Where the keyboard focus is, asked of the window that holds it.
///
/// The focus is the platform's: it moves on a click, a Tab, a Return and
/// whenever AppKit takes it away, so StateUI never mirrors it as state. The host
/// needs two answers - which view inside an element takes the keyboard, and
/// whether a window's first responder is inside an element - and asks the
/// window for both at the moment they matter.
@MainActor
enum AppKitFocus {
    /// The view inside `view` that takes the keyboard: the view itself where it
    /// does, or the first one within it that does - a text field's own field,
    /// not the box it stands in.
    static func focusable(in view: NSView) -> NSView? {
        if view.acceptsFirstResponder { return view }

        for subview in view.subviews {
            if let found = focusable(in: subview) { return found }
        }
        return nil
    }

    /// Whether `responder` - a window's first responder - is `view` or inside
    /// it, a text field's field editor counting as the field it edits.
    static func holds(_ view: NSView, _ responder: NSResponder?) -> Bool {
        var holder = responder
        if let editor = responder as? NSTextView, editor.isFieldEditor,
           let field = editor.delegate as? NSView {
            holder = field
        }
        guard let holding = holder as? NSView else { return false }
        return holding === view || holding.isDescendant(of: view)
    }
}
#endif
