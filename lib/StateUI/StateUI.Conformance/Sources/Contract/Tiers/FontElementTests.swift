// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `FontElementContract` on a host: words stand in the step of the platform's type ramp, the family, size, weight
/// and slant the tree gives them, scaling with the user's text size as it says, and change as the tree changes them -
/// on every element wearing the tier.
@_spi(Host) public enum FontElementTests: ConformanceFamily {
    public static let name = "FontElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(FontElementContract.self).flatMap { element in
            [
                Aspects.holds(FontElementContract.fontSize, on: element, 14, then: 20, with: Words.on(element)),
                eachWeightStands(on: element),
                Aspects.holds(FontElementContract.fontAttributes, on: element, .none, then: .italic,
                              with: Words.on(element)),
                theStylesStandInTheRampsOrder(on: element),
                theTreesSizeAndWeightStandOverTheStyle(on: element),
                Aspects.holds(FontElementContract.fontFamily, on: element, "Arial", then: "Courier New", with: Words.on(element)),
                Aspects.holds(FontElementContract.isFontAutoScalingEnabled, on: element, true, then: false,
                              with: Words.on(element)),
            ]
        }
    }

    /// `element`'s words stand at each of the four weights the tree gives them in turn, from regular to bold.
    @MainActor static func eachWeightStands(on element: String) -> ConformanceCase {
        ConformanceCase("\(element).fontWeight.standsAtEachWeightTheTreeGives", proves: [
            Covered(FontElementContract.fontWeight, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let weight = State(wrappedValue: FontWeight.regular)
            s.start {
                Specimens.page(element, Words.on(element) + [Write(FontElementContract.fontWeight, weight.wrappedValue)],
                               beside: [
                                   Button("Heavier").onClicked {
                                       weight.wrappedValue = FontWeight(rawValue: weight.wrappedValue.rawValue + 1) ?? .bold
                                   }.id("heavier"),
                               ])
            }
            let specimen = try s.specimen(element)
            s.expect(try s.held(FontElementContract.fontWeight, on: specimen), .regular, "the weight the tree gave")
            for heavier in [FontWeight.medium, .semibold, .bold] {
                try s.perform(.activate, on: s.element("heavier"))
                try s.settle { try s.held(FontElementContract.fontWeight, on: specimen) == heavier }
                s.expect(try s.held(FontElementContract.fontWeight, on: specimen), heavier,
                         "the weight the tree changed it to")
            }
        }
    }

    /// `element`'s words stand at the sizes of the platform's type ramp, each style in turn: a display larger than a
    /// title, a title than a subtitle, a subtitle than the body, the body than a caption, and a headline heavier than
    /// the body.
    @MainActor static func theStylesStandInTheRampsOrder(on element: String) -> ConformanceCase {
        ConformanceCase("\(element).textStyle.standsInTheRampsOrder", proves: [
            Covered(FontElementContract.textStyle, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            // Each next style changes the size, so a step is seen to have landed.
            let order: [TextStyle] = [.display, .title, .subtitle, .body, .caption, .headline]
            let step = State(wrappedValue: 0)
            s.start {
                Specimens.page(element, Words.on(element) + [Write(FontElementContract.textStyle, order[step.wrappedValue])],
                               beside: [Button("Next").onClicked { step.wrappedValue += 1 }.id("next")])
            }
            let specimen = try s.specimen(element)
            var sizes: [TextStyle: Double] = [:]
            var weights: [TextStyle: FontWeight] = [:]
            for (index, style) in order.enumerated() {
                if index > 0 {
                    let before = sizes[order[index - 1]]
                    try s.perform(.activate, on: s.element("next"))
                    try s.settle { try s.held(FontElementContract.fontSize, on: specimen) != before }
                }
                sizes[style] = try s.held(FontElementContract.fontSize, on: specimen)
                weights[style] = try s.held(FontElementContract.fontWeight, on: specimen)
            }
            let ramp = [TextStyle.display, .title, .subtitle, .body, .caption].map { sizes[$0] ?? .nan }
            s.expect(zip(ramp, ramp.dropFirst()).allSatisfy { $0 > $1 }, true,
                     "display, title, subtitle, body and caption from the largest down: \(ramp)")
            s.expect((weights[.headline]?.rawValue ?? -1) > (weights[.body]?.rawValue ?? 4), true,
                     "a headline heavier than the body: \(String(describing: weights[.headline])) over "
                         + String(describing: weights[.body]))
        }
    }

    /// The size and the weight the tree gives `element`'s words stand over its style's.
    @MainActor static func theTreesSizeAndWeightStandOverTheStyle(on element: String) -> ConformanceCase {
        ConformanceCase("\(element).textStyle.givesWayToTheTreesSizeAndWeight", proves: [
            Covered(FontElementContract.textStyle, on: element),
        ], needs: [Covered(FontElementContract.fontSize, on: element), Covered(FontElementContract.fontWeight, on: element)]) { s in
            s.start {
                Specimens.page(element, Words.on(element) + [
                    Write(FontElementContract.textStyle, TextStyle.title), Write(FontElementContract.fontSize, 13.0),
                    Write(FontElementContract.fontWeight, FontWeight.medium),
                ])
            }
            let specimen = try s.specimen(element)
            s.expect(try s.held(FontElementContract.fontSize, on: specimen), 13, within: 0.01, "the tree's size")
            s.expect(try s.held(FontElementContract.fontWeight, on: specimen), .medium, "the tree's weight")
        }
    }
}
