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

    /// What the dialogs ask, one showing at a time; each answers under its ticket.
    private let questions = QuestionQueue<GTKQuestion>()

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
            guard let window, let question = HostQuestion(call) else {
                return fail(call, "there is no window to ask the user in")
            }
            let asked = GTKQuestion(call, question, window: window)
            let (ticket, showsNow) = questions.ask(asked)
            asked.ticket = ticket
            if showsNow { asked.show() }
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
            perform(registered: call, in: tree)
        }
    }

    /// Performs an act the application registered: its own, or one aimed at its own element, handed that
    /// element's control; an act nobody registered is refused by name.
    private func perform(registered call: HostActCall, in tree: MountedTree) {
        guard let performer = GTKInterop.performers[call.act] else {
            return fail(call, "the GTK host does not perform the act '\(call.act.name)'")
        }

        var view: GTKView?
        if case .aimed = performer {
            view = aimed(call, in: tree)
            guard view != nil else { return }
        }
        // A performer may await; the call is answered once it returns.
        Task { @MainActor in
            do {
                switch performer {
                case .application(let perform): reply(call, try await perform(call.arguments))
                case .aimed(let perform): reply(call, try await perform(view!, Array(call.arguments.dropFirst())))
                }
            } catch {
                fail(call, "\(error)")
            }
        }
    }

    /// The question under `ticket` was answered by the response `id`; the next question shows.
    func respond(_ ticket: Int64, _ id: String) {
        guard let (asked, next) = questions.answered(ticket) else { return }
        let (accepted, words) = asked.answer(id)
        reply(asked.call, asked.question.answer(accepted: accepted, words: words))
        next?.show()
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

    /// The view the act is aimed at (`MountedTree.aimed`); nil, the act failed, where there is none.
    private func aimed(_ call: HostActCall, in tree: MountedTree) -> GTKView? {
        do {
            let element = try tree.aimed(call)
            if let view = (element.native as? GTKElement)?.view { return view }
            fail(call, "\(element.id) has no view")
        } catch {
            fail(call, error.reason)
        }
        return nil
    }

    private func reply(_ call: HostActCall, _ values: [HostValue]) {
        core.reply(call, values)
    }

    private func fail(_ call: HostActCall, _ reason: String) {
        core.fail(call, reason, log: { GTKLog.error($0) })
    }
}
