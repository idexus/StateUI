// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

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
    /// case to `log`; the verdict on each member its cases cover - ✅ or ☑️ where a passing case proved it, – where
    /// the host's family never has it, and why it stays empty otherwise. A member of a failing case gets no verdict
    /// from it.
    @discardableResult
    public static func run(
        _ family: any ConformanceFamily.Type, part: Part = .whole, on driver: any HostDriver,
        report: @escaping (Failure) -> Void, log: (String) -> Void
    ) -> [HostVerdict] {
        var verdicts: [HostVerdict] = []
        for (index, each) in family.cases.enumerated() where part.holds(index) {
            let title = "Conformance \(driver.host) · \(family.name)/\(each.name)"
            guard !each.covers.isEmpty else {
                report(Failure(message: "\(title) covers no member of the contract", file: #filePath, line: #line))
                continue
            }
            let outcome = Outcome(covering: each.covers, on: driver.register)
            verdicts += outcome.facts
            if let reason = outcome.reason {
                log("\(title): \(reason)")
                continue
            }
            switch run(each, as: title, on: driver, report: report) {
            case .passed:
                log("\(title): passed")
                verdicts += outcome.proofs
            case .cannot(let cannot, let reason):
                log("\(title): the driver cannot \(cannot) - \(reason)")
                verdicts += each.covers.map { $0.verdict(.cannot("\(cannot) - \(reason)")) }
            case .failed:
                log("\(title): failed")
            }
        }
        return HostVerdict.merged(verdicts)
    }

    /// How one case came out.
    private enum Result {
        case passed
        case cannot(DriverCannot, reason: String)
        case failed
    }

    /// Runs one case.
    private static func run(
        _ each: ConformanceCase, as title: String, on driver: any HostDriver, report: @escaping (Failure) -> Void
    ) -> Result {
        let session = Session(driver: driver, case: "\(each.name)", report: report)
        do {
            try each.body(session)
        } catch let cannot as DriverCannot {
            if let reason = driver.reason(cannot: cannot.ability) { return .cannot(cannot, reason: reason) }
            session.fail("the driver cannot \(cannot), and says nothing of why")
        } catch {
            session.fail("threw \(error)")
        }
        return session.failures == 0 ? .passed : .failed
    }
}
