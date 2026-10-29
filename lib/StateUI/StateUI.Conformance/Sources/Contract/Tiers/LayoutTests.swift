// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LayoutContract` on a host: a layout cuts what it holds to its outline where it clips and not otherwise, lets a
/// press through where nothing it holds stands where it says so, and standing a page whole runs under what stands over
/// the page where it ignores the safe area - each case made for every layout.
@_spi(Host) public enum LayoutTests: ConformanceFamily {
    public static let name = "Layout"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(LayoutContract.self).flatMap { element in
            [
                clipped(element), throughIt(element), underTheBars(element),
                Aspects.holds(LayoutContract.clipsContent, on: element, false, then: true),
                Aspects.holds(LayoutContract.letsInputThrough, on: element, false, then: true),
            ]
        }
    }

    /// What a layout holds drawn past its edge - moved there, which its arithmetic does not see - shows until the tree
    /// says it clips, and then shows no more.
    @MainActor
    static func clipped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).cutsWhatItHoldsToItsOutlineWhereItClips", proves: [
            Covered(LayoutContract.clipsContent, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let clips = State(wrappedValue: false)
            s.start {
                VStack {
                    ZStack {
                        Holding.layout(element, clips: clips.wrappedValue, width: 40, height: 40) {
                            Rectangle()
                                .fill(.red)
                                .width(20)
                                .height(20)
                                .horizontalAlignment(.start)
                                .verticalAlignment(.start)
                                .translationX(30).translationY(30)
                        }
                    }
                    .width(100).height(100).id("room")
                    Button("Clip").onClicked { clips.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let room = try s.element("room")
            try s.settle { try s.shows(.red, on: room, at: Point(45, 45)) }
            s.expect(try s.color(of: room, at: Point(45, 45)), shows: .red, "past its edge, shown")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: room, at: Point(45, 45)) == nil }
            s.expect(try s.color(of: room, at: Point(45, 45)), nil, "cut once it clips")
            s.expect(try s.color(of: room, at: Point(35, 35)), shows: .red, "inside, still shown")
        }
    }

    /// A press on a layout where it holds nothing reaches what stands beneath it once the tree lets input through.
    @MainActor
    static func throughIt(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).letsAPressThroughWhereItHoldsNothing", proves: [
            Covered(LayoutContract.letsInputThrough, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let through = State(wrappedValue: false)
            s.start {
                VStack {
                    ZStack {
                        Rectangle()
                            .fill(.blue)
                            .id("beneath")
                        Holding.layout(element, through: through.wrappedValue) {
                            Rectangle()
                                .fill(.red)
                                .width(20)
                                .height(20)
                                .horizontalAlignment(.start)
                                .verticalAlignment(.start)
                        }
                    }
                    .width(100).height(100)
                    Button("Through").onClicked { through.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let beneath = try s.element("beneath")
            s.expect(try s.reaches(beneath, at: Point(60, 60)), false, "the layout over it takes the press")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.reaches(beneath, at: Point(60, 60)) }
            s.expect(try s.reaches(beneath, at: Point(60, 60)), true, "let through where it holds nothing")
        }
    }
}

extension LayoutTests {
    /// A layout standing a page whole reaches out under what stands over the page - a window's bar, a status bar, a
    /// home indicator - where the tree says it ignores the safe area, its room the larger by it and
    /// holding the one it stood in, and stands back clear of it told to ignore none.
    @MainActor
    static func underTheBars(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).runsUnderWhatStandsOverItsPageWhereItIgnoresTheSafeArea", proves: [
            Covered(LayoutContract.ignoresSafeArea, on: element),
        ]) { s in
            let edges = State(wrappedValue: SafeAreaEdges.none)
            let frames = Received<[Double]>()
            s.start {
                Holding.layout(element, ignores: edges.wrappedValue, heard: { frames.values.append($0) }) {
                    Rectangle()
                        .fill(.red)
                }
                .title("Under")
            }

            // A phone's bars, where the host's test window stands under none.
            s.standUnderSystemBars(top: 24, bottom: 48)

            // Its room in the window: top, bottom, left, right.
            let room = { () -> [Double]? in
                guard let frame = frames.values.last else { return nil }
                let (corner, size) = (FrameReport.inWindow(frame), FrameReport.size(frame))
                return [corner[1], corner[1] + size[1], corner[0], corner[0] + size[0]]
            }
            s.settle { room() != nil }
            let clear = room() ?? []

            edges.wrappedValue = .all
            s.settle { room() != nil && room() != clear }
            let under = room() ?? []
            let holds = under.count == 4 && clear.count == 4 && under[0] <= clear[0] && under[1] >= clear[1]
                && under[2] <= clear[2] && under[3] >= clear[3]
            s.expect(holds && under != clear, true, "under what stands over it: \(under) around \(clear)")

            edges.wrappedValue = .none
            s.settle { room() == clear }
            s.expect(room(), clear, "and clear of it again")
        }
    }
}

/// A layout of each kind holding a view, as a layout's cases need it.
@MainActor
enum Holding {
    /// A layout of `element`'s kind holding `content`, clipping, letting input through and ignoring the safe area as
    /// said, as large as said where it is and then at its room's corner, its frames told to `heard`.
    static func layout(
        _ element: String, clips: Bool = false, through: Bool = false, width: Double? = nil, height: Double? = nil,
        ignores: SafeAreaEdges = .none, heard: (@MainActor ([Double]) -> Void)? = nil, _ content: () -> any View
    ) -> AnyView {
        let held = AnyView(content())
        var worn: [any Worn] = [
            Write(LayoutContract.clipsContent, clips), Write(LayoutContract.letsInputThrough, through),
            Write(LayoutContract.ignoresSafeArea, ignores),
        ]
        if let heard { worn.append(Hear(ViewContract.frameChanged, heard)) }
        if let width {
            worn += [Write(VisualElementContract.width, width), Write(ViewContract.horizontalAlignment, Alignment.start)]
        }
        if let height {
            worn += [Write(VisualElementContract.height, height), Write(ViewContract.verticalAlignment, Alignment.start)]
        }
        let dressing = Dressing(worn, id: "layout")
        let layout: any View = switch element {
        case "Grid": dressing.dress(Grid { held })
        case "HStack": dressing.dress(HStack { held })
        case "ZStack": dressing.dress(ZStack { held })
        case "PhaseLayout": dressing.dress(AnyView(Specimens.phaseLayout(holding: held)))
        default: dressing.dress(VStack { held })
        }
        return AnyView(layout)
    }
}
