// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import StateUIHost
@testable import StateUIGTK

/// A dialog, its field or its button a test looks for over a window and does not find.
struct GTKNoDialog: Error, CustomStringConvertible {
    let description: String
}

extension GTKRenderer {
    /// The dialog showing over `window` - the host's window where nil - now; nil while none shows.
    func visibleDialog(over window: GTKWindow? = nil) -> GTKWidget? {
        guard let window = window ?? self.window else { return nil }
        return adw_application_window_get_visible_dialog(window.widget.of(AdwApplicationWindow.self))?.of(GtkWidget.self)
    }

    /// The dialog showing over the window, waited for as GTK presents it.
    var dialog: GTKWidget? {
        var shown: GTKWidget?
        settle {
            shown = visibleDialog()
            return shown != nil
        }
        return shown
    }

    /// The heading of the dialog showing.
    var dialogHeading: String? {
        dialog.flatMap { adw_alert_dialog_get_heading($0.of(AdwAlertDialog.self)) }.map { String(cString: $0) }
    }

    /// Answers the dialog showing as the user would: its field first holding `words`, then its button doing `button`
    /// pressed - its response - and, as libadwaita does once its sheet has gone, the dialog told it closed.
    func answer(_ button: QuestionButton, typing words: String? = nil, over window: GTKWindow? = nil) throws {
        guard let dialog = visibleDialog(over: window) ?? (window == nil ? self.dialog : nil) else {
            throw GTKNoDialog(description: "no dialog showed")
        }
        let widgets = GTKTestHost.descendants(of: dialog)
        if let words {
            guard let field = widgets.first(where: { GTKTestHost.holds($0, gtk_entry_get_type()) }) else {
                throw GTKNoDialog(description: "the dialog holds no field")
            }
            gtk_editable_set_text(field.opaque, words)
        }
        GTKTestHost.emit(dialog.opaque, "response", words: GTKQuestion.response(of: button))
        // The response pressed closes the dialog, as its button does.
        adw_dialog_force_close(dialog.of(AdwDialog.self))
        if visibleDialog(over: window) == dialog { GTKTestHost.emit(dialog.opaque, "closed") }
        settle { true }
    }

    /// Dismisses the dialog showing as Escape does: libadwaita tells the dialog it closed once its sheet has gone,
    /// which a window behind another, drawn no frames, never gets to by itself.
    func dismiss() throws {
        guard let dialog else { throw GTKNoDialog(description: "no dialog showed") }
        GTKTestHost.emit(dialog.opaque, "closed")
        settle { true }
    }
}
