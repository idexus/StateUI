// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `LayoutContract` on a host: a layout cuts what it holds to its outline where it clips and not otherwise, lets a
/// press through where nothing it holds stands where it says so, and keeps clear of the edges it avoids - each case
/// made for every layout.
@_spi(Host) public enum LayoutTests: ConformanceFamily {
    public static let name = "Layout"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(LayoutContract.self).flatMap { element in
            [
                clipped(element), throughIt(element),
                Aspects.holds(LayoutContract.avoidsSafeArea, on: element, .uniform(.container), then: .uniform(.none)),
                Aspects.holds(LayoutContract.clipsContent, on: element, false, then: true),
                Aspects.holds(LayoutContract.letsInputThrough, on: element, false, then: true),
            ]
        }
    }

    /// What a layout holds drawn past its edge - moved there, which its arithmetic does not see - shows until the tree
    /// says it clips, and then shows no more.
    static func clipped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).cutsWhatItHoldsToItsOutlineWhereItClips", covers: [
            Covered(LayoutContract.clipsContent, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let clips = State(wrappedValue: false)
            s.start {
                VStack {
                    ZStack {
                        Holding.layout(element, clips: clips.wrappedValue, width: 40, height: 40) {
                            ColorBox(.red).width(20).height(20).horizontalAlignment(.start).verticalAlignment(.start)
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
            try s.settle { try s.color(of: room, at: Point(45, 45)) == .red }
            s.expect(try s.color(of: room, at: Point(45, 45)), .red, "past its edge, shown")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: room, at: Point(45, 45)) == nil }
            s.expect(try s.color(of: room, at: Point(45, 45)), nil, "cut once it clips")
            s.expect(try s.color(of: room, at: Point(35, 35)), .red, "inside, still shown")
        }
    }

    /// A press on a layout where it holds nothing reaches what stands beneath it once the tree lets input through.
    static func throughIt(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).letsAPressThroughWhereItHoldsNothing", covers: [
            Covered(LayoutContract.letsInputThrough, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let through = State(wrappedValue: false)
            s.start {
                VStack {
                    ZStack {
                        ColorBox(.blue).id("beneath")
                        Holding.layout(element, through: through.wrappedValue) {
                            ColorBox(.red).width(20).height(20).horizontalAlignment(.start).verticalAlignment(.start)
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

/// A layout of each kind holding a view, as a layout's cases need it.
enum Holding {
    /// A layout of `element`'s kind holding `content`, clipping and letting input through as said, as large as
    /// said where it is and then at its room's corner.
    static func layout(
        _ element: String, clips: Bool = false, through: Bool = false, width: Double? = nil, height: Double? = nil,
        _ content: () -> any View
    ) -> any View {
        let held = content()
        var worn: [any Worn] = [Write(LayoutContract.clipsContent, clips), Write(LayoutContract.letsInputThrough, through)]
        if let width {
            worn += [Write(VisualElementContract.width, width), Write(ViewContract.horizontalAlignment, Alignment.start)]
        }
        if let height {
            worn += [Write(VisualElementContract.height, height), Write(ViewContract.verticalAlignment, Alignment.start)]
        }
        let dressing = Dressing(worn, id: "layout")
        switch element {
        case "Grid": return dressing.dress(Grid { held })
        case "HStack": return dressing.dress(HStack { held })
        case "ZStack": return dressing.dress(ZStack { held })
        default: return dressing.dress(VStack { held })
        }
    }
}
