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
            Aspects.standsAlone("Image"),
            ConformanceCase("aPictureFromBytesStandsAtItsOwnSize", proves: [
                Covered(ImageContract.source),
            ]) { s in
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        Image(ImageSource(bytes: Self.redPixels))
                            .onEvent(ViewContract.frameChanged) { frames.values.append($0) }.id("image")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                s.settle { frames.values.last.map(FrameReport.place) == [0, 0, 4, 2] }
                s.expect(frames.values.last.map(FrameReport.place), [0, 0, 4, 2], "the bytes' pixels")
                // A host may draw the pixels a frame after it has read their size.
                let image = try s.element("image")
                try s.settle { try s.color(of: image, at: Point(2, 1)) != nil }
                s.expect(try s.color(of: image, at: Point(2, 1)), shows: Color(red: 255, green: 0, blue: 0), "the bytes' colour")
            },
            ConformanceCase("anIconOfThePlatformsIsDrawn", proves: [
                Covered(ImageContract.source),
            ]) { s in
                s.start {
                    VStack { Image(.icon(.add)).contentMode(.fit).width(32).height(32).id("image") }
                        .horizontalAlignment(.start)
                        .verticalAlignment(.start)
                }
                let image = try s.element("image")
                let grid = stride(from: 1.0, to: 32, by: 2).flatMap { x in stride(from: 1.0, to: 32, by: 2).map { Point(x, $0) } }
                try s.settle { try grid.contains { try s.color(of: image, at: $0) != nil } }
                s.expect(try grid.contains { try s.color(of: image, at: $0) != nil }, true, "the platform's plus drawn")
            },
            ConformanceCase("aPictureStandsAtItsOwnSize", proves: [
                Covered(ImageContract.source),
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
            ConformanceCase("aDrawingAskedForByABitmapsNameStandsAtItsDeclaredSize", proves: [
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
            ConformanceCase("thePictureTheTreeChangesItToReplacesIt", proves: [
                Covered(ImageContract.source),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
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
            ConformanceCase("aPictureTheApplicationDoesNotHaveShowsNothing", proves: [
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

    /// A PNG of red pixels, 4 across and 2 down.
    static let redPixels: [UInt8] = [
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0, 0, 0, 2, 8, 2, 0, 0, 0, 240, 202,
        234, 52, 0, 0, 0, 16, 73, 68, 65, 84, 120, 218, 99, 248, 207, 192, 0, 71, 12, 200, 28, 0, 111, 170, 7, 249,
        104, 221, 175, 167, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
    ]
}
