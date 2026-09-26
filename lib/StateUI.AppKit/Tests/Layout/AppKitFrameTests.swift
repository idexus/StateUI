// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

final class AppKitFrameTests: XCTestCase {
    @MainActor
    func testFrameReportUsesParentWindowAndSafeAreaCoordinates() throws {
        var reports: [[HostValue]] = []
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, payload in reports.append(payload) })
        defer { renderer.closeForTesting() }

        var patch = HostPatch(id: .manual("measured"), type: .label)
        patch.properties = [.text: .string("Measured")]
        patch.events = .replace([.frameChanged: 50])
        renderer.applyForTesting(patch)
        let node = try XCTUnwrap(renderer.rootElementForTesting)
        let measured = try XCTUnwrap(node.view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: .borderless,
            backing: .buffered,
            defer: false)
        let root = InsetFrameRoot(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        window.contentView = root
        let parent = FlippedFrameView(frame: NSRect(x: 25, y: 30, width: 300, height: 200))
        root.addSubview(parent)
        parent.addSubview(measured)
        measured.frame = NSRect(x: 10, y: 20, width: 100, height: 40)

        node.flushFrameReportForTesting()

        guard case .numbers(let values)? = reports.last?.first else {
            return XCTFail("the native frame was not reported")
        }
        XCTAssertEqual(values, [10, 20, 100, 40, 35, 50, 30, 40])
    }

    @MainActor
    func testAnAncestorMoveQueuesAFrameReportForAStationaryChild() throws {
        var reports: [[HostValue]] = []
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, payload in reports.append(payload) })
        defer { renderer.closeForTesting() }

        var patch = HostPatch(id: .manual("measured"), type: .label)
        patch.events = .replace([.frameChanged: 51])
        renderer.applyForTesting(patch)
        let node = try XCTUnwrap(renderer.rootElementForTesting)
        let measured = try XCTUnwrap(node.view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: .borderless,
            backing: .buffered,
            defer: false)
        let root = FlippedFrameView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        window.contentView = root
        let parent = FlippedFrameView(frame: NSRect(x: 20, y: 20, width: 200, height: 100))
        root.addSubview(parent)
        parent.addSubview(measured)
        measured.frame = NSRect(x: 5, y: 6, width: 40, height: 20)
        node.flushFrameReportForTesting()
        reports.removeAll()

        parent.frame.origin.y = 70
        XCTAssertTrue(node.frameReportQueuedForTesting)
        node.flushFrameReportForTesting()

        guard case .numbers(let values)? = reports.last?.first else {
            return XCTFail("moving an ancestor did not report the changed global frame")
        }
        XCTAssertEqual(Array(values.prefix(4)), [5, 6, 40, 20])
        XCTAssertEqual(Array(values[4..<6]), [25, 76])
    }
}

@MainActor
private class FlippedFrameView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class InsetFrameRoot: FlippedFrameView {
    override var safeAreaRect: NSRect {
        NSRect(x: 5, y: 10, width: bounds.width - 5, height: bounds.height - 10)
    }
}

#endif
