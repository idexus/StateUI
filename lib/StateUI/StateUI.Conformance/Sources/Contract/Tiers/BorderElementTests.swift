// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BorderElementContract` on a host: an element stands in the shape the tree gives it, outlined in its color and
/// width, and changes as the tree changes them - on every element wearing the tier.
@_spi(Host) public enum BorderElementTests: ConformanceFamily {
    public static let name = "BorderElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(BorderElementContract.self).flatMap { element in
            [
                Aspects.holds(BorderElementContract.shape, on: element, .rectangle, then: .roundedRectangle(12),
                              with: Words.on(element) + outlined + room),
                Aspects.holds(BorderElementContract.stroke, on: element, .solidColor(.red), then: .solidColor(.blue),
                              with: Words.on(element) + [Write(BorderElementContract.lineWidth, 2)]),
                Aspects.holds(BorderElementContract.lineWidth, on: element, 2, then: 4,
                              with: Words.on(element) + [Write(BorderElementContract.stroke, Brush.solidColor(.red))]),
            ] + boxCases(element)
        }
    }

    /// A box of 60 by 40 at the top left, room for a corner of 12: an empty layout has none to round.
    @MainActor
    static var room: [any Worn] {
        [
            Write(VisualElementContract.width, 60), Write(VisualElementContract.height, 40),
            Write(ViewContract.horizontalAlignment, Alignment.start),
        ]
    }

    /// An outline to show the shape in: an element that draws nothing shows no shape.
    @MainActor
    static var outlined: [any Worn] {
        [Write(BorderElementContract.stroke, Brush.solidColor(.red)), Write(BorderElementContract.lineWidth, 2)]
    }
}
