// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

@MainActor
final class AppKitFrameTests: XCTestCase {
    /// Turns the host until `done` holds: its jobs, its pump, and a display frame each turn.
    @MainActor
    private func settle(_ renderer: AppKitRenderer, until done: () -> Bool) {
        for _ in 0..<150 {
            guard !done() else { break }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            renderer.runtime.pump.turn()
            renderer.displayFrameForTesting()
        }
    }

    /// A view says nothing of where it stands before a layout places it: the first report its handler hears is
    /// where it is laid out.
    @MainActor
    func testAViewSaysNothingBeforeItIsLaidOut() {
        let heard = Received<[Double]>()
        let renderer = AppKitRenderer.running {
            VStack {
                Rectangle().fill(.steelBlue).width(120).height(60)
                    .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { renderer.closeForTesting() }
        settle(renderer) { !heard.values.isEmpty }

        XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 0, 120, 60])
    }

    /// A view that joins a shown page says nothing before its layout either: a display frame comes before the
    /// layout pass that places it.
    @MainActor
    func testAViewThatJoinsSaysNothingBeforeItIsLaidOut() {
        let heard = Received<[Double]>()
        let shown = State(wrappedValue: false)
        let renderer = AppKitRenderer.running {
            VStack {
                Text("above").height(20)
                if shown.wrappedValue {
                    Rectangle().fill(.steelBlue).width(120).height(60)
                        .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
                }
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { renderer.closeForTesting() }
        shown.wrappedValue = true
        settle(renderer) { heard.values.count >= 2 || heard.values.first?[2] == 120 }

        XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 20, 120, 60])
    }

    /// A view on a sheet says where it stands as the sheet is laid out, before it draws, as on a window: the sheet's
    /// root is a window's, so what the report changes draws in the same frame.
    @MainActor
    func testAViewOnASheetSaysWhereItStandsAsTheSheetIsLaidOut() throws {
        let heard = Received<[Double]>()
        let sheets = State(wrappedValue: [1])
        let renderer = AppKitRenderer.running {
            ModalStack(sheets.projectedValue) {
                Text("home")
            } destination: { _ in
                VStack {
                    Rectangle().fill(.steelBlue).width(120).height(60)
                        .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
        }
        defer { renderer.closeForTesting() }
        let sheet = try XCTUnwrap(renderer.windowsForTesting.first?.modals.first?.window?.contentView)

        sheet.layoutSubtreeIfNeeded()

        XCTAssertTrue(sheet is AppKitWindowContentView, "the sheet's root is a window's")
        XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 0, 120, 60], "said as it is laid out")
    }

    /// A list's scroll moves its rows with no layout: a view in a row says where it stands once the list moved - by
    /// less than a row, so no row coming into view lays anything out.
    @MainActor
    func testAViewInAListSaysWhereItStandsOnceTheListMoved() throws {
        let heard = Received<[Double]>()
        let renderer = AppKitRenderer.running {
            VStack {
                ItemsView(0..<100) { item in
                    Rectangle().fill(item == 2 ? .firebrick : .steelBlue).width(120).height(60)
                        .onEvent(ViewContract.frameChanged) { if item == 2 { heard.values.append($0) } }
                }
                .width(200).height(300)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { renderer.closeForTesting() }
        settle(renderer) { !heard.values.isEmpty }
        let before = try XCTUnwrap(heard.values.last)
        let scroller = try XCTUnwrap(renderer.nativeViews(AppKitItemsView.self).first?.collection.enclosingScrollView)

        scroller.contentView.scroll(to: NSPoint(x: 0, y: 30))
        scroller.reflectScrolledClipView(scroller.contentView)
        settle(renderer) { heard.values.last?[5] != before[5] }

        let after = try XCTUnwrap(heard.values.last)
        XCTAssertEqual(after[5], before[5] - 30, "30 higher in its window")
        XCTAssertEqual(Array(after.prefix(4)), Array(before.prefix(4)), "where it was in its cell")
    }

    /// A split view's pane its split view alone resized - the divider moving, as each frame of the sidebar's slide
    /// moves it - lets what reads a frame in it say where it stands in that layout pass, before the window draws: no
    /// display frame comes between.
    @MainActor
    func testAViewInAPaneTheSplitViewResizedSaysWhereItStandsInThatPass() throws {
        let heard = Received<[Double]>()
        let shown = State(wrappedValue: true)
        let renderer = AppKitRenderer.running {
            SplitView(shown.projectedValue) {
                Text("Menu")
            } detail: {
                Rectangle().fill(.steelBlue)
                    .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
            }
        }
        defer { renderer.closeForTesting() }
        let split = try XCTUnwrap(renderer.nativeViews(AppKitSplitView.self).first)
        settle(renderer) { split.isEffectivelyPresentedForTesting && !heard.values.isEmpty }
        renderer.displayFrameForTesting()
        let before = try XCTUnwrap(heard.values.last?[2])
        let divider = split.splitController.splitViewItems[0].viewController.view.frame.maxX

        split.splitController.splitView.setPosition(divider + 40, ofDividerAt: 0)
        split.splitController.splitView.layoutSubtreeIfNeeded()

        XCTAssertLessThan(try XCTUnwrap(heard.values.last?[2]), before, "said in the pass that narrowed it")
    }

    @MainActor
    func testFrameReportUsesParentWindowAndSafeAreaCoordinates() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var patch = HostPatch(id: .manual("measured"), type: .text)
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

        XCTAssertEqual(node.frameNumbers(), [10, 20, 100, 40, 35, 50, 30, 40])
    }

    @MainActor
    func testAnAncestorMoveQueuesAFrameReportForAStationaryChild() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var patch = HostPatch(id: .manual("measured"), type: .text)
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
        renderer.displayFrameForTesting()

        parent.frame.origin.y = 70
        XCTAssertTrue(renderer.runtime.frames.wantsFrames, "moving an ancestor asks the display's frame for a report")
        let values = try XCTUnwrap(node.frameNumbers())
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
