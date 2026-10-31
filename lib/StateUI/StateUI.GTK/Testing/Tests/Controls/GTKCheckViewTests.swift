// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGTKTesting
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

    /// A toggle's words stand beside it - a check box's in the button, a switch's at its start and the switch at
    /// its end, mirrored right to left - and name it; a click on a switch's words turns it.
    func testATogglesWordsStandBesideIt() throws {
        try onUIThread {
            let on = State(wrappedValue: false)
            let host = GTKRenderer.running {
                VStack {
                    Switch(on.projectedValue).text("Wi-Fi").width(300)
                    CheckBox(true).text("agree").textCase(.uppercase)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let toggle = try XCTUnwrap(host.views(GTKSwitchView.self).first)
            XCTAssertEqual(try XCTUnwrap(host.views(GTKCheckView.self).first).text, "AGREE")
            XCTAssertEqual(toggle.text, "Wi-Fi")
            let named = stateui_test_accessible_property_is_words(
                UnsafeMutableRawPointer(toggle.control.opaque), Int32(GTK_ACCESSIBLE_PROPERTY_LABEL.rawValue), "Wi-Fi")
            XCTAssertNil(named, "the switch named by its words")
            g_free(named)

            host.layOut()
            XCTAssertEqual(toggle.place(of: toggle.caption).minX, 0, "the words from the start")
            XCTAssertEqual(toggle.place(of: toggle.control).maxX, 300, "the switch at the end")
            toggle.setDirection(GTK_TEXT_DIR_RTL)
            host.layOut()
            XCTAssertEqual(toggle.place(of: toggle.control).minX, 0, "the switch at the end, right to left")

            toggle.clickWords()
            host.settle { on.wrappedValue }
            XCTAssertTrue(on.wrappedValue, "a click on the words turns it")
        }
    }

    /// A switch takes no background, as its register says: GTK paints its box as its track, which a color there
    /// would recolor.
    func testASwitchTakesNoBackground() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack { Switch(true).background(Color(hex: 0xFF0000)) }
            }
            let toggle = host.views(GTKSwitchView.self)[0]
            XCTAssertFalse(
                GTKTestHost.classes(of: toggle.widget).contains { $0.hasPrefix("stateui-fill") },
                "the switch wears a fill: \(GTKTestHost.classes(of: toggle.widget))")
        }
    }

    /// A switch, a check box and a slider draw what GTK draws in the accent - the track while on, the ticked box,
    /// the track up to the thumb - in their tint, and nothing in it where they have none.
    func testAControlDrawsItsAccentInItsTint() {
        onUIThread {
            let ticked = State(wrappedValue: true)
            let host = GTKRenderer.running {
                VStack {
                    Switch(true).tint(Color(hex: 0xFF0000))
                    CheckBox(ticked.projectedValue).tint(Color(hex: 0xFF0000))
                    Slider(0.5).tint(Color(hex: 0xFF0000)).width(200)
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

}

private extension GTKSwitchView {
    /// Where `part` stands in the switch's row.
    func place(of part: GTKWidget) -> (minX: Double, maxX: Double) {
        var bounds = graphene_rect_t()
        _ = gtk_widget_compute_bounds(part, widget, &bounds)
        return (Double(bounds.origin.x), Double(bounds.origin.x + bounds.size.width))
    }
}
