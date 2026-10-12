// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SpacerContract` on a host: a spacer takes the room its stack's other children leave, so the child after it
/// stands at the stack's far end - each case made for both stacks.
@_spi(Host) public enum SpacerTests: ConformanceFamily {
    public static let name = "Spacer"

    public static var cases: [ConformanceCase] {
        [Aspects.standsAlone("Spacer"), takesTheRoomLeft("HStack"), takesTheRoomLeft("VStack")]
    }

    /// In a stack 200 long, two boxes of 20 and a spacer between them: the second box stands at 180.
    @MainActor
    static func takesTheRoomLeft(_ stack: String) -> ConformanceCase {
        ConformanceCase("\(stack).aSpacerTakesTheRoomItsStackLeaves", proves: [
            Covered(SpacerContract.self),
        ], needs: [Covered(ViewContract.frameChanged, on: "ColorBox")]) { s in
            let last = Received<[Double]>()
            s.start {
                VStack {
                    Stacked.stack(stack, spacing: 8) {
                        [
                            ColorBox(.red).width(20).height(20),
                            Spacer(),
                            ColorBox(.blue).width(20).height(20)
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
            s.settle { last.values.last.map(FrameReport.place)?[along] == 180 }
            s.expect(last.values.last.map(FrameReport.place)?[along], 180, "at the stack's far end")
        }
    }
}
