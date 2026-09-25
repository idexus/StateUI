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

    /// The question's number: one across the process, so an answer after its renderer has gone answers nothing of
    /// another's.
    let ticket: Int64
    private static var nextTicket: Int64 = 1

    private weak var window: GTKWindow?

    /// A prompt's field, while its dialog shows.
    private var field: GTKWidget?

    /// Each response's caption, by its id.
    private var captions: [String: String] = [:]

    init(_ call: HostActCall, window: GTKWindow) {
        self.call = call
        self.window = window
        ticket = Self.nextTicket
        Self.nextTicket += 1
    }

    /// Shows the dialog over the window.
    func show() {
        guard let window else { return }
        func text(_ index: Int) -> String? { call.arguments.value(index)?.string }

        let dialog: UnsafeMutablePointer<AdwDialog>
        switch call.act {
        case .alert:
            dialog = adw_alert_dialog_new(text(0), text(1))
            respond(dialog, "accept", text(2) ?? "OK", .suggested, closes: true)
        case .confirm:
            dialog = adw_alert_dialog_new(text(0), text(1))
            respond(dialog, "cancel", text(3) ?? "Cancel", nil, closes: true)
            respond(dialog, "accept", text(2) ?? "OK", .suggested)
        case .chooseAction:
            // Dismissed any other way than by a button - Escape among them - nothing was chosen.
            dialog = adw_alert_dialog_new(text(0), nil)
            adw_alert_dialog_set_close_response(dialog.of(AdwAlertDialog.self), "close")
            if let destruction = text(2) { respond(dialog, "destroy", destruction, .destructive) }
            let choices = call.arguments.value(3).flatMap { [String](propValue: $0) } ?? []
            for (index, choice) in choices.enumerated() { respond(dialog, "choice-\(index)", choice, nil) }
            if let cancel = text(1) { respond(dialog, "cancel", cancel, nil) }
        default:
            dialog = adw_alert_dialog_new(text(0), text(1))
            respond(dialog, "cancel", text(3) ?? "Cancel", nil, closes: true)
            respond(dialog, "accept", text(2) ?? "OK", .suggested)
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
        switch call.act {
        case .chooseAction:
            return (captions[id] != nil, captions[id])
        case .prompt:
            let words = field.map { String(cString: gtk_editable_get_text($0.opaque)) }
            return (id == "accept", words)
        default:
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
        let arguments = call.arguments
        if let placeholder = arguments.value(4)?.string { gtk_entry_set_placeholder_text(entry.of(GtkEntry.self), placeholder) }
        if let most = arguments.value(5)?.number, most > 0 { gtk_entry_set_max_length(entry.of(GtkEntry.self), Int32(most)) }
        let purpose = arguments.value(6).flatMap { InputPurpose(propValue: $0) } ?? .default
        gtk_entry_set_input_purpose(entry.of(GtkEntry.self), Self.purpose(purpose))
        gtk_editable_set_text(entry.opaque, arguments.value(7)?.string ?? "")
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
