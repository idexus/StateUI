// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) @testable import StateUIConformance
import XCTest

/// A host that shows no page: the runner's own rules, with no toolkit under them.
@MainActor
private final class RegisterOnly: HostDriver {
    let host = "Nowhere"
    let register: HostRegister
    var cannot: [String: String] = [:]
    var otherwise: String?

    init(realizing records: [HostRecord], unrealized: Set<String> = [], notPlanned: [String: String] = [:]) {
        register = HostRegister(records: records, unrealized: unrealized, viewless: [], notPlanned: notPlanned)
    }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        preconditionFailure("a host of a register alone shows no page")
    }

    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? otherwise
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

    @discardableResult
    private func run(_ cases: [ConformanceCase], on driver: RegisterOnly) -> [HostVerdict] {
        Handed.cases = cases
        return Conformance.run(
            Handed.self, on: driver, report: { self.failures.append($0.message) }, log: { self.lines.append($0) })
    }

    /// A case runs only where the host realizes every member it covers; the register says the rest.
    func testACaseRunsOnlyWhereEveryMemberItCoversIsRealized() {
        let register = HostRegister(
            records: [.complete("Switch", "isOn"), .partial("Switch", "toggled", missing: "A sound."),
                      .notPlanned("Stepper", "step", reason: "No steps here.")],
            unrealized: ["Map"], viewless: [], notPlanned: ["MenuBar": "No bar here."])

        XCTAssertTrue(Outcome(covering: [Covered(SwitchContract.isOn), Covered(SwitchContract.toggled)], on: register).runs)
        let never = Outcome(covering: [Covered(StepperContract.step), Covered(SwitchContract.isOn)], on: register)
        XCTAssertFalse(never.runs)
        XCTAssertEqual(never.facts, [HostVerdict(element: "Stepper", member: "step", mark: .notPlanned(reason: "No steps here."))])
        XCTAssertEqual(Outcome(covering: [Covered(StepperContract.value)], on: register).facts, [
            HostVerdict(element: "Stepper", member: "value", mark: .notRealized),
        ])
        XCTAssertEqual(Outcome(covering: [Covered(MapContract.self)], on: register).facts, [
            HostVerdict(element: "Map", member: nil, mark: .notRealized),
        ])
        XCTAssertEqual(Outcome(covering: [Covered(MenuBarContract.self)], on: register).facts, [
            HostVerdict(element: "MenuBar", member: nil, mark: .notPlanned(reason: "No bar here.")),
        ])
    }

    /// A passing case proves each member it covers: whole where the host realizes it whole, and with what the host
    /// records as missing where it realizes it in part; a failing case proves nothing.
    func testAPassingCaseProvesWhatItCoversAndAFailingOneNothing() {
        let verdicts = run([
            ConformanceCase("passes", covers: [Covered(SwitchContract.isOn), Covered(SwitchContract.toggled)]) { _ in },
            ConformanceCase("fails", covers: [Covered(SwitchContract.self)]) { s in s.expect(true, false) },
        ], on: RegisterOnly(realizing: [
            .complete("Switch", "isOn"), .partial("Switch", "toggled", missing: "A sound."),
        ]))

        XCTAssertEqual(HostVerdict.text(verdicts), "Switch.isOn: ✅\nSwitch.toggled: ☑️ A sound.\n")
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/passes: passed", "Conformance Nowhere · Handed/fails: failed"])
    }

    /// A case the host's register stops says why, and the verdict says it for each member: – with the reason for one
    /// never had, empty for one not realized; nothing fails.
    func testACaseTheRegisterStopsSaysWhy() {
        let verdicts = run([
            ConformanceCase("never", covers: [Covered(StepperContract.step)]) { _ in },
            ConformanceCase("gap", covers: [Covered(StepperContract.value)]) { _ in },
        ], on: RegisterOnly(realizing: [.notPlanned("Stepper", "step", reason: "No steps here.")]))

        XCTAssertEqual(failures, [])
        XCTAssertEqual(HostVerdict.text(verdicts), "Stepper.step: – No steps here.\nStepper.value: not realized\n")
        XCTAssertEqual(lines, [
            "Conformance Nowhere · Handed/never: not planned - Stepper.step: No steps here.",
            "Conformance Nowhere · Handed/gap: a gap - Stepper.value is not realized",
        ])
    }

    /// A family run in parts runs each case in one part alone, and the parts together run them all.
    func testAFamilysPartsRunEachCaseOnce() {
        let driver = RegisterOnly(realizing: [.complete("Switch", "isOn")])
        let names = (0..<5).map { "case\($0)" }
        let cases = names.map { name in ConformanceCase(name, covers: [Covered(SwitchContract.isOn)]) { _ in } }

        for number in 1...2 {
            Handed.cases = cases
            Conformance.run(Handed.self, part: Conformance.Part(number, of: 2), on: driver, report: { _ in },
                            log: { self.lines.append($0) })
        }

        XCTAssertEqual(lines.map { $0.split(separator: "/").last.map(String.init) ?? "" }.sorted(),
                       names.map { "\($0): passed" })
    }

    /// A case that covers nothing fails: no verdict could ever say whether it runs.
    func testACaseThatCoversNothingFails() {
        run([
            ConformanceCase("nothing", covers: []) { _ in },
            ConformanceCase("something", covers: [Covered(SwitchContract.isOn)]) { _ in },
        ], on: RegisterOnly(realizing: [.complete("Switch", "isOn")]))

        XCTAssertEqual(failures, ["Conformance Nowhere · Handed/nothing covers no member of the contract"])
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/something: passed"])
    }

    /// An expectation that fails names the host and the case, and the case is reported failed.
    func testAFailureNamesTheHostAndTheCase() {
        run([ConformanceCase("sums", covers: [Covered(SwitchContract.isOn)]) { s in s.expect(1 + 1, 3) }],
            on: RegisterOnly(realizing: [.complete("Switch", "isOn")]))

        XCTAssertEqual(failures, ["Nowhere · sums: 3 expected, 2 came"])
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/sums: failed"])
    }

    /// What a driver cannot do is a failure unless the driver says why it cannot; where it says why, the members stay
    /// empty with its words.
    func testADriverThatCannotSaysWhyOrFails() {
        let driver = RegisterOnly(realizing: [.complete("Switch", "isOn")])
        let cannot = ConformanceCase("reads", covers: [Covered(SwitchContract.isOn)]) { _ in
            throw DriverCannot("read isOn of Switch")
        }

        run([cannot], on: driver)
        XCTAssertEqual(failures, ["Nowhere · reads: the driver cannot read isOn of Switch, and says nothing of why"])

        failures = []
        lines = []
        driver.cannot = ["read isOn of Switch": "The toolkit keeps it."]
        let verdicts = run([cannot], on: driver)
        XCTAssertEqual(failures, [])
        XCTAssertEqual(lines, [
            "Conformance Nowhere · Handed/reads: the driver cannot read isOn of Switch - The toolkit keeps it.",
        ])
        XCTAssertEqual(HostVerdict.text(verdicts), "Switch.isOn: cannot read isOn of Switch - The toolkit keeps it.\n")
    }

    /// A driver may say why for what it lists nowhere: the case says it, and each member it covers is empty with it.
    func testADriverSaysWhyForWhatItHasNoPathFor() {
        let driver = RegisterOnly(realizing: [.complete("Switch", "isOn")])
        driver.otherwise = "No path yet."
        let verdicts = run([ConformanceCase("reads", covers: [Covered(SwitchContract.isOn)]) { _ in
            throw DriverCannot("read isOn of Switch")
        }], on: driver)

        XCTAssertEqual(failures, [])
        XCTAssertEqual(HostVerdict.text(verdicts), "Switch.isOn: cannot read isOn of Switch - No path yet.\n")
    }
}
