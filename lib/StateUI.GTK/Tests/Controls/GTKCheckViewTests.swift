// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

final class GTKCheckViewTests: XCTestCase {
    /// The user's tick reaches the state and the handler once; the program's tick is heard by nobody.
    func testAUsersTickIsHeardAndTheProgramsIsNot() throws {
        try onUIThread {
            let ticked = State(wrappedValue: false)
            let heard = Received<Bool>()
            let host = GTKRenderer.running {
                VStack {
                    CheckBox(ticked.projectedValue).onToggled { heard.values.append($0) }
                    Button("Untick").onClicked { ticked.wrappedValue = false }
                }
            }
            let box = try XCTUnwrap(host.views(GTKCheckView.self).first)

            box.toggle()
            host.settle { ticked.wrappedValue }
            XCTAssertTrue(ticked.wrappedValue)
            XCTAssertEqual(heard.values, [true])

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { !box.isOn }
            XCTAssertFalse(box.isOn, "the state the button wrote reached the box")
            XCTAssertEqual(heard.values, [true], "and nobody heard it as the user's")
        }
    }

    /// A check box is the box and nothing else: it takes no caption's room.
    func testACheckBoxTakesItsBoxsRoomAlone() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { CheckBox(State(wrappedValue: true).projectedValue) }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let box = try XCTUnwrap(host.views(GTKCheckView.self).first)

            XCTAssertLessThanOrEqual(box.measure(width: nil, height: nil).width, 32, "no wider than its box")
            XCTAssertGreaterThan(box.measure(width: nil, height: nil).width, 0)
        }
    }

    /// The user checks one radio button of a named set: the one checked before reports it is off, then the new one
    /// that it is on, and the tree's choice follows.
    func testAUsersChoiceTakesTheGroupsOtherCheckAway() {
        onUIThread {
            let choice = State(wrappedValue: "Small")
            let heard = Received<String>()
            let host = GTKRenderer.running {
                VStack {
                    ForEach(["Small", "Large"]) { name in
                        RadioButton(name)
                            .groupName("size")
                            .isOn(choice.wrappedValue == name)
                            .onToggled { chosen in
                                heard.values.append("\(name) \(chosen)")
                                if chosen { choice.wrappedValue = name }
                            }
                            .id(name)
                    }
                }
            }
            let radios = host.views(GTKCheckView.self)
            XCTAssertEqual(radios.map(\.text), ["Small", "Large"])
            XCTAssertEqual(radios.map(\.isOn), [true, false])

            radios[1].toggle()
            host.settle { choice.wrappedValue == "Large" }

            XCTAssertEqual(heard.values, ["Small false", "Large true"])
            XCTAssertEqual(choice.wrappedValue, "Large")
            XCTAssertEqual(radios.map(\.isOn), [false, true])
        }
    }

    /// Buttons that name no set are a set with their siblings alone, and each change is heard once: GTK takes no
    /// check away itself, the host does.
    func testButtonsNamingNoSetAreOneWithTheirSiblings() {
        onUIThread {
            let heard = Received<String>()
            let host = GTKRenderer.running {
                VStack {
                    ForEach(["A", "B"]) { name in
                        RadioButton(name).isOn(name == "A").onToggled { heard.values.append("\(name) \($0)") }.id(name)
                    }
                    HStack {
                        RadioButton("C").isOn(true).onToggled { heard.values.append("C \($0)") }
                    }
                }
            }
            let radios = host.views(GTKCheckView.self)

            radios[1].toggle()
            host.settle { heard.values.count == 2 }

            XCTAssertEqual(heard.values, ["A false", "B true"])
            XCTAssertEqual(radios.map(\.isOn), [false, true, true], "C, beside no other, keeps its check")
        }
    }

    /// A radio button is drawn as a radio - GTK draws a check button so only in a group - and a check box as a box.
    func testARadioButtonIsDrawnAsARadio() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    CheckBox(State(wrappedValue: true).projectedValue)
                    RadioButton("Only").isOn(true)
                }
            }
            let views = host.views(GTKCheckView.self)

            XCTAssertEqual(views.map(\.indicator), ["check", "radio"])
        }
    }
}

private extension GTKCheckView {
    /// Turns the button as the user's click does.
    func toggle() {
        gtk_widget_activate(widget)
    }

    /// The CSS name of the indicator GTK draws: a box's "check", or "radio".
    var indicator: String {
        let first = gtk_widget_get_first_child(widget)
        return first.flatMap { gtk_widget_get_css_name($0) }.map { String(cString: $0) } ?? ""
    }
}
