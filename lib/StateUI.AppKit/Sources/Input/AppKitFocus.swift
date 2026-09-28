// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// Where the keyboard focus is, asked of the window that holds it; StateUI never mirrors it as state.
/// Design: docs/design/platforms/appkit/input.md#focus
@MainActor
enum AppKitFocus {
    /// The view inside `view` that takes the keyboard: itself, or the first one within it that does.
    static func focusable(in view: NSView) -> NSView? {
        if view.acceptsFirstResponder { return view }

        for subview in view.subviews {
            if let found = focusable(in: subview) { return found }
        }
        return nil
    }

    /// Whether a window's first `responder` is `view` or inside it; a field editor counts as its field.
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
