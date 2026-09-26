// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// Performs the acts the application calls on the host, and answers each - a reply with its values, or a failure
/// with the reason - so a caller never waits on an act nobody performs. A question for the user answers when the
/// user does: its call waits under a ticket the dialog hands back.
/// Design: docs/design/platforms/winui/runtime.md#acts
@MainActor
final class WinUIActPerformer {
    private let core: CoreLink

    /// What is kept of the scenes for the next start.
    private let scenes: SceneKeeper

    /// What the dialogs ask, one showing at a time; each answers under its ticket.
    private let questions = QuestionQueue<Asked>()

    /// A question the application asked, the window it is asked in, and the ticket its answer comes back under.
    private final class Asked {
        let call: HostActCall
        let question: HostQuestion
        weak var window: WinUIWindow?
        var ticket: Int64 = 0

        init(call: HostActCall, question: HostQuestion, window: WinUIWindow) {
            self.call = call
            self.question = question
            self.window = window
        }
    }

    init(core: CoreLink, scenes: SceneKeeper) {
        self.core = core
        self.scenes = scenes
    }

    /// Performs one act, and answers it; `window` is where a word to a screen reader and the keyboard stand.
    func perform(_ call: HostActCall, in tree: MountedTree, window: WinUIWindow?) {
        switch call.act {
        case .currentTime:
            var time: [Int32] = [0, 0, 0, 0]
            stateui_winui_clock(&time)
            reply(call, HostActs.currentTime(
                hour: Int(time[0]), minute: Int(time[1]), second: Int(time[2]), millisecond: Int(time[3])))
        case .currentTimeZone:
            reply(call, [.string(WinUIStrings.read { stateui_winui_time_zone($0, $1) })])
        case .utcOffset:
            utcOffset(call)
        case .alert, .confirm, .chooseAction, .prompt:
            guard let window, window.content != nil, let question = HostQuestion(call) else {
                return fail(call, "there is no window to ask the user in")
            }
            let asked = Asked(call: call, question: question, window: window)
            let (ticket, showsNow) = questions.ask(asked)
            asked.ticket = ticket
            if showsNow { show(asked) }
        case .announce:
            if let content = window?.content { stateui_winui_announce(content.handle, call.arguments.first?.string ?? "") }
            reply(call, [])
        case .hideOnScreenKeyboard:
            reply(call, [.bool(window?.content.map { stateui_winui_hide_keyboard($0.handle) } ?? false)])
        case .focus, .unfocus:
            focus(call, in: tree)
        case .persistValue:
            WinUIPersistence.keep(call, core: core)
            reply(call, [])
        case .persistSceneValue:
            if scenes.keep(call.arguments), let text = scenes.changed(root: tree.root) {
                WinUIPersistence.writeScenes(text)
            }
            reply(call, [])
        case .handlerFailed:
            WinUIRenderer.log.error("a handler failed: \(call.arguments.first?.string ?? "")")
            reply(call, [])
        default:
            // An act the application registered: its own, or one aimed at its own element.
            guard !WinUIInterop.acts.perform(
                call, in: tree, core: core, view: { ($0.native as? WinUIElement)?.view },
                log: { WinUIRenderer.log.error($0) })
            else { return }
            fail(call, "the WinUI host does not perform the act '\(call.act.name)'")
        }
    }

    /// The question asked under `ticket` was answered: accepted or not, and the words chosen or typed; the next
    /// question shows.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        guard let (asked, next) = questions.answered(ticket) else { return }
        reply(asked.call, asked.question.answer(accepted: accepted, words: words))
        if let next { show(next) }
    }

    /// Puts a question to the user in WinUI's own dialog; its answer comes back by its ticket. A window gone by its
    /// turn fails it, and the next question takes its turn.
    /// Design: docs/design/platforms/winui/runtime.md#questions-for-the-user
    private func show(_ asked: Asked) {
        guard let content = asked.window?.content else {
            fail(asked.call, "there is no window to ask the user in")
            if let (_, next) = questions.answered(asked.ticket), let next { show(next) }
            return
        }

        // The title, the message, the captions that accept, cancel and destroy, the placeholder, the first words.
        let question = asked.question
        let kind: Int32 = switch question.kind {
        case .alert: 0
        case .confirm: 1
        case .chooseAction: 2
        case .prompt: 3
        }
        let words: [String?] = [
            question.title, question.message, question.accept, question.cancel, question.destruction,
            question.placeholder, question.words,
        ]
        WinUIStrings.withCStrings(words.map { $0 ?? "" } + question.choices) { pointers in
            func at(_ index: Int) -> UnsafePointer<CChar>? { words[index] == nil ? nil : pointers[index] }
            Array(pointers.dropFirst(words.count)).withUnsafeBufferPointer { offered in
                var relayed = StateUIQuestion(
                    kind: kind, title: at(0), message: at(1), accept: at(2), cancel: at(3), destruction: at(4),
                    choices: offered.baseAddress, choiceCount: Int32(question.choices.count), placeholder: at(5),
                    maximumLength: Int32(question.maximumLength ?? 0), purpose: question.purpose.rawValue,
                    initial: at(6))
                stateui_winui_ask(content.handle, asked.ticket, &relayed)
            }
        }
    }

    /// How far a zone is from UTC on a day, in minutes, as ICU says; a zone it does not know fails the act.
    private func utcOffset(_ call: HostActCall) {
        let (zone, day) = HostActs.utcOffsetQuestion(call)
        var minutes: Int32 = 0
        guard stateui_winui_utc_offset(
            zone, Int32(day?.year ?? 0), Int32(day?.month ?? 0), Int32(day?.day ?? 0), &minutes)
        else { return fail(call, HostActs.unknownZone(zone).reason) }

        reply(call, HostActs.utcOffset(minutes: Int(minutes)))
    }

    /// Puts the focus on the view the act names, or takes it off; `focus` answers whether the view took it.
    private func focus(_ call: HostActCall, in tree: MountedTree) {
        guard let view = aimed(call, in: tree) else { return }

        let done = stateui_winui_focus(view.handle, call.act == .focus)
        reply(call, call.act == .focus ? [.bool(done)] : [])
    }

    /// The view the act is aimed at (`MountedTree.aimed`); nil, the act failed, where there is none.
    private func aimed(_ call: HostActCall, in tree: MountedTree) -> WinUIView? {
        do {
            let element = try tree.aimed(call)
            if let view = (element.native as? WinUIElement)?.view { return view }
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
        core.fail(call, reason, log: { WinUIRenderer.log.error($0) })
    }
}
