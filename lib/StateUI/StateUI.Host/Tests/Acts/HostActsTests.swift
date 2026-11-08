// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The acts every host performs, how those asking the time are read and answered, an application's own acts, and
/// the lines a host's log writes.
@MainActor
final class HostActsTests: XCTestCase {
    /// The local day and time of day are seven numbers; a zone's distance from UTC is asked of a zone and a day,
    /// answered in minutes, and a zone nobody knows fails with its name.
    func testTheTimeIsAskedAndAnsweredAlike() {
        XCTAssertEqual(
            HostActs.currentTime(LocalTime(year: 2026, month: 7, day: 1, hour: 9, minute: 5, second: 30, millisecond: 250)),
            [.numbers([2026, 7, 1, 9, 5, 30, 250])])
        let asked = HostActs.utcOffsetQuestion(HostActCall(
            act: .utcOffset, arguments: [.string("Europe/Warsaw"), CalendarDate(year: 2026, month: 7, day: 1).propValue],
            completion: 1))
        XCTAssertEqual(asked.zone, "Europe/Warsaw")
        XCTAssertEqual(asked.day, CalendarDate(year: 2026, month: 7, day: 1))
        XCTAssertNil(HostActs.utcOffsetQuestion(HostActCall(act: .utcOffset, arguments: [], completion: 1)).zone)
        XCTAssertEqual(HostActs.utcOffset(minutes: 120), [.number(120)])
        XCTAssertEqual(HostActs.unknownZone("Mars/Base").reason, "no time zone 'Mars/Base' is known")
    }

    /// Every act the hosts perform is one the contracts declare, named once.
    func testEveryActTheHostsPerformIsDeclaredOnce() {
        let names = (HostActs.performed + HostActs.files).map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(names.contains("utcOffset"))
        XCTAssertTrue(names.contains("launchAddress"))
    }

    /// An application's own act is handed the values its contract declares and answers its own; a call carrying
    /// others fails with what the contract declares.
    func testAnApplicationsActTakesTheValuesItsContractDeclares() async throws {
        let acts = InteropActs<String>()
        acts.add(InteropTestActs.greet) { name in "Hello, \(name)" }
        guard case .application(let perform)? = acts.performers[InteropTestActs.greet.token] else {
            return XCTFail("the act is not the application's")
        }

        let answer = try await perform([.string("Ada")])
        XCTAssertEqual(answer, [.string("Hello, Ada")])
        do {
            _ = try await perform([])
            XCTFail("a call carrying no value was answered")
        } catch {
            XCTAssertTrue("\(error)".contains("was called with 0 value(s)"), "\(error)")
        }
    }

    /// An aimed act is handed the control the host finds for the element named; an element the host shows
    /// otherwise, or one not on screen, fails with why, and an act nobody registered is not performed.
    func testAnAimedActIsHandedItsElementsControl() async throws {
        let acts = InteropActs<String>()
        acts.add(InteropWheelContract.shake, control: { view in view == "wheel" ? 7 : nil }) { control in "shook \(control)" }
        guard case .aimed(let perform)? = acts.performers[InteropWheelContract.shake.token] else {
            return XCTFail("the act is not aimed")
        }
        let shaken = try await perform("wheel", [])
        XCTAssertEqual(shaken, [.string("shook 7")])
        do {
            _ = try await perform("label", [])
            XCTFail("an element shown otherwise was performed on")
        } catch {
            XCTAssertTrue("\(error)".contains("shows otherwise"), "\(error)")
        }

        let runtime = HostRuntime.still()
        runtime.tree.apply(HostPatch(id: .manual("root"), type: .vStack), complete: true)
        var said: [String] = []
        let gone = HostActCall(act: InteropWheelContract.shake.token, arguments: [.string("gone")], completion: nil)
        XCTAssertTrue(acts.perform(gone, in: runtime.tree, core: runtime.core, view: { _ in "wheel" }, log: { said.append($0) }))
        XCTAssertEqual(said.count, 1)
        XCTAssertTrue(said.first?.hasPrefix("there is no view") == true, "\(said)")
        let unknown = HostActCall(act: InteropTestActs.greet.token, arguments: [], completion: nil)
        XCTAssertFalse(acts.perform(unknown, in: runtime.tree, core: runtime.core, view: { _ in nil }, log: { _ in }))
    }

