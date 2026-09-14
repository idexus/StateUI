// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitScrollViewTests: XCTestCase {
    @MainActor
    func testHorizontalScrollerKeepsItsContentsMeasuredHeight() {
        let scroll = AppKitScrollView()
        scroll.setItems([AppKitLayoutItem(
            view: FixedScrollTestView(width: 500, height: 36))])
        scroll.apply(
            orientation: ScrollOrientation.horizontal.rawValue,
            padding: NSEdgeInsets(top: 3, left: 5, bottom: 7, right: 11),
            verticalBarVisibility: 2,
            horizontalBarVisibility: 2,
            offset: nil,
            snapInterval: 0,
            snapFrom: 0,
            momentum: 1,
            snapsAtMost: 0)

        XCTAssertEqual(scroll.intrinsicContentSize.width, 516, accuracy: 0.001)
        XCTAssertEqual(scroll.intrinsicContentSize.height, 46, accuracy: 0.001)
    }

    @MainActor
    func testSeveralChildrenKeepAStableInternalVerticalStack() {
        let scroll = AppKitScrollView()
        scroll.frame = NSRect(x: 0, y: 0, width: 120, height: 80)
        let first = AppKitLayoutItem(view: FixedScrollTestView(width: 40, height: 30))
        let second = AppKitLayoutItem(view: FixedScrollTestView(width: 50, height: 40))

        scroll.setItems([first, second])
        scroll.layoutSubtreeIfNeeded()

        XCTAssertTrue(scroll.usesStackWrapperForTesting)
        XCTAssertEqual(scroll.documentChildCountForTesting, 2)

        scroll.setItems([second])
        scroll.layoutSubtreeIfNeeded()

        XCTAssertTrue(scroll.usesStackWrapperForTesting)
        XCTAssertEqual(scroll.documentChildCountForTesting, 1)
    }

    @MainActor
    func testProgrammaticOffsetIsSilentAndSurvivesTheFirstLayout() {
        let scroll = AppKitScrollView()
        scroll.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        scroll.setItems([AppKitLayoutItem(
            view: FixedScrollTestView(width: 80, height: 500))])
        var changes: [(NSPoint, NSPoint)] = []
        scroll.onOffsetChanged = { changes.append(($0, $1)) }

        scroll.apply(
            orientation: ScrollOrientation.vertical.rawValue,
            padding: NSEdgeInsets(),
            verticalBarVisibility: 0,
            horizontalBarVisibility: 0,
            offset: NSPoint(x: 0, y: 160),
            snapInterval: 0,
            snapFrom: 0,
            momentum: 1,
            snapsAtMost: 0)
        scroll.layoutSubtreeIfNeeded()

        XCTAssertEqual(scroll.offset.y, 160, accuracy: 0.001)
        XCTAssertTrue(changes.isEmpty)

        scroll.beginMovementForTesting()
        scroll.moveAsReaderForTesting(to: NSPoint(x: 0, y: 210))

        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].0.y, 160, accuracy: 0.001)
        XCTAssertEqual(changes[0].1.y, 210, accuracy: 0.001)
    }

    @MainActor
    func testAnUnboundScrollerStartsAtTheBeginningAfterItsFirstLayout() {
        let scroll = AppKitScrollView()
        scroll.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        scroll.setItems([AppKitLayoutItem(
            view: FixedScrollTestView(width: 80, height: 500))])

        scroll.apply(
            orientation: ScrollOrientation.vertical.rawValue,
            padding: NSEdgeInsets(),
            verticalBarVisibility: 0,
            horizontalBarVisibility: 0,
            offset: nil,
            snapInterval: 0,
            snapFrom: 0,
            momentum: 1,
            snapsAtMost: 0)
        scroll.layoutSubtreeIfNeeded()

        XCTAssertEqual(scroll.offset, .zero)
    }

    @MainActor
    func testOrientationAndBarVisibilityMapToNativeScrolling() {
        let scroll = AppKitScrollView()
        scroll.apply(
            orientation: ScrollOrientation.horizontal.rawValue,
            padding: NSEdgeInsets(top: 2, left: 3, bottom: 4, right: 5),
            verticalBarVisibility: 1,
            horizontalBarVisibility: 2,
            offset: nil,
            snapInterval: 0,
            snapFrom: 0,
            momentum: 1,
            snapsAtMost: 0)

        XCTAssertFalse(scroll.hasVerticalScroller)
        XCTAssertFalse(scroll.hasHorizontalScroller)
        XCTAssertFalse(scroll.autohidesScrollers)
        XCTAssertEqual(scroll.padding.left, 3)
        XCTAssertEqual(scroll.orientation, .horizontal)
    }

    @MainActor
    func testHostUsesThePublicScrollOrientationValuesDirectly() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, _ in })
        defer { renderer.closeForTesting() }
        var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
        scroll.properties = [
            .orientation: .enumeration(ScrollOrientation.horizontal.rawValue),
        ]
        renderer.applyForTesting(tree(scroll))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)

        XCTAssertEqual(native.orientation, .horizontal)
        XCTAssertTrue(native.hasHorizontalScroller)
        XCTAssertFalse(native.hasVerticalScroller)
    }

    @MainActor
    func testHorizontalScrollerHandsAVerticalWheelToItsEnclosingScroller() throws {
        let outer = ScrollWheelSpyView()
        outer.frame = NSRect(x: 0, y: 0, width: 200, height: 120)
        let page = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 600))
        outer.documentView = page

        let inner = AppKitScrollView()
        inner.frame = NSRect(x: 0, y: 0, width: 200, height: 40)
        inner.setItems([AppKitLayoutItem(
            view: FixedScrollTestView(width: 500, height: 36))])
        inner.apply(
            orientation: ScrollOrientation.horizontal.rawValue,
            padding: NSEdgeInsets(),
            verticalBarVisibility: 2,
            horizontalBarVisibility: 0,
            offset: nil,
            snapInterval: 0,
            snapFrom: 0,
            momentum: 1,
            snapsAtMost: 0)
        page.addSubview(inner)

        let wheel = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: -24,
            wheel2: 0,
            wheel3: 0))
        let event = try XCTUnwrap(NSEvent(cgEvent: wheel))
        XCTAssertGreaterThan(abs(event.scrollingDeltaY), abs(event.scrollingDeltaX))

        inner.scrollWheel(with: event)

        XCTAssertEqual(outer.receivedWheelEvents, 1)
    }

    /// A trackpad gesture is one decision. Its end and its momentum carry no
    /// delta, and a sideways wobble in the middle must not split it, or the
    /// enclosing page never hears the gesture end and cannot settle.
    @MainActor
    func testAHorizontalScrollerKeepsAWholeVerticalGestureOnItsEnclosingScroller() throws {
        let (outer, inner) = nestedScrollers()
        let gesture = [
            try wheel(dy: -10, dx: 0, phase: 1, momentum: 0),
            try wheel(dy: -12, dx: 0, phase: 2, momentum: 0),
            try wheel(dy: -1, dx: -3, phase: 2, momentum: 0),
            try wheel(dy: 0, dx: 0, phase: 4, momentum: 0),
            try wheel(dy: -8, dx: 0, phase: 0, momentum: 1),
            try wheel(dy: 0, dx: 0, phase: 0, momentum: 3),
        ]
        XCTAssertEqual(gesture[0].phase, .began)
        XCTAssertEqual(gesture[3].phase, .ended)
        XCTAssertEqual(gesture[4].momentumPhase, .began)
        XCTAssertEqual(gesture[5].momentumPhase, .ended)

        for event in gesture { inner.scrollWheel(with: event) }

        XCTAssertEqual(outer.receivedWheelEvents, gesture.count)
    }

    @MainActor
    func testAHorizontalGestureStaysOnItsOwnScrollerThroughAVerticalWobble() throws {
        let (outer, inner) = nestedScrollers()
        let gesture = [
            try wheel(dy: 0, dx: -10, phase: 1, momentum: 0),
            try wheel(dy: -4, dx: -1, phase: 2, momentum: 0),
            try wheel(dy: 0, dx: 0, phase: 4, momentum: 0),
        ]

        for event in gesture { inner.scrollWheel(with: event) }

        XCTAssertEqual(outer.receivedWheelEvents, 0)
    }

    @MainActor
    private func nestedScrollers() -> (ScrollWheelSpyView, AppKitScrollView) {
        let outer = ScrollWheelSpyView()
        outer.frame = NSRect(x: 0, y: 0, width: 200, height: 120)
        let page = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 600))
        outer.documentView = page

        let inner = AppKitScrollView()
        inner.frame = NSRect(x: 0, y: 0, width: 200, height: 40)
        inner.setItems([AppKitLayoutItem(
            view: FixedScrollTestView(width: 500, height: 36))])
        inner.apply(
            orientation: ScrollOrientation.horizontal.rawValue,
            padding: NSEdgeInsets(),
            verticalBarVisibility: 2,
            horizontalBarVisibility: 0,
            offset: nil,
            snapInterval: 0,
            snapFrom: 0,
            momentum: 1,
            snapsAtMost: 0)
        page.addSubview(inner)
        return (outer, inner)
    }

    /// A continuous (trackpad) scroll event with Core Graphics' own phase
    /// numbers: scroll phase 1 began, 2 changed, 4 ended; momentum phase 1
    /// began, 3 ended.
    private func wheel(dy: Int32, dx: Int32, phase: Int64, momentum: Int64) throws -> NSEvent {
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: dy,
            wheel2: dx,
            wheel3: 0))
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(try XCTUnwrap(CGEventField(rawValue: 99)), value: phase)
        event.setIntegerValueField(try XCTUnwrap(CGEventField(rawValue: 123)), value: momentum)
        return try XCTUnwrap(NSEvent(cgEvent: event))
    }

    @MainActor
    func testSnapMomentumAndPointLimitSettleOnOneDeterministicTarget() {
        let scroll = AppKitScrollView()
        scroll.frame = NSRect(x: 0, y: 0, width: 100, height: 80)
        scroll.setItems([AppKitLayoutItem(
            view: FixedScrollTestView(width: 1_000, height: 40))])
        scroll.apply(
            orientation: ScrollOrientation.horizontal.rawValue,
            padding: NSEdgeInsets(),
            verticalBarVisibility: 2,
            horizontalBarVisibility: 0,
            offset: nil,
            snapInterval: 100,
            snapFrom: 0,
            momentum: 0.5,
            snapsAtMost: 1)
        scroll.layoutSubtreeIfNeeded()
        var stopped = 0
        scroll.onScrollStopped = { stopped += 1 }

        scroll.beginMovementForTesting()
        scroll.moveAsReaderForTesting(to: NSPoint(x: 460, y: 0))
        scroll.settleForTesting()

        XCTAssertEqual(scroll.offset.x, 100, accuracy: 0.001)
        XCTAssertEqual(stopped, 1)
    }

    @MainActor
    func testADiscreteWheelTurnAdvancesOnePointWithoutMomentumShortening() {
        let scroll = AppKitScrollView()
        scroll.frame = NSRect(x: 0, y: 0, width: 100, height: 80)
        scroll.setItems([AppKitLayoutItem(
            view: FixedScrollTestView(width: 1_000, height: 40))])
        scroll.apply(
            orientation: ScrollOrientation.horizontal.rawValue,
            padding: NSEdgeInsets(),
            verticalBarVisibility: 2,
            horizontalBarVisibility: 0,
            offset: nil,
            snapInterval: 100,
            snapFrom: 0,
            momentum: 0,
            snapsAtMost: 1)
        scroll.layoutSubtreeIfNeeded()
        var stopped = 0
        scroll.onScrollStopped = { stopped += 1 }

        XCTAssertTrue(scroll.stepDiscreteWheelForTesting(by: 1))
        scroll.settleForTesting()

        XCTAssertEqual(scroll.offset.x, 100, accuracy: 0.001)
        XCTAssertEqual(stopped, 1)
    }

    @MainActor
    func testHostPatchReportsChangedAxesNearestItemAndRestExactlyOnce() throws {
        var reports: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }
        var content = HostPatch(id: .manual("content"), type: .colorBox)
        content.properties = [.width: .number(500), .height: .number(500)]
        var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
        scroll.properties = [
            .orientation: .enumeration(2),
            .snapInterval: .number(100),
        ]
        scroll.events = .replace([
            .scrollXChanged: 10,
            .scrollYChanged: 11,
            .snapItemChanged: 12,
            .scrollStopped: 13,
        ])
        scroll.children = .arranged([content])
        renderer.applyForTesting(tree(scroll))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        native.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        native.layoutSubtreeIfNeeded()
        reports.removeAll()
        native.beginMovementForTesting()
        native.moveAsReaderForTesting(to: NSPoint(x: 120, y: 40))
        native.settleForTesting()

        XCTAssertEqual(reports.map(\.0), [10, 11, 12, 10, 13])
        XCTAssertEqual(reports[0].1, [.number(120)])
        XCTAssertEqual(reports[1].1, [.number(40)])
        XCTAssertEqual(reports.last?.1, [])
    }

    /// A vertical scroller's bar visibility reaches its native scroller:
    /// `.never` takes the bar away, `.always` keeps it from hiding, and a
    /// scroller that says neither leaves AppKit to show and hide it.
    @MainActor
    func testAVerticalScrollersBarVisibilityReachesItsNativeScroller() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                ScrollView { Label("Default") }
                ScrollView { Label("Never") }.verticalScrollBarVisibility(.never)
                ScrollView { Label("Always") }.verticalScrollBarVisibility(.always)
            }
        }
        defer { renderer.closeForTesting() }
        let scrollers = renderer.nativeViews(AppKitScrollView.self)

        XCTAssertEqual(scrollers.map { $0.hasVerticalScroller }, [true, false, true])
        XCTAssertEqual(scrollers.map { $0.autohidesScrollers }, [true, true, false])
    }

    /// A horizontal scroller's bar visibility reaches its native scroller
    /// the same way.
    @MainActor
    func testAHorizontalScrollersBarVisibilityReachesItsNativeScroller() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                ScrollView { Label("Default") }
                    .orientation(.horizontal)
                ScrollView { Label("Never") }
                    .orientation(.horizontal)
                    .horizontalScrollBarVisibility(.never)
                ScrollView { Label("Always") }
                    .orientation(.horizontal)
                    .horizontalScrollBarVisibility(.always)
            }
        }
        defer { renderer.closeForTesting() }
        let scrollers = renderer.nativeViews(AppKitScrollView.self)

        XCTAssertEqual(scrollers.map { $0.hasHorizontalScroller }, [true, false, true])
        XCTAssertEqual(scrollers.map { $0.autohidesScrollers }, [true, true, false])
    }

    /// A released scroll carries the scroller's momentum fraction of the way
    /// the reader sent it: all of it by default, half of it for a momentum
    /// of one half.
    @MainActor
    func testAScrollersMomentumScalesWhereAReleaseComesToRest() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                ScrollView { ColorBox(.red).height(1_000) }
                    .width(100)
                    .height(100)
                ScrollView { ColorBox(.red).height(1_000) }
                    .momentum(0.5)
                    .width(100)
                    .height(100)
            }
        }
        defer { renderer.closeForTesting() }
        let scrollers = renderer.nativeViews(AppKitScrollView.self)

        let rests = scrollers.map { scroller -> CGFloat in
            scroller.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
            scroller.layoutSubtreeIfNeeded()
            scroller.beginMovementForTesting()
            scroller.moveAsReaderForTesting(to: NSPoint(x: 0, y: 300))
            scroller.settleForTesting()
            return scroller.offset.y
        }

        XCTAssertEqual(rests, [300, 150])
    }
}

@MainActor
private final class FixedScrollTestView: NSView {
    private let size: NSSize

    init(width: CGFloat, height: CGFloat) {
        size = NSSize(width: width, height: height)
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FixedScrollTestView is created in code")
    }

    override var intrinsicContentSize: NSSize { size }
}

@MainActor
private final class ScrollWheelSpyView: NSScrollView {
    private(set) var receivedWheelEvents = 0

    override func scrollWheel(with event: NSEvent) {
        receivedWheelEvents += 1
    }
}

#endif
