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

    /// Words on a bar the tree paints stand light on a dark bar and dark on a light one, where the tree writes no
    /// colour for them (`BandWords`).
    @MainActor
    func testWordsOnAPaintedBarFollowHowDarkItIs() throws {
        let dark = State(wrappedValue: true)
        let (navy, yellow) = (Color(red: 0, green: 0, blue: 128), Color(red: 255, green: 230, blue: 0))
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                TitledPage(title: "Root")
            } destination: { _ in Label("Pushed") }
                .barBackgroundColor(dark.wrappedValue ? navy : yellow)
        }
        defer { host.finish() }
        let page = { (host.runtime.tree.root.flatMap { Self.first(.page, in: $0) }?.native as? UIKitElement)?.controller }
        let words = { () -> CGFloat? in
            let color = page()?.navigationItem.standardAppearance?.titleTextAttributes[.foregroundColor] as? UIColor
            var white: CGFloat = -1
            return color?.getWhite(&white, alpha: nil) == true ? white : nil
        }
        host.settle { words() != nil }
        XCTAssertEqual(words() ?? -1, 1, accuracy: 0.01, "light on navy")

        dark.wrappedValue = false
        host.settle { (words() ?? 1) < 0.01 }
        XCTAssertEqual(words() ?? -1, 0, accuracy: 0.01, "dark on yellow")
    }

    /// The first tabbed view in `element`'s tree.
    @MainActor
    private static func tabbedView(in element: MountedElement) -> MountedElement? {
        first(.tabbedView, in: element)
    }

    /// The first element of `type` in `element`'s tree.
    @MainActor
    private static func first(_ type: NodeType, in element: MountedElement) -> MountedElement? {
        element.type == type ? element : element.children.lazy.compactMap { first(type, in: $0) }.first
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
