// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance
import XCTest

/// A page whose note a click takes away.
private struct NotePage: View {
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
final class UIKitLeaveTests: XCTestCase {
    /// Every element shown and taken away twice leaves the host holding as many views as the first time.
    @MainActor
    func testEveryElementsViewIsLetGoOfEachTimeItLeaves() throws {
        let driver = UIKitDriver()
        defer { driver.finish() }
        // UIKit itself keeps every UIStepper it ever drew (iOS 27): one made by UIKit alone outlives its window too.
        let elements = Specimens.wearing(VisualElementContract.self).filter { $0 != "Stepper" }
        XCTAssertEqual(try Leaving.outlived(on: driver, elements), [])
    }

    /// An element that leaves the tree lets go of its view: the host holds one view fewer alive, the count its
    /// tally writes.
    @MainActor
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        // UIKit autoreleases what it hands back: each pool drained here.
        let host = autoreleasepool { UIKitRenderer.running { NotePage() } }
        defer { host.finish() }
        let before = UIKitElement.liveViewCount

        autoreleasepool {
            XCTAssertEqual(host.views(UIKitTextView.self).count, 1)
            host.views(UIKitButtonView.self).first?.sendActions(for: .primaryActionTriggered)
            host.settle { host.views(UIKitTextView.self).isEmpty }
        }

        XCTAssertEqual(UIKitElement.liveViewCount, before - 1, "the label's view outlived its element")
    }
}
