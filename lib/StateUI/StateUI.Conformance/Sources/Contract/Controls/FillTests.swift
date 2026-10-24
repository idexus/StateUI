// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `FillContract` on a host: a fill is made of its material, showing another as the tree writes it, takes the room a
/// ZStack offers it, and along a stack takes no room of its own - that case made for both stacks.
@_spi(Host) public enum FillTests: ConformanceFamily {
    public static let name = "Fill"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Fill"), madeOfItsMaterial, takesTheRoomOffered,
            takesNoRoomAlong("HStack"), takesNoRoomAlong("VStack"),
        ]
    }

    /// A fill is made of the color the tree gives it, corner to corner, and then of the one the tree writes.
    @MainActor
    static var madeOfItsMaterial: ConformanceCase {
        ConformanceCase("aFillIsMadeOfItsMaterial", proves: [
            Covered(FillContract.self),
        ], needs: [Covered(VisualElementContract.background, on: "Fill"), Covered(ButtonContract.clicked)]) { s in
            let warm = State(wrappedValue: true)
            s.start {
                VStack {
                    Fill(warm.wrappedValue ? Color.red : Color.blue)
                        .width(100)
                        .height(40)
                        .id("fill")
                    Button("Cool").onClicked { warm.wrappedValue = false }.id("change")
                }
                .horizontalAlignment(.start)
            }
            let fill = try s.element("fill")

            try s.settle { try s.shows(.red, on: fill, at: Point(50, 20)) }
            s.expect(try s.color(of: fill, at: Point(50, 20)), shows: .red, "its middle, its material")
            s.expect(
                try s.color(of: fill, at: Point(2, 2)), shows: .red, "its corner: a fill given no shape is a rectangle")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.shows(.blue, on: fill, at: Point(50, 20)) }
            s.expect(try s.color(of: fill, at: Point(50, 20)), shows: .blue, "the material the tree wrote")
        }
    }

    /// In a ZStack 120 by 80 a fill stating no size stands in the whole room.
    @MainActor
    static var takesTheRoomOffered: ConformanceCase {
        ConformanceCase("aFillTakesTheRoomAZStackOffers", proves: [
            Covered(FillContract.self),
        ], needs: [Covered(ViewContract.frameChanged, on: "Fill")]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    ZStack {
                        Fill(.blue)
                            .onEvent(ViewContract.frameChanged) { frames.values.append($0) }
                    }
                    .width(120)
                    .height(80)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { frames.values.last.map(FrameReport.place) == [0, 0, 120, 80] }
            s.expect(frames.values.last.map(FrameReport.place), [0, 0, 120, 80], "the room its ZStack offers")
        }
    }

    /// In a stack 200 long, a fill stating no length and a box of 20, 8 apart: the fill takes no room along the stack,
    /// so the box stands at 8.
    @MainActor
    static func takesNoRoomAlong(_ stack: String) -> ConformanceCase {
        ConformanceCase("\(stack).aFillTakesNoRoomAlongItsStack", proves: [
            Covered(FillContract.self),
        ], needs: [Covered(ViewContract.frameChanged, on: "Rectangle")]) { s in
            let last = Received<[Double]>()
            s.start {
                VStack {
                    Stacked.stack(stack, spacing: 8) {
                        [
                            Fill(.blue),
                            Rectangle()
                                .fill(.red)
                                .width(20)
                                .height(20)
                                .onEvent(ViewContract.frameChanged) { last.values.append($0) },
                        ]
                    }
                    .width(stack == "HStack" ? 200 : 40)
                    .height(stack == "HStack" ? 40 : 200)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let along = stack == "HStack" ? 0 : 1
            s.settle { last.values.last.map(FrameReport.place)?[along] == 8 }
            s.expect(last.values.last.map(FrameReport.place)?[along], 8, "right after the fill and the spacing")
        }
    }
}
