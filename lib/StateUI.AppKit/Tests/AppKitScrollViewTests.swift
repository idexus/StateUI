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
            offset: nil)

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
            offset: NSPoint(x: 0, y: 160))
        scroll.layoutSubtreeIfNeeded()

        XCTAssertEqual(scroll.offset.y, 160, accuracy: 0.001)
        XCTAssertTrue(changes.isEmpty)

        scroll.beginMovementForTesting()
        scroll.moveAsReaderForTesting(to: NSPoint(x: 0, y: 210))
        scroll.frame(now: 0)

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
            offset: nil)
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
            offset: nil)

        XCTAssertFalse(scroll.hasVerticalScroller)
        XCTAssertFalse(scroll.hasHorizontalScroller)
        XCTAssertFalse(scroll.autohidesScrollers)
        XCTAssertEqual(scroll.padding.left, 3)
        XCTAssertEqual(scroll.orientation, .horizontal)
    }

    @MainActor
    func testHostUsesThePublicScrollOrientationValuesDirectly() throws {
        let renderer = testRenderer(
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
            offset: nil)
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
            offset: nil)
        page.addSubview(inner)
        return (outer, inner)
    }

    /// A continuous (trackpad) scroll event with Core Graphics' own phase
    /// numbers: scroll phase 1 began, 2 changed, 4 ended; momentum phase 1
    /// began, 3 ended.
    private func wheel(
        dy: Int32, dx: Int32, phase: Int64, momentum: Int64, at seconds: Double? = nil
    ) throws -> NSEvent {
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
        if let seconds { event.timestamp = CGEventTimestamp(seconds * 1_000_000_000) }
        return try XCTUnwrap(NSEvent(cgEvent: event))
    }

    @MainActor
    func testHostPatchReportsChangedAxesAndRestExactlyOnce() throws {
        var reports: [(Int32, [HostValue])] = []
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }
        var content = HostPatch(id: .manual("content"), type: .colorBox)
        content.properties = [.width: .number(500), .height: .number(500)]
        var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
        scroll.properties = [
            .orientation: .enumeration(2),
        ]
        scroll.events = .replace([
            .scrollXChanged: 10,
            .scrollYChanged: 11,
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
        renderer.displayFrameForTesting()
        native.restForTesting()
        renderer.displayFrameForTesting()

        XCTAssertEqual(reports.map(\.0), [10, 11, 13])
        XCTAssertEqual(reports[0].1, [.number(120)])
        XCTAssertEqual(reports[1].1, [.number(40)])
        XCTAssertEqual(reports.last?.1, [])
    }

    /// A movement no live scroll brackets - a wheel's click - rests once the
    /// offset has stood still for 120 ms of the frame clock's time, and says so
    /// once: the quiet is the display's own time, never a timer's.
    @MainActor
    func testAMovementNoLiveScrollBracketsRestsOnTheFrameClock() throws {
        var now = 0.0
        var reports: [Int32] = []
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { handler, _ in reports.append(handler) },
            clock: { now })
        defer { renderer.closeForTesting() }
        var content = HostPatch(id: .manual("content"), type: .colorBox)
        content.properties = [.width: .number(500), .height: .number(500)]
        var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
        scroll.properties = [.orientation: .enumeration(2)]
        scroll.events = .replace([.scrollYChanged: 11, .scrollStopped: 13])
        scroll.children = .arranged([content])
        renderer.applyForTesting(tree(scroll))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        native.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        native.layoutSubtreeIfNeeded()
        reports.removeAll()

        native.beginMovementForTesting()
        native.moveAsReaderForTesting(to: NSPoint(x: 0, y: 40))
        renderer.displayFrameForTesting()
        XCTAssertEqual(reports, [11], "where it went, on the next frame")

        now = 100
        renderer.displayFrameForTesting()
        XCTAssertEqual(reports, [11], "still for less than the quiet")

        now = 120
        renderer.displayFrameForTesting()
        XCTAssertEqual(reports, [11, 13], "at rest once it has stood still long enough")

        now = 300
        renderer.displayFrameForTesting()
        XCTAssertEqual(reports, [11, 13], "and said once")
    }

    /// A scroller's movement is stepped by the frame clock alone: no timer and
    /// no second clock decides when it rests.
    func testAScrollersMovementReadsNoClockButTheFrameClock() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.AppKit
            .appendingPathComponent("Sources")
        let timers = ["asyncAfter(", "DispatchWorkItem", "Timer.", "scheduledTimer", "afterDelay:"]
        var found: [String] = []

        for name in ["AppKitContainers.swift", "AppKitScrollMovement.swift"] {
            guard let text = try? String(
                contentsOf: sources.appendingPathComponent(name), encoding: .utf8)
            else { continue }

            for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
            where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                for timer in timers where line.contains(timer) {
                    found.append("\(name):\(number + 1): \(timer)")
                }
            }
        }

        XCTAssertEqual(found, [], "a scroller rests on the frame clock's time")
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

    /// A run that answers a tap on one part of the room is still as long as the
    /// room plus its reach, so a trackpad or a wheel has somewhere to scroll it:
    /// its content is the run's layout, sized by the length it was given rather
    /// than by whatever a host counts into a placed layout's natural size.
    @MainActor
    func testARunThatAnswersATapIsAsLongAsItsReach() throws {
        let renderer = AppKitRenderer.running { TappedRun() }
        defer { renderer.closeForTesting() }
        let scroller = try XCTUnwrap(renderer.nativeViews(AppKitScrollView.self).first)

        // The room arrives with the first frame report, and the run is built
        // again with its length.
        let deadline = Date(timeIntervalSinceNow: 2)
        while (scroller.documentView?.frame.width ?? 0) <= scroller.contentView.bounds.width + 1,
              Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            renderer.pump()
            scroller.window?.contentView?.layoutSubtreeIfNeeded()
        }

        let room = scroller.contentView.bounds.width
        XCTAssertGreaterThan(room, 1)
        XCTAssertEqual(scroller.documentView?.frame.width ?? 0, room + 300, accuracy: 1)
    }

    /// A push of the trackpad turns a run of cards by what it pushed: past half
    /// a card, the next card is named as the run passes halfway, and when the
    /// scroller comes to rest the run travels on to it rather than back.
    @MainActor
    func testATrackpadPushPastHalfACardTurnsTheRun() throws {
        let positions = Received<Int>()
        let renderer = AppKitRenderer.running {
            GalleryView(0..<7) { number in Label("\(number)") }
                .onPositionChanged { positions.values.append($0) }
                .onItemTapped { _ in }
        }
        defer { renderer.closeForTesting() }
        let scroller = try XCTUnwrap(renderer.nativeViews(AppKitScrollView.self).first)

        // The run is the room plus six turns long once the room has arrived.
        let deadline = Date(timeIntervalSinceNow: 2)
        while (scroller.documentView?.frame.width ?? 0) < scroller.contentView.bounds.width + 600,
              Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            renderer.pump()
            scroller.window?.contentView?.layoutSubtreeIfNeeded()
        }

        // A card is 176 wide and a turn is three fifths of one, 105.6; the push
        // goes 80 - past half a turn, short of a whole one.
        scroller.beginMovementForTesting()
        scroller.moveAsReaderForTesting(to: NSPoint(x: 80, y: 0))
        scroller.restForTesting()
        let settled = Date(timeIntervalSinceNow: 2)
        while positions.values.last != 1 || abs(scroller.contentView.bounds.origin.x - 105.6) > 0.5,
              Date() < settled {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            renderer.displayFrameForTesting()
            renderer.pump()
        }

        XCTAssertEqual(scroller.contentView.bounds.origin.x, 105.6, accuracy: 0.5)
        XCTAssertEqual(positions.values.last, 1)
    }

    /// What the reader scrolled comes back as the state it wrote, and the
    /// scroller is already there: it is not moved again, which mid-gesture is
    /// the platform's own scroll interrupted on every report.
    @MainActor
    func testAReadersScrollIsNotWrittenBackToItsScroller() throws {
        let renderer = AppKitRenderer.running { BoundStrip() }
        defer { renderer.closeForTesting() }
        let scroller = try XCTUnwrap(renderer.nativeViews(AppKitScrollView.self).first)
        scroller.window?.contentView?.layoutSubtreeIfNeeded()
        let moves = scroller.programmaticMovesForTesting

        scroller.contentView.scroll(to: NSPoint(x: 0, y: 120))
        scroller.reflectScrolledClipView(scroller.contentView)
        renderer.displayFrameForTesting()

        XCTAssertEqual(scroller.contentView.bounds.origin.y, 120, accuracy: 0.5)
        XCTAssertEqual(scroller.programmaticMovesForTesting, moves, "the reader's own offset is not written back")
    }

    /// What the platform's scroller reports while it moves is taken on the next
    /// display frame, once, and the frame clock runs for as long as the
    /// scroller moves. AppKit moves the clip view from inside its own frame
    /// step; a render there holds that step's frame, and the scroll events
    /// behind it arrive merged into one jump.
    @MainActor
    func testWhatAMovingScrollerReportsIsTakenOnTheNextDisplayFrame() throws {
        let renderer = AppKitRenderer.running { BoundStrip() }
        defer { renderer.closeForTesting() }
        let scroller = try XCTUnwrap(renderer.nativeViews(AppKitScrollView.self).first)
        let reading = try XCTUnwrap(renderer.nativeViews(AppKitLabelView.self).first)
        scroller.window?.contentView?.layoutSubtreeIfNeeded()
        XCTAssertFalse(renderer.frameClockRunningForTesting, "a still page keeps no clock")

        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scroller)
        let renders = renderer.windowSynchronizationCountForTesting
        for y: CGFloat in [40, 80, 120] {
            scroller.contentView.scroll(to: NSPoint(x: 0, y: y))
            scroller.reflectScrolledClipView(scroller.contentView)
        }

        XCTAssertEqual(reading.stringValue, "0 down", "nothing is taken inside the platform's scroll step")
        XCTAssertTrue(renderer.frameClockRunningForTesting, "a moving scroller holds the frame clock")

        renderer.displayFrameForTesting()
        XCTAssertEqual(reading.stringValue, "120 down")
        XCTAssertEqual(renderer.windowSynchronizationCountForTesting, renders + 1, "one render for the frame")

        NotificationCenter.default.post(name: NSScrollView.didEndLiveScrollNotification, object: scroller)
        renderer.displayFrameForTesting()
        XCTAssertFalse(renderer.frameClockRunningForTesting, "a scroller that stands lets the clock go")
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


/// A run the reader can scroll 300 points beyond its room, answering a tap on
/// its first hundred.
private struct TappedRun: ContentView {
    @State private var across = Point.zero

    var content: any View {
        ScrollReader(across: 300) {
            ColorBox(Color("#3366FF"))
        }
        .scrollOffset($across)
        .onTapped(within: { room in Rect(0, 0, 100, room.height) }) {}
    }
}
/// A tall strip whose offset a state carries, read back by a label.
private struct BoundStrip: ContentView {
    @State private var offset = Point.zero

    var content: any View {
        VStack {
            ScrollView {
                ColorBox(Color("#3366FF")).height(2_000)
            }
            .scrollOffset($offset)
            .height(300)

            Label("\(Int($offset.journey.value.y)) down")
        }
    }
}

#endif
