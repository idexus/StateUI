// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The pickers, realized through the registry: what each says it realizes -
/// and what it refuses to claim - and the date and time their user picks
/// reported by member, as the lanes those values are carried in.
///
/// What a picker does on screen is held to `AppKitPickerViewTests` and
/// `AppKitDateTimePickerViewTests`, which drive the same registered views.
final class AppKitPickerRegistrationTests: XCTestCase {
    /// The registry realizes all three, each with its own value and event -
    /// and claims no moment a native control does not have: an AppKit date or
    /// time picker never opens or closes.
    @MainActor
    func testTheRegistryRealizesThePickersAndClaimsNoMomentTheyLack() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.isSuperset(of: ["Picker", "DatePicker", "TimePicker"]))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Picker", owner: "Picker", member: "selectedIndex")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Picker", owner: "Picker", member: "opened")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "DatePicker", owner: "DatePicker", member: "date")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "TimePicker", owner: "TimePicker", member: "timeChanged")))

        XCTAssertFalse(realization.members.contains(
            HostRealizedMember(element: "DatePicker", owner: "DatePicker", member: "opened")),
            "a native date picker has no moment of opening, so the host claims none")
    }

    /// A date picker wears the date the tree describes, and the date its
    /// user picks is reported by member - as the three lanes a civil date is
    /// carried in, never as an instant in a zone.
    @MainActor
    func testADatePickerWearsItsDateAndReportsTheUsersChoice() throws {
        var reports: [(Int32, [HostValue])] = []
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        var due = HostPatch(id: .manual("due"), type: .datePicker)
        due.properties[.date] = .numbers([2026, 9, 16])
        due.events = .replace([.dateChanged: 21])
        renderer.applyForTesting(tree(due))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("due")) as? AppKitDateTimePickerView)
        XCTAssertEqual(native.valueLanesForTesting, [2026, 9, 16])

        native.changeForTesting(to: [2027, 1, 1])

        XCTAssertEqual(reports.map(\.0), [21])
        XCTAssertEqual(reports.first?.1.first?.numbers, [2027, 1, 1])
    }

    /// A time picker does the same with the lanes a time of day is carried in.
    @MainActor
    func testATimePickerWearsItsTimeAndReportsTheUsersChoice() throws {
        var reports: [(Int32, [HostValue])] = []
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        var alarm = HostPatch(id: .manual("alarm"), type: .timePicker)
        alarm.properties[.time] = .numbers([9, 30, 0])
        alarm.events = .replace([.timeChanged: 33])
        renderer.applyForTesting(tree(alarm))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("alarm")) as? AppKitDateTimePickerView)
        XCTAssertEqual(native.valueLanesForTesting, [9, 30, 0])

        native.changeForTesting(to: [7, 15, 0])

        XCTAssertEqual(reports.map(\.0), [33])
        XCTAssertEqual(reports.first?.1.first?.numbers, [7, 15, 0])
    }

    /// A date picker keeps the range its element describes, which the whole
    /// applier reads beside the date itself.
    @MainActor
    func testADatePickersRangeComesFromItsOwnMembers() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var due = HostPatch(id: .manual("due"), type: .datePicker)
        due.properties[.date] = .numbers([2026, 9, 16])
        due.properties[.minimumDate] = .numbers([2026, 1, 1])
        due.properties[.maximumDate] = .numbers([2026, 12, 31])
        renderer.applyForTesting(tree(due))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("due")) as? AppKitDateTimePickerView)

        XCTAssertEqual(native.minimumLanesForTesting, [2026, 1, 1])
        XCTAssertEqual(native.maximumLanesForTesting, [2026, 12, 31])
    }
}
#endif
