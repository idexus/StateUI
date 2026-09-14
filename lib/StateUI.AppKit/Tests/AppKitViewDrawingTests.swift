// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// AppKit rewrites a layer-backed view's transform and opacity whenever its
/// frame or alpha moves. What StateUI draws over the frame must survive
/// that, pivot where StateUI says, compose with a placement, and leave the
/// layer AppKit's own.
final class AppKitViewDrawingTests: XCTestCase {
    @MainActor
    func testADrawingTransformSurvivesItsViewsFrameMoving() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(stack(box(rotation: 30))))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))

        for step in 1...3 {
            native.frame = NSRect(x: CGFloat(step * 7), y: 0, width: 100 + CGFloat(step), height: 60)
            XCTAssertEqual(try rotation(of: native), 30, accuracy: 0.001)
        }
    }

    @MainActor
    func testARotationPivotsAboutTheAnchor() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var cornered = box(id: "cornered", rotation: 90)
        cornered.properties[.pivotX] = .number(0)
        cornered.properties[.pivotY] = .number(0)
        renderer.applyForTesting(tree(stack(box(rotation: 90), cornered)))
        let centred = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        let turned = try XCTUnwrap(renderer.viewForTesting(id: .manual("cornered")))
        centred.frame = NSRect(x: 0, y: 0, width: 100, height: 60)
        turned.frame = NSRect(x: 0, y: 0, width: 100, height: 60)

        assertPoint(try drawn(CGPoint(x: 0, y: 0), in: centred), CGPoint(x: 80, y: -20))
        assertPoint(try drawn(CGPoint(x: 50, y: 30), in: centred), CGPoint(x: 50, y: 30))
        assertPoint(try drawn(CGPoint(x: 100, y: 0), in: turned), CGPoint(x: 0, y: 100))
    }

    @MainActor
    func testAPlacementIsDrawnOverTheViewsOwnTransform() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var own = box(rotation: 10)
        own.properties[.opacity] = .number(0.5)
        var layout = HostPatch(id: .manual("layout"), type: .absoluteLayout)
        layout.driven = .replace([
            .absoluteLayoutBounds: HostStateBinding(state: 95, mode: .out, kind: .placement),
        ])
        layout.children = .arranged([own])
        renderer.applyForTesting(tree(layout))
        let run = PlacedRun([Placement(Rect(0, 0, 100, 60), transform: .rotate(30), opacity: 0.5)])
        renderer.applyStateForTesting(95, value: run.carried)

        let nativeLayout = try XCTUnwrap(renderer.viewForTesting(id: .manual("layout")))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        nativeLayout.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        nativeLayout.layoutSubtreeIfNeeded()

        XCTAssertEqual(try rotation(of: native), 40, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(native.layer).opacity, 0.25, accuracy: 0.0001)

        native.alphaValue = 0.5
        native.alphaValue = 0.5
        XCTAssertEqual(try XCTUnwrap(native.layer).opacity, 0.25, accuracy: 0.0001)
    }

    /// Every control keeps the backing layer AppKit makes for it - the one
    /// that draws its content at the screen's scale - and still wears its
    /// drawing transform after its frame moves.
    @MainActor
    func testEveryControlKeepsAppKitsLayerAndItsDrawing() throws {
        let appKitLayer = String(describing: type(of: NSView().makeBackingLayer()))
        let pages: Set<NodeType> = [.page, .navigationStack, .tabbedView, .splitView]
        let drawn = HostContract.controls
            .filter { $0.value != .structure && $0.value != .provider }
            .keys.sorted()

        for node in drawn {
            let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
            var control = HostPatch(id: .manual("control"), type: node)
            control.properties[.rotation] = .number(30)
            renderer.applyForTesting(pages.contains(node) ? windowTree(page: control) : tree(control))
            if let view = renderer.viewForTesting(id: .manual("control")) {
                view.wantsLayer = true
                let layer = try XCTUnwrap(view.layer, node.name)
                XCTAssertEqual(String(describing: type(of: layer)), appKitLayer, node.name)

                view.frame = NSRect(x: 3, y: 4, width: 90, height: 50)
                XCTAssertEqual(abs(try rotation(of: view)), 30, accuracy: 0.001, node.name)
            }
            renderer.closeForTesting()
        }
    }

    // MARK: - Helpers

    private func windowTree(page: HostPatch) -> HostPatch {
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([page])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    private func box(id: String = "box", rotation: Double) -> HostPatch {
        var box = HostPatch(id: .manual(id), type: .boxView)
        box.properties[.rotation] = .number(rotation)
        box.properties[.width] = .number(100)
        box.properties[.height] = .number(60)
        return box
    }

    private func stack(_ children: HostPatch...) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged(children)
        return stack
    }

    /// The in-plane turn the layer draws with, in degrees.
    @MainActor
    private func rotation(of view: NSView) throws -> Double {
        let transform = CATransform3DGetAffineTransform(try XCTUnwrap(view.layer).transform)
        return atan2(Double(transform.b), Double(transform.a)) * 180 / .pi
    }

    /// Where the layer draws a point of the view, relative to its origin, in
    /// its flipped superview's space.
    @MainActor
    private func drawn(_ point: CGPoint, in view: NSView) throws -> CGPoint {
        XCTAssertTrue(view.superview?.isFlipped == true)
        let transform = CATransform3DGetAffineTransform(try XCTUnwrap(view.layer).transform)
        return point.applying(transform)
    }

    private func assertPoint(
        _ actual: CGPoint,
        _ expected: CGPoint,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.001, file: file, line: line)
    }
}
#endif
