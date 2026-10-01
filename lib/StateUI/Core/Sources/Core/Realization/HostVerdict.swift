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
        /// 🔌: its cases passed only through the host's own entry or record - an act handed past the toolkit's
        /// input, a read of what the host keeps rather than what the toolkit holds; which, and why.
        case byHost(String)

        /// 🧩: the host leaves it to the application, which registers its own control for it there.
        case byApplication
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
        case .byHost(let why): "\(subject): 🔌 \(why)"
        case .byApplication: "\(subject): 🧩"
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
        } else if let why = text(after: "🔌"), !why.isEmpty {
            mark = .byHost(why)
        } else if said == "🧩" {
            mark = .byApplication
        } else {
            return nil
        }
        self.init(element: String(parts[0]), member: parts.count == 2 ? String(parts[1]) : nil, mark: mark)
    }

    /// Whether the dictionary counts the verdict as met: proven whole, never on the host's family, or left to the
    /// application's own registration.
    public var meets: Bool {
        switch mark {
        case .proven, .notPlanned, .byApplication: true
        case .partial, .notRealized, .cannot, .waiting, .failed, .partly, .byHost: false
        }
    }

    /// Whether a case proving the subject passed: proved whole or in part, or never had by the host's family.
    private var passed: Bool {
        switch mark {
        case .proven, .partial, .notPlanned, .byHost, .byApplication: true
        case .notRealized, .cannot, .waiting, .failed, .partly: false
        }
    }

    /// What the verdict says after the subject: the reason a case did not prove it.
    private var said: String {
        String(description.dropFirst(subject.count + 2))
    }

    /// The worst of two verdicts on one subject: a failure over everything; a proof beside a case that did not
    /// prove it, partly proven; a proof in part over one whole, and one through the toolkit over one only through
    /// the host's own entry; the host realizing nothing below any word of a case.
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
            // A gap recorded outweighs a proof; a proof through the toolkit outweighs one through the host's own.
            for rank in [Self.isPartial, Self.isProven, Self.isByHost] {
                if rank(first.mark) { return first }
                if rank(second.mark) { return second }
            }
            return first
        case (true, false): return HostVerdict(element: first.element, member: first.member, mark: .partly(second.said))
        case (false, true): return HostVerdict(element: first.element, member: first.member, mark: .partly(first.said))
        case (false, false): return first
        }
    }

    private static func isPartial(_ mark: Mark) -> Bool { if case .partial = mark { true } else { false } }
    private static func isProven(_ mark: Mark) -> Bool { if case .proven = mark { true } else { false } }
    private static func isByHost(_ mark: Mark) -> Bool { if case .byHost = mark { true } else { false } }

    /// One verdict a subject, the worst its cases gave, in the order a run writes them.
    public static func merged(_ verdicts: some Sequence<HostVerdict>) -> [HostVerdict] {
        var chosen: [String: HostVerdict] = [:]
        for verdict in verdicts {
            chosen[verdict.subject] = chosen[verdict.subject].map { worse($0, verdict) } ?? verdict
        }
        return chosen.values.sorted { $0.subject < $1.subject }
    }

    /// The line over a run's verdicts naming the revision of its family the run was made at.
    static let revisionLine = "# revision "

    /// The text a run writes: the revision of its family it was made at, where it is known, then one verdict a
    /// subject, a line each, sorted.
    public static func text(_ verdicts: some Sequence<HostVerdict>, revision: String? = nil) -> String {
        let lines = merged(verdicts).map(\.description)
        return ((revision.map { [revisionLine + $0] } ?? []) + lines).joined(separator: "\n") + "\n"
    }

    /// A run's text without the line naming its revision: what two runs at other revisions compare by.
    public static func withoutRevision(_ text: String) -> String {
        guard text.hasPrefix(revisionLine), let end = text.firstIndex(of: "\n") else {
            return text.hasPrefix(revisionLine) ? "" : text
        }
        return String(text[text.index(after: end)...])
    }

    /// The revision a run's text says it was made at; nil where it says none.
    public static func revision(of text: String) -> String? {
        guard let first = text.split(separator: "\n").first, first.hasPrefix(revisionLine) else { return nil }
        var revision = String(first.dropFirst(revisionLine.count))
        if revision.hasSuffix("\r") { revision.removeLast() }
        return revision.isEmpty ? nil : revision
    }

    /// The revision `family`'s verdicts on `host` stand at, as `revisions` - the text of
    /// `lib/StateUI/StateUI.Conformance/revisions.txt` - says: the family's own on every host, then the host's own, each 1
    /// where no line names it - `1.1`.
    /// Design: docs/design/contracts/dictionary.md#fresh-verdicts
    public static func revision(of family: String, on host: String, in revisions: String) -> String {
        var every = 1
        var own = 1
        for line in revisions.split(whereSeparator: \.isNewline) where !line.hasPrefix("#") {
            let words = line.split(separator: " ")
            if words.count == 2, words[0] == family, let number = Int(words[1]) { every = number }
            if words.count == 3, words[0] == host, words[1] == family, let number = Int(words[2]) { own = number }
        }
        return "\(every).\(own)"
    }

    /// Whether `held` - a verdict file of `family` on `host`, nil where there is none - is stale: it names another
    /// revision than `revisions` says the family stands at, or none.
    public static func isStale(_ held: String?, family: String, on host: String, in revisions: String) -> Bool {
        held.flatMap { revision(of: $0) } != revision(of: family, on: host, in: revisions)
    }

    /// The verdicts a run's text holds; nil where a line says none.
    public static func read(_ text: String) -> [HostVerdict]? {
        var verdicts: [HostVerdict] = []
        for (index, line) in text.split(separator: "\n").enumerated() {
            let line = line.hasSuffix("\r") ? String(line.dropLast()) : String(line)
            if index == 0, line.hasPrefix(revisionLine) { continue }
            guard let verdict = HostVerdict(line: line) else { return nil }
            verdicts.append(verdict)
        }
        return verdicts
    }
}
