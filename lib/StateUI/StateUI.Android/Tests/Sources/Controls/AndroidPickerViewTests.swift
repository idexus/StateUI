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
            ("testAChoicesLookComesGoesAndReachesNewOptions", testAChoicesLookComesGoesAndReachesNewOptions),
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
            let sizes = ["S", "M", "L"]
            let host = AndroidRenderer.running {
                Picker(sizes, selection: chosen.projectedValue)
                    .onSelectionChanged { heard.values.append(chosen.wrappedValue) }
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

    /// Radio buttons and segments take the words' size and color they are given, the platform's again once they are
    /// given none, and options that come after take the look given.
    func testAChoicesLookComesGoesAndReachesNewOptions() throws {
        try onMainActor {
            for presentation in [PickerPresentation.radio, .segmented] {
                let host = AndroidRenderer.running {
                    Picker(["S", "M"], selection: State(wrappedValue: "S").projectedValue).presentation(presentation)
                }
                let picker = try XCTUnwrap(host.views(AndroidPickerView.self).first)
                @MainActor func looks() -> [String] {
                    let count = Java.callInt(picker.reference, TestJava.getChildCount)
                    return (0..<count).map { index in
                        Java.frame {
                            guard let button = Java.callObject(picker.reference, TestJava.getChildAt, .int(index)) else {
                                return "none"
                            }
                            let size = Java.callFloat(button, TestJava.getTextSize)
                            let color = UInt32(bitPattern: Java.callInt(button, TestJava.getCurrentTextColor))
                            return "\(Int(size)) #\(String(color, radix: 16))"
                        }
                    }
                }
                let platform = looks()
                var big = TextLook()
                big.size = 30
                big.color = .color(red: 255, green: 0, blue: 0, alpha: 255)

                picker.setLook(big, alignment: .start)
                let given = looks()
                XCTAssertTrue(given.allSatisfy { $0.hasSuffix("#ffff0000") }, "\(presentation) given: \(given)")
                XCTAssertNotEqual(given, platform)
                picker.setLook(TextLook(), alignment: .start)
                XCTAssertEqual(looks(), platform, "\(presentation): the platform's again")

                picker.setLook(big, alignment: .start)
                picker.setChoices(["S", "M", "L"], chosen: 0, writeChosen: true, title: "")
                XCTAssertEqual(looks(), [given[0], given[0], given[0]], "\(presentation): new options take the look")
            }
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
