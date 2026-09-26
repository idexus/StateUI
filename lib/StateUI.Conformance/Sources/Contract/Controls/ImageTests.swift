// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ImageContract` on a host: a picture found by its name stands at its own size - a bitmap's pixels, a drawing's
/// declared size - the picture the tree changes it to replaces it, one the application does not have shows nothing,
/// and a moving picture plays as the tree says.
///
/// Every host's suite holds the two pictures the cases name: test_dot.png, 6 by 4, and test_wide.svg, 40 by 20.
@_spi(Host) public enum ImageTests: ConformanceFamily {
    public static let name = "Image"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPictureStandsAtItsOwnSize", covers: [
                Covered(ImageContract.self), Covered(ImageContract.source),
            ]) { s in
                let frames = Received<[Double]>()
                s.start {
                    VStack { Image("test_dot.png").onEvent(ViewContract.frameChanged) { frames.values.append($0) }.id("image") }
                        .horizontalAlignment(.start)
                        .verticalAlignment(.start)
                }

                s.settle { frames.values.last.map(FrameReport.place) == [0, 0, 6, 4] }
                s.expect(frames.values.last.map(FrameReport.place), [0, 0, 6, 4])
                s.expect(try s.held(ImageContract.source, on: s.element("image")), "test_dot.png")
            },
            ConformanceCase("aDrawingAskedForByABitmapsNameStandsAtItsDeclaredSize", covers: [
                Covered(ImageContract.source),
            ]) { s in
                let frames = Received<[Double]>()
                s.start {
                    VStack { Image("test_wide.png").onEvent(ViewContract.frameChanged) { frames.values.append($0) }.id("image") }
                        .horizontalAlignment(.start)
                        .verticalAlignment(.start)
                }

                s.settle { frames.values.last.map(FrameReport.place) == [0, 0, 40, 20] }
                s.expect(frames.values.last.map(FrameReport.place), [0, 0, 40, 20], "the drawing test_wide.svg")
            },
            ConformanceCase("thePictureTheTreeChangesItToReplacesIt", covers: [
                Covered(ImageContract.source), Covered(ButtonContract.clicked),
            ]) { s in
                let wide = State(wrappedValue: false)
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        Image(wide.wrappedValue ? "test_wide.svg" : "test_dot.png")
                            .horizontalAlignment(.start)
                            .onEvent(ViewContract.frameChanged) { frames.values.append($0) }.id("image")
                        Button("Wide").onClicked { wide.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { frames.values.last.map(FrameReport.size) == [6, 4] }

                try s.perform(.activate, on: s.element("change"))
                s.settle { frames.values.last.map(FrameReport.size) == [40, 20] }
                s.expect(frames.values.last.map(FrameReport.size), [40, 20])
                s.expect(try s.held(ImageContract.source, on: s.element("image")), "test_wide.svg")
            },
            ConformanceCase("aPictureTheApplicationDoesNotHaveShowsNothing", covers: [
                Covered(ImageContract.source),
            ]) { s in
                let frames = Received<[Double]>()
                s.start {
                    VStack { Image("nowhere.png").onEvent(ViewContract.frameChanged) { frames.values.append($0) }.id("image") }
                        .horizontalAlignment(.start)
                        .verticalAlignment(.start)
                }
                let image = try s.element("image")
                s.settle { !frames.values.isEmpty }

                s.expect(try s.color(of: image, at: Point(0, 0)), nil, "nothing drawn")
            },
            Aspects.holds(ImageContract.isAnimating, on: "Image", false, then: true,
                          with: [Write(ImageContract.source, "test_dot.png")]),
        ]
    }
}
