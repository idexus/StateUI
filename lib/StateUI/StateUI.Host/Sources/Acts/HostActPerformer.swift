// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Performs the acts the application calls on the host, and answers each - a reply with its values, or a failure
/// with the reason - so a caller never waits on an act nobody performs: the same on every host, the toolkit's part
/// its own (`ActToolkit`, `FileToolkit`). A question for the user and a file dialog answer when the user does, one
/// showing at a time; an act of the application's own is its registered performer's.
///
/// THE FOCUS IS THE PLATFORM'S: `focus` answers whether the view took it - false is an answer, not a failure: a
/// view disabled, off screen or with nothing to type into refuses it.
/// Design: docs/design/host/runtime.md#acts
@_spi(Host) @MainActor public final class HostActPerformer {
    private let toolkit: any ActToolkit
    private let files: (any FileToolkit)?
    private let answers: any ActAnswering
    private let tree: () -> MountedTree?
    private let answered: () -> Void

    /// What the user is asked, one showing at a time; each answers under its ticket.
    private let questions = QuestionQueue<(call: HostActCall, asked: Asked)>()

    /// What the user is asked: a question, or a dialog for files.
    private enum Asked {
        case question(HostQuestion)
        case files(HostFileDialog)
    }

    /// A performer for the acts called on the host whose toolkit `toolkit` is - `files` its toolkit for files, where
    /// it has one - its answers through `answers`, its aimed acts found in `tree`; `answered` runs after the user
    /// answered, as the caller's work then waits for its turn.
    public init(
        toolkit: any ActToolkit, files: (any FileToolkit)? = nil, answers: any ActAnswering = CoreLink(),
        tree: @escaping () -> MountedTree?, answered: @escaping () -> Void = {}
    ) {
        self.toolkit = toolkit
        self.files = files
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
            guard let question = HostQuestion(call) else { return fail(call, "the act asks nothing") }
            ask(call, .question(question))
        case .openFiles, .saveFile, .readFile, .launchFile, .launchLink:
            guard let files else { return fail(call, notPerformed(call)) }
            perform(call, files: files)
        case .announce:
            toolkit.announce(call.arguments.first?.string ?? "")
            reply(call, [])
        case .useColorScheme:
            let theme = call.arguments.first.flatMap(ColorScheme.init(propValue:)) ?? .system
            toolkit.useColorScheme(theme)
            CoreLink().holdColorScheme(theme)
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
            fail(call, notPerformed(call))
        }
    }

    /// Why `call` fails on a host that does not perform its act.
    private func notPerformed(_ call: HostActCall) -> String {
        "the \(toolkit.host) host does not perform the act '\(call.act.name)'"
    }

    // MARK: - Questions for the user

    /// Asks the user; the answer comes back when they give it.
    private func ask(_ call: HostActCall, _ asked: Asked) {
        let (ticket, showsNow) = questions.ask((call, asked))
        if showsNow { show(ticket, call: call, asked: asked) }
    }

    /// Puts a question or a file dialog to the user; with no window to ask in by its turn it fails, and the next
    /// takes its turn.
    /// Design: docs/design/host/runtime.md#questions-for-the-user
    private func show(_ ticket: Int64, call: HostActCall, asked: Asked) {
        let shown = switch asked {
        case .question(let question):
            toolkit.show(question) { [weak self] accepted, words in
                self?.answer(ticket, .success(question.answer(accepted: accepted, words: words)))
            }
        case .files(let dialog):
            files?.show(dialog) { [weak self] chosen in self?.answer(ticket, chosen.map(dialog.answer)) } ?? false
        }
        guard !shown else { return }
        fail(call, "there is no window to ask the user in")
        if questions.answered(ticket)?.next != nil { showFirst() }
    }

    /// Shows what is now first in line.
    private func showFirst() {
        guard let (ticket, first) = questions.first else { return }
        show(ticket, call: first.call, asked: first.asked)
    }

    /// What was asked under `ticket` was answered: its caller hears the answer, and the next shows.
    private func answer(_ ticket: Int64, _ answer: Result<[HostValue], ActFailure>) {
        guard let (asked, next) = questions.answered(ticket) else { return }
        deliver(asked.call, answer)
        if next != nil { showFirst() }
        answered()
    }

    /// The toolkit answered `call` after it was performed: its caller hears the answer, and its work takes its turn.
    private func heard(_ call: HostActCall, _ answer: Result<[HostValue], ActFailure>) {
        deliver(call, answer)
        answered()
    }

    private func deliver(_ call: HostActCall, _ answer: Result<[HostValue], ActFailure>) {
        switch answer {
        case .success(let values): reply(call, values)
        case .failure(let failure): fail(call, failure.reason)
        }
    }

    // MARK: - Files and launches

    /// A file dialog waits its turn among the questions; a file is read, and a file or an address launched, at once.
    /// Design: docs/design/host/runtime.md#files
    private func perform(_ call: HostActCall, files: any FileToolkit) {
        if let dialog = HostFileDialog(call) { return ask(call, .files(dialog)) }
        let file = call.arguments.value(0).flatMap(ChosenFile.init(propValue:))
        let launched: (Bool) -> Void = { [weak self] took in self?.heard(call, .success([.bool(took)])) }
        switch call.act {
        case .readFile:
            guard let file else { return fail(call, "the act names no file") }
            let maximum = call.arguments.value(1)?.number.map { Int(min(max($0, 0), 0x1p52)) }
            files.read(file, atMost: maximum) { [weak self] read in self?.heard(call, read.map { [$0.propValue] }) }
        case .launchFile:
            guard let file else { return fail(call, "the act names no file") }
            files.launch(file, answered: launched)
        default:
            files.launch(address: call.arguments.value(0)?.string ?? "", answered: launched)
        }
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
