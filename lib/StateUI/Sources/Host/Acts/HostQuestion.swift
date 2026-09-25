// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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

    /// The caption of the button accepting it: "OK" where the act says none.
    public let accept: String

    /// The caption of the button cancelling it: "Cancel" where a confirmation or a prompt says none; a choice's
    /// only where it says one.
    public let cancel: String?

    /// A choice's dangerous action.
    public let destruction: String?

    /// The other actions a choice offers.
    public let choices: [String]

    /// A prompt's placeholder.
    public let placeholder: String?

    /// The most characters a prompt takes; nil for no bound.
    public let maximumLength: Int?

    /// What a prompt's words are for.
    public let purpose: InputPurpose

    /// The words a prompt starts with.
    public let words: String

    /// The question `call` asks; nil for an act that is no question.
    public init?(_ call: HostActCall) {
        let arguments = call.arguments
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
            cancel = text(1)
            destruction = text(2)
            choices = arguments.count > 3 ? [String](propValue: arguments[3]) ?? [] : []
        } else {
            message = text(1)
            accept = text(2) ?? "OK"
            cancel = kind == .alert ? nil : text(3) ?? "Cancel"
            destruction = nil
            choices = []
        }
        placeholder = kind == .prompt ? text(4) : nil
        maximumLength = kind == .prompt && arguments.count > 5 ? arguments[5].number.map(Int.init).flatMap { $0 > 0 ? $0 : nil } : nil
        purpose = kind == .prompt && arguments.count > 6 ? InputPurpose(propValue: arguments[6]) ?? .default : .default
        words = kind == .prompt ? text(7) ?? "" : ""
    }

    /// The act's answer: a confirmation's yes or no; a choice's action or a prompt's words where the user accepted,
    /// nothing where not; an alert's nothing.
    public func answer(accepted: Bool, words: String?) -> [HostValue] {
        switch kind {
        case .alert: []
        case .confirm: [.bool(accepted)]
        case .chooseAction, .prompt: [(accepted ? words : nil).propValue]
        }
    }
}

/// Questions for the user, one at a time: each under a ticket of its own across the process - so an answer after
/// its runtime has gone answers nothing of another's - the first asked showing, the next once it is answered.
@_spi(Host) @MainActor public final class QuestionQueue<Question> {
    private var waiting: [(ticket: Int64, question: Question)] = []
    private static var nextTicket: Int64 { get { QuestionTickets.next } set { QuestionTickets.next = newValue } }

    /// No question waiting.
    public init() {}

    /// Asks `question`: its ticket, and whether it shows now - none before it waits.
    public func ask(_ question: Question) -> (ticket: Int64, showsNow: Bool) {
        let ticket = Self.nextTicket
        Self.nextTicket += 1
        waiting.append((ticket, question))
        return (ticket, waiting.count == 1)
    }

    /// The question under `ticket` was answered: it, and the next question to show now; nil where none waits under
    /// that ticket.
    public func answered(_ ticket: Int64) -> (question: Question, next: Question?)? {
        guard let index = waiting.firstIndex(where: { $0.ticket == ticket }) else { return nil }
        let question = waiting.remove(at: index).question
        return (question, index == 0 ? waiting.first?.question : nil)
    }
}

/// The next ticket of every question in the process.
@MainActor
private enum QuestionTickets {
    static var next: Int64 = 1
}
