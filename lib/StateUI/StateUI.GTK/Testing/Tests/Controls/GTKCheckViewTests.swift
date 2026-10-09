// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

@MainActor
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

    /// A switch, a check box and a slider draw what GTK draws in the accent - the track while on, the ticked box,
    /// the track up to the thumb - in their tint, and nothing in it where they have none.
    func testAControlDrawsItsAccentInItsTint() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Switch(true).tint(Color("#FF0000"))
                    CheckBox(State(wrappedValue: true).projectedValue).tint(Color("#FF0000"))
                    Slider(0.5).tint(Color("#FF0000")).width(200)
                    Switch(true)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let views: [GTKView] = host.views(GTKSwitchView.self) + host.views(GTKCheckView.self) + host.views(GTKSliderView.self)
            @MainActor func red(_ view: GTKView) -> Bool {
                host.layOut()
                let size = view.frame
                var grid: [(Double, Double)] = []
                for x in 0..<10 {
                    for y in 0..<10 {
                        grid.append((size.width * (Double(x) + 0.5) / 10, size.height * (Double(y) + 0.5) / 10))
                    }
                }
                return view.pixels(at: grid).contains { near($0, 0xFFFF_0000, within: 8) }
            }
            host.settle { red(views[0]) }

            XCTAssertEqual(views.map(red), [true, false, true, true], "the switches, the box, the slider")
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
