// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// What pages and their arrangements say on UIKit's bars and the window's scene.
final class UIKitPagesTests: XCTestCase {
    /// Tabs pushed onto a stack are its last place and name the window by their own title, on the bar and the
    /// scene alike - never by what they show: their pages name their tabs alone.
    @MainActor
    func testTabsOnAStackNameTheWindowByTheirOwnTitle() throws {
        let path = State(wrappedValue: [Int]())
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(path.projectedValue) {
                TitledPage(title: "Items and Cards")
            } destination: { _ in
                TabbedView([1, 2]) { number in TitledPage(title: "Example \(number)") }.title("ItemsView")
            }
        }
        defer { host.finish() }
        let window: UIWindow = try XCTUnwrap(host.roster.windows.first?.1.window)
        host.settle { window.windowScene?.title == "Items and Cards" }
        XCTAssertEqual(window.windowScene?.title, "Items and Cards")

        path.wrappedValue = [1]
        let pushed: () -> UIViewController? = {
            (host.runtime.tree.root.flatMap { Self.tabbedView(in: $0) }?.native as? UIKitElement)?.controller
        }
        host.settle { pushed() != nil }
        host.runtime.pump.turn()
        let tabs: UIViewController = try XCTUnwrap(pushed())
        XCTAssertEqual(tabs.navigationItem.title, "ItemsView", "the bar's title")
        XCTAssertEqual(window.windowScene?.title, "ItemsView", "the scene's")
    }

    /// The first tabbed view in `element`'s tree.
    @MainActor
    private static func tabbedView(in element: MountedElement) -> MountedElement? {
        element.type == .tabbedView ? element : element.children.lazy.compactMap { tabbedView(in: $0) }.first
    }
}

/// A page that names itself.
private struct TitledPage: ContentView {
    let title: String

    @Environment private var page: PageSession

    var content: any View {
        let title = self.title
        let page = self.page
        return Label(title).onCreated { page.title = title }
    }
}
