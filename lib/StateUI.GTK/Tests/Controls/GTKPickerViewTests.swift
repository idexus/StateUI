// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// A picker whose choice a button of the program's changes too, saying what it heard.
private struct PickerPage: ContentView {
    let heard: Received<String>
    @State private var size = 1

    var content: any View {
        let heard = heard
        return VStack {
            Label("size \(size)")
            Picker(["S", "M", "L"])
                .selectedIndex($size)
                .onSelectedIndexChanged { heard.values.append("chose \($0)") }
            Button("Small").onClicked { size = 0 }
        }
    }
}

final class GTKPickerViewTests: XCTestCase {
    /// The picker lists its choices and shows the one the tree chose.
    func testAPickerListsItsChoicesAndShowsTheChosenOne() throws {
        try onUIThread {
            let host = GTKRenderer.running { PickerPage(heard: Received()) }
            let picker = try XCTUnwrap(host.views(GTKPickerView.self).first)

            XCTAssertEqual(picker.listed, ["S", "M", "L"])
            XCTAssertEqual(picker.chosen, 1)
        }
    }

    /// The user's choice is heard once and reaches the state; the program's is shown and heard by nobody.
    func testAUsersChoiceIsHeardAndTheProgramsIsNot() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = GTKRenderer.running { PickerPage(heard: heard) }
            let picker = try XCTUnwrap(host.views(GTKPickerView.self).first)

            picker.choose(2)
            host.settle { heard.values == ["chose 2"] && host.views(GTKLabelView.self).first?.text == "size 2" }
            XCTAssertEqual(heard.values, ["chose 2"])
            XCTAssertEqual(host.views(GTKLabelView.self).first?.text, "size 2", "the state took the user's choice")

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { picker.chosen == 0 }
            XCTAssertEqual(picker.chosen, 0, "the program's choice shown")
            XCTAssertEqual(heard.values, ["chose 2"], "and heard by nobody")
        }
    }
}

private extension GTKPickerView {
    /// The words the drop-down's list holds, in order.
    var listed: [String] {
        guard let model = gtk_drop_down_get_model(widget.opaque) else { return [] }
        return (0..<g_list_model_get_n_items(model)).map { place in
            String(cString: gtk_string_list_get_string(model, place))
        }
    }

    /// Chooses as the user's click in the list does.
    func choose(_ place: Int) {
        gtk_drop_down_set_selected(widget.opaque, guint(place))
    }
}
