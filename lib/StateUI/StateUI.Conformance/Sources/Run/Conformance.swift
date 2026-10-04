// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Runs a family of cases on a host and gives its verdict on every member they cover: each case covered by what the
/// host realizes runs, each other says why it does not, and nothing is passed over in silence.
/// Design: docs/design/host/conformance.md#the-runner
@MainActor
@_spi(Host) public enum Conformance {
    /// A share of a family's cases, for a host that runs a large family in parts: the `number`th of `count` parts
    /// holds every `count`th case, from the `number`th on, and the parts together hold every case once.
    public struct Part: Equatable, Sendable {
        /// Which part, from 1.
        public let number: Int

        /// How many parts the family is run in.
        public let count: Int

        /// The whole family, in one part.
        public static let whole = Part(1, of: 1)

        /// The `number`th of `count` parts.
        public init(_ number: Int, of count: Int) {
            precondition(count >= 1 && (1...count).contains(number), "part \(number) of \(count)")
            self.number = number
            self.count = count
        }

        /// Whether the case at `index` of the family's cases is this part's.
        func holds(_ index: Int) -> Bool {
            index % count == number - 1
        }
    }

    /// Runs `family` - or `part` of it - on `driver`'s host, handing every failure to `report` and a line for each
    /// case to `log`, or, where none is given, saying each as it ends - its place in the run and how long it took
    /// (`HostLog.note`); the verdict on each member its cases prove - ✅, ☑️ or ✓ where a passing case proved it, –
    /// where the host's family never has it, 🧩 where it is the application's, ❌ with the first failure where a case
    /// failed, and why it stays empty otherwise - the worst its cases gave.
    @discardableResult
    public static func run(
        _ family: any ConformanceFamily.Type, part: Part = .whole, on driver: any HostDriver,
        report: @escaping (Failure) -> Void, log: ((String) -> Void)? = nil
    ) -> [HostVerdict] {
        let held = family.cases.indices.filter(part.holds)
        let progress = HostLog(host: driver.host)
        // The register is the host's whole registry read: once a run, not once a case.
        let register = driver.register
        var verdicts: [HostVerdict] = []
        // What the cases that do not apply on this host say: each only of a member no other case judges.
        var inapplicable: [HostVerdict] = []
        for (place, index) in held.enumerated() {
            let each = family.cases[index]
            let title = "Conformance \(driver.host) · \(family.name)/\(each.name)"
            let began = ContinuousClock.now
            let tell = { (line: String) in
                if let log { return log(line) }
                progress.note("[\(place + 1)/\(held.count)] \(line) in \(Self.milliseconds(since: began)) ms")
            }
            guard !each.proves.isEmpty else {
                report(Failure(message: "\(title) proves no member of the contract", file: #filePath, line: #line))
                continue
            }
            let outcome = Outcome(proving: each.proves, needing: each.needs, on: register)
            verdicts += outcome.facts
            if let reason = outcome.reason {
                tell("\(title): \(reason)")
                continue
            }
            switch run(each, as: title, on: driver, report: report) {
            case .passed(let byHost):
                tell("\(title): passed")
                verdicts += outcome.proofs(byHost: byHost)
            case .cannot(let why):
                tell("\(title): cannot \(why)")
                verdicts += each.proves.map { $0.verdict(.cannot(why)) }
            case .inapplicable(let why):
                tell("\(title): does not apply - cannot \(why)")
                inapplicable += each.proves.map { $0.verdict(.cannot(why)) }
            case .absent(let why):
                tell("\(title): never here - \(why)")
                verdicts += each.proves.map { $0.verdict(.notPlanned(reason: why)) }
            case .failed(let message):
                tell("\(title): failed")
                verdicts += each.proves.map { $0.verdict(.failed(message)) }
            }
        }
        let judged = Set(verdicts.map(\.subject))
        return HostVerdict.merged(verdicts + inapplicable.filter { !judged.contains($0.subject) })
    }

    /// Whole milliseconds since `instant`.
    private static func milliseconds(since instant: ContinuousClock.Instant) -> Int64 {
        let elapsed = (ContinuousClock.now - instant).components
        return elapsed.seconds * 1_000 + elapsed.attoseconds / 1_000_000_000_000_000
    }

    /// How one case came out: passed, with what it reached only through the host's own; could not prove what it
    /// proves on this host, and why; does not apply there, the platform holding nothing it needs, and why; proved
    /// its members absent there, and why; or failed, with its first failure.
    private enum Result {
        case passed([Session.ByHost])
        case cannot(String)
        case inapplicable(String)
        case absent(String)
        case failed(String)
    }

    /// Runs one case.
    private static func run(
        _ each: ConformanceCase, as title: String, on driver: any HostDriver, report: @escaping (Failure) -> Void
    ) -> Result {
        let session = Session(driver: driver, case: "\(each.name)", report: report)
        do {
            try each.body(session)
        } catch let cannot as DriverCannot where session.failures == 0 {
            if let because = cannot.because ?? driver.platformHasNone[cannot.ability] {
                return .inapplicable("\(cannot) - \(because)")
            }
            if let reason = driver.reason(cannot: cannot.ability) { return .cannot("\(cannot) - \(reason)") }
            session.fail("the driver cannot \(cannot), and says nothing of why")
        } catch let absence as Session.Absence where session.failures == 0 {
            return .absent(absence.why)
        } catch {
            session.fail("threw \(error)")
        }
        return session.firstFailure.map { .failed($0) } ?? .passed(session.byHost)
    }
}
