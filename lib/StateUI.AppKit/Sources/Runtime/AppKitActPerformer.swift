// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Performs the acts the application calls on the host, and answers each - a reply with its values, or a failure
/// with the reason - so a caller never waits on an act nobody performs. A question for the user answers when the
/// user does; an act of the application's own is its registered performer's (`InteropActs`).
///
/// THE FOCUS IS THE PLATFORM'S: the host asks the window who holds it and never mirrors that identity as state.
/// `focus` answers whether the view took it - false is an answer, not a failure: a view disabled, off screen or
/// with nothing to type into refuses it. `hideOnScreenKeyboard` takes the focus off whatever holds it in the window
/// the user is looking at, answering whether anything did.
/// Design: docs/design/host/runtime.md#acts
@MainActor
final class AppKitActPerformer {
    private let core = CoreLink()
    private unowned let renderer: AppKitRenderer

    /// What the alerts ask, one showing at a time; each answers under its ticket.
    private let questions = QuestionQueue<AppKitQuestion>()

    /// What the host told the screen reader, in order.
    private(set) var announcedForTesting: [String] = []

    /// A performer for the acts `renderer`'s application calls.
    init(renderer: AppKitRenderer) {
        self.renderer = renderer
    }

    /// Performs one act, and answers it.
    func perform(_ call: HostActCall) {
        switch call.act {
        case .currentTime:
            let now = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: Date())
            reply(call, HostActs.currentTime(
                hour: now.hour ?? 0, minute: now.minute ?? 0, second: now.second ?? 0,
                millisecond: (now.nanosecond ?? 0) / 1_000_000))
        case .currentTimeZone:
            reply(call, [.string(TimeZone.current.identifier)])
        case .utcOffset:
            utcOffset(call)
        case .alert, .confirm, .chooseAction, .prompt:
            ask(call)
        case .announce:
            announce(call.arguments.first?.string ?? "")
            reply(call, [])
        case .persistValue:
            renderer.savePersistent(call)
            reply(call, [])
        case .persistSceneValue:
            renderer.keepSceneValue(call)
            reply(call, [])
        case .handlerFailed:
            AppKitRenderer.log.error("a handler failed: \(call.arguments.first?.string ?? "")")
            reply(call, [])
        case .focus, .unfocus:
            aim(call)
        case .hideOnScreenKeyboard:
            reply(call, [.bool(hideKeyboard())])
        default:
            // An act the application registered: its own, or one aimed at its own element.
            guard !AppKitInterop.acts.perform(
                call, in: renderer.runtime.tree, core: core, view: { ($0.native as? AppKitElement)?.view },
                log: { AppKitRenderer.log.error($0) })
            else { return }
            fail(call, "the AppKit host does not perform the act '\(call.act.name)'")
        }
    }

    /// How far a zone is from UTC on a day, in minutes; a zone the system does not know fails the act.
    private func utcOffset(_ call: HostActCall) {
        let (name, day) = HostActs.utcOffsetQuestion(call)
        guard let zone = name.map(TimeZone.init(identifier:)) ?? TimeZone.current else {
            return fail(call, HostActs.unknownZone(name).reason)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let date = day.flatMap {
            calendar.date(from: DateComponents(year: $0.year, month: $0.month, day: $0.day, hour: 12))
        } ?? Date()
        reply(call, HostActs.utcOffset(minutes: zone.secondsFromGMT(for: date) / 60))
    }

    /// Asks the user in the window they are looking at; the answer comes back when they give it.
    private func ask(_ call: HostActCall) {
        guard let window = renderer.userWindow, let question = HostQuestion(call) else {
            return fail(call, "there is no window to ask the user in")
        }
        let asked = AppKitQuestion(call, question, in: window)
        let (ticket, showsNow) = questions.ask(asked)
        asked.ticket = ticket
        if showsNow { show(asked) }
    }

    /// Puts a question to the user; a window gone by its turn fails it, and the next takes its turn.
    /// Design: docs/design/host/runtime.md#questions-for-the-user
    private func show(_ asked: AppKitQuestion) {
        guard asked.window != nil else {
            fail(asked.call, "there is no window to ask the user in")
            if let (_, next) = questions.answered(asked.ticket), let next { show(next) }
            return
        }
        showing = asked
        asked.ask(presenting: renderer.presentsWindows) { [weak self, ticket = asked.ticket] accepted, words in
            self?.answered(ticket, accepted: accepted, words: words)
        }
    }

    /// The question under `ticket` was answered: its caller hears the answer, and the next question shows.
    private func answered(_ ticket: Int64, accepted: Bool, words: String?) {
        guard let (asked, next) = questions.answered(ticket) else { return }
        reply(asked.call, asked.question.answer(accepted: accepted, words: words))
        showing = nil
        if let next { show(next) }
        renderer.runtime.pump.turn()
    }

    /// The question showing now, where one is.
    private(set) var showing: AppKitQuestion?

    /// Tells the screen reader `words`, now, over whatever it was saying.
    private func announce(_ words: String) {
        announcedForTesting.append(words)
        NSAccessibility.post(
            element: renderer.userWindow ?? NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: words, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Puts the keyboard on the view the act names, or takes it off (`MountedTree.aimed`).
    private func aim(_ call: HostActCall) {
        let view: NSView
        do {
            let element = try renderer.runtime.tree.aimed(call)
            guard let found = (element.native as? AppKitElement)?.view else {
                return fail(call, "\(element.id) has no view")
            }
            view = found
        } catch {
            return fail(call, error.reason)
        }

        if call.act == .unfocus {
            if let window = view.window, AppKitFocus.holds(view, window.firstResponder) {
                window.makeFirstResponder(nil)
            }
            return reply(call, [])
        }
        guard let window = view.window, let focusable = AppKitFocus.focusable(in: view) else {
            return reply(call, [.bool(false)])
        }
        reply(call, [.bool(window.makeFirstResponder(focusable))])
    }

    /// Takes the focus off whatever holds it in the window the user is looking at; whether anything did.
    private func hideKeyboard() -> Bool {
        guard let window = renderer.userWindow,
              let holder = window.firstResponder as? NSView,
              holder !== window.contentView
        else { return false }

        return window.makeFirstResponder(nil)
    }

    private func reply(_ call: HostActCall, _ values: [HostValue]) {
        core.reply(call, values)
    }

    private func fail(_ call: HostActCall, _ reason: String) {
        core.fail(call, reason, log: { AppKitRenderer.log.error($0) })
    }
}

#endif
