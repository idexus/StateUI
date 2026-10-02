// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance
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

/// A page whose button a click takes away.
private struct ButtonNotePage: ContentView {
    @State private var shown = true

    var content: some View {
        VStack {
            if shown {
                Button("note").fontSize(17)
            }
            Button("Hide")
                .onClicked { shown = false }
        }
    }
}

/// A page that shows `element` and takes it away again, a click each way.
private struct ComingAndGoing: ContentView {
    let element: String
    @State private var shown = true

    var content: some View {
        VStack {
            if shown {
                Specimens.view(element)
            }
            Button("Toggle")
                .onClicked { shown.toggle() }
        }
    }
}

final class UIKitLeaveTests: XCTestCase {
    /// Every view a page shows and takes away is let go of each time: shown and taken away twice, the host holds
    /// as many views as after the first time.
    @MainActor
    func testEveryElementsViewIsLetGoOfEachTimeItLeaves() throws {
        // UIKit itself keeps every UIStepper it ever drew (iOS 27): one made by UIKit alone outlives its window too.
        for element in Specimens.wearing(VisualElementContract.self) where element != "Map" && element != "Stepper" {
            let host = autoreleasepool { UIKitRenderer.running { ComingAndGoing(element: element) } }
            func toggled() -> Int {
                autoreleasepool {
                    host.views(UIKitButtonView.self).last?.sendActions(for: .primaryActionTriggered)
                    host.settle { false }
                }
                return UIKitElement.liveViewCount
            }
            let once = toggled()
            _ = toggled()
            XCTAssertEqual(toggled(), once, "\(element)'s views outlived it")
            host.finish()
        }
    }

    /// A button that leaves the tree is let go of with its element: its look holds no reference back to it.
    @MainActor
    func testAButtonIsLetGoOfWhenItsElementLeaves() throws {
        let host = autoreleasepool { UIKitRenderer.running { ButtonNotePage() } }
        defer { host.finish() }
        let before = UIKitElement.liveViewCount

        autoreleasepool {
            XCTAssertEqual(host.views(UIKitButtonView.self).count, 2)
            host.views(UIKitButtonView.self).last?.sendActions(for: .primaryActionTriggered)
            host.settle { host.views(UIKitButtonView.self).count == 1 }
        }

        XCTAssertEqual(UIKitElement.liveViewCount, before - 1, "the button's view outlived its element")
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
            XCTAssertEqual(host.views(UIKitLabelView.self).count, 1)
            host.views(UIKitButtonView.self).first?.sendActions(for: .primaryActionTriggered)
            host.settle { host.views(UIKitLabelView.self).isEmpty }
        }

        XCTAssertEqual(UIKitElement.liveViewCount, before - 1, "the label's view outlived its element")
    }
}
