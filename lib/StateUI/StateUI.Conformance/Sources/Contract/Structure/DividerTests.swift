// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `DividerContract` on a host: a divider is a line across its stack, between the children it parts.
@_spi(Host) public enum DividerTests: ConformanceFamily {
    public static let name = "Divider"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Divider"),
            ConformanceCase("aLineStandsAcrossItsStack", proves: [
                Covered(DividerContract.self),
            ], needs: [Covered(ViewContract.frameChanged, on: "Divider")]) { s in
                let line = Received<[Double]>()
                let below = Received<[Double]>()
                s.start {
                    VStack {
                        VStack {
                            Rectangle().fill(.red).width(40).height(20)
                            Divider().onEvent(ViewContract.frameChanged) { line.values.append($0) }
                            Rectangle().fill(.blue).width(40).height(20)
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
