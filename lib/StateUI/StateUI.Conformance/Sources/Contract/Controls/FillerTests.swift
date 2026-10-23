// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `FillerContract` on a host: a filler is made of its material, showing another as the tree writes it, and takes
/// the room its stack's other children leave, alike with a spacer - that case made for both stacks.
@_spi(Host) public enum FillerTests: ConformanceFamily {
    public static let name = "Filler"

    public static var cases: [ConformanceCase] {
        [Aspects.standsAlone("Filler"), madeOfItsMaterial, takesTheRoomLeft("HStack"), takesTheRoomLeft("VStack")]
    }

    /// A filler is made of the color the tree gives it, corner to corner, and then of the one the tree writes.
    @MainActor
    static var madeOfItsMaterial: ConformanceCase {
        ConformanceCase("aFillerIsMadeOfItsMaterial", proves: [
            Covered(FillerContract.self),
        ], needs: [Covered(VisualElementContract.background, on: "Filler"), Covered(ButtonContract.clicked)]) { s in
            let warm = State(wrappedValue: true)
            s.start {
                VStack {
                    Filler(warm.wrappedValue ? Color.red : Color.blue)
                        .width(100)
                        .height(40)
                        .id("filler")
                    Button("Cool").onClicked { warm.wrappedValue = false }.id("change")
                }
                .horizontalAlignment(.start)
            }
            let filler = try s.element("filler")

            try s.settle { try s.shows(.red, on: filler, at: Point(50, 20)) }
            s.expect(try s.color(of: filler, at: Point(50, 20)), shows: .red, "its middle, its material")
            s.expect(
                try s.color(of: filler, at: Point(2, 2)), shows: .red, "its corner: a filler given no shape is a rectangle")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.shows(.blue, on: filler, at: Point(50, 20)) }
            s.expect(try s.color(of: filler, at: Point(50, 20)), shows: .blue, "the material the tree wrote")
        }
    }

    /// In a stack 200 long, a box of 20 at each end and a filler and a spacer between them, 8 apart: the 136 the
    /// boxes and the spacing leave is shared alike, the filler standing at 28 and 68 long, across the whole stack.
    @MainActor
    static func takesTheRoomLeft(_ stack: String) -> ConformanceCase {
        ConformanceCase("\(stack).aFillerTakesTheRoomItsStackLeaves", proves: [
            Covered(FillerContract.self),
        ], needs: [Covered(ViewContract.frameChanged, on: "Filler")]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    Stacked.stack(stack, spacing: 8) {
                        [
                            Rectangle()
                                .fill(.red)
                                .width(20)
                                .height(20),
                            Filler(.blue)
                                .onEvent(ViewContract.frameChanged) { frames.values.append($0) },
                            Spacer(),
                            Rectangle()
                                .fill(.red)
                                .width(20)
                                .height(20),
                        ]
                    }
                    .width(stack == "HStack" ? 200 : 40)
                    .height(stack == "HStack" ? 40 : 200)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let expected: [Double] = stack == "HStack" ? [28, 0, 68, 40] : [0, 28, 40, 68]
            s.settle { frames.values.last.map(FrameReport.place) == expected }
            s.expect(frames.values.last.map(FrameReport.place), expected, "half the room left, across the stack")
        }
    }
}
