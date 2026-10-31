// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SeparatorContract` on a host: a separator is a line across its stack, between the children it parts.
@_spi(Host) public enum SeparatorTests: ConformanceFamily {
    public static let name = "Separator"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Separator"),
            ConformanceCase("aLineStandsAcrossItsStack", proves: [
                Covered(SeparatorContract.self),
            ], needs: [Covered(ViewContract.frameChanged, on: "Separator")]) { s in
                let line = Received<[Double]>()
                let below = Received<[Double]>()
                s.start {
                    VStack {
                        VStack {
                            Rectangle()
                                .fill(.red)
                                .width(40)
                                .height(20)
                            Separator().onEvent(ViewContract.frameChanged) { line.values.append($0) }
                            Rectangle()
                                .fill(.blue)
                                .width(40)
                                .height(20)
                                .onEvent(ViewContract.frameChanged) { below.values.append($0) }
                        }
                        .spacing(0)
                        .width(200)
                        .horizontalAlignment(.start)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                // A hairline is a pixel thick, a third of a point on a dense screen: read unrounded.
                s.settle { (line.values.last?[3] ?? 0) > 0 && !below.values.isEmpty }
                let place = line.values.last.map(FrameReport.place)
                let thickness = line.values.last?[3] ?? 0
                s.expect(place?[1], 20, "under the first box")
                s.expect(place?[2], 200, "across the whole stack")
                s.expect(thickness, 1.5, within: 1.49, "as thick as a line")
                s.expect(
                    below.values.last.map(FrameReport.place)?[1], (20 + thickness).rounded(), "the next box under the line")
            },
        ]
    }
}
