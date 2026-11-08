// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

final class AndroidDateFieldViewTests: XCTestCase {
    static var allTests: [(String, (AndroidDateFieldViewTests) -> () throws -> Void)] {
        [
            ("testAFieldWritesItsDayAndTimeAsItsFormatSays", testAFieldWritesItsDayAndTimeAsItsFormatSays),
            ("testTheUsersDayReachesTheStateAndTheHandler", testTheUsersDayReachesTheStateAndTheHandler),
            ("testTheUsersTimeReachesTheStateAndTheHandler", testTheUsersTimeReachesTheStateAndTheHandler),
        ]
    }

    func testAFieldWritesItsDayAndTimeAsItsFormatSays() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    DatePicker(CalendarDate(year: 2026, month: 9, day: 24)).format(.short)
                    TimePicker(ClockTime(hour: 7, minute: 5)).format(.short)
                    DatePicker(CalendarDate(year: 2026, month: 9, day: 24)).format(.long)
                    DatePicker(CalendarDate(year: 2026, month: 9, day: 24)).format(.medium)
                    TimePicker(ClockTime(hour: 7, minute: 5)).format(.medium)
                }
            }
            let fields = host.views(AndroidDateFieldView.self)

            XCTAssertFalse(fields[0].text.isEmpty)
            XCTAssertTrue(fields[1].text.contains(":05"), fields[1].text)
            XCTAssertTrue(fields[2].text.contains("2026"), fields[2].text)
            XCTAssertEqual(Set([fields[0].text, fields[2].text, fields[3].text]).count, 3, "three forms of one day")
            XCTAssertTrue(fields[4].text.contains(":05:00"), "the medium form writes seconds: \(fields[4].text)")
        }
    }

    /// The calendar's choice - its month counted from nought, as Android counts it - lands as the day it is.
    func testTheUsersDayReachesTheStateAndTheHandler() throws {
        try onMainActor {
            let due = State(wrappedValue: CalendarDate(year: 2026, month: 9, day: 24))
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                DatePicker(due.projectedValue).format(.long).onDateChanged { heard.values.append($0.text) }
            }
            let field = try XCTUnwrap(host.views(AndroidDateFieldView.self).first)

            Java.call(field.reference, TestJava.onDateSet, .object(nil), .int(2027), .int(0), .int(15))

            XCTAssertEqual(due.wrappedValue, CalendarDate(year: 2027, month: 1, day: 15))
            XCTAssertEqual(heard.values, ["2027-01-15"])
            XCTAssertTrue(field.text.contains("2027"), field.text)
        }
    }

    func testTheUsersTimeReachesTheStateAndTheHandler() throws {
        try onMainActor {
            let alarm = State(wrappedValue: ClockTime(hour: 7, minute: 0))
            let heard = Received<Int>()
            let host = AndroidRenderer.running {
                TimePicker(alarm.projectedValue).onTimeChanged { heard.values.append($0.hour * 60 + $0.minute) }
            }
            let field = try XCTUnwrap(host.views(AndroidDateFieldView.self).first)

            Java.call(field.reference, TestJava.onTimeSet, .object(nil), .int(9), .int(30))

            XCTAssertEqual(alarm.wrappedValue, ClockTime(hour: 9, minute: 30))
            XCTAssertEqual(heard.values, [570])
        }
    }
}
