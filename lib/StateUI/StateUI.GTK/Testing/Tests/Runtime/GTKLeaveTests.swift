// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
@_spi(Host) import StateUIConformance
import XCTest

/// A page whose note a click takes away.
struct NotePage: View {
    @State private var shown = true

    var body: some View {
        VStack {
            if shown {
                Text("note")
            }
            Button("Hide")
                .onClicked { shown = false }
        }
    }
}

@MainActor
final class GTKLeaveTests: XCTestCase {
    /// An element that leaves the tree lets go of its widget: Swift holds one view fewer, and the panel one child.
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        try onUIThread {
            let host = GTKRenderer.running { NotePage() }
            let before = GTKView.liveCount
            XCTAssertEqual(host.views(GTKTextView.self).map(\.text), ["note"])
            let stack = try XCTUnwrap(host.views(GTKStackView.self).first)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            // A view's deinit is MainActor's, and runs in the turn after the one it left in.
            _ = host.runtime.core.runJobs()

            XCTAssertEqual(host.views(GTKTextView.self).count, 0)
            XCTAssertEqual(GTKView.liveCount, before - 1, "the label's view outlived its element")
            XCTAssertEqual(Self.children(of: stack.widget), 1, "the panel still holds the label's widget")
        }
    }

    /// Every element shown and taken away twice leaves the host holding as many views as the first time.
    func testEveryElementsViewIsLetGoOfEachTimeItLeaves() throws {
        try onUIThread {
            XCTAssertEqual(try Leaving.outlived(on: GTKDriver()), [])
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
