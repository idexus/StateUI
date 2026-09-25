// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// Performs the acts the application calls on the host, and answers each - a reply with its values, or a failure
/// with the reason - so a caller never waits on an act nobody performs. A question for the user answers when the
/// user does.
/// Design: docs/design/platforms/gtk/runtime.md#acts
@MainActor
final class GTKActPerformer {
    private let core: CoreLink

    /// What the dialogs ask, the one showing first; each answers under its ticket.
    private var questions: [GTKQuestion] = []

    init(core: CoreLink) {
        self.core = core
    }

    /// Performs one act, and answers it; `window` is where a question, a word to a screen reader and the keyboard
    /// stand.
    func perform(_ call: HostActCall, in tree: MountedTree, window: GTKWindow?, applicationID: String) {
        switch call.act {
        case .currentTime:
            reply(call, [currentTime().propValue])
        case .currentTimeZone:
            let zone = g_time_zone_new_local()!
            reply(call, [.string(String(cString: g_time_zone_get_identifier(zone)))])
            g_time_zone_unref(zone)
        case .utcOffset:
            utcOffset(call)
        case .alert, .confirm, .chooseAction, .prompt:
            guard let window else { return fail(call, "there is no window to ask the user in") }
            questions.append(GTKQuestion(call, window: window))
            if questions.count == 1 { questions[0].show() }
        case .announce:
            if let window {
                gtk_accessible_announce(
                    window.widget.opaque, call.arguments.first?.string ?? "", GTK_ACCESSIBLE_ANNOUNCEMENT_PRIORITY_MEDIUM)
            }
            reply(call, [])
        case .hideOnScreenKeyboard:
            // A desktop's keyboard is its own; no field brings one up to take down.
            reply(call, [.bool(false)])
        case .focus, .unfocus:
            focus(call, in: tree)
        case .persistValue:
            GTKKeptValues.keep(call, core: core, applicationID: applicationID)
            reply(call, [])
        case .handlerFailed:
            GTKLog.error("a handler failed: \(call.arguments.first?.string ?? "")")
            reply(call, [])
        default:
            fail(call, "the GTK host does not perform the act '\(call.act.name)'")
        }
    }

    /// The question under `ticket` was answered by the response `id`; the next question shows.
    func respond(_ ticket: Int64, _ id: String) {
        guard let index = questions.firstIndex(where: { $0.ticket == ticket }) else { return }
        let question = questions.remove(at: index)
        let call = question.call
        let (accepted, words) = question.answer(id)

        switch call.act {
        case .confirm: reply(call, [.bool(accepted)])
        case .chooseAction, .prompt: reply(call, [(accepted ? words : nil).propValue])
        default: reply(call, [])
        }
        if index == 0, let next = questions.first { next.show() }
    }

    /// The local time of day: hour, minute, second, millisecond.
    private func currentTime() -> [Double] {
        let now = g_date_time_new_now_local()!
        defer { g_date_time_unref(now) }
        return [
            Double(g_date_time_get_hour(now)), Double(g_date_time_get_minute(now)),
            Double(g_date_time_get_second(now)), Double(g_date_time_get_microsecond(now) / 1000),
        ]
    }

    /// How far a zone is from UTC on a day, in minutes, taken at the day's noon; a zone GLib does not know fails the
    /// act.
    private func utcOffset(_ call: HostActCall) {
        let name = call.arguments.value(0)?.string
        guard let zone = name.map({ g_time_zone_new_identifier($0) }) ?? g_time_zone_new_local() else {
            return fail(call, "no time zone '\(name ?? "")' is known")
        }
        defer { g_time_zone_unref(zone) }

        let today = g_date_time_new_now(zone)!
        let day = call.arguments.value(1).flatMap { CalendarDate(propValue: $0) }
        let noon = g_date_time_new(
            zone, Int32(day?.year ?? Int(g_date_time_get_year(today))),
            Int32(day?.month ?? Int(g_date_time_get_month(today))),
            Int32(day?.day ?? Int(g_date_time_get_day_of_month(today))), 12, 0, 0)
        g_date_time_unref(today)
        guard let noon else { return fail(call, "no such day") }
        defer { g_date_time_unref(noon) }

        reply(call, [.number(Double(g_date_time_get_utc_offset(noon) / 60_000_000))])
    }

    /// Puts the focus on the view the act names - or the first control in it that takes it - or takes it off;
    /// `focus` answers whether the view took it.
    private func focus(_ call: HostActCall, in tree: MountedTree) {
        guard let view = aimed(call, in: tree) else { return }

        if call.act == .focus {
            reply(call, [.bool(gtk_widget_grab_focus(view.widget) != 0)])
            return
        }
        if let root = gtk_widget_get_root(view.widget), let focus = gtk_root_get_focus(root),
           focus == view.widget || gtk_widget_is_ancestor(focus, view.widget) != 0 {
            gtk_root_set_focus(root, nil)
        }
        reply(call, [])
    }

    /// The view the act is aimed at, which its first argument names; nil, the act failed, where there is none.
    private func aimed(_ call: HostActCall, in tree: MountedTree) -> GTKView? {
        let target: ElementId? = switch call.arguments.first {
        case .string(let name)?: .manual(name)
        case .number(let number)?: .auto(Int(number))
        default: nil
        }
        guard let target else {
            fail(call, "\(call.act.name) has to say which view it is for")
            return nil
        }
        guard let view = (tree.root?.first(id: target)?.native as? GTKElement)?.view else {
            fail(call, "there is no view \(target) on screen")
            return nil
        }
        return view
    }

    private func reply(_ call: HostActCall, _ values: [HostValue]) {
        if let completion = call.completion { _ = core.reply(completion, with: values) }
    }

    /// Fails an act: a caller waiting on it throws the reason, and one nobody waits for is logged.
    private func fail(_ call: HostActCall, _ reason: String) {
        if let completion = call.completion {
            _ = core.fail(completion, reason: reason)
        } else {
            GTKLog.error(reason)
        }
    }
}
