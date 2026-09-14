// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitWindowContentTests: XCTestCase {
    @MainActor
    func testOverlayUsesChildAlignmentWithoutReplacingThePage() {
        let page = NSView()
        let panel = NSButton()
        let content = AppKitWindowContentView()
        content.frame = NSRect(x: 0, y: 0, width: 200, height: 100)

        content.set(
            page: page,
            overlay: AppKitLayoutItem(
                view: panel,
                horizontal: 2,
                vertical: 3,
                width: 60))
        content.layoutSubtreeIfNeeded()

        XCTAssertEqual(page.frame, content.bounds)
        XCTAssertEqual(panel.frame, NSRect(x: 140, y: 0, width: 60, height: 100))
        XCTAssertTrue(content.hitTest(NSPoint(x: 10, y: 10)) === page)
        XCTAssertTrue(content.hitTest(NSPoint(x: 170, y: 10)) === panel)
    }

    @MainActor
    func testRemovingOverlayKeepsTheSamePageAndRemovesOnlyThePanel() {
        let page = NSView()
        let panel = NSButton()
        let content = AppKitWindowContentView()
        content.set(page: page, overlay: AppKitLayoutItem(view: panel))

        content.set(page: page, overlay: nil)

        XCTAssertTrue(page.superview === content)
        XCTAssertNil(panel.superview)
        XCTAssertEqual(content.subviews.count, 1)
    }

    @MainActor
    func testWindowPatchPresentsOverlayAboveItsStablePage() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(withOverlay: true))

        let nativeWindow = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(nativeWindow.contentView as? AppKitWindowContentView)
        let page = try XCTUnwrap(renderer.viewForTesting(id: .manual("page")))
        let panel = try XCTUnwrap(renderer.viewForTesting(id: .manual("panel")))

        XCTAssertTrue(page.superview === content)
        XCTAssertTrue(panel.isDescendant(of: content))

        renderer.applyForTesting(tree(withOverlay: false))

        XCTAssertTrue(page.superview === content)
        XCTAssertNil(panel.superview)
    }

    @MainActor
    func testTransparentOverlayLayoutLetsUnusedAreaReachThePage() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var action = HostPatch(id: .manual("action"), type: .button)
        action.properties = [
            .text: .string("Inspector action"),
            .width: .number(120),
            .height: .number(32),
            .horizontalAlignment: .enumeration(2),
            .verticalAlignment: .enumeration(2),
        ]
        var panel = HostPatch(id: .manual("panel"), type: .grid)
        panel.properties = [
            .letsInputThrough: .bool(true),
        ]
        panel.children = .arranged([action])
        var overlay = HostPatch(id: .manual("overlay"), type: .overlay)
        overlay.children = .arranged([panel])

        renderer.applyForTesting(tree(overlay: overlay))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let content = try XCTUnwrap(window.contentView as? AppKitWindowContentView)
        let body = try XCTUnwrap(renderer.viewForTesting(id: .manual("body")))
        let panelView = try XCTUnwrap(renderer.viewForTesting(id: .manual("panel")))
        let panelLayout = try XCTUnwrap(panelView as? AppKitGridView)
        let button = try XCTUnwrap(renderer.viewForTesting(id: .manual("action")))
        content.frame = NSRect(x: 0, y: 0, width: 300, height: 180)
        content.layoutSubtreeIfNeeded()

        let backgroundPoint = content.convert(NSPoint(x: 10, y: 10), to: content.superview)
        let backgroundHit = content.hitTest(backgroundPoint)
        let actionPoint = button.convert(
            NSPoint(x: button.bounds.midX, y: button.bounds.midY),
            to: content.superview)
        let actionHit = content.hitTest(actionPoint)
        XCTAssertTrue(panelLayout.inputTransparencyForTesting.transparent)
        XCTAssertFalse(panelLayout.inputTransparencyForTesting.cascades)
        XCTAssertTrue(
            backgroundHit === body,
            "background hit \(String(describing: backgroundHit)); panel \(panelView.frame), body \(body.frame)")
        XCTAssertTrue(
            actionHit === button,
            "action hit \(String(describing: actionHit)); panel \(panelView.frame), button \(button.frame)")
    }

    private func tree(withOverlay: Bool) -> HostPatch {
        let body = HostPatch(id: .manual("body"), type: .colorBox)
        var page = HostPatch(id: .manual("page"), type: .page)
        page.children = .arranged([body])

        var window = HostPatch(id: .manual("window"), type: .window)
        if withOverlay {
            var panel = HostPatch(id: .manual("panel"), type: .colorBox)
            panel.properties[.width] = .number(60)
            panel.properties[.horizontalAlignment] = .enumeration(2)
            var overlay = HostPatch(id: .manual("overlay"), type: .overlay)
            overlay.children = .arranged([panel])
            window.children = .arranged([page, overlay])
        } else {
            window.children = .arranged([page])
        }

        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    private func tree(overlay: HostPatch) -> HostPatch {
        let body = HostPatch(id: .manual("body"), type: .colorBox)
        var page = HostPatch(id: .manual("page"), type: .page)
        page.children = .arranged([body])
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([page, overlay])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }
}

#endif
