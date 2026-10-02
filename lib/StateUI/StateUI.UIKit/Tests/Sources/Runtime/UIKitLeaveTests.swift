// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
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

final class UIKitLeaveTests: XCTestCase {
    /// An element that leaves the tree lets go of its view: the host holds one view fewer alive, the count its
    /// tally writes.
    @MainActor
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        // UIKit autoreleases what it hands back: each pool drained here.
        let host = autoreleasepool { UIKitRenderer.running { NotePage() } }
        defer { host.finish() }
        let before = UIKitElement.liveViewCount

        autoreleasepool {
            XCTAssertEqual(host.views(UIKitLabelView.self).count, 1)
            host.views(UIKitButtonView.self).first?.sendActions(for: .primaryActionTriggered)
            host.settle { host.views(UIKitLabelView.self).isEmpty }
        }

        XCTAssertEqual(UIKitElement.liveViewCount, before - 1, "the label's view outlived its element")
    }
}
