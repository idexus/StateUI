// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

final class GTKCheckViewTests: XCTestCase {
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

    /// A radio button is drawn as a radio - GTK draws a check button so only in a group - and a check box as a box.
    func testARadioButtonIsDrawnAsARadio() {
        onUIThread {
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
