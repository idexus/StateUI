// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One question for the user - an alert, a confirmation, a choice of actions, a prompt - as every host reads the act
/// that asks it, and the answer it gives.
/// Design: docs/design/host/runtime.md#questions-for-the-user
@_spi(Host) public struct HostQuestion: Equatable, Sendable {
    /// What the question is.
    public enum Kind: Equatable, Sendable {
        /// Something said, answered by one button.
        case alert
        /// Yes or no.
        case confirm
        /// One of the actions offered, or none.
        case chooseAction
        /// Words the user types.
        case prompt
    }

    /// What the question is.
    public let kind: Kind

    /// Its title.
    public let title: String?

    /// Its message; a choice has none.
    public let message: String?

    /// The caption of the button accepting it: "OK" where the act says none; a choice has none.
    public let accept: String

    /// The caption of the button cancelling it, which every question but an alert offers: "Cancel" where the act
    /// says none; nil for an alert.
    public let cancel: String?

    /// The caption of the button cancelling a confirmation, a choice or a prompt, which always offer one: `cancel`.
    public var cancelling: String { cancel ?? Self.cancelWord }

    /// The cancelling caption of a question whose act names none - the core sends the library's own words in the
    /// system's language, so this stands only for an act that came without them.
    private static let cancelWord = "Cancel"

    /// The actions a choice offers, in order.
    public let choices: [String]

    /// The place of a choice's dangerous action among `choices`; nil for none.
    public let destructive: Int?

    /// A prompt's placeholder.
    public let placeholder: String?

    /// The most characters a prompt takes; nil for no bound.
    public let maximumLength: Int?

    /// What a prompt's words are for.
    public let purpose: InputPurpose

    /// How a prompt's field takes what is typed: as a field of its purpose, its spelling checked and its words
    /// predicted.
    public var traits: InputTraits { InputTraits(spellChecked: true, predicted: true, purpose: purpose) }

    /// The words a prompt starts with.
    public let words: String

    /// The question `call` asks; nil for an act that is no question.
    public init?(_ call: HostActCall) {
        let arguments = AskedWindow.arguments(of: call)
        func text(_ index: Int) -> String? { index < arguments.count ? arguments[index].string : nil }
        switch call.act {
        case .alert: kind = .alert
        case .confirm: kind = .confirm
        case .chooseAction: kind = .chooseAction
        case .prompt: kind = .prompt
        default: return nil
        }
        title = text(0)
        if kind == .chooseAction {
            message = nil
            accept = "OK"
            let offered = arguments.count > 1 ? [String](propValue: arguments[1]) ?? [] : []
            let dangerous = arguments.count > 2 ? arguments[2].number.map(Int.init) : nil
            choices = offered
            destructive = dangerous.flatMap { offered.indices.contains($0) ? $0 : nil }
            cancel = text(3) ?? Self.cancelWord
        } else {
            message = text(1)
            accept = text(2) ?? "OK"
            cancel = kind == .alert ? nil : text(3) ?? Self.cancelWord
            choices = []
            destructive = nil
        }
        placeholder = kind == .prompt ? text(4) : nil
        maximumLength = kind == .prompt && arguments.count > 5 ? arguments[5].number.map(Int.init).flatMap { $0 > 0 ? $0 : nil } : nil
        purpose = kind == .prompt && arguments.count > 6 ? InputPurpose(propValue: arguments[6]) ?? .default : .default
        words = kind == .prompt ? text(7) ?? "" : ""
    }

    /// The question's buttons, each its caption and what pressing it answers: an alert's one; a confirmation's and
    /// a prompt's accepting one, then the cancel; a choice's actions in order, then the cancel.
    /// Design: docs/design/host/runtime.md#questions-for-the-user
    public var buttons: [(caption: String, role: QuestionButton)] {
        switch kind {
        case .alert: [(accept, .accept)]
        case .confirm, .prompt: [(accept, .accept), (cancelling, .cancel)]
        case .chooseAction: choices.enumerated().map { ($1, .action($0)) } + [(cancelling, .cancel)]
        }
    }

    /// What the user gave the question: whether they accepted it, the words they typed, and the place of the
    /// action they chose.
    public struct Given: Equatable, Sendable {
        /// Whether they accepted it: pressed its accepting button, or chose an action.
        public let accepted: Bool

        /// The words they typed; nil for none.
        public let words: String?

        /// The place of the action they chose among a choice's; nil for none.
        public let chosen: Int?

        /// The user accepted where `accepted`, typing `words`.
        public init(accepted: Bool, words: String? = nil) {
            self.accepted = accepted
            self.words = words
            chosen = nil
        }

        /// The user chose the action at `place` among a choice's.
        public init(chosen place: Int) {
            accepted = true
            words = nil
            chosen = place
        }

        /// The user pressed `button`, a prompt's field holding `words`.
        public init(pressed button: QuestionButton, typing words: String? = nil) {
            switch button {
            case .accept: self.init(accepted: true, words: words)
            case .cancel: self.init(accepted: false)
            case .action(let place): self.init(chosen: place)
            }
        }

        /// The user cancelled or dismissed the question.
        public static let dismissed = Given(accepted: false)
    }

    /// The act's answer: a confirmation's yes or no; a choice's place - of an action it offers - or a prompt's words,
    /// cut to its bound, where the user accepted, nothing where not; an alert's nothing.
    public func answer(_ given: Given) -> [HostValue] {
        switch kind {
        case .alert: []
        case .confirm: [.bool(given.accepted)]
        case .chooseAction:
            [(given.accepted ? given.chosen.flatMap { choices.indices.contains($0) ? $0 : nil } : nil).propValue]
        case .prompt:
            [(given.accepted ? given.words.map { InputWords.cut($0, toBound: maximumLength) ?? $0 } : nil).propValue]
        }
    }
}

/// Questions for the user, one at a time: each under a ticket of its own across the process - so an answer after
/// its runtime has gone answers nothing of another's - the first asked showing, the next once it is answered.
@_spi(Host) @MainActor public final class QuestionQueue<Question> {
    private var waiting: [(ticket: Int64, question: Question)] = []

    /// No question waiting.
    public init() {}

    /// Asks `question`: its ticket, and whether it shows now - none before it waits.
    public func ask(_ question: Question) -> (ticket: Int64, showsNow: Bool) {
        let ticket = HostNumbers.next()
        waiting.append((ticket, question))
        return (ticket, waiting.count == 1)
    }

    /// The question showing now - the first waiting - with its ticket; nil where none waits.
    public var first: (ticket: Int64, question: Question)? {
        waiting.first
    }

    /// The ticket of the first question waiting that `matches` picks; nil where none does.
    public func ticket(where matches: (Question) -> Bool) -> Int64? {
        waiting.first { matches($0.question) }?.ticket
    }

    /// The question under `ticket` was answered: it, and the next question to show now; nil where none waits under
    /// that ticket.
    public func answered(_ ticket: Int64) -> (question: Question, next: Question?)? {
        guard let index = waiting.firstIndex(where: { $0.ticket == ticket }) else { return nil }
        let question = waiting.remove(at: index).question
        return (question, index == 0 ? waiting.first?.question : nil)
    }
}