    /// An aimed act queued before its control left the tree holds nothing of the control meanwhile and, beginning,
    /// fails with that rather than reach it; one whose control stands as it begins is handed the control.
    func testAQueuedAimedActBeginsOnlyWhereItsControlStillStands() async throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(HostPatch(id: .manual("wheel"), type: .vStack), complete: true)
        let acts = InteropActs<Wheel>()
        var spun = 0
        acts.add(InteropWheelContract.shake, control: { $0 }) { _ in spun += 1; return "spun" }
        var wheel: Wheel? = Wheel()
        weak let dropped = wheel
        var said: [String] = []
        let call = HostActCall(act: InteropWheelContract.shake.token, arguments: [.string("wheel")], completion: nil)

        XCTAssertTrue(acts.perform(call, in: runtime.tree, core: runtime.core, view: { _ in wheel }, log: { said.append($0) }))
        runtime.tree.apply(HostPatch(id: .manual("empty"), type: .vStack), complete: true)
        wheel = nil
        XCTAssertNil(dropped, "the queue holds no control the tree dropped")
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(spun, 0, "an act begins on no control that left")
        XCTAssertEqual(said.count, 1)
        XCTAssertTrue(said.first?.contains("left before") == true, "\(said)")

        runtime.tree.apply(HostPatch(id: .manual("wheel"), type: .vStack), complete: true)
        wheel = Wheel()
        XCTAssertTrue(acts.perform(call, in: runtime.tree, core: runtime.core, view: { _ in wheel }, log: { said.append($0) }))
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(spun, 1, "a control standing as the act begins is handed over")
        XCTAssertEqual(said.count, 1)
    }

    /// An act forgotten is not performed, and every other registration stands - a backend's acts, which a host's
    /// tests register once for the whole run, among them.
    func testAnActForgottenLeavesTheOthersStanding() {
        let acts = InteropActs<String>()
        acts.add(InteropTestActs.greet) { name in "Hello, (name)" }
        acts.add(InteropWheelContract.shake, control: { _ in 7 }) { control in "\(control)" }

        acts.forget(InteropTestActs.greet.token)

        XCTAssertNil(acts.performers[InteropTestActs.greet.token])
        XCTAssertNotNil(acts.performers[InteropWheelContract.shake.token])
    }

    /// A second performer of one act is said: the first is replaced, which an application registering its act
    /// twice did not mean.
    func testASecondPerformerOfOneActIsSaid() {
        let acts = InteropActs<String>()
        acts.add(InteropTestActs.greet) { name in "Hello, \(name)" }
        XCTAssertFalse(hasComplained("`\(InteropTestActs.greet.token)` was registered twice"))

        acts.add(InteropTestActs.greet) { name in "Hi, \(name)" }

        XCTAssertTrue(hasComplained("`\(InteropTestActs.greet.token)` was registered twice"))
    }

    /// A host's log writes one line a message, begun by the host's name.
    func testALogLineNamesItsHost() {
        let written = Written()
        let log = HostLog(host: "WinUI", output: { written.lines.append($0) })
        log.error("a window closed")
        XCTAssertEqual(written.lines, ["StateUI WinUI: a window closed\n"])
    }
}

/// A control an aimed act is handed, counted as it goes.
@MainActor private final class Wheel {}

/// What a log wrote.
private final class Written: @unchecked Sendable {
    var lines: [String] = []
}

/// An act of an application's own, declared the way an application declares one.
private enum InteropTestActs: ApplicationTier {
    static let name = "Interop"

    static let greet = ElementAct<Self, String, String>("greet")

    static let members: [any ContractMember] = [greet]
}

/// A control of an application's own, with the act aimed at it.
private enum InteropWheelContract: ElementContract {
    static let nodeType: NodeType = "Interop.Wheel"

    static let shake = ElementAct<Self, Void, String>("shake")

    static let members: [any ContractMember] = [shake]
}
