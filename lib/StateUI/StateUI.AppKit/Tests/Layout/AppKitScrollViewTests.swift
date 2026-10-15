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
        scroll.moveAsUserForTesting(to: NSPoint(x: 0, y: 210))
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
            presentsWindows: false)
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

    /// A vertical scroller's bar visibility reaches its native scroller:
    /// `.never` takes the bar away, `.visible` keeps it from hiding, and a
    /// scroller that says neither leaves AppKit to show and hide it.
    @MainActor
    func testAVerticalScrollersBarVisibilityReachesItsNativeScroller() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                ScrollView { Text("Default") }
                ScrollView { Text("Never") }.verticalScrollIndicator(.never)
                ScrollView { Text("Always") }.verticalScrollIndicator(.visible)
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
                ScrollView { Text("Default") }
                    .orientation(.horizontal)
                ScrollView { Text("Never") }
                    .orientation(.horizontal)
                    .horizontalScrollIndicator(.never)
                ScrollView { Text("Always") }
                    .orientation(.horizontal)
                    .horizontalScrollIndicator(.visible)
            }
        }
        defer { renderer.closeForTesting() }
        let scrollers = renderer.nativeViews(AppKitScrollView.self)

        XCTAssertEqual(scrollers.map { $0.hasHorizontalScroller }, [true, false, true])
        XCTAssertEqual(scrollers.map { $0.autohidesScrollers }, [true, true, false])
    }

    /// A TRACKPAD PUSH TURNS A RUN OF CARDS BY WHAT IT PUSHED: the gesture
    /// along the run is the layout's, the run moves with the fingers, and let
    /// go still it travels on to the card it passed - the system's momentum
    /// after the lift swallowed, as the layout throws the run itself.
    @MainActor
    func testATrackpadPushTurnsARunOfCards() throws {
        let positions = Received<Int>()
        let renderer = AppKitRenderer.running {
            GalleryView(0..<7) { number in Text("\(number)") }
                .onPositionChanged { positions.values.append($0) }
        }
        defer { renderer.closeForTesting() }
        let layout = try XCTUnwrap(Self.layout(in: renderer))

        // A card is 176 wide and a turn is three fifths of one, 105.6; the push
        // goes 80 - past half a turn, short of a whole one.
        layout.scrollWheel(with: try Self.scroll(phase: .began))
        layout.scrollWheel(with: try Self.scroll(x: -80, phase: .changed))
        // Held still before it lifts: no throw.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        layout.scrollWheel(with: try Self.scroll(phase: .ended))
        let swallowed = Self.taken(by: layout, try Self.scroll(x: -30, momentum: .continuous))

        let settled = Date(timeIntervalSinceNow: 2)
        while positions.values.last != 1, Date() < settled {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            renderer.displayFrameForTesting()
            renderer.runtime.pump.turn()
        }

        XCTAssertEqual(positions.values.last, 1)
        XCTAssertTrue(swallowed, "the momentum after the lift is the layout's to swallow")
    }

    /// A GESTURE ACROSS THE RUN IS LEFT to whatever holds the layout: its first
    /// move says whose it is.
    @MainActor
    func testAGestureAcrossTheRunIsLeftToWhatHoldsIt() throws {
        let renderer = AppKitRenderer.running { GalleryView(0..<7) { number in Text("\(number)") } }
        defer { renderer.closeForTesting() }
        let layout = try XCTUnwrap(Self.layout(in: renderer))
        let reader = try XCTUnwrap(layout.hand)

        XCTAssertTrue(reader(try Self.scroll(phase: .began)), "a gesture begun is the layout's until it moves")
        XCTAssertFalse(reader(try Self.scroll(y: -80, phase: .changed)), "moving down, it is not the run's")
        XCTAssertFalse(reader(try Self.scroll(phase: .ended)))
        XCTAssertTrue(reader(try Self.scroll(x: -40)), "a wheel along the run is")
    }

    /// The view of the layout a hand moves, once the host stood it.
    @MainActor
    private static func layout(in renderer: AppKitRenderer) -> AppKitZStackView? {
        let deadline = Date(timeIntervalSinceNow: 2)
        while !renderer.nativeViews(AppKitZStackView.self).contains(where: { $0.hand != nil }), Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            renderer.runtime.pump.turn()
            if renderer.frameClock.held { renderer.displayFrameForTesting() }
        }
        return renderer.nativeViews(AppKitZStackView.self).first { $0.hand != nil }
    }

    /// Whether `layout` took `event` rather than sending it on.
    @MainActor
    private static func taken(by layout: AppKitZStackView, _ event: NSEvent) -> Bool {
        layout.hand?(event) ?? false
    }

    /// A trackpad's scroll event moving what is under the fingers by `x` and `y` points, at a step of its gesture
    /// or of the momentum after it - a wheel's notch where it is at neither.
    private static func scroll(
        x: Int32 = 0, y: Int32 = 0, phase: CGScrollPhase? = nil, momentum: CGMomentumScrollPhase? = nil
    ) throws -> NSEvent {
        let made = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0))
        made.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase?.rawValue ?? 0))
        made.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(momentum?.rawValue ?? 0))
        // Stamped now, as the system stamps what it sends: a made event's time is nought.
        made.timestamp = CGEventTimestamp(clock_gettime_nsec_np(CLOCK_UPTIME_RAW))
        return try XCTUnwrap(NSEvent(cgEvent: made))
    }

    /// What the user scrolled comes back as the state it wrote, and the
    /// scroller is already there: it is not moved again, which mid-gesture is
    /// the platform's own scroll interrupted on every report.
    @MainActor
    func testAUsersScrollIsNotWrittenBackToItsScroller() throws {
        let renderer = AppKitRenderer.running { BoundStrip() }
        defer { renderer.closeForTesting() }
        let scroller = try XCTUnwrap(renderer.nativeViews(AppKitScrollView.self).first)
        scroller.window?.contentView?.layoutSubtreeIfNeeded()
        let moves = scroller.programmaticMovesForTesting

        scroller.contentView.scroll(to: NSPoint(x: 0, y: 120))
        scroller.reflectScrolledClipView(scroller.contentView)
        renderer.displayFrameForTesting()

        XCTAssertEqual(scroller.contentView.bounds.origin.y, 120, accuracy: 0.5)
        XCTAssertEqual(scroller.programmaticMovesForTesting, moves, "the user's own offset is not written back")
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
        let reading = try XCTUnwrap(renderer.nativeViews(AppKitTextView.self).first)
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

/// A tall strip whose offset a state carries, read back by a label.
private struct BoundStrip: View {
    @State private var offset = Point.zero

    var body: some View {
        VStack {
            ScrollView {
                Rectangle().fill(Color("#3366FF")).height(2_000)
            }
            .scrollOffset($offset)
            .height(300)

            Text("\(Int($offset.journey.value.y)) down")
        }
    }
}

#endif
