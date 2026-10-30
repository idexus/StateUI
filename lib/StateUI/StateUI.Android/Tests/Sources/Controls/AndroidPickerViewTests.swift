// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

final class AndroidPickerViewTests: XCTestCase {
    static var allTests: [(String, (AndroidPickerViewTests) -> () throws -> Void)] {
        [
            ("testTheFieldShowsTheChoiceOrTheTitleWithoutOne", testTheFieldShowsTheChoiceOrTheTitleWithoutOne),
            ("testAUsersChoiceIsReportedAndTheProgramsIsNot", testAUsersChoiceIsReportedAndTheProgramsIsNot),
            ("testARadioGroupOffersTheValuesAndTellsTheUsersCheck", testARadioGroupOffersTheValuesAndTellsTheUsersCheck),
        ]
    }

    /// The first row is the title: none chosen shows it, a choice shows the row after its index.
    func testTheFieldShowsTheChoiceOrTheTitleWithoutOne() throws {
        try onMainActor {
            let chosen = State<String?>(wrappedValue: nil)
            let host = AndroidRenderer.running {
                Picker(["S", "M", "L"], selection: chosen.projectedValue).placeholder("Size")
            }
            host.layOut()
            let picker = try XCTUnwrap(host.views(AndroidPickerView.self).first)
            XCTAssertEqual(Self.shown(by: picker), "Size")

            chosen.wrappedValue = "L"
            host.runtime.pump.turn()
            host.layOut()
            XCTAssertEqual(Self.shown(by: picker), "L")
        }
    }

    /// Android's echo of the program's choice - sent as it measures, or after its next layout - is kept back;
    /// the user's choice lands on the state as its value.
    func testAUsersChoiceIsReportedAndTheProgramsIsNot() throws {
        try onMainActor {
            let chosen = State(wrappedValue: "S")
            let heard = Received<String>()
            let written = Binding.Proxy(get: { chosen.wrappedValue }, set: { heard.values.append($0); chosen.wrappedValue = $0 })
            let host = AndroidRenderer.running {
                Picker(["S", "M", "L"], selection: written)
            }
            host.layOut()
            let picker = try XCTUnwrap(host.views(AndroidPickerView.self).first)
            XCTAssertEqual(heard.values, [], "Android's echo of the program's choice of S, as it measured")

            // What an application's first layout sends: the row a spinner starts on, then the program's again.
            Self.select(row: 0, on: picker)
            Self.select(row: 1, on: picker)
            XCTAssertEqual(heard.values, [], "a report of the row the program's choice stands on is its echo")

            Self.select(row: 3, on: picker)
            XCTAssertEqual(heard.values, ["L"])
            XCTAssertEqual(chosen.wrappedValue, "L")
        }
    }

    /// A picker offered as radio buttons is a radio group of the values, the program's check standing and the
    /// user's told as the value.
    func testARadioGroupOffersTheValuesAndTellsTheUsersCheck() throws {
        try onMainActor {
            let chosen = State(wrappedValue: "M")
            let host = AndroidRenderer.running {
                Picker(["S", "M", "L"], selection: chosen.projectedValue).presentation(.radio)
            }
            host.layOut()
            let picker = try XCTUnwrap(host.views(AndroidPickerView.self).first)
            XCTAssertEqual(picker.presentation, .radio)
            XCTAssertEqual(Java.callStaticInt(AndroidDriver.testPicker, AndroidDriver.checkedRadio, .object(picker.reference)), 1)

            Java.callStatic(AndroidDriver.testPicker, AndroidDriver.chooseRadio, .object(picker.reference), .int(2))
            XCTAssertEqual(chosen.wrappedValue, "L")
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
