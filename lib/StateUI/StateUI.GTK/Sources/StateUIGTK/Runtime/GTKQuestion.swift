// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// One question for the user - an alert, a confirmation, a choice of actions, a prompt - as libadwaita's
/// `AdwAlertDialog` over the window, kept until the user answers it.
/// Design: docs/design/platforms/gtk/runtime.md#questions-for-the-user
@MainActor
final class GTKQuestion {
    /// What the act asks, read by the host layer's rule.
    let question: HostQuestion

    /// What hears the answer.
    private let answered: (HostQuestion.Given) -> Void

    /// The questions showing, by the number their dialog's answer comes back under.
    private static let showing = Numbered<GTKQuestion>()

    /// A prompt's field, while its dialog shows.
    private var field: GTKWidget?

    /// What each response answers, by its id.
    private var roles: [String: QuestionButton] = [:]

    init(_ question: HostQuestion, answered: @escaping (HostQuestion.Given) -> Void) {
        self.question = question
        self.answered = answered
    }

    /// The id of the response doing `button`.
    static func response(of button: QuestionButton) -> String {
        switch button {
        case .accept: "accept"
        case .cancel: "cancel"
        case .action(let place): "action-\(place)"
        }
    }

    /// Shows the dialog over `window`: its cancel first, as GNOME stands it, which a dialog dismissed any other
    /// way - Escape among them - answers as; an alert's one button answers its dismissal.
    func show(over window: GTKWindow) {
        let number = Self.showing.hold(self)

        let dialog = adw_alert_dialog_new(question.title, question.kind == .chooseAction ? nil : question.message)!
        let buttons = question.buttons
        for (caption, role) in buttons.filter({ $0.role == .cancel }) + buttons.filter({ $0.role != .cancel }) {
            let appearance: Appearance? = switch role {
            case .accept: .suggested
            case .action(let place) where place == question.destructive: .destructive
            case .cancel, .action: nil
            }
            respond(dialog, role, caption, appearance)
        }
        adw_alert_dialog_set_close_response(
            dialog.of(AdwAlertDialog.self), Self.response(of: question.kind == .alert ? .accept : .cancel))
        if question.kind == .prompt {
            let field = makeField()
            adw_alert_dialog_set_extra_child(dialog.of(AdwAlertDialog.self), field)
            // The words are typed at once: the dialog gives the keyboard to its field as it shows.
            adw_dialog_set_focus(dialog, field)
        }
        connectSignal(UnsafeMutableRawPointer(dialog), "response", number: number) { _, response, data in
            let number = viewNumber(data)
            let id = response.map { String(cString: $0.assumingMemoryBound(to: CChar.self)) } ?? ""
            MainActor.assumeIsolated { GTKQuestion.showing.take(number)?.respond(id) }
        }
        adw_dialog_present(dialog, window.widget)
    }

    /// The user answered by the response `id`: what its button does, with the words a prompt's field holds.
    private func respond(_ id: String) {
        answered(HostQuestion.Given(
            pressed: roles[id] ?? .cancel, typing: field.map { String(cString: gtk_editable_get_text($0.opaque)) }))
    }

    private enum Appearance {
        case suggested
        case destructive
    }

    /// Adds a button doing `role` under `caption`; the suggested one is what Enter answers.
    private func respond(
        _ dialog: UnsafeMutablePointer<AdwDialog>, _ role: QuestionButton, _ caption: String, _ appearance: Appearance?
    ) {
        let alert = dialog.of(AdwAlertDialog.self)
        let id = Self.response(of: role)
        roles[id] = role
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
    }

    /// A prompt's field: its placeholder, the most characters, the keyboard its purpose asks for, and the words it
    /// starts holding; Enter in it accepts.
    private func makeField() -> GTKWidget {
        let entry = gtk_entry_new()!
        if let placeholder = question.placeholder { gtk_entry_set_placeholder_text(entry.of(GtkEntry.self), placeholder) }
        if let most = question.maximumLength { gtk_entry_set_max_length(entry.of(GtkEntry.self), Int32(clamping: most)) }
        let (hints, purpose) = GTKTextFieldView.input(question.traits)
        gtk_entry_set_input_hints(entry.of(GtkEntry.self), hints)
        gtk_entry_set_input_purpose(entry.of(GtkEntry.self), purpose)
        gtk_editable_set_text(entry.opaque, question.words)
        gtk_entry_set_activates_default(entry.of(GtkEntry.self), 1)
        field = entry
        return entry
    }
}
