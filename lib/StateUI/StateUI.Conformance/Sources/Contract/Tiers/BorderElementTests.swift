// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BorderElementContract` on a host: an element stands in the shape the tree gives it, outlined in its colour and
/// width, over what the tree lets show through it, and changes as the tree changes them - on every element wearing
/// the tier.
@_spi(Host) public enum BorderElementTests: ConformanceFamily {
    public static let name = "BorderElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(BorderElementContract.self).flatMap { element in
            [
                Aspects.holds(BorderElementContract.shape, on: element, .rectangle, then: .roundedRectangle(12),
                              with: Words.on(element) + outlined),
                Aspects.holds(BorderElementContract.stroke, on: element, .solidColor(.red), then: .solidColor(.blue),
                              with: Words.on(element) + [Write(BorderElementContract.lineWidth, 2)]),
                Aspects.holds(BorderElementContract.lineWidth, on: element, 2, then: 4,
                              with: Words.on(element) + [Write(BorderElementContract.stroke, Brush.solidColor(.red))]),
                backdrop(element),
            ] + boxCases(element)
        }
    }

    /// The element shows what the tree lets show through it, and what the tree changes it to - glass where the host
    /// draws glass, else the material standing in for it, whose colour a host with no materials paints.
    static func backdrop(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).backdrop.showsWhatTheTreeGivesOrWhatStandsInForIt", proves: [
            Covered(BorderElementContract.backdrop, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: Backdrop.material(.thin))
            let changed = Backdrop.glass(.clear)
            s.start {
                Specimens.page(element, Words.on(element) + [Write(BorderElementContract.backdrop, value.wrappedValue)],
                               beside: [Button("Change").onClicked { value.wrappedValue = changed }.id("change")])
            }
            let specimen = try s.specimen(element)
            @MainActor func shows(_ wanted: Backdrop) throws -> Bool {
                let held = try s.held(BorderElementContract.backdrop, on: specimen)
                return held == wanted || held == .material(wanted.material)
            }
            s.expect(try shows(.material(.thin)), true, "the material the tree gave")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try shows(changed) }
            s.expect(try shows(changed), true, "the glass the tree changed it to, or the material standing in for it")
        }
    }

    /// An outline to show the shape in: an element that draws nothing shows no shape.
    static var outlined: [any Worn] {
        [Write(BorderElementContract.stroke, Brush.solidColor(.red)), Write(BorderElementContract.lineWidth, 2)]
    }
}
