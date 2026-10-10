// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The jobs a thread that cannot park keeps for later - a sleep on WebAssembly -
// come due in the order of their time, and none before it.

import XCTest
@testable import StateUI

@MainActor
final class TimetableTests: XCTestCase {
    /// Jobs come due in the order of their time, whatever order they were added in.
    func testJobsComeDueInTheOrderOfTheirTime() {
        var timetable = Timetable<String, Double>()
        timetable.add("late", due: 30)
        timetable.add("early", due: 10)
        timetable.add("middle", due: 20)

        XCTAssertEqual(timetable.takeDue(at: 35), ["early", "middle", "late"])
        XCTAssertTrue(timetable.isEmpty)
    }

    /// Jobs due at the same time come in the order they were added.
    func testJobsDueTogetherKeepTheirOrder() {
        var timetable = Timetable<String, Double>()
        for name in ["first", "second", "third"] { timetable.add(name, due: 5) }

        XCTAssertEqual(timetable.takeDue(at: 5), ["first", "second", "third"])
    }

    /// A job not yet due stays, and the earliest time to come is the next one's.
    func testAJobNotYetDueWaits() {
        var timetable = Timetable<String, Double>()
        timetable.add("now", due: 10)
        timetable.add("later", due: 50)

        XCTAssertEqual(timetable.takeDue(at: 9), [])
        XCTAssertEqual(timetable.nextDue, 10)
        XCTAssertEqual(timetable.takeDue(at: 10), ["now"])
        XCTAssertEqual(timetable.nextDue, 50)
        XCTAssertEqual(timetable.count, 1)
    }
}
