// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
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

final class WinUILeaveTests: XCTestCase {
    /// An element that leaves the tree lets go of its WinUI element: Swift holds one view fewer.
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        try onUIThread {
            let host = WinUIRenderer.running { NotePage() }
            let before = WinUIView.liveCount
            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), ["note"])

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            // A view's deinit is MainActor's, and runs in the turn after the one it left in.
            _ = host.runtime.core.runJobs()

            XCTAssertEqual(host.views(WinUILabelView.self).count, 0)
            XCTAssertEqual(WinUIView.liveCount, before - 1, "the label's view outlived its element")
        }
    }
}
