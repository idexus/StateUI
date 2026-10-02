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
    var platformHasNone: [String: String] = [:]
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

    /// What this host reaches past its toolkit.
    var own: [String: String] = [:]

    func byHost(_ ability: String) -> String? {
        own[ability]
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

    /// A case runs only where the host realizes every member it proves and everything it needs; the register says
    /// the rest.
    func testACaseRunsOnlyWhereEveryMemberItCoversIsRealized() {
        let register = HostRegister(
            records: [.complete("Switch", "isOn"), .partial("Switch", "toggled", missing: "A sound."),
                      .notPlanned("Stepper", "step", reason: "No steps here.")],
            unrealized: ["Map"], viewless: [], notPlanned: ["MenuBar": "No bar here."])

        XCTAssertTrue(Outcome(proving: [Covered(SwitchContract.isOn), Covered(SwitchContract.toggled)], on: register).runs)
        let never = Outcome(proving: [Covered(StepperContract.step), Covered(SwitchContract.isOn)], on: register)
        XCTAssertFalse(never.runs)
        XCTAssertEqual(never.facts, [HostVerdict(element: "Stepper", member: "step", mark: .notPlanned(reason: "No steps here."))])
        XCTAssertEqual(Outcome(proving: [Covered(StepperContract.value)], on: register).facts, [
            HostVerdict(element: "Stepper", member: "value", mark: .notRealized),
        ])
        XCTAssertEqual(
            Outcome(proving: [Covered(SwitchContract.toggled), Covered(StepperContract.value), Covered(SwitchContract.isOn)],
                    on: register).facts,
            [
                HostVerdict(element: "Stepper", member: "value", mark: .notRealized),
                HostVerdict(element: "Switch", member: "isOn", mark: .waiting(on: "Stepper.value")),
                HostVerdict(element: "Switch", member: "toggled", mark: .waiting(on: "Stepper.value")),
            ], "what the host realizes waits on what it does not")
        XCTAssertEqual(Outcome(proving: [Covered(MapContract.self)], on: register).facts, [
            HostVerdict(element: "Map", member: nil, mark: .notRealized),
        ])
        let left = HostRegister(records: [], unrealized: [], viewless: [], byApplication: ["Map"])
        let map = Outcome(proving: [Covered(MapContract.region)], on: left)
        XCTAssertFalse(map.runs, "a case of what the application realizes does not run")
        XCTAssertEqual(map.facts, [HostVerdict(element: "Map", member: "region", mark: .byApplication)])
        XCTAssertFalse(Outcome(proving: [Covered(ButtonContract.clicked)], needing: [Covered(MapContract.region)], on: left).runs)
        XCTAssertEqual(Outcome(proving: [Covered(MenuBarContract.self)], on: register).facts, [
            HostVerdict(element: "MenuBar", member: nil, mark: .notPlanned(reason: "No bar here.")),
        ])
        let needing = Outcome(proving: [Covered(SwitchContract.isOn)], needing: [Covered(StepperContract.value)], on: register)
        XCTAssertFalse(needing.runs, "a case runs only where what it needs is realized too")
        XCTAssertEqual(needing.facts, [
            HostVerdict(element: "Switch", member: "isOn", mark: .waiting(on: "Stepper.value")),
        ], "what it needs gets no verdict of its own")
    }

    /// A member a passing case reached only through the host's own entry or record is proven by the host's own,
    /// ✓ with which and why - the member of the read alone, every member of the element acted on - and one the toolkit
    /// served is ✅.
    func testWhatACaseReachedOnlyThroughTheHostIsTheHostsOwn() {
        let driver = RegisterOnly(realizing: [
            .complete("Switch", "isOn"), .complete("Switch", "toggled"), .complete("Label", "text"),
        ])
        driver.own = ["read isOn of Switch": "a copy the host keeps", "tap on Label": "handed to the recognizer"]
        let verdicts = run([
            ConformanceCase("reads", proves: [Covered(SwitchContract.isOn), Covered(SwitchContract.toggled)]) { s in
                s.note("read isOn of Switch", element: "Switch", member: "isOn")
                s.note("read toggled of Switch", element: "Switch", member: "toggled")
            },
            ConformanceCase("taps", proves: [Covered(LabelContract.self)]) { s in
                s.note("tap on Label", element: "Label")
            },
        ], on: driver)

        XCTAssertEqual(HostVerdict.text(verdicts), """
            Label: ✓ tap on Label: handed to the recognizer
            Switch.isOn: ✓ read isOn of Switch: a copy the host keeps
            Switch.toggled: ✅

            """)
    }

    /// A case says nothing of what it only needs, a failing one fails what it proves with its first failure, and one
    /// that proved its members absent here marks them never had, with why.
    func testACaseJudgesWhatItProvesAlone() {
        let verdicts = run([
            ConformanceCase("passes", proves: [Covered(SwitchContract.isOn)], needs: [Covered(SwitchContract.toggled)]) { _ in },
            ConformanceCase("fails", proves: [Covered(SwitchContract.toggled)]) { s in
                s.fail("true expected, false came")
                s.fail("a second")
            },
            ConformanceCase("absent", proves: [Covered(SwitchContract.self)]) { s in
                throw s.absent("Switch takes no keyboard focus here: it refuses it, and nothing is heard")
            },
        ], on: RegisterOnly(realizing: [.complete("Switch", "isOn"), .complete("Switch", "toggled")]))

        XCTAssertEqual(HostVerdict.text(verdicts), """
            Switch: – Switch takes no keyboard focus here: it refuses it, and nothing is heard
            Switch.isOn: ✅
            Switch.toggled: ❌ true expected, false came

            """)
    }

    /// A passing case proves each member it proves: whole where the host realizes it whole, and with what the host
    /// records as missing where it realizes it in part; a failing case fails them.
    func testAPassingCaseProvesWhatItCoversAndAFailingOneNothing() {
        let verdicts = run([
            ConformanceCase("passes", proves: [Covered(SwitchContract.isOn), Covered(SwitchContract.toggled)]) { _ in },
            ConformanceCase("fails", proves: [Covered(SwitchContract.self)]) { s in s.expect(true, false) },
        ], on: RegisterOnly(realizing: [
            .complete("Switch", "isOn"), .partial("Switch", "toggled", missing: "A sound."),
        ]))

        XCTAssertTrue(HostVerdict.text(verdicts).hasPrefix("Switch: ❌ "), HostVerdict.text(verdicts))
        XCTAssertTrue(HostVerdict.text(verdicts).hasSuffix("Switch.isOn: ✅\nSwitch.toggled: ☑️ A sound.\n"))
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/passes: passed", "Conformance Nowhere · Handed/fails: failed"])
    }

    /// A case the host's register stops says why, and the verdict says it for each member: – with the reason for one
    /// never had, empty for one not realized; nothing fails.
    func testACaseTheRegisterStopsSaysWhy() {
        let verdicts = run([
            ConformanceCase("never", proves: [Covered(StepperContract.step)]) { _ in },
            ConformanceCase("gap", proves: [Covered(StepperContract.value)]) { _ in },
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
        let cases = names.map { name in ConformanceCase(name, proves: [Covered(SwitchContract.isOn)]) { _ in } }

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
            ConformanceCase("nothing", proves: []) { _ in },
            ConformanceCase("something", proves: [Covered(SwitchContract.isOn)]) { _ in },
        ], on: RegisterOnly(realizing: [.complete("Switch", "isOn")]))

        XCTAssertEqual(failures, ["Conformance Nowhere · Handed/nothing proves no member of the contract"])
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/something: passed"])
    }

    /// An expectation that fails names the host and the case, and the case is reported failed.
    func testAFailureNamesTheHostAndTheCase() {
        run([ConformanceCase("sums", proves: [Covered(SwitchContract.isOn)]) { s in s.expect(1 + 1, 3) }],
            on: RegisterOnly(realizing: [.complete("Switch", "isOn")]))

        XCTAssertEqual(failures, ["Nowhere · sums: 3 expected, 2 came"])
        XCTAssertEqual(lines, ["Conformance Nowhere · Handed/sums: failed"])
    }

    /// A colour StateUI draws shows as the screen shows it: each channel a few steps off, as smoothing an edge leaves
    /// it, is the colour; more is another, and nothing is none.
    func testAColourShowsWithinTheStepsSmoothingTakes() {
        let red = Color(red: 255, green: 0, blue: 0)
        XCTAssertTrue(Session.shows(Color(red: 253, green: 0, blue: 0), red))
        XCTAssertTrue(Session.shows(Color(red: 251, green: 4, blue: 0, alpha: 251), red))
        XCTAssertFalse(Session.shows(Color(red: 250, green: 0, blue: 0), red))
        XCTAssertFalse(Session.shows(Color(red: 255, green: 0, blue: 5), red))
        XCTAssertFalse(Session.shows(nil, red))

        run([ConformanceCase("paints", proves: [Covered(SwitchContract.isOn)]) { s in
            s.expect(Color(red: 253, green: 0, blue: 0), shows: red)
            s.expect(nil, shows: red, "on its outline")
        }], on: RegisterOnly(realizing: [.complete("Switch", "isOn")]))
        XCTAssertEqual(failures, ["Nowhere · paints: \(red) expected, nothing came - on its outline"])
    }

    /// What a driver cannot do is a failure unless the driver says why it cannot; where it says why, the members stay
    /// empty with its words.
    func testADriverThatCannotSaysWhyOrFails() {
        let driver = RegisterOnly(realizing: [.complete("Switch", "isOn")])
        let cannot = ConformanceCase("reads", proves: [Covered(SwitchContract.isOn)]) { _ in
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
            "Conformance Nowhere · Handed/reads: cannot read isOn of Switch - The toolkit keeps it.",
        ])
        XCTAssertEqual(HostVerdict.text(verdicts), "Switch.isOn: cannot read isOn of Switch - The toolkit keeps it.\n")
    }

    /// A driver may say why for what it lists nowhere: the case says it, and each member it covers is empty with it.
    func testADriverSaysWhyForWhatItHasNoPathFor() {
        let driver = RegisterOnly(realizing: [.complete("Switch", "isOn")])
        driver.otherwise = "No path yet."
        let verdicts = run([ConformanceCase("reads", proves: [Covered(SwitchContract.isOn)]) { _ in
            throw DriverCannot("read isOn of Switch")
        }], on: driver)

        XCTAssertEqual(failures, [])
        XCTAssertEqual(HostVerdict.text(verdicts), "Switch.isOn: cannot read isOn of Switch - No path yet.\n")
    }

    /// A case needing what the platform holds nothing of does not apply there: another case's verdict on a member
    /// stands alone, and a member no other case judges stays empty with why - whether the driver lists it or its
    /// read says so.
    func testACaseThePlatformHoldsNothingForDoesNotApply() {
        let driver = RegisterOnly(realizing: [.complete("Switch", "isOn"), .complete("Switch", "toggled")])
        driver.platformHasNone = ["read isOn of Switch": "The toolkit keeps no such value; its effect proves it."]
        let verdicts = run([
            ConformanceCase("reads", proves: [Covered(SwitchContract.isOn), Covered(SwitchContract.toggled)]) { _ in
                throw DriverCannot("read isOn of Switch")
            },
            ConformanceCase("sees", proves: [Covered(SwitchContract.isOn)]) { _ in },
        ], on: driver)

        XCTAssertEqual(failures, [])
        XCTAssertEqual(HostVerdict.text(verdicts), """
            Switch.isOn: ✅
            Switch.toggled: cannot read isOn of Switch - The toolkit keeps no such value; its effect proves it.

            """)

        let said = run([
            ConformanceCase("marks", proves: [Covered(SwitchContract.isOn)]) { _ in
                throw DriverCannot("read a level", because: "The toolkit marks no level.")
            },
            ConformanceCase("sees", proves: [Covered(SwitchContract.isOn)]) { _ in },
        ], on: driver)
        XCTAssertEqual(HostVerdict.text(said), "Switch.isOn: ✅\n")
    }
}
