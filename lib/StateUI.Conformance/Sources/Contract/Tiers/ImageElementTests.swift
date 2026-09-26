// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ImageElementContract` on a host: a picture is placed in its room as its aspect says - fitted whole, filling it,
/// stretched across it, or centred at its own size - and the aspect the tree changes it to held; each case made for
/// every element wearing the tier.
///
/// The picture is the suite's test_wide.svg: 40 by 20, of one colour.
@_spi(Host) public enum ImageElementTests: ConformanceFamily {
    public static let name = "ImageElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(ImageElementContract.self).flatMap { element in
            [
                Aspects.holds(ImageElementContract.aspect, on: element, .fit, then: .fill, with: picture(element)),
            ]
        } + [
            placed(.fit, in: (30, 30), filled: [(15, 15)], empty: [(15, 3), (15, 27)]),
            placed(.fill, in: (30, 30), filled: [(1, 1), (15, 15), (28, 28)], empty: []),
            placed(.stretch, in: (30, 30), filled: [(1, 1), (15, 28), (28, 1)], empty: []),
            placed(.center, in: (60, 60), filled: [(30, 30), (12, 22)], empty: [(5, 30), (30, 15)]),
        ]
    }

    /// What `element`'s specimen wears to show the picture.
    static func picture(_ element: String) -> [any Worn] {
        element == "Button"
            ? [Write(ButtonContract.icon, ImageSource("test_wide.svg"))]
            : [Write(ImageContract.source, ImageSource("test_wide.svg"))]
    }

    /// An image's picture placed as `aspect` says in a room of `size` covers the points `filled` and leaves the points
    /// `empty` empty.
    static func placed(
        _ aspect: Aspect, in size: (Double, Double), filled: [(Double, Double)], empty: [(Double, Double)]
    ) -> ConformanceCase {
        ConformanceCase("Image.\(aspect).placesItsPictureSo", covers: [Covered(ImageElementContract.aspect, on: "Image")]) { s in
            s.start {
                VStack {
                    Image("test_wide.svg").aspect(aspect).width(size.0).height(size.1).id("image")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let image = try s.element("image")
            try s.settle { try filled.allSatisfy { try s.color(of: image, at: Point($0.0, $0.1)) != nil } }

            for point in filled {
                s.expect(try s.color(of: image, at: Point(point.0, point.1)) != nil, true, "drawn at \(point)")
            }
            for point in empty {
                s.expect(try s.color(of: image, at: Point(point.0, point.1)), nil, "empty at \(point)")
            }
        }
    }
}
