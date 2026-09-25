// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Runs a family of cases on a host: each covered by what the host realizes runs, each other says why it does
/// not, and nothing is passed over in silence.
/// Design: docs/design/host/conformance.md#the-runner
@MainActor
@_spi(Host) public enum Conformance {
    /// Runs `family` on `driver`'s host, handing every failure to `report` and a line for each case to `log`.
    /// A family none of whose cases ran fails: a suite that tested nothing is not green.
    public static func run(
        _ family: any ConformanceFamily.Type, on driver: any HostDriver,
        report: @escaping (Failure) -> Void, log: (String) -> Void
    ) {
        var ran = 0
        for each in family.cases {
            let title = "Conformance \(driver.host) · \(family.name)/\(each.name)"
            guard !each.covers.isEmpty else {
                report(Failure(message: "\(title) covers no member of the contract", file: #filePath, line: #line))
                continue
            }
            switch Outcome(covering: each.covers, on: driver.marks) {
            case .notPlanned(let covered, let reason):
                log("\(title): not planned - \(covered): \(reason)")
            case .gap(let covered):
                log("\(title): a gap - \(covered) is not realized")
            case .runs:
                ran += 1
                log("\(title): " + run(each, as: title, on: driver, report: report))
            }
        }
        if ran == 0 {
            report(Failure(
                message: "Conformance \(driver.host) · \(family.name): no case ran", file: #filePath, line: #line))
        }
    }

    /// Runs one case; what came of it.
    private static func run(
        _ each: ConformanceCase, as title: String, on driver: any HostDriver, report: @escaping (Failure) -> Void
    ) -> String {
        let session = Session(driver: driver, case: "\(each.name)", report: report)
        do {
            try each.body(session)
        } catch let cannot as DriverCannot {
            if let reason = driver.cannot[cannot.ability] { return "the driver cannot \(cannot) - \(reason)" }
            session.fail("the driver cannot \(cannot), and says nothing of why")
        } catch {
            session.fail("threw \(error)")
        }
        return session.failures == 0 ? "passed" : "failed"
    }
}
