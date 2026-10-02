// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// A page whose note a click takes away.
private struct NotePage: ContentView {
    @State private var shown = true

    var content: some View {
        VStack {
            if shown {
                Label("note")
            }
            Button("Hide")
                .onClicked { shown = false }
        }
    }
}

final class AppKitLeaveTests: XCTestCase {
    /// An element that leaves the tree lets go of its view: the host holds one view fewer alive, the count its
    /// tally writes.
    @MainActor
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        // AppKit autoreleases what it hands back - a walk of `subviews` an array of them: each pool drained here.
        let renderer = autoreleasepool { AppKitRenderer.running { NotePage() } }
        defer { renderer.closeForTesting() }
        let before = AppKitElement.liveViewCount

        autoreleasepool {
            XCTAssertEqual(renderer.nativeViews(AppKitLabelView.self).count, 1)
            renderer.nativeViews(AppKitButtonView.self).first?.clickForTesting()
            renderer.runtime.pump.turn()
            XCTAssertEqual(renderer.nativeViews(AppKitLabelView.self).count, 0)
        }

        XCTAssertEqual(AppKitElement.liveViewCount, before - 1, "the label's view outlived its element")
    }
}

#endif
