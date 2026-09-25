// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// A group whose words for assistive technology a button takes away.
private struct SaidPage: ContentView {
    @State private var said = true

    var content: any View {
        VStack {
            if said {
                VStack { Label("Title") }.accessibilityLabel("The title").accessibilityHint("Names the page").id("group")
            } else {
                VStack { Label("Title") }.id("group")
            }
            Button("Quiet").onClicked { said = false }
        }
    }
}

final class GTKAccessibilityTests: XCTestCase {
    /// An element's label, hint and heading level reach GTK's accessible; where it says nothing, it holds only
    /// GTK's own - a group none.
    func testAnElementsWordsReachAssistiveTechnology() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    VStack { Label("Title") }.accessibilityLabel("The title").accessibilityHint("Names the page")
                    Label("Title").accessibilityHeadingLevel(.level2)
                    VStack { Label("Plain") }
                }
            }
            let root = host.views(GTKStackView.self)[0]
            let views = GTKTestHost.children(of: root.widget)

            XCTAssertEqual(views.map(\.said), ["label description", "label heading", ""], "a heading named by its words")
        }
    }

    /// Words the element no longer says are taken back.
    func testWordsNoLongerSaidAreTakenBack() throws {
        try onUIThread {
            let host = GTKRenderer.running { SaidPage() }
            let group = try XCTUnwrap(host.views(GTKStackView.self).first { $0.said != "" })
            XCTAssertEqual(group.widget.said, "label description")

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.runtime.pump.turn()

            XCTAssertEqual(group.widget.said, "")
        }
    }
}

private extension GTKView {
    var said: String { widget.said }
}

private extension UnsafeMutablePointer where Pointee == GtkWidget {
    /// What GTK's accessible holds of the words: a label, a description, a heading's role and level. GTK's test
    /// interface says only whether each is set, and every widget holds a hidden state of its own.
    var said: String {
        let accessible = opaque
        var said: [String] = []
        if gtk_test_accessible_has_property(accessible, GTK_ACCESSIBLE_PROPERTY_LABEL) != 0 { said.append("label") }
        if gtk_test_accessible_has_property(accessible, GTK_ACCESSIBLE_PROPERTY_DESCRIPTION) != 0 {
            said.append("description")
        }
        if gtk_test_accessible_has_role(accessible, GTK_ACCESSIBLE_ROLE_HEADING) != 0,
           gtk_test_accessible_has_property(accessible, GTK_ACCESSIBLE_PROPERTY_LEVEL) != 0 {
            said.append("heading")
        }
        return said.joined(separator: " ")
    }
}
