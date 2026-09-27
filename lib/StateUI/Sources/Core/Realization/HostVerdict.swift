// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host's run of its tests said of one member of one element, or of the element itself: the mark the
/// control dictionary shows for it, and why it is empty where it is. A run writes one a line.
/// Design: docs/design/contracts/dictionary.md#marks
@_spi(Host) public struct HostVerdict: Hashable, Sendable, CustomStringConvertible {
    /// What the run said.
    public enum Mark: Hashable, Sendable {
        /// ✅: a passing case proved it.
        case proven
        /// ☑️: a passing case proved it, while the host records what is missing.
        case partial(missing: String)
        /// –: the host's family never has it, and meets the contract there; why.
        case notPlanned(reason: String)
        /// Empty: the host does not realize it yet.
        case notRealized
        /// Empty: the host's driver cannot do or read what the case needs; what, and why.
        case cannot(String)
        /// Empty: the host realizes it, and its case waits on another member the host does not realize yet; which.
        case waiting(on: String)
        /// ❌: a case proving it failed on the host; what was expected and what came.
        case failed(String)
        /// ◐: some of its cases proved it, another could not run or read; why not.
        case partly(String)
    }

    /// The element.
    public let element: String

    /// The member; nil for the element itself - made by the host, which the creation table marks.
    public let member: String?

    /// What the run said of it.
    public let mark: Mark

    /// `member` of `element` - or `element` itself where `member` is nil - marked `mark`.
    public init(element: String, member: String?, mark: Mark) {
        self.element = element
        self.member = member
        self.mark = mark
    }

    /// What the verdict is about: "Button.clicked", or "Button" for the element itself.
    public var subject: String {
        member.map { "\(element).\($0)" } ?? element
    }

    /// The verdict as a run writes it: "Button.clicked: ✅".
    public var description: String {
        switch mark {
        case .proven: "\(subject): ✅"
        case .partial(let missing): "\(subject): ☑️ \(missing)"
        case .notPlanned(let reason): "\(subject): – \(reason)"
        case .notRealized: "\(subject): not realized"
        case .cannot(let why): "\(subject): cannot \(why)"
        case .waiting(let gap): "\(subject): waits on \(gap)"
        case .failed(let message): "\(subject): ❌ \(message)"
        case .partly(let why): "\(subject): ◐ \(why)"
        }
    }

    /// The verdict a line says; nil for a line that says none.
    public init?(line: String) {
        guard let colon = line.indices.first(where: { line[$0...].hasPrefix(": ") }) else { return nil }
        let subject = line[..<colon]
        let said = String(line[line.index(colon, offsetBy: 2)...])
        let parts = subject.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber } }) else {
            return nil
        }

        func text(after sign: String) -> String? {
            said.hasPrefix(sign + " ") ? String(said.dropFirst(sign.count + 1)) : nil
        }
        let mark: Mark
        if said == "✅" {
            mark = .proven
        } else if let missing = text(after: "☑️"), !missing.isEmpty {
            mark = .partial(missing: missing)
        } else if let reason = text(after: "–"), !reason.isEmpty {
            mark = .notPlanned(reason: reason)
        } else if said == "not realized" {
            mark = .notRealized
        } else if let why = text(after: "cannot"), !why.isEmpty {
            mark = .cannot(why)
        } else if let gap = text(after: "waits on"), !gap.isEmpty {
            mark = .waiting(on: gap)
        } else if let message = text(after: "❌"), !message.isEmpty {
            mark = .failed(message)
        } else if let why = text(after: "◐"), !why.isEmpty {
            mark = .partly(why)
        } else {
            return nil
        }
        self.init(element: String(parts[0]), member: parts.count == 2 ? String(parts[1]) : nil, mark: mark)
    }

    /// Whether the dictionary counts the verdict as met: proven whole, or never on the host's family.
    public var meets: Bool {
        switch mark {
        case .proven, .notPlanned: true
        case .partial, .notRealized, .cannot, .waiting, .failed, .partly: false
        }
    }

    /// Whether a case proving the subject passed: proved whole or in part, or never had by the host's family.
    private var passed: Bool {
        switch mark {
        case .proven, .partial, .notPlanned: true
        case .notRealized, .cannot, .waiting, .failed, .partly: false
        }
    }

    /// What the verdict says after the subject: the reason a case did not prove it.
    private var said: String {
        String(description.dropFirst(subject.count + 2))
    }

    /// The worst of two verdicts on one subject: a failure over everything; a proof beside a case that did not
    /// prove it, partly proven; a proof in part over one whole; the host realizing nothing below any word of a case.
    /// Design: docs/design/contracts/dictionary.md#marks
    static func worse(_ one: HostVerdict, _ other: HostVerdict) -> HostVerdict {
        let (first, second) = one.description <= other.description ? (one, other) : (other, one)
        switch (first.mark, second.mark) {
        case (.failed, _): return first
        case (_, .failed): return second
        case (.notRealized, _): return second
        case (_, .notRealized): return first
        case (.partly, _): return first
        case (_, .partly): return second
        default: break
        }
        switch (first.passed, second.passed) {
        case (true, true):
            if case .partial = first.mark { return first }
            if case .partial = second.mark { return second }
            if case .proven = second.mark { return second }
            return first
        case (true, false): return HostVerdict(element: first.element, member: first.member, mark: .partly(second.said))
        case (false, true): return HostVerdict(element: first.element, member: first.member, mark: .partly(first.said))
        case (false, false): return first
        }
    }

    /// One verdict a subject, the worst its cases gave, in the order a run writes them.
    public static func merged(_ verdicts: some Sequence<HostVerdict>) -> [HostVerdict] {
        var chosen: [String: HostVerdict] = [:]
        for verdict in verdicts {
            chosen[verdict.subject] = chosen[verdict.subject].map { worse($0, verdict) } ?? verdict
        }
        return chosen.values.sorted { $0.subject < $1.subject }
    }

    /// The line over a run's verdicts naming the inputs the run was made of.
    static let inputsLine = "# inputs "

    /// The text a run writes: the inputs it was made of where they are known, then one verdict a subject, a line
    /// each, sorted.
    public static func text(_ verdicts: some Sequence<HostVerdict>, inputs: String? = nil) -> String {
        let lines = merged(verdicts).map(\.description)
        return ((inputs.map { [inputsLine + $0] } ?? []) + lines).joined(separator: "\n") + "\n"
    }

    /// A run's text without the line naming its inputs: what two runs of other sources compare by.
    public static func withoutInputs(_ text: String) -> String {
        guard text.hasPrefix(inputsLine), let end = text.firstIndex(of: "\n") else {
            return text.hasPrefix(inputsLine) ? "" : text
        }
        return String(text[text.index(after: end)...])
    }

    /// The inputs a run's text says it was made of; nil where it says none.
    public static func inputs(of text: String) -> String? {
        guard let first = text.split(separator: "\n").first, first.hasPrefix(inputsLine) else { return nil }
        var inputs = String(first.dropFirst(inputsLine.count))
        if inputs.hasSuffix("\r") { inputs.removeLast() }
        return inputs.isEmpty ? nil : inputs
    }

    /// The verdicts a run's text holds; nil where a line says none.
    public static func read(_ text: String) -> [HostVerdict]? {
        var verdicts: [HostVerdict] = []
        for (index, line) in text.split(separator: "\n").enumerated() {
            let line = line.hasSuffix("\r") ? String(line.dropLast()) : String(line)
            if index == 0, line.hasPrefix(inputsLine) { continue }
            guard let verdict = HostVerdict(line: line) else { return nil }
            verdicts.append(verdict)
        }
        return verdicts
    }
}
