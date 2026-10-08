// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A material on a state the host carries: laid as lanes and read back whole, a pair as its half in force, and
/// handed on as `$x` with no body made its reader.
final class MaterialChannelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// Every kind of material comes back from its lanes as it was laid.
    func testAMaterialIsLaidAndReadBackWhole() {
        let materials: [Material] = [
            .color(Color("#512BD4")),
            .gradient(.linearGradient(
                [GradientStop(Color("#7C5CFC"), 0), GradientStop(Color("#E879A9"), 1)],
                startPoint: Point(0, 0), endPoint: Point(1, 1))),
            .blur(.thin),
            .blur(.thick.tint(Color("#512BD4").opacity(0.15))),
            .glass(Glass.clear.tint(Color("#0F766E")).isInteractive(true)),
        ]
        withTheme(.light) {
            for material in materials {
                XCTAssertEqual(Material(carried: material.carried), material, "\(material.propValue)")
            }
        }
    }

    /// A pair lies as its half in force, and a half that is none as nothing; the host reads a blur with its
    /// stand-in for the theme in force.
    func testAPairLiesAsTheHalfInForce() {
        let pair = Material(light: .color(Color("#512BD4")), dark: nil)
        withTheme(.light) {
            XCTAssertEqual(Material.propValue(lanes: lanes(of: pair)), Color("#512BD4").propValue)
        }
        withTheme(.dark) {
            XCTAssertEqual(Material.propValue(lanes: lanes(of: pair)), PropValue.nothing)
            let standIn = Material.propValue(lanes: lanes(of: .blur(.thick)))?.values?.last
            XCTAssertEqual(standIn, Color("#1C1C1E").opacity(0.88).propValue, "the dark theme's stand-in")
        }
    }

    /// Handed on as `$x`, a material state reaches its element as a plain value the host reads as a material,
    /// and a write asks for no render: nothing read it at build.
    func testAMaterialHandedOnIsCarriedAndAsksForNoRender() {
        let material = State(wrappedValue: Material.blur(.thin))
        let renders = Renders()

        let patch = renders.render(Text("x").background(material.projectedValue).id("text").node)
        XCTAssertEqual(
            patch.driven?[.background],
            HostStateBinding(state: material.number, mode: .out, kind: .plain, laneKind: .material))
        Renderer.shared.clearInvalidation()

        material.wrappedValue = .glass(.regular)

        XCTAssertFalse(Renderer.shared.needsRender, "nothing read it at build")
        XCTAssertEqual(material.wrappedValue, .glass(.regular))
    }

    private func lanes(of material: Material) -> [Double] {
        guard case .lanes(let lanes) = material.carried else { return [] }
        return lanes
    }
}
