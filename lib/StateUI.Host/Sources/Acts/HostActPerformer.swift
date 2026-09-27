// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Performs the acts the application calls on the host, and answers each - a reply with its values, or a failure
/// with the reason - so a caller never waits on an act nobody performs: the same on every host, the toolkit's part
/// its own (`ActToolkit`). A question for the user answers when the user does, one showing at a time; an act of the
/// application's own is its registered performer's.
///
/// THE FOCUS IS THE PLATFORM'S: `focus` answers whether the view took it - false is an answer, not a failure: a
/// view disabled, off screen or with nothing to type into refuses it.
/// Design: docs/design/host/runtime.md#acts
@_spi(Host) @MainActor public final class HostActPerformer {
    private let toolkit: any ActToolkit
    private let answers: any ActAnswering
    private let tree: () -> MountedTree?
    private let answered: () -> Void

    /// What the questions ask, one showing at a time; each answers under its ticket.
    private let questions = QuestionQueue<(call: HostActCall, question: HostQuestion)>()

    /// A performer for the acts called on the host whose toolkit `toolkit` is, its answers through `answers`, its
    /// aimed acts found in `tree`; `answered` runs after the user answered a question, as the caller's work then
    /// waits for its turn.
    public init(
        toolkit: any ActToolkit, answers: any ActAnswering = CoreLink(), tree: @escaping () -> MountedTree?,
        answered: @escaping () -> Void = {}
    ) {
        self.toolkit = toolkit
        self.answers = answers
        self.tree = tree
        self.answered = answered
    }

    /// Performs one act, and answers it.
    public func perform(_ call: HostActCall) {
        switch call.act {
        case .currentTime:
            let now = toolkit.localTime()
            reply(call, HostActs.currentTime(
                hour: now.hour, minute: now.minute, second: now.second, millisecond: now.millisecond))
        case .currentTimeZone:
            reply(call, [.string(toolkit.localZone())])
        case .utcOffset:
            let (zone, day) = HostActs.utcOffsetQuestion(call)
            guard let minutes = toolkit.utcOffset(of: zone, on: day) else {
                return fail(call, HostActs.unknownZone(zone).reason)
            }
            reply(call, HostActs.utcOffset(minutes: minutes))
        case .alert, .confirm, .chooseAction, .prompt:
            ask(call)
        case .announce:
            toolkit.announce(call.arguments.first?.string ?? "")
            reply(call, [])
        case .hideOnScreenKeyboard:
            reply(call, [.bool(toolkit.hideOnScreenKeyboard())])
        case .focus, .unfocus:
            aim(call)
        case .handlerFailed:
            toolkit.log("a handler failed: \(call.arguments.first?.string ?? "")")
            reply(call, [])
        default:
            if [.persistValue, .persistSceneValue].contains(call.act), toolkit.keep(call) { return reply(call, []) }
            guard !toolkit.performOwn(call), !toolkit.performRegistered(call) else { return }
            fail(call, "the \(toolkit.host) host does not perform the act '\(call.act.name)'")
        }
    }

    // MARK: - Questions for the user

    /// Asks the user; the answer comes back when they give it.
    private func ask(_ call: HostActCall) {
        guard let question = HostQuestion(call) else { return fail(call, "the act asks nothing") }
        let (ticket, showsNow) = questions.ask((call, question))
        if showsNow { show(ticket, call: call, question: question) }
    }

    /// Puts a question to the user; with no window to ask in by its turn it fails, and the next takes its turn.
    /// Design: docs/design/host/runtime.md#questions-for-the-user
    private func show(_ ticket: Int64, call: HostActCall, question: HostQuestion) {
        let shown = toolkit.show(question) { [weak self] accepted, words in
            self?.answer(ticket, accepted: accepted, words: words)
        }
        guard !shown else { return }
        fail(call, "there is no window to ask the user in")
        if questions.answered(ticket)?.next != nil { showFirst() }
    }

    /// Shows the question now first in line.
    private func showFirst() {
        guard let (ticket, asked) = questions.first else { return }
        show(ticket, call: asked.call, question: asked.question)
    }

    /// The question under `ticket` was answered: its caller hears the answer, and the next question shows.
    private func answer(_ ticket: Int64, accepted: Bool, words: String?) {
        guard let (asked, next) = questions.answered(ticket) else { return }
        reply(asked.call, asked.question.answer(accepted: accepted, words: words))
        if next != nil { showFirst() }
        answered()
    }

    // MARK: - The focus

    /// Puts the focus on the view the act names, or takes it off (`MountedTree.aimed`).
    private func aim(_ call: HostActCall) {
        guard let tree = tree() else { return fail(call, "no tree is shown") }
        let element: MountedElement
        do {
            element = try tree.aimed(call)
        } catch {
            return fail(call, error.reason)
        }
        if call.act == .unfocus {
            guard toolkit.unfocus(element) else { return fail(call, "\(element.id) has no view") }
            return reply(call, [])
        }
        guard let took = toolkit.focus(element) else { return fail(call, "\(element.id) has no view") }
        reply(call, [.bool(took)])
    }

    private func reply(_ call: HostActCall, _ values: [HostValue]) {
        answers.reply(call, values)
    }

    private func fail(_ call: HostActCall, _ reason: String) {
        answers.fail(call, reason, log: { [toolkit] in toolkit.log($0) })
    }
}
