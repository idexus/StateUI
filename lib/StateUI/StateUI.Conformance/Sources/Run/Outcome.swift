// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Whether a case runs on a host - every member it covers realized there - and what the host's register says of
/// each member the case does not run for.
@_spi(Host) public struct Outcome: Equatable, Sendable {
    /// The members the host's family never has, with why: the case does not run, and each is marked –.
    public let notPlanned: [Covered: String]

    /// The members the host does not realize yet: the case does not run, and each stays empty.
    public let notRealized: [Covered]

    /// The members the host leaves to the application's own registration: the case does not run, and each is marked 🧩.
    public let byApplication: [Covered]

    /// What the register says of each member the case covers, where the host realizes it.
    public let realized: [Covered: HostRecord.Judgement]

    /// Whether the case runs: every member it proves realized, in full or in part, and everything it needs.
    public var runs: Bool {
        notPlanned.isEmpty && notRealized.isEmpty && byApplication.isEmpty && gaps.isEmpty
    }

    /// The outcome of a case proving `proves` with the help of `needs` on a host with `register`: what it proves is
    /// judged, what it needs only stops it where the host lacks it.
    public init(proving proves: [Covered], needing needs: [Covered] = [], on register: HostRegister) {
        var notPlanned: [Covered: String] = [:]
        var notRealized: [Covered] = []
        var byApplication: [Covered] = []
        var realized: [Covered: HostRecord.Judgement] = [:]
        var gaps: [Covered] = []
        for covered in proves {
            switch covered.judgement(in: register) {
            case .notPlanned(let reason)?: notPlanned[covered] = reason
            case .byApplication?: byApplication.append(covered)
            case .unrealized?, nil: notRealized.append(covered)
            case let judgement?: realized[covered] = judgement
            }
        }
        for need in needs where !proves.contains(need) {
            switch need.judgement(in: register) {
            case .notPlanned?, .unrealized?, .byApplication?, nil: gaps.append(need)
            default: break
            }
        }
        self.notPlanned = notPlanned
        self.notRealized = notRealized
        self.byApplication = byApplication
        self.realized = realized
        self.gaps = gaps
    }

    /// What the case needs and the host does not realize, or never has.
    public let gaps: [Covered]

    /// What the register alone says, whether or not the case runs: – for each member never had, 🧩 for each left to
    /// the application, empty for each not realized, and - where only a gap stops the case - each member realized
    /// waiting on the first gap.
    public var facts: [HostVerdict] {
        let never = notPlanned.map { $0.key.verdict(.notPlanned(reason: $0.value)) }
            + byApplication.map { $0.verdict(.byApplication) }
        let missing = notRealized.map { $0.verdict(.notRealized) }
        guard notPlanned.isEmpty, byApplication.isEmpty, let gap = notRealized.first ?? gaps.first else {
            return never + missing
        }
        let waiting = realized.keys.sorted { $0.description < $1.description }
        return missing + waiting.map { $0.verdict(.waiting(on: gap.description)) }
    }

    /// What a passing case proved: ✅ each member realized in full, ☑️ with what is missing each realized in part -
    /// and ✓ each it reached only through the host's own entry or record, `byHost`.
    func proofs(byHost: [Session.ByHost] = []) -> [HostVerdict] {
        realized.map { covered, judgement in
            if let own = byHost.first(where: { $0.bears(on: covered) }) { return covered.verdict(.byHost(own.why)) }
            if case .partial(let missing) = judgement { return covered.verdict(.partial(missing: missing)) }
            return covered.verdict(.proven)
        }
    }

    /// Why the case does not run, as a line of the run says it; nil where it runs.
    public var reason: String? {
        if let (covered, reason) = notPlanned.min(by: { $0.key.description < $1.key.description }) {
            return "not planned - \(covered): \(reason)"
        }
        if let covered = byApplication.first { return "the application's - \(covered) is the application's to register" }
        if let covered = notRealized.first ?? gaps.first { return "a gap - \(covered) is not realized" }
        return nil
    }
}
