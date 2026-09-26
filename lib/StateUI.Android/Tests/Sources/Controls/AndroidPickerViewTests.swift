// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidPickerViewTests: XCTestCase {
    static var allTests: [(String, (AndroidPickerViewTests) -> () throws -> Void)] {
        [
            ("testTheFieldShowsTheChoiceOrTheTitleWithoutOne", testTheFieldShowsTheChoiceOrTheTitleWithoutOne),
            ("testAUsersChoiceIsReportedAndTheProgramsIsNot", testAUsersChoiceIsReportedAndTheProgramsIsNot),
        ]
    }

    /// The first row is the title: none chosen shows it, a choice shows the row after its index.
    func testTheFieldShowsTheChoiceOrTheTitleWithoutOne() throws {
        try onMainActor {
            let chosen = State(wrappedValue: -1)
            let host = AndroidRenderer.running {
                Picker(["S", "M", "L"]).selectedIndex(chosen.projectedValue).title("Size")
            }
            host.layOut()
            let picker = try XCTUnwrap(host.views(AndroidPickerView.self).first)
            XCTAssertEqual(Self.shown(by: picker), "Size")

            chosen.wrappedValue = 2
            host.pump()
            host.layOut()
            XCTAssertEqual(Self.shown(by: picker), "L")
        }
    }

    /// Android's echo of the program's choice - sent as it measures, or after its next layout - is kept back;
    /// the user's choice lands on the state and the handler.
    func testAUsersChoiceIsReportedAndTheProgramsIsNot() throws {
        try onMainActor {
            let chosen = State(wrappedValue: 0)
            let heard = Received<Int>()
            let host = AndroidRenderer.running {
                Picker(["S", "M", "L"])
                    .selectedIndex(chosen.projectedValue)
                    .onSelectedIndexChanged { heard.values.append($0) }
            }
            host.layOut()
            let picker = try XCTUnwrap(host.views(AndroidPickerView.self).first)
            XCTAssertEqual(heard.values, [], "Android's echo of the program's choice of S, as it measured")

            // What an application's first layout sends: the row a spinner starts on, then the program's again.
            Self.select(row: 0, on: picker)
            Self.select(row: 1, on: picker)
            XCTAssertEqual(heard.values, [], "a report of the row the program's choice stands on is its echo")

            Self.select(row: 3, on: picker)
            XCTAssertEqual(heard.values, [2])
            XCTAssertEqual(chosen.wrappedValue, 2)
        }
    }

    /// The words the closed field shows.
    @MainActor
    private static func shown(by picker: AndroidPickerView) -> String? {
        Java.frame {
            guard let field = Java.callObject(picker.reference, TestJava.getSelectedView) else { return nil }
            return Java.text(Java.callObject(field, JavaAPI.getText).flatMap { Java.callObject($0, JavaAPI.toString) })
        }
    }

    /// Android's report that `row` is selected, as it sends it after a layout.
    @MainActor
    private static func select(row: Int32, on picker: AndroidPickerView) {
        Java.call(
            picker.reference, TestJava.onItemSelected, .object(nil), .object(nil), .int(row), .long(Int64(row)))
    }
}
