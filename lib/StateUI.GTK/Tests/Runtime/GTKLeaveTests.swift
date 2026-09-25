// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// A page whose note a click takes away.
struct NotePage: ContentView {
    @State private var shown = true

    var content: any View {
        VStack {
            if shown {
                Label("note")
            }
            Button("Hide")
                .onClicked { shown = false }
        }
    }
}

final class GTKLeaveTests: XCTestCase {
    /// An element that leaves the tree lets go of its widget: Swift holds one view fewer, and the panel one child.
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        try onUIThread {
            let host = GTKRenderer.running { NotePage() }
            let before = GTKView.liveCount
            XCTAssertEqual(host.views(GTKLabelView.self).map(\.text), ["note"])
            let stack = try XCTUnwrap(host.views(GTKStackView.self).first)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            // A view's deinit is MainActor's, and runs in the turn after the one it left in.
            _ = host.core.runJobs()

            XCTAssertEqual(host.views(GTKLabelView.self).count, 0)
            XCTAssertEqual(GTKView.liveCount, before - 1, "the label's view outlived its element")
            XCTAssertEqual(Self.children(of: stack.widget), 1, "the panel still holds the label's widget")
        }
    }

    private static func children(of widget: GTKWidget) -> Int {
        var count = 0
        var child = gtk_widget_get_first_child(widget)
        while let each = child {
            count += 1
            child = gtk_widget_get_next_sibling(each)
        }
        return count
    }
}
