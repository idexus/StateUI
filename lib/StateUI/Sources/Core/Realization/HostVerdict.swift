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
        } else {
            return nil
        }
        self.init(element: String(parts[0]), member: parts.count == 2 ? String(parts[1]) : nil, mark: mark)
    }

    /// Whether the dictionary counts the verdict as met: proven whole, or never on the host's family.
    public var meets: Bool {
        switch mark {
        case .proven, .notPlanned: true
        case .partial, .notRealized, .cannot: false
        }
    }

    /// How much a verdict says of a member other verdicts speak of too: a proof above the driver's word that it
    /// could not, and that above the host realizing nothing.
    var weight: Int {
        switch mark {
        case .proven, .partial, .notPlanned: 3
        case .cannot: 2
        case .notRealized: 1
        }
    }

    /// One verdict a subject, the weightiest where several speak of it - the first line of them where they weigh
    /// alike - in the order a run writes them.
    public static func merged(_ verdicts: some Sequence<HostVerdict>) -> [HostVerdict] {
        var chosen: [String: HostVerdict] = [:]
        for verdict in verdicts {
            guard let held = chosen[verdict.subject] else {
                chosen[verdict.subject] = verdict
                continue
            }
            if verdict.weight > held.weight || (verdict.weight == held.weight && verdict.description < held.description) {
                chosen[verdict.subject] = verdict
            }
        }
        return chosen.values.sorted { $0.subject < $1.subject }
    }

    /// The text a run writes: one verdict a subject, a line each, sorted.
    public static func text(_ verdicts: some Sequence<HostVerdict>) -> String {
        merged(verdicts).map(\.description).joined(separator: "\n") + "\n"
    }

    /// The verdicts a run's text holds; nil where a line says none.
    public static func read(_ text: String) -> [HostVerdict]? {
        var verdicts: [HostVerdict] = []
        for line in text.split(separator: "\n") {
            let line = line.hasSuffix("\r") ? String(line.dropLast()) : String(line)
            guard let verdict = HostVerdict(line: line) else { return nil }
            verdicts.append(verdict)
        }
        return verdicts
    }
}
