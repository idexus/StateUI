// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUIHostConformance
import XCTest

/// A host that shows no page: the runner's own rules, with no toolkit under them.
@MainActor
private final class MarksOnly: HostDriver {
    let host = "Nowhere"
    let marks: HostMarks
    var cannot: [String: String] = [:]

    init(realizing records: [HostRecord], notPlanned: Set<String> = []) {
        marks = HostMarks(records: records, unrealized: [], viewless: [], notPlanned: notPlanned)
    }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        preconditionFailure("a host of marks alone shows no page")
    }

    func step() {}
    func turn() {}
    func frame() {}
    func perform(_ act: UserAct, on element: MountedElement) throws {}
    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? { nil }
}

/// A family of the cases a test hands it.
private enum Handed: ConformanceFamily {
    static let name = "Handed"
    nonisolated(unsafe) static var cases: [ConformanceCase] = []
}

@MainActor
final class ConformanceRunnerTests: XCTestCase {
    private var failures: [String] = []
    private var lines: [String] = []

    private func run(_ cases: [ConformanceCase], on driver: MarksOnly) {
        Handed.cases = cases
        Conformance.run(Handed.self, on: driver, report: { self.failures.append($0.message) }, log: { self.lines.append($0) })
    }

    /// A case runs only where the host realizes every member it covers; else it says which it does not, and why.
    func testACaseRunsOnlyWhereEveryMemberItCoversIsRealized() {
        let marks = HostMarks(
            records: [.complete("Switch", "isOn"), .partial("Switch", "toggled", missing: "A sound."),
                      .notPlanned("Stepper", "step", reason: "No steps here.")],
            unrealized: ["Map"], viewless: [])

        XCTAssertEqual(Outcome(covering: [Covered(SwitchContract.isOn), Covered(SwitchContract.toggled)], on: marks), .runs)
        XCTAssertEqual(
            Outcome(covering: [Covered(StepperContract.step)], on: marks),
            .notPlanned(Covered(StepperContract.step), reason: "No steps here."))
        XCTAssertEqual(Outcome(covering: [Covered(StepperContract.value)], on: marks), .gap(Covered(StepperContract.value)))
    }

    /// A family none of whose cases ran fails: a suite that tested nothing is not green.
    func testAFamilyNoneOfWhoseCasesRanFails() {
        run([ConformanceCase("unrealized", covers: [Covered(StepperContract.value)]) { _ in }], on: MarksOnly(realizing: []))

        XCTAssertEqual(failures, ["Conformance Nowhere · Handed: no case ran"])
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/unrealized: a gap - Stepper.value is not realized"])
    }

    /// A case that covers nothing fails: no mark could ever say whether it runs.
    func testACaseThatCoversNothingFails() {
        run([
            ConformanceCase("nothing", covers: []) { _ in },
            ConformanceCase("something", covers: [Covered(SwitchContract.isOn)]) { _ in },
        ], on: MarksOnly(realizing: [.complete("Switch", "isOn")]))

        XCTAssertEqual(failures, ["Conformance Nowhere · Handed/nothing covers no member of the contract"])
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/something: passed"])
    }

    /// An expectation that fails names the host and the case, and the case is reported failed.
    func testAFailureNamesTheHostAndTheCase() {
        run([ConformanceCase("sums", covers: [Covered(SwitchContract.isOn)]) { s in s.expect(1 + 1, 3) }],
            on: MarksOnly(realizing: [.complete("Switch", "isOn")]))

        XCTAssertEqual(failures, ["Nowhere · sums: 3 expected, 2 came"])
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/sums: failed"])
    }

    /// A run proves what its passing cases covered, and nothing a failing case covered.
    func testOnlyAPassingCaseProvesWhatItCovers() {
        Handed.cases = [
            ConformanceCase("passes", covers: [Covered(SwitchContract.isOn)]) { _ in },
            ConformanceCase("fails", covers: [Covered(SwitchContract.toggled)]) { s in s.expect(true, false) },
        ]
        let proven = Conformance.run(
            Handed.self, on: MarksOnly(realizing: [.complete("Switch", "isOn"), .complete("Switch", "toggled")]),
            report: { _ in }, log: { _ in })

        XCTAssertEqual(proven, [Covered(SwitchContract.isOn)])
        XCTAssertEqual(Coverage.text(proven), "Switch.isOn\n")
    }

    /// What a driver cannot do is a failure unless the driver says why it cannot.
    func testADriverThatCannotSaysWhyOrFails() {
        let driver = MarksOnly(realizing: [.complete("Switch", "isOn")])
        let cannot = ConformanceCase("reads", covers: [Covered(SwitchContract.isOn)]) { _ in
            throw DriverCannot("read isOn of Switch")
        }

        run([cannot], on: driver)
        XCTAssertEqual(failures, ["Nowhere · reads: the driver cannot read isOn of Switch, and says nothing of why"])

        failures = []
        lines = []
        driver.cannot = ["read isOn of Switch": "The toolkit keeps it."]
        run([cannot], on: driver)
        XCTAssertEqual(failures, [])
        XCTAssertEqual(lines, [
            "Conformance Nowhere · Handed/reads: the driver cannot read isOn of Switch - The toolkit keeps it.",
        ])
    }
}
