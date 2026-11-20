// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A layout program measuring its views through the host: the sizes its arithmetic reads are the native halves',
/// a view measuring otherwise is placed again, and a layout saying its own size is measured by it.
/// Design: docs/design/host/layout.md#a-layout-program
final class ProgramMeasureTests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        rowRuns = 0
        WordsView.asked = 0
    }

    /// THE ARITHMETIC READS WHAT THE NATIVE HALVES MEASURE: each view stands as wide as its words, after the last.
    @MainActor
    func testALayoutPlacesItsViewsByTheSizesTheyMeasure() throws {
        let bench = MeasuringBench(RowPage())
        let layout = try bench.laidOut(300, 100)

        XCTAssertEqual(layout.placement?.placements.map(\.bounds), [
            Rect(x: 0, y: 0, width: 10, height: 20), Rect(x: 18, y: 0, width: 30, height: 20), Rect(x: 56, y: 0, width: 20, height: 20),
        ])
    }

    /// A VIEW IS ASKED ONCE IN A WORKING-OUT, whatever the arithmetic asks of it again.
    @MainActor
    func testAViewIsMeasuredOnceInAWorkingOut() throws {
        let bench = MeasuringBench(RowPage(asksTwice: true))
        _ = try bench.laidOut(300, 100)
        let runs = rowRuns

        XCTAssertGreaterThan(runs, 0)
        XCTAssertEqual(WordsView.asked, 3, "three views, each asked once in the working-out that measured them")
    }

    /// A VIEW WHOSE WORDS CHANGED IS PLACED AGAIN BY ITS NEW SIZE: the patch reaching it says the layout its views
    /// may measure otherwise, and the next cycle works it out.
    @MainActor
    func testAViewSizedAnewIsPlacedAgain() throws {
        let bench = MeasuringBench(RowPage())
        let layout = try bench.laidOut(300, 100)

        try bench.click("Longer")

        XCTAssertEqual(layout.placement?.placements.map(\.bounds), [
            Rect(x: 0, y: 0, width: 40, height: 20), Rect(x: 48, y: 0, width: 30, height: 20), Rect(x: 86, y: 0, width: 20, height: 20),
        ])
    }

    /// A LAYOUT THAT MEASURES NOTHING STANDS AS IT STOOD when a view of it changes: no cycle is asked for it.
    @MainActor
    func testALayoutMeasuringNothingIsNotWorkedOutAgainForAView() throws {
        let bench = MeasuringBench(RowPage(measures: false))
        _ = try bench.laidOut(300, 100)

        try bench.click("Longer")
        let afterTheBuild = rowRuns
        bench.settle()

        XCTAssertEqual(rowRuns, afterTheBuild, "the build worked it out; the view's new words asked nothing more")
        XCTAssertEqual(WordsView.asked, 0)
    }

    /// A WIDTH OFFERED REACHES THE NATIVE HALF: words offered less than they take stand in more lines.
    @MainActor
    func testAProposalIsOfferedToTheView() throws {
        let bench = MeasuringBench(RowPage(offers: 15))
        let layout = try bench.laidOut(300, 100)

        XCTAssertEqual(layout.placement?.placements.map(\.bounds.width), [10, 15, 15])
        XCTAssertEqual(layout.placement?.placements.map(\.bounds.height), [20, 40, 40])
    }

    /// A ROW THAT BECOMES A COLUMN KEEPS ITS VIEWS: the room narrowed past what the views take side by side, the
    /// same arithmetic stands them one under the other, and every view is the mounting it was.
    @MainActor
    func testAnArrangementChangedByTheRoomKeepsItsViews() throws {
        let bench = MeasuringBench(RowPage(wraps: true))
        let layout = try bench.laidOut(300, 100)
        let mounted = layout.children.map(\.mount)
        XCTAssertEqual(layout.placement?.placements.map(\.bounds), [
            Rect(x: 0, y: 0, width: 10, height: 20), Rect(x: 18, y: 0, width: 30, height: 20), Rect(x: 56, y: 0, width: 20, height: 20),
        ])

        layout.layoutProgram?.layOut(50, 100)
        bench.settle()

        XCTAssertEqual(layout.placement?.placements.map(\.bounds), [
            Rect(x: 0, y: 0, width: 10, height: 20), Rect(x: 0, y: 28, width: 30, height: 20), Rect(x: 0, y: 56, width: 20, height: 20),
        ])
        XCTAssertEqual(layout.children.map(\.mount), mounted, "no view was made again")
    }

    /// A LAYOUT SAYING ITS OWN SIZE IS MEASURED BY IT, within its padding; one saying none takes its padding alone.
    @MainActor
    func testALayoutSayingItsSizeIsMeasuredByIt() throws {
        let bench = MeasuringBench(RowPage(saysItsSize: true))
        let layout = try bench.laidOut(300, 100)

        XCTAssertEqual(layout.programSize(nil), LayoutSize(width: 76, height: 20), "the row's own size")
        XCTAssertEqual(layout.programSize(40), LayoutSize(width: 40, height: 20), "no wider than it is offered")
        XCTAssertEqual(
            ZStackArithmetic.size(
                of: [NoChild](), padding: Insets(2), width: nil, motionLayout: true, program: layout.programSize),
            LayoutSize(width: 80, height: 24))

        let plain = MeasuringBench(RowPage())
        let filling = try plain.laidOut(300, 100)
        XCTAssertNil(filling.programSize(nil))
        XCTAssertEqual(
            ZStackArithmetic.size(
                of: [NoChild](), padding: Insets(2), width: nil, motionLayout: true, program: filling.programSize),
            LayoutSize(width: 4, height: 4))
    }

    /// THE TOOLKIT MEASURES THE LAYOUT AGAIN WHERE ITS OWN SIZE MOVED, and only there: a view's longer words make
    /// the row wider, so its native half is asked to measure again; a working-out that says the same size asks
    /// nothing.
    @MainActor
    func testALayoutWhoseSizeMovedIsMeasuredAgain() throws {
        let bench = MeasuringBench(RowPage(saysItsSize: true))
        let layout = try bench.laidOut(300, 100)
        let native = try XCTUnwrap(layout.native as? WordsView)
        XCTAssertEqual(layout.programSize(nil), LayoutSize(width: 76, height: 20))
        native.measuredAgain = 0

        layout.layoutProgram?.layOut(320, 100)
        bench.settle()
        XCTAssertEqual(native.measuredAgain, 0, "another room, the same size of its own")

        try bench.click("Longer")
        XCTAssertEqual(native.measuredAgain, 1)
        XCTAssertEqual(layout.programSize(nil), LayoutSize(width: 106, height: 20))
    }
}

