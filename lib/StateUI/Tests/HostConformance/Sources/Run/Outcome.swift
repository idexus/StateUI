// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Whether a case runs on a host - every member it covers realized there - and what the host's register says of
/// each member the case does not run for.
@_spi(Host) public struct Outcome: Equatable, Sendable {
    /// The members the host's family never has, with why: the case does not run, and each is marked –.
    public let notPlanned: [Covered: String]

    /// The members the host does not realize yet: the case does not run, and each stays empty.
    public let notRealized: [Covered]

    /// What the register says of each member the case covers, where the host realizes it.
    public let realized: [Covered: HostRecord.Judgement]

    /// Whether the case runs: every member it covers realized, in full or in part.
    public var runs: Bool {
        notPlanned.isEmpty && notRealized.isEmpty
    }

    /// The outcome of a case covering `covers` on a host with `register`.
    public init(covering covers: [Covered], on register: HostRegister) {
        var notPlanned: [Covered: String] = [:]
        var notRealized: [Covered] = []
        var realized: [Covered: HostRecord.Judgement] = [:]
        for covered in covers {
            switch covered.judgement(in: register) {
            case .notPlanned(let reason)?: notPlanned[covered] = reason
            case nil: notRealized.append(covered)
            case let judgement?: realized[covered] = judgement
            }
        }
        self.notPlanned = notPlanned
        self.notRealized = notRealized
        self.realized = realized
    }

    /// What the register alone says, whether or not the case runs: – for each member never had, empty for each not
    /// realized.
    public var facts: [HostVerdict] {
        notPlanned.map { $0.key.verdict(.notPlanned(reason: $0.value)) } + notRealized.map { $0.verdict(.notRealized) }
    }

    /// What a passing case proved: ✅ each member realized in full, ☑️ with what is missing each realized in part.
    public var proofs: [HostVerdict] {
        realized.map { covered, judgement in
            if case .partial(let missing) = judgement { return covered.verdict(.partial(missing: missing)) }
            return covered.verdict(.proven)
        }
    }

    /// Why the case does not run, as a line of the run says it; nil where it runs.
    public var reason: String? {
        if let (covered, reason) = notPlanned.min(by: { $0.key.description < $1.key.description }) {
            return "not planned - \(covered): \(reason)"
        }
        if let covered = notRealized.first { return "a gap - \(covered) is not realized" }
        return nil
    }
}
