// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// The acts every host performs, how those asking the time are read and answered, an application's own acts, and
/// the lines a host's log writes.
@MainActor
final class HostActsTests: XCTestCase {
    /// The time of day is four numbers; a zone's distance from UTC is asked of a zone and a day, answered in
    /// minutes, and a zone nobody knows fails with its name.
    func testTheTimeIsAskedAndAnsweredAlike() {
        XCTAssertEqual(HostActs.currentTime(hour: 9, minute: 5, second: 30, millisecond: 250), [.numbers([9, 5, 30, 250])])
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
        let names = HostActs.performed.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(names.contains("utcOffset"))
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
        acts.add(InteropTestActs.shake, control: { view in view == "wheel" ? 7 : nil }) { control in "shook \(control)" }
        guard case .aimed(let perform)? = acts.performers[InteropTestActs.shake.token] else {
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
        let gone = HostActCall(act: InteropTestActs.shake.token, arguments: [.string("gone")], completion: nil)
        XCTAssertTrue(acts.perform(gone, in: runtime.tree, core: runtime.core, view: { _ in "wheel" }, log: { said.append($0) }))
        XCTAssertEqual(said.count, 1)
        XCTAssertTrue(said.first?.hasPrefix("there is no view") == true, "\(said)")
        let unknown = HostActCall(act: InteropTestActs.greet.token, arguments: [], completion: nil)
        XCTAssertFalse(acts.perform(unknown, in: runtime.tree, core: runtime.core, view: { _ in nil }, log: { _ in }))
    }

    /// A host's log writes one line a message, begun by the host's name.
    func testALogLineNamesItsHost() {
        let written = Written()
        let log = HostLog(host: "WinUI", output: { written.lines.append($0) })
        log.error("a window closed")
        XCTAssertEqual(written.lines, ["StateUI WinUI: a window closed\n"])
    }
}

/// What a log wrote.
private final class Written: @unchecked Sendable {
    var lines: [String] = []
}

/// Acts of an application's own, declared the way an application declares them.
private enum InteropTestActs: ApplicationTier {
    static let name = "Interop"

    static let greet = ElementAct<Self, String, String>("Interop.Greet")
    static let shake = ElementAct<Self, Void, String>("Interop.Shake")

    static let members: [any ContractMember] = [greet, shake]
}