/// How many times the row's arithmetic ran.
@MainActor private var rowRuns = 0

/// A row of words, each as wide as it measures, eight points apart.
private struct RowPage: View {
    var measures = true
    var asksTwice = false
    var offers: Double?
    var saysItsSize = false
    var wraps = false

    @State private var words = ["a", "bbb", "cc"]

    var body: some View {
        VStack {
            Button("Longer")
                .onClicked { words[0] = "aaaa" }
            if saysItsSize {
                row.measure(Self.rowSize)
            } else {
                row
            }
        }
    }

    private var row: MotionLayout<[Int], Int, Double> {
        let (measures, asksTwice, offers, wraps, words) = (measures, asksTwice, offers, wraps, words)
        return MotionLayout(Array(words.indices), parameters: State(wrappedValue: 0.0).projectedValue) { index in
            Text(words[index])
        } placements: { context, _ in
            rowRuns += 1
            guard measures else { return context.subviews.map { _ in Placement(Rect(x: 0, y: 0, width: 10, height: 10)) } }
            let sizes = context.subviews.map { view in
                if asksTwice { _ = view.sizeThatFits(width: offers) }
                return view.sizeThatFits(width: offers)
            }
            // One under the other where the views side by side are wider than the room, and the row wraps.
            let row = sizes.reduce(0) { $0 + $1.width } + 8 * Double(max(0, sizes.count - 1))
            let stacked = wraps && row > context.bounds.width
            var (across, down) = (0.0, 0.0)
            return sizes.map { size in
                defer { if stacked { down += size.height + 8 } else { across += size.width + 8 } }
                return Placement(Rect(x: across, y: down, width: size.width, height: size.height))
            }
        }
    }

    /// The row's own size: its views side by side, no wider than the room offered.
    private static let rowSize: @MainActor (LayoutMeasurementContext<Int>, Double) -> LayoutSize = { context, _ in
        let sizes = context.subviews.map { $0.sizeThatFits() }
        let width = sizes.reduce(0) { $0 + $1.width } + 8 * Double(max(0, sizes.count - 1))
        return LayoutSize(
            width: min(width, context.proposal.width ?? width), height: sizes.map(\.height).max() ?? 0)
    }
}

/// A page on a runtime whose native halves measure words: mounted, laid out and turned by hand.
@MainActor
private final class MeasuringBench {
    let runtime: HostRuntime
    private let clock = WoundClock()

    init(_ page: RowPage) {
        Renderer.shared.setApplication(OneWindowApplication { page })
        runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { WordsView($0) }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
    }

    /// The page's motion layout, told its room and worked out.
    func laidOut(_ width: Double, _ height: Double) throws -> MountedElement {
        let layout = try XCTUnwrap(runtime.tree.root?.first(type: .motionLayout))
        try XCTUnwrap(layout.layoutProgram).layOut(width, height)
        settle()
        return layout
    }

    /// Turns and frames until what was asked for has run and what moves has come to rest.
    func settle() {
        for frame in 0..<400 {
            runtime.pump.turn()
            clock.time += 16
            runtime.displayCycle.frame(now: clock.time)
            if frame >= 4, !clock.held { break }
        }
    }

    /// The button captioned `caption` clicked, and what it began shown.
    func click(_ caption: String) throws {
        let button = try XCTUnwrap(runtime.tree.root?.first(type: .button))
        XCTAssertEqual(button.value(.text)?.string, caption)
        button.send(.clicked, [], in: runtime)
        settle()
    }
}

/// A native half measuring its words: ten points a letter in a line twenty high, its first line resting fifteen
/// down; offered less than they take, the words stand in as many lines as it takes.
@MainActor
private final class WordsView: NativeElement {
    static var asked = 0

    unowned let element: MountedElement
    var measuredAgain = 0

    init(_ element: MountedElement) {
        self.element = element
    }

    func measured(width: Double?, height: Double?) -> HostChildMeasured {
        Self.asked += 1
        let words = element.type == .text ? element : element.first(type: .text)
        let natural = Double(words?.value(.text)?.string?.count ?? 0) * 10
        guard let width, width > 0, width < natural else {
            return HostChildMeasured(size: LayoutSize(width: natural, height: 20), firstBaseline: 15)
        }
        return HostChildMeasured(
            size: LayoutSize(width: width, height: 20 * (natural / width).rounded(.up)), firstBaseline: 15)
    }

    let presentsView = true
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func invalidateMeasurements() { measuredAgain += 1 }
    func configureLayoutMotion() {}
    func leave() {}
}

/// No child at all: a layout measured with no view in it.
private struct NoChild: LayoutChild {
    var values = LayoutValues()
    var isShown: Bool { true }
    func size(offered width: Double?) -> LayoutSize { .zero }
    func firstBaseline(offered width: Double?) -> Double? { nil }
}
