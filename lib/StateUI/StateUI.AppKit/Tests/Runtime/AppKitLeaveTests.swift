// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
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

/// A page whose drop target a click takes away.
private struct DropPage: View {
    @State private var shown = true

    var body: some View {
        VStack {
            if shown {
                Text("target")
                    .onDropped { _ in }
            }
            Button("Hide")
                .onClicked { shown = false }
        }
    }
}

/// The AppKit driver losing every click: a walk on it can prove nothing.
@MainActor
private final class LosingClicks: HostDriver {
    let driver = AppKitDriver()
    var host: String { driver.host }
    var register: HostRegister { driver.register }
    var cannot: [String: String] { driver.cannot }
    var liveViews: Int? { driver.liveViews }
    var liveViewKinds: [String: Int]? { driver.liveViewKinds }

    func start(
        clock: TestClock?, reducesMotion: Bool, @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) -> MountedTree {
        driver.start(clock: clock, reducesMotion: reducesMotion, page)
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {}
    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? { try driver.held(property, on: element) }
    func step() { driver.step() }
    func close() { driver.close() }
    func turn() { driver.turn() }
    func frame() { driver.frame() }
    func served() throws -> String { try driver.served() }
    func held() throws -> (taken: Int, stopped: Int) { try driver.held() }
}

@MainActor
final class AppKitLeaveTests: XCTestCase {
    /// An element that leaves the tree lets go of its view: the host holds one view fewer alive, the count its
    /// tally writes.
    @MainActor
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        // AppKit autoreleases what it hands back - a walk of `subviews` an array of them: each pool drained here.
        let renderer = autoreleasepool { AppKitRenderer.running { NotePage() } }
        defer { renderer.finish() }
        let before = AppKitElement.liveViewCount

        autoreleasepool {
            XCTAssertEqual(renderer.nativeViews(AppKitTextView.self).count, 1)
            renderer.nativeViews(AppKitButtonView.self).first?.clickForTesting()
            renderer.runtime.pump.turn()
            XCTAssertEqual(renderer.nativeViews(AppKitTextView.self).count, 0)
        }

        XCTAssertEqual(AppKitElement.liveViewCount, before - 1, "the label's view outlived its element")
    }

    /// A drag that went over the window holds none of the views taking drops once it ends: one leaving after it is
    /// let go of.
    @MainActor
    func testADragEndedHoldsNoViewTakingDrops() throws {
        let renderer = autoreleasepool { AppKitRenderer.running { DropPage() } }
        defer { renderer.finish() }
        let before = AppKitElement.liveViewCount

        try autoreleasepool {
            let target = try XCTUnwrap(renderer.nativeViews(AppKitTextView.self).first)
            let root = try XCTUnwrap(target.window?.contentView as? AppKitWindowContentView)
            let drops = try XCTUnwrap(root.drops)
            let carried = AppKitDrops.Carried(words: "words")
            root.layoutSubtreeIfNeeded()
            let middle = target.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), to: nil)
            XCTAssertEqual(drops.entered(at: middle, carrying: carried, in: root), .copy, "the drag is over the target")
            drops.exited()
            _ = drops.entered(at: middle, carrying: carried, in: root)
            XCTAssertTrue(drops.dropped(carried))
            renderer.nativeViews(AppKitButtonView.self).first?.clickForTesting()
            renderer.runtime.pump.turn()
        }

        XCTAssertEqual(AppKitElement.liveViewCount, before - 1, "the target's view outlived its element")
    }

    /// A view taking drops that leaves while a drag is over it is let go of, and the drag's end - leaving the
    /// window, let go, moved on - tells the element gone nothing.
    @MainActor
    func testATargetLeavingUnderADragIsLetGoOfWhenTheDragLeaves() throws {
        try targetLeavesUnderADrag { drops, _, _, _ in drops.exited() }
    }

    @MainActor
    func testATargetLeavingUnderADragIsLetGoOfWhenTheDragIsLetGo() throws {
        try targetLeavesUnderADrag { drops, _, _, carried in XCTAssertFalse(drops.dropped(carried)) }
    }

    @MainActor
    func testATargetLeavingUnderADragIsLetGoOfWhenTheDragMoves() throws {
        try targetLeavesUnderADrag { drops, root, at, carried in
            XCTAssertEqual(drops.moved(to: at, carrying: carried, in: root), [])
            drops.exited()
        }
    }

    /// A drag comes over DropPage's target, the target leaves, and `end` ends the drag: the renderer alive, its
    /// view is let go of.
    @MainActor
    private func targetLeavesUnderADrag(
        _ end: (AppKitDrops, AppKitWindowContentView, NSPoint, AppKitDrops.Carried) -> Void
    ) throws {
        let renderer = autoreleasepool { AppKitRenderer.running { DropPage() } }
        defer { renderer.finish() }
        let before = AppKitElement.liveViewCount

        try autoreleasepool {
            let target = try XCTUnwrap(renderer.nativeViews(AppKitTextView.self).first)
            let root = try XCTUnwrap(target.window?.contentView as? AppKitWindowContentView)
            let drops = try XCTUnwrap(root.drops)
            let carried = AppKitDrops.Carried(words: "words")
            root.layoutSubtreeIfNeeded()
            let middle = target.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), to: nil)
            XCTAssertEqual(drops.entered(at: middle, carrying: carried, in: root), .copy, "the drag is over the target")
            renderer.nativeViews(AppKitButtonView.self).first?.clickForTesting()
            renderer.runtime.pump.turn()
            XCTAssertEqual(renderer.nativeViews(AppKitTextView.self).count, 0)
            end(drops, root, middle, carried)
        }

        XCTAssertEqual(AppKitElement.liveViewCount, before - 1, "the target's view outlived its element")
    }

    /// A walk whose clicks change nothing proves nothing: it fails, naming the element, rather than finding as many
    /// views alive each time.
    @MainActor
    func testAWalkWhoseClicksChangeNothingFails() throws {
        let driver = LosingClicks()
        defer { driver.driver.renderer?.finish() }
        XCTAssertThrowsError(try Leaving.outlived(on: driver, ["Text"])) { error in
            XCTAssertEqual("\(error)", "Text: the specimen did not go though its toggle was clicked")
        }
    }

    /// Every element shown and taken away twice leaves the host holding as many views as the first time.
    @MainActor
    func testEveryElementsViewIsLetGoOfEachTimeItLeaves() throws {
        let driver = AppKitDriver()
        defer { driver.renderer?.finish() }
        XCTAssertEqual(try Leaving.outlived(on: driver), [])
    }
}

#endif
