// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `FilledShapeContract` on a host: a shape enclosing an area is filled as the tree says, and in the fill the tree
/// changes it to; each case made for every shape wearing the tier.
@_spi(Host) public enum FilledShapeTests: ConformanceFamily {
    public static let name = "FilledShape"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(FilledShapeContract.self).flatMap { element in
            [
                filled(element),
                Aspects.holds(
                    FilledShapeContract.fill, on: element, .solidColor(.red), then: .solidColor(.blue),
                    with: ShapeTests.figure(element)),
            ]
        }
    }

    /// A shape is filled in its color inside its figure, and in the color the tree changes it to.
    @MainActor
    static func filled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isFilledInItsColor", proves: [
            Covered(FilledShapeContract.fill, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let blue = State(wrappedValue: false)
            s.start {
                Specimens.page(element, ShapeTests.figure(element) + [
                    Write(FilledShapeContract.fill, Brush.solidColor(blue.wrappedValue ? .blue : .red)),
                    Write(VisualElementContract.width, 40), Write(VisualElementContract.height, 40),
                ], beside: [Button("Blue").onClicked { blue.wrappedValue = true }.id("change")])
            }
            let shape = try s.specimen(element)
            let inside = Point(20, 20)
            try s.settle { try s.shows(.red, on: shape, at: inside) }
            s.expect(try s.color(of: shape, at: inside), shows: .red)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.shows(.blue, on: shape, at: inside) }
            s.expect(try s.color(of: shape, at: inside), shows: .blue, "the color the tree changed it to")
        }
    }
}
