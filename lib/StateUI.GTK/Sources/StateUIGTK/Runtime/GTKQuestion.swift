// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// One question for the user - an alert, a confirmation, a choice of actions, a prompt - as libadwaita's
/// `AdwAlertDialog` over the window, its answer coming back under its ticket.
/// Design: docs/design/platforms/gtk/runtime.md#questions-for-the-user
@MainActor
final class GTKQuestion {
    let call: HostActCall

    /// What the act asks, read by the host layer's rule.
    let question: HostQuestion

    /// The question's ticket, which its queue gives it.
    var ticket: Int64 = 0

    private weak var window: GTKWindow?

    /// A prompt's field, while its dialog shows.
    private var field: GTKWidget?

    /// Each response's caption, by its id.
    private var captions: [String: String] = [:]

    init(_ call: HostActCall, _ question: HostQuestion, window: GTKWindow) {
        self.call = call
        self.question = question
        self.window = window
    }

    /// Shows the dialog over the window.
    func show() {
        guard let window else { return }

        let dialog: UnsafeMutablePointer<AdwDialog>
        switch question.kind {
        case .alert:
            dialog = adw_alert_dialog_new(question.title, question.message)
            respond(dialog, "accept", question.accept, .suggested, closes: true)
        case .confirm:
            dialog = adw_alert_dialog_new(question.title, question.message)
            respond(dialog, "cancel", question.cancel ?? "Cancel", nil, closes: true)
            respond(dialog, "accept", question.accept, .suggested)
        case .chooseAction:
            // Dismissed any other way than by a button - Escape among them - nothing was chosen.
            dialog = adw_alert_dialog_new(question.title, nil)
            adw_alert_dialog_set_close_response(dialog.of(AdwAlertDialog.self), "close")
            if let destruction = question.destruction { respond(dialog, "destroy", destruction, .destructive) }
            for (index, choice) in question.choices.enumerated() { respond(dialog, "choice-\(index)", choice, nil) }
            if let cancel = question.cancel { respond(dialog, "cancel", cancel, nil) }
        case .prompt:
            dialog = adw_alert_dialog_new(question.title, question.message)
            respond(dialog, "cancel", question.cancel ?? "Cancel", nil, closes: true)
            respond(dialog, "accept", question.accept, .suggested)
            let field = makeField()
            adw_alert_dialog_set_extra_child(dialog.of(AdwAlertDialog.self), field)
            // The words are typed at once: the dialog gives the keyboard to its field as it shows.
            adw_dialog_set_focus(dialog, field)
        }
        connectSignal(UnsafeMutableRawPointer(dialog), "response", number: ticket) { _, response, data in
            let ticket = viewNumber(data)
            let id = response.map { String(cString: $0.assumingMemoryBound(to: CChar.self)) } ?? ""
            MainActor.assumeIsolated { GTKRenderer.shared?.acts.respond(ticket, id) }
        }
        adw_dialog_present(dialog, window.widget)
    }

    /// What the user answered by the response `id`: whether it was accepted, and the words chosen or typed.
    func answer(_ id: String) -> (accepted: Bool, words: String?) {
        switch question.kind {
        case .chooseAction:
            return (captions[id] != nil, captions[id])
        case .prompt:
            let words = field.map { String(cString: gtk_editable_get_text($0.opaque)) }
            return (id == "accept", words)
        case .alert, .confirm:
            return (id == "accept", nil)
        }
    }

    private enum Appearance {
        case suggested
        case destructive
    }

    /// Adds a button answering `id` under `caption`; `closes` makes it the answer of a dialog dismissed, and the
    /// suggested one is what Enter answers.
    private func respond(
        _ dialog: UnsafeMutablePointer<AdwDialog>, _ id: String, _ caption: String, _ appearance: Appearance?,
        closes: Bool = false
    ) {
        let alert = dialog.of(AdwAlertDialog.self)
        captions[id] = caption
        adw_alert_dialog_add_response(alert, id, caption)
        switch appearance {
        case .suggested?:
            adw_alert_dialog_set_response_appearance(alert, id, ADW_RESPONSE_SUGGESTED)
            adw_alert_dialog_set_default_response(alert, id)
        case .destructive?:
            adw_alert_dialog_set_response_appearance(alert, id, ADW_RESPONSE_DESTRUCTIVE)
        case nil:
            break
        }
        if closes { adw_alert_dialog_set_close_response(alert, id) }
    }

    /// A prompt's field: its placeholder, the most characters, the keyboard its purpose asks for, and the words it
    /// starts holding; Enter in it accepts.
    private func makeField() -> GTKWidget {
        let entry = gtk_entry_new()!
        if let placeholder = question.placeholder { gtk_entry_set_placeholder_text(entry.of(GtkEntry.self), placeholder) }
        if let most = question.maximumLength { gtk_entry_set_max_length(entry.of(GtkEntry.self), Int32(clamping: most)) }
        gtk_entry_set_input_purpose(entry.of(GtkEntry.self), Self.purpose(question.purpose))
        gtk_editable_set_text(entry.opaque, question.words)
        gtk_entry_set_activates_default(entry.of(GtkEntry.self), 1)
        field = entry
        return entry
    }

    private static func purpose(_ purpose: InputPurpose) -> GtkInputPurpose {
        switch purpose {
        case .email: GTK_INPUT_PURPOSE_EMAIL
        case .numeric: GTK_INPUT_PURPOSE_NUMBER
        case .telephone: GTK_INPUT_PURPOSE_PHONE
        case .url: GTK_INPUT_PURPOSE_URL
        default: GTK_INPUT_PURPOSE_FREE_FORM
        }
    }
}
